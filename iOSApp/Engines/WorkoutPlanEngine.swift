import Foundation

struct WorkoutPlanEngine {

    /// Value-type overload — safe to call from a background thread.
    static func generatePlans(
        log: [WorkoutLogEntry],
        exercises: [Exercise],
        readiness: ReadinessState,
        lastPerformance: [UUID: [SetRecord]] = [:],
        weeklyVolume: [BodyRegion: Int] = [:],
        analytics: AnalyticsResult? = nil
    ) -> [GuidedWorkoutPlan] {
        // Cold start: no history — return a single guided intro plan
        guard !log.isEmpty else {
            return [makeIntroductionPlan(exercises: exercises)]
        }

        let daysSince  = daysSinceTrainedByRegion(log: log)
        let intensity  = intensityForScore(readiness.score)
        let fresh      = BodyRegion.allCases.filter { (daysSince[$0] ?? 99) >= 2 }
        let stale      = BodyRegion.allCases.filter { (daysSince[$0] ?? 99) < 2 }
        // Exercises done in the last 2 sessions — deprioritised to encourage muscle rest
        let recentExIds: Set<UUID> = Set(log.prefix(2).flatMap { $0.exercises.map { $0.exercise.id } })

        let primary   = makePlan(exercises: exercises, log: log, lastPerf: lastPerformance,
                                 focus: primarySplit(fresh: fresh, stale: stale, weeklyVolume: weeklyVolume, analytics: analytics),
                                 intensity: intensity, recentExIds: recentExIds, analytics: analytics, readiness: readiness)
        let alternateIntensity: GuidedWorkoutPlan.Intensity = {
            switch intensity {
            case .heavy: return .moderate
            case .moderate, .light: return .light
            }
        }()
        let alternate = makePlan(exercises: exercises, log: log, lastPerf: lastPerformance,
                                 focus: alternateSplit(fresh: fresh, stale: stale, weeklyVolume: weeklyVolume),
                                 intensity: alternateIntensity, recentExIds: recentExIds, analytics: analytics, readiness: readiness)
        let recovery  = makeRecoveryPlan(exercises: exercises, log: log,
                                         lastPerf: lastPerformance, recentExIds: recentExIds)
        return [primary, alternate, recovery]
    }

    /// Convenience overload that reads from the store (main-thread only).
    static func generatePlans(store: SeedStore, readiness: ReadinessState) -> [GuidedWorkoutPlan] {
        generatePlans(log: store.workoutLog, exercises: store.exercises,
                      readiness: readiness, lastPerformance: store.lastPerformanceCache,
                      weeklyVolume: store.homeCache.weeklyVolume,
                      analytics: store.analyticsCache)
    }

    // MARK: - Split Selection

    private static func primarySplit(fresh: [BodyRegion], stale: [BodyRegion],
                                      weeklyVolume: [BodyRegion: Int] = [:],
                                      analytics: AnalyticsResult? = nil) -> [BodyRegion] {
        // V-001: exclude regions at ≥20 sets this week from primary plan
        let capped = Set(weeklyVolume.filter { $0.value >= 20 }.keys)
        let freshFiltered = fresh.filter { !capped.contains($0) }
        let staleFiltered = stale.filter { !capped.contains($0) }

        // T-005: push/pull ratio correction from categoryAnalytics
        if let cats = analytics?.categoryAnalytics, !cats.isEmpty {
            let pushVolume = cats.filter {
                $0.pattern == .horizontalPush || $0.pattern == .verticalPush
            }.reduce(0.0) { $0 + $1.weeklyVolumeAvg }
            let pullVolume = cats.filter {
                $0.pattern == .horizontalPull || $0.pattern == .verticalPull
            }.reduce(0.0) { $0 + $1.weeklyVolumeAvg }
            if pullVolume > 0 {
                let ratio = pushVolume / pullVolume
                if ratio > 1.6 {
                    // Push-heavy — force pull split
                    let pullRegions = [BodyRegion.back, .arms].filter { !capped.contains($0) }
                    if !pullRegions.isEmpty { return pullRegions }
                } else if ratio < 0.7 {
                    // Pull-heavy — force push split
                    let pushRegions = [BodyRegion.chest, .shoulders].filter { !capped.contains($0) }
                    if !pushRegions.isEmpty { return pushRegions }
                }
            }
        }

        if freshFiltered.count >= 2 {
            if freshFiltered.contains(.chest) && freshFiltered.contains(.shoulders) { return [.chest, .shoulders, .arms].filter { !capped.contains($0) } }
            if freshFiltered.contains(.back)  && freshFiltered.contains(.arms)      { return [.back, .arms].filter { !capped.contains($0) } }
            if freshFiltered.contains(.legs)                                         { return [.legs, .core].filter { !capped.contains($0) } }
            return Array(freshFiltered.prefix(3))
        }
        return Array((freshFiltered + staleFiltered).prefix(3))
    }

