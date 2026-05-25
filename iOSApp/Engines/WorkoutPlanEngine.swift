import Foundation

struct WorkoutPlanEngine {

    /// Value-type overload — safe to call from a background thread.
    static func generatePlans(
        log: [WorkoutLogEntry],
        exercises: [Exercise],
        readiness: ReadinessState,
        lastPerformance: [UUID: [SetRecord]] = [:]
    ) -> [GuidedWorkoutPlan] {
        let recentRegions = recentlyTrainedRegions(log: log)
        let intensity = intensityForScore(readiness.score)
        let fresh = BodyRegion.allCases.filter { !recentRegions.contains($0) }
        let stale = BodyRegion.allCases.filter {  recentRegions.contains($0) }
        let primary   = makePlan(exercises: exercises, lastPerf: lastPerformance,
                                 focus: primarySplit(fresh: fresh, stale: stale), intensity: intensity)
        let alternate = makePlan(exercises: exercises, lastPerf: lastPerformance,
                                 focus: alternateSplit(fresh: fresh, stale: stale), intensity: .moderate)
        let recovery  = makeRecoveryPlan(exercises: exercises, lastPerf: lastPerformance)
        return [primary, alternate, recovery]
    }

    /// Convenience overload that reads from the store (main-thread only).
    static func generatePlans(store: SeedStore, readiness: ReadinessState) -> [GuidedWorkoutPlan] {
        generatePlans(log: store.workoutLog, exercises: store.exercises,
                      readiness: readiness, lastPerformance: store.lastPerformanceCache)
    }

    // MARK: - Split Selection

    private static func primarySplit(fresh: [BodyRegion], stale: [BodyRegion]) -> [BodyRegion] {
        // Prefer muscles that haven't been trained in the last 2 workouts
        if fresh.count >= 2 {
            // Pick a classic push / pull / legs split from fresh muscles
            if fresh.contains(.chest) && fresh.contains(.shoulders) { return [.chest, .shoulders, .arms] }
            if fresh.contains(.back)  && fresh.contains(.arms)      { return [.back, .arms] }
            if fresh.contains(.legs)                                 { return [.legs, .core] }
            return Array(fresh.prefix(3))
        }
        // Fall back to least-recently trained
        return Array((fresh + stale).prefix(3))
    }

    private static func alternateSplit(fresh: [BodyRegion], stale: [BodyRegion]) -> [BodyRegion] {
        let all = fresh + stale
        if all.contains(.back) && all.contains(.legs) { return [.back, .legs] }
        if all.contains(.chest) && all.contains(.core) { return [.chest, .core] }
        return Array(all.dropFirst().prefix(3))
    }

    // MARK: - Plan Builders (value-type, background-safe)

    private static func makePlan(
        exercises allExercises: [Exercise],
        lastPerf: [UUID: [SetRecord]],
        focus: [BodyRegion],
        intensity: GuidedWorkoutPlan.Intensity
    ) -> GuidedWorkoutPlan {
        var result: [GuidedExercise] = []
        for region in focus {
            let pool = allExercises.filter { $0.bodyRegion == region }
            let compounds  = pool.filter(\.isCompound)
            let isolations = pool.filter { !$0.isCompound }
            if let main = compounds.randomElement() {
                result.append(guided(main, intensity: intensity, lastPerf: lastPerf))
            }
            if result.count < 5, let iso = isolations.randomElement() {
                result.append(guided(iso, intensity: intensity, lastPerf: lastPerf))
            }
        }
        result = Array(result.prefix(6))
        let title     = planTitle(regions: focus, intensity: intensity)
        let minutes   = result.count * (intensity == .heavy ? 10 : 7)
        let coachNote = coachNote(intensity: intensity, regions: focus)
        return GuidedWorkoutPlan(
            id: UUID(), title: title,
            subtitle: focus.map(\.rawValue).joined(separator: " · "),
            bodyRegions: focus, exercises: result,
            estimatedMinutes: minutes, intensity: intensity, coachNote: coachNote
        )
    }

    private static func makeRecoveryPlan(exercises allExercises: [Exercise], lastPerf: [UUID: [SetRecord]]) -> GuidedWorkoutPlan {
        let picks: [BodyRegion] = [.core, .arms, .shoulders]
        let result: [GuidedExercise] = picks.compactMap { region in
            allExercises.filter { $0.bodyRegion == region && !$0.isCompound }.randomElement()
        }.map { guided($0, intensity: .light, lastPerf: lastPerf) }
        return GuidedWorkoutPlan(
            id: UUID(), title: "Active Recovery", subtitle: "Light · Full Body",
            bodyRegions: [.core, .arms, .shoulders], exercises: Array(result.prefix(4)),
            estimatedMinutes: 25, intensity: .light,
            coachNote: "Keep it easy today. Light movement boosts blood flow and speeds up recovery without adding fatigue."
        )
    }

    private static func guided(_ exercise: Exercise, intensity: GuidedWorkoutPlan.Intensity, lastPerf: [UUID: [SetRecord]]) -> GuidedExercise {
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

    // MARK: - Helpers

    private static func recentlyTrainedRegions(log: [WorkoutLogEntry]) -> Set<BodyRegion> {
        var regions = Set<BodyRegion>()
        for entry in log.prefix(2) {
            entry.exercises.forEach { regions.insert($0.exercise.bodyRegion) }
        }
        return regions
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

    private static func coachNote(intensity: GuidedWorkoutPlan.Intensity, regions: [BodyRegion]) -> String {
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