    private static func alternateSplit(fresh: [BodyRegion], stale: [BodyRegion],
                                       weeklyVolume: [BodyRegion: Int] = [:]) -> [BodyRegion] {
        // V-001: exclude regions at ≥20 sets this week
        let capped = Set(weeklyVolume.filter { $0.value >= 20 }.keys)
        let all = (fresh + stale).filter { !capped.contains($0) }
        if all.contains(.back) && all.contains(.legs)  { return [.back, .legs] }
        if all.contains(.chest) && all.contains(.core) { return [.chest, .core] }
        return Array(all.dropFirst().prefix(3))
    }

    // MARK: - Plan Builders

    private static func makePlan(
        exercises allExercises: [Exercise],
        log: [WorkoutLogEntry],
        lastPerf: [UUID: [SetRecord]],
        focus: [BodyRegion],
        intensity: GuidedWorkoutPlan.Intensity,
        recentExIds: Set<UUID>,
        analytics: AnalyticsResult? = nil,
        readiness: ReadinessState? = nil
    ) -> GuidedWorkoutPlan {
        // T-006: build a set of plateaued exercise IDs from analytics
        let plateauedIds: Set<UUID> = analytics.map { a in
            Set(a.exerciseAnalytics.filter(\.isPlateau).map(\.id))
        } ?? []

        var result: [GuidedExercise] = []
        for region in focus {
            let pool       = allExercises.filter { $0.bodyRegion == region }
            let compounds  = pool.filter(\.isCompound)
            let isolations = pool.filter { !$0.isCompound }

            // T-006: if the top compound is plateaued, try the next-best in same region
            if let top = bestExercise(from: compounds, lastPerf: lastPerf, recentExIds: recentExIds),
               plateauedIds.contains(top.id) {
                let fallback = compounds.filter { $0.id != top.id }
                if let alt = bestExercise(from: fallback, lastPerf: lastPerf, recentExIds: recentExIds) {
                    result.append(guided(alt, intensity: intensity, lastPerf: lastPerf))
                } else {
                    result.append(guided(top, intensity: intensity, lastPerf: lastPerf))
                }
            } else if let main = bestExercise(from: compounds, lastPerf: lastPerf, recentExIds: recentExIds) {
                result.append(guided(main, intensity: intensity, lastPerf: lastPerf))
            }

            if result.count < 5,
               let iso = bestExercise(from: isolations, lastPerf: lastPerf, recentExIds: recentExIds) {
                result.append(guided(iso, intensity: intensity, lastPerf: lastPerf))
            }
        }
        result = Array(result.prefix(6))
        let title   = planTitle(regions: focus, intensity: intensity)
        let minutes = result.count * (intensity == .heavy ? 10 : 7)
        return GuidedWorkoutPlan(
            id: UUID(), title: title,
            subtitle: focus.map(\.rawValue).joined(separator: " · "),
            bodyRegions: focus, exercises: result,
            estimatedMinutes: minutes, intensity: intensity,
            coachNote: smartCoachNote(intensity: intensity, regions: focus,
                                      exercises: result, lastPerf: lastPerf,
                                      readiness: readiness, analytics: analytics)
        )
    }

    private static func makeRecoveryPlan(
        exercises allExercises: [Exercise],
        log: [WorkoutLogEntry],
        lastPerf: [UUID: [SetRecord]],
        recentExIds: Set<UUID>
    ) -> GuidedWorkoutPlan {
        // Pick the 2 regions most needing light work (longest since trained)
        let daysSince = daysSinceTrainedByRegion(log: log)
        let sorted = BodyRegion.allCases
            .filter { $0 != .core } // always add core separately
            .sorted { (daysSince[$0] ?? 99) > (daysSince[$1] ?? 99) }
        // Manually deduplicate while preserving order
        var seen = Set<BodyRegion>()
        let rawPicks: [BodyRegion] = [sorted.first ?? .arms, sorted.dropFirst().first ?? .shoulders, .core]
        let picks: [BodyRegion] = rawPicks.filter { seen.insert($0).inserted }

        let result: [GuidedExercise] = picks.prefix(3).compactMap { region in
            let pool = allExercises.filter { $0.bodyRegion == region && !$0.isCompound }
            return bestExercise(from: pool, lastPerf: lastPerf, recentExIds: recentExIds)
        }.map { guided($0, intensity: .light, lastPerf: lastPerf) }

        let focusLabel = picks.prefix(2).map(\.rawValue).joined(separator: " & ")
        let minutes = result.count * 6
        return GuidedWorkoutPlan(
            id: UUID(), title: "Active Recovery — \(focusLabel)",
            subtitle: "Light · \(focusLabel)",
            bodyRegions: Array(picks.prefix(3)), exercises: Array(result.prefix(4)),
            estimatedMinutes: minutes, intensity: .light,
            coachNote: "Light movement on \(focusLabel.lowercased()). Keeps blood flowing without adding fatigue."
        )
    }

    private static func makeIntroductionPlan(exercises: [Exercise]) -> GuidedWorkoutPlan {
        // Deterministic: first compound in each key region sorted by name
        let focusRegions: [BodyRegion] = [.legs, .chest, .back, .shoulders, .core]
        let picks: [GuidedExercise] = focusRegions.compactMap { region in
            exercises
                .filter { $0.bodyRegion == region && $0.isCompound }
                .sorted { $0.name < $1.name }
                .first
                .map { guided($0, intensity: .light, lastPerf: [:]) }
        }
        return GuidedWorkoutPlan(
            id: UUID(),
            title: "First Workout",
            subtitle: "Full Body · Getting Started",
            bodyRegions: [.legs, .chest, .back, .shoulders, .core],
            exercises: Array(picks.prefix(5)),
            estimatedMinutes: 30,
            intensity: .light,
            coachNote: "Your first session — the goal isn't performance, it's learning the movements and finding starting weights. Start lighter than you think you need to. Keep RPE at 6/10 — controlled, never grinding. After 3 sessions the app will personalise weights and plans based on your actual data."
        )
    }

    // MARK: - Exercise Scoring

    /// Picks the best exercise from a pool using history + progression signals.
    /// Returns nil only when pool is empty.
    private static func bestExercise(
        from pool: [Exercise],
        lastPerf: [UUID: [SetRecord]],
        recentExIds: Set<UUID>
    ) -> Exercise? {
        guard !pool.isEmpty else { return nil }
        return pool.max {
            exerciseScore($0, lastPerf: lastPerf, recentExIds: recentExIds) <
            exerciseScore($1, lastPerf: lastPerf, recentExIds: recentExIds)
        }
    }

    private static func exerciseScore(
        _ exercise: Exercise,
        lastPerf: [UUID: [SetRecord]],
        recentExIds: Set<UUID>
    ) -> Double {
        var s = 50.0

        guard let sets = lastPerf[exercise.id] else {
            // No history: lower priority — we can't set a meaningful target weight yet
            return s - 5
        }

        // Has history: familiar movement with known weights
        s += 20

        // Penalise exercises trained in last 2 sessions — give those muscles rest
        if recentExIds.contains(exercise.id) { s -= 18 }

        // Performance quality from last session
        let actual = sets.reduce(0) { $0 + $1.reps }
        let target = sets.reduce(0) { $0 + max($1.targetReps, 1) }
        let pct    = Double(actual) / Double(max(target, 1))
        if pct >= 0.90      { s += 12 }  // was on target → reinforce this exercise
        else if pct < 0.60  { s -= 8  }  // was struggling → rest before returning

        // Ready-to-progress bonus: all sets hit target → recommend now so user applies the increase
        let allHit = sets.allSatisfy { $0.targetReps > 0 && $0.reps >= $0.targetReps }
        if allHit { s += 10 }

        return s
    }

    // MARK: - Helpers

    /// Returns the number of calendar days since each body region was last trained.
    /// 99 = never trained.
    private static func daysSinceTrainedByRegion(log: [WorkoutLogEntry]) -> [BodyRegion: Int] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        return Dictionary(uniqueKeysWithValues: BodyRegion.allCases.map { region in
            let lastDate = log
                .filter { $0.exercises.contains(where: { $0.exercise.bodyRegion == region }) }
                .map(\.startedAt)
                .max()
            let days = lastDate.flatMap {
                cal.dateComponents([.day], from: cal.startOfDay(for: $0), to: today).day
            } ?? 99
            return (region, days)
        })
    }

    private static func guided(
        _ exercise: Exercise,
        intensity: GuidedWorkoutPlan.Intensity,
        lastPerf: [UUID: [SetRecord]]
    ) -> GuidedExercise {
        let (sets, reps) = setsAndReps(for: intensity, isCompound: exercise.isCompound)
        let weight = lastPerf[exercise.id]?.first?.weight ?? 0
        return GuidedExercise(exercise: exercise, targetSets: sets, targetReps: reps, targetWeight: weight)
    }

    private static func setsAndReps(for intensity: GuidedWorkoutPlan.Intensity, isCompound: Bool) -> (Int, Int) {
        switch intensity {
        case .heavy:    return isCompound ? (4, 5)  : (3, 8)
        case .moderate: return isCompound ? (3, 8)  : (3, 12)
        case .light:    return isCompound ? (3, 12) : (2, 15)
        }
    }

    private static func intensityForScore(_ score: Int) -> GuidedWorkoutPlan.Intensity {
        switch score {
        case 78...: return .heavy
        case 55..<78: return .moderate
        default:    return .light
        }
    }

    private static func planTitle(regions: [BodyRegion], intensity: GuidedWorkoutPlan.Intensity) -> String {
        let r = regions.map(\.rawValue)
        if r.contains("Chest") && r.contains("Shoulders") { return "Push Day" }
        if r.contains("Back")  && r.contains("Arms")      { return "Pull Day" }
        if r.contains("Legs")                              { return "Leg Day" }
        if r.contains("Chest") && r.contains("Back")      { return "Upper Body" }
        return r.prefix(2).joined(separator: " + ")
    }

    private static func smartCoachNote(
        intensity: GuidedWorkoutPlan.Intensity,
        regions: [BodyRegion],
        exercises: [GuidedExercise],
        lastPerf: [UUID: [SetRecord]],
        readiness: ReadinessState? = nil,
        analytics: AnalyticsResult? = nil
    ) -> String {
        var slots: [String] = []

        // Slot 1: readiness context (highest-magnitude factor)
        if let r = readiness, !r.factors.isEmpty {
            let top = r.factors.sorted { !$0.isPositive && $1.isPositive }.first ?? r.factors[0]
            if r.score >= 78 {
                slots.append("Readiness is high today.")
            } else if r.score < 55 {
                slots.append("Low readiness — \(top.text.lowercased()).")
            } else {
                // moderate: mention the top factor
                slots.append(top.text + ".")
            }
        }

        // Slot 2: key lift — fastest improving or plateauing
        if let a = analytics, !a.exerciseAnalytics.isEmpty {
            let relevant = a.exerciseAnalytics.filter { ea in
                exercises.contains(where: { $0.exercise.id == ea.id })
            }
            if let plateaued = relevant.first(where: { $0.isPlateau }) {
                slots.append("\(plateaued.exercise.name) has stalled — try a different rep range today.")
            } else if let improving = relevant.sorted(by: { $0.slopePerWeek > $1.slopePerWeek }).first,
                      improving.slopePerWeek > 0.5 {
                slots.append("\(improving.exercise.name) is trending up.")
            }
        }

        // Slot 3: watch-out from pattern imbalance OR progression nudge
        let ready = exercises.filter { ex in
            guard let sets = lastPerf[ex.exercise.id] else { return false }
            return sets.allSatisfy { $0.targetReps > 0 && $0.reps >= $0.targetReps }
        }
        if !ready.isEmpty {
            let names = ready.prefix(2).map { $0.exercise.name }.joined(separator: " and ")
            let verb  = ready.count == 1 ? "is" : "are"
            let suffix: String
            switch intensity {
            case .heavy:    suffix = "Push the progression today."
            case .moderate: suffix = "Solid day to apply the increase."
            case .light:    suffix = "Move the weight up and keep the reps clean."
            }
            slots.append("\(names) \(verb) ready for more weight. \(suffix)")
        }

        if !slots.isEmpty {
            let note = slots.prefix(3).joined(separator: " ")
            return String(note.prefix(180))
        }

        // Fallback: intensity-based defaults
        switch intensity {
        case .heavy:
            return "Your readiness is high — a great day to push hard. Focus on progressive overload and full range of motion."
        case .moderate:
            return "Solid day to train. Hit your working sets with good form and leave one rep in reserve."
        case .light:
            return "Keep the effort moderate. Prioritise technique over load and finish feeling energised, not drained."
        }
    }
}
