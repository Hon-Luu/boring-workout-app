import Foundation

// MARK: - Output types

struct WorkoutFeedback {
    let points: [FeedbackPoint]
    let recommendation: String
}

struct FeedbackPoint: Identifiable {
    let id = UUID()
    let text: String
    let type: PointType
    enum PointType { case positive, neutral, warning }
}

struct ExerciseTodayHint {
    enum Kind { case increase(kg: Double), hold, deload(to: Double), firstSession }
    let kind: Kind

    var label: String {
        switch kind {
        case .increase:         return "Ready to go up"
        case .hold:             return "Hold weight"
        case .deload(let to):   return "Back off → \(to.weightFormatted) kg"
        case .firstSession:     return "First time — start light"
        }
    }

    var isUrgent: Bool {
        if case .deload = kind { return true }
        return false
    }
}

struct ExerciseProgress {
    let exerciseName: String
    let exerciseId: UUID
    let currentWeight: Double
    let pastWeight: Double?
    let sessionCount: Int

    var gain: Double? { pastWeight.map { currentWeight - $0 } }
    var isStalled: Bool {
        guard let g = gain else { return false }
        return sessionCount >= 4 && abs(g) < 1.0
    }
}

// MARK: - Engine

enum WorkoutFeedbackEngine {

    // MARK: - Top-level entry point

    /// `history` = previous sessions newest-first, NOT including `workout`.
    static func analyze(workout: WorkoutLogEntry, history: [WorkoutLogEntry]) -> WorkoutFeedback {
        var points:  [FeedbackPoint] = []
        var recs:    [String] = []

        for we in workout.exercises {
            let exHistory: [ExerciseSession] = history.compactMap { session in
                guard let m = session.exercises.first(where: { $0.exercise.id == we.exercise.id })
                else { return nil }
                return ExerciseSession(date: session.startedAt, sets: m.completedSets)
            }
            let result = analyzeExercise(we, history: exHistory)
            points.append(contentsOf: result.points)
            if let r = result.recommendation { recs.append(r) }
        }

        // Volume trend vs 3-session average
        if history.count >= 2 {
            let avg = history.prefix(3).map(\.totalVolume).reduce(0, +) / Double(min(history.count, 3))
            if avg > 0 {
                let pct = (workout.totalVolume - avg) / avg
                if pct > 0.12 {
                    points.append(.init(text: "Output was notably up on your recent average — good session.", type: .positive))
                } else if pct < -0.15 {
                    points.append(.init(text: "Output was down on your usual numbers — could be fatigue catching up.", type: .warning))
                }
            }
        }

        // Workout completion
        let allSets = workout.exercises.flatMap(\.sets)
        let incomplete = allSets.filter { !$0.isCompleted }.count
        if incomplete > 0 {
            points.append(.init(text: "\(incomplete) set\(incomplete == 1 ? "" : "s") left unfinished — get through all your work before chasing heavier weight.", type: .warning))
        }

        let rec = recs.first ?? defaultRec(workout: workout)
        return WorkoutFeedback(points: points, recommendation: rec)
    }


    // MARK: - Pre-workout narrative brief

    static func preworkoutBrief(exercises: [TemplateExercise], hints: [UUID: ExerciseTodayHint]) -> String? {
        var increases: [(name: String, kg: Double)] = []
        var deloads: [(name: String, to: Double)] = []
        var holds: [String] = []
        var struggling: [String] = []

        for te in exercises {
            let name = te.exercise.name
            guard let hint = hints[te.exercise.id] else { continue }
            switch hint.kind {
            case .increase(let kg): increases.append((name, kg))
            case .deload(let to):   deloads.append((name, to))
            case .hold:             holds.append(name)
            case .firstSession:     break
            }
        }

        var sentences: [String] = []

        // Weight increases
        if !increases.isEmpty {
            let names = increases.map(\.name)
            let kgLabel = increases[0].kg.weightFormatted + " kg"
            if names.count == 1 {
                sentences.append("\(names[0]) goes up \(kgLabel) today — you've been consistent and it's time to move.")
            } else if names.count == 2 {
                sentences.append("\(names[0]) and \(names[1]) both go up \(kgLabel) today.")
            } else {
                let all = names.dropLast().joined(separator: ", ") + " and " + names.last!
                sentences.append("\(all) all go up today.")
            }
        }

        // Deloads
        for d in deloads {
            sentences.append("\(d.name) gets a reset today — dropping to \(d.to.weightFormatted) kg. Focus on clean reps, not the number.")
        }

        // Hold + context
        if !holds.isEmpty && !increases.isEmpty {
            if holds.count == 1 {
                sentences.append("\(holds[0]) stays the same — not quite ready to move up yet.")
            } else {
                sentences.append("Everything else stays the same.")
            }
        }

        // Nothing changing
        if increases.isEmpty && deloads.isEmpty {
            if holds.isEmpty {
                return nil  // no history at all
            }
            return "Same weights as last session. Lock in clean reps across every set — that's what earns the next move up."
        }

        return sentences.joined(separator: " ")
    }

    // MARK: - Last workout narrative

    static func sessionNarrative(workout: WorkoutLogEntry, history: [WorkoutLogEntry]) -> String {
        let feedback = analyze(workout: workout, history: history)
        let warnings = feedback.points.filter { $0.type == .warning }
        let positives = feedback.points.filter { $0.type == .positive }

        var sentences: [String] = []

        // Overall tone
        if warnings.isEmpty && !positives.isEmpty {
            sentences.append("Good session.")
        } else if !warnings.isEmpty && positives.isEmpty {
            sentences.append("Tough session.")
        } else if !warnings.isEmpty && !positives.isEmpty {
            sentences.append("Mixed session.")
        } else {
            sentences.append("Steady session.")
        }

        // Key callouts — pull text from points, max 2
        let callouts = (warnings + positives).prefix(2)
        if !callouts.isEmpty {
            let parts = callouts.map(\.text).joined(separator: " ")
            sentences.append(parts)
        }

        // What it means going forward
        sentences.append(feedback.recommendation)

        return sentences.joined(separator: " ")
    }

    // MARK: - Upcoming session brief

    static func upcomingSessionBrief(exercises: [TemplateExercise], log: [WorkoutLogEntry]) -> String {
        let ids = exercises.map(\.exercise.id)
        let hints = todayHints(for: ids, in: log)

        // Summarise last session performance
        var lastSessionParts: [String] = []
        var increases: [(String, Double)] = []
        var deloads: [(String, Double)] = []
        var struggles: [String] = []

        for te in exercises {
            let id = te.exercise.id
            let name = te.exercise.name
            guard let hint = hints[id] else { continue }
            switch hint.kind {
            case .increase(let kg): increases.append((name, kg))
            case .deload(let to):   deloads.append((name, to))
            case .hold:
                // Check if it was a struggle hold vs a clean hold
                let sessions: [(WorkoutExercise, Date)] = log.compactMap { entry in
                    guard let we = entry.exercises.first(where: { $0.exercise.id == id }) else { return nil }
                    return (we, entry.startedAt)
                }
                if let (latestWE, _) = sessions.first {
                    let q = SessionQuality(sets: latestWE.completedSets)
                    if q.isStruggling { struggles.append(name) }
                }
            case .firstSession: break
            }
        }

        var sentences: [String] = []

        // Last session summary
        let totalExercises = exercises.count
        let improvingCount = increases.count
        let struggleCount = deloads.count + struggles.count

        if improvingCount > 0 && struggleCount == 0 {
            sentences.append("Last session looked solid.")
        } else if struggleCount > 0 && improvingCount == 0 {
            sentences.append("Last session was a grind — a few things didn't quite click.")
        } else if improvingCount > 0 && struggleCount > 0 {
            sentences.append("Mixed bag last time — some strong spots, some still finding their footing.")
        } else {
            sentences.append("Last session was steady — clean and consistent, nothing forced.")
        }

        // What's changing next session
        if !increases.isEmpty {
            let names: String
            if increases.count == 1 {
                names = increases[0].0
            } else if increases.count == 2 {
                names = "\(increases[0].0) and \(increases[1].0)"
            } else {
                names = increases.dropLast().map(\.0).joined(separator: ", ") + " and " + increases.last!.0
            }
            let kg = increases[0].1.weightFormatted
            sentences.append("\(names) \(increases.count == 1 ? "goes" : "go") up \(kg) kg.")
        }

        for (name, to) in deloads {
            sentences.append("\(name) drops to \(to.weightFormatted) kg — it's been struggling and needs a reset.")
        }

        if increases.isEmpty && deloads.isEmpty {
            sentences.append("Same weights across the board.")
        }

        return sentences.joined(separator: " ")
    }

    // MARK: - Per-exercise coaching note (one sentence for Today's Plan)

    static func exerciseNote(for exerciseId: UUID, in log: [WorkoutLogEntry]) -> String? {
        let sessions: [(WorkoutExercise, Date)] = log.compactMap { entry in
            guard let we = entry.exercises.first(where: { $0.exercise.id == exerciseId })
            else { return nil }
            return (we, entry.startedAt)
        }
        guard let (latestWE, _) = sessions.first else { return nil }

        let completed = latestWE.completedSets
        guard !completed.isEmpty else { return nil }

        let weight = completed.map(\.weight).max() ?? 0
        let increment: Double = latestWE.exercise.isCompound ? 2.5 : 1.25
        let history: [ExerciseSession] = sessions.dropFirst().map { we, date in
            ExerciseSession(date: date, sets: we.completedSets)
        }
        let analysis = analyzeExercise(latestWE, history: history)
        let q = SessionQuality(sets: completed)

        // Weight recommendation from analysis
        if let rec = analysis.recommendation {
            if rec.lowercased().contains("drop") || rec.lowercased().contains("deload") {
                let deload = (weight * 0.9 / increment).rounded() * increment
                return "Hit a wall last session — backing off to \(deload.weightFormatted) kg. Get clean reps first."
            } else if rec.lowercased().contains("add") {
                return "Handled \(weight.weightFormatted) kg well — time to move up \(increment.weightFormatted) kg."
            } else if rec.lowercased().contains("hold") || rec.lowercased().contains("one more") {
                return "Clean last session. One more solid one here before going up."
            }
        }

        // Fallback based on quality
        if q.isStruggling {
            return "Tough last session at \(weight.weightFormatted) kg — dial in the reps before adding weight."
        } else if q.isClean {
            return "Looking solid at \(weight.weightFormatted) kg."
        }
        return nil
    }

    // MARK: - Today's per-exercise hints

    /// Returns a short actionable hint for each exercise ID based on workout history.
    static func todayHints(for exerciseIds: [UUID], in log: [WorkoutLogEntry]) -> [UUID: ExerciseTodayHint] {
        var result: [UUID: ExerciseTodayHint] = [:]
        for id in exerciseIds {
            let sessions: [(WorkoutExercise, Date)] = log.compactMap { entry in
                guard let we = entry.exercises.first(where: { $0.exercise.id == id }) else { return nil }
                return (we, entry.startedAt)
            }
            guard let (latestWE, _) = sessions.first else {
                result[id] = ExerciseTodayHint(kind: .firstSession)
                continue
            }
            let history: [ExerciseSession] = sessions.dropFirst().map { we, date in
                ExerciseSession(date: date, sets: we.completedSets)
            }
            let analysis = analyzeExercise(latestWE, history: history)
            let increment: Double = latestWE.exercise.isCompound ? 2.5 : 1.25
            let currentWeight = latestWE.completedSets.map(\.weight).max() ?? 0

            if let rec = analysis.recommendation {
                if rec.lowercased().contains("add") {
                    result[id] = ExerciseTodayHint(kind: .increase(kg: increment))
                } else if rec.lowercased().contains("deload") {
                    let deload = (currentWeight * 0.9 / increment).rounded() * increment
                    result[id] = ExerciseTodayHint(kind: .deload(to: deload))
                } else {
                    result[id] = ExerciseTodayHint(kind: .hold)
                }
            } else {
                result[id] = ExerciseTodayHint(kind: .hold)
            }
        }
        return result
    }

    // MARK: - Medium-term progress trend

    /// Compares each exercise's current weight to ~6 weeks ago. Returns sorted by gain descending.
    static func progressTrend(log: [WorkoutLogEntry], lookbackDays: Int = 42) -> [ExerciseProgress] {
        let cutoff = Date().addingTimeInterval(-Double(lookbackDays) * 86400)
        var byExercise: [UUID: (name: String, sessions: [(date: Date, weight: Double)])] = [:]

        for entry in log {
            for we in entry.exercises {
                let maxWeight = we.completedSets.map(\.weight).max() ?? 0
                guard maxWeight > 0 else { continue }
                let id = we.exercise.id
                if byExercise[id] == nil {
                    byExercise[id] = (we.exercise.name, [])
                }
                byExercise[id]?.sessions.append((entry.startedAt, maxWeight))
            }
        }

        return byExercise.compactMap { id, data in
            let sorted = data.sessions.sorted { $0.date > $1.date }
            guard let current = sorted.first?.weight else { return nil }
            let pastSession = sorted.last(where: { $0.date <= cutoff })
            return ExerciseProgress(
                exerciseName: data.name,
                exerciseId: id,
                currentWeight: current,
                pastWeight: pastSession?.weight,
                sessionCount: sorted.count
            )
        }
        .sorted { ($0.gain ?? 0) > ($1.gain ?? 0) }
    }

    // MARK: - Session snapshot

    private struct ExerciseSession {
        let date: Date
        let sets: [SetRecord]

        var quality: SessionQuality { SessionQuality(sets: sets) }
    }

    // MARK: - Quality snapshot for one exercise session

    private struct SessionQuality {
        let repHitRate: Double       // fraction of target reps achieved (1.0 = all hit)
        let repSurplusAvg: Double    // avg extra reps beyond target across sets (positive = exceeded)
        let setCompletionRate: Double
        let repDecline: Double       // how much reps drop from first to last set (0 = no decline)

        init(sets: [SetRecord]) {
            guard !sets.isEmpty else {
                repHitRate = 0; repSurplusAvg = 0; setCompletionRate = 0; repDecline = 0; return
            }
            let targeted = sets.filter { $0.targetReps > 0 }
            repHitRate = targeted.isEmpty ? 1.0 :
                Double(targeted.filter { $0.reps >= $0.targetReps }.count) / Double(targeted.count)

            let surpluses = targeted.map { Double($0.reps - $0.targetReps) }
            repSurplusAvg = surpluses.isEmpty ? 0 : surpluses.reduce(0, +) / Double(surpluses.count)

            setCompletionRate = Double(sets.filter(\.isCompleted).count) / Double(sets.count)

            // Decline = (first set reps - last set reps) / first set reps
            if let first = targeted.first?.reps, let last = targeted.last?.reps, first > 0, targeted.count > 1 {
                repDecline = max(0, Double(first - last) / Double(first))
            } else {
                repDecline = 0
            }
        }

        /// 0–100 quality score for one session
        var score: Double {
            var s = repHitRate * 50.0                             // 0–50 base
            s += min(repSurplusAvg / 2.0, 1.0) * 25.0            // 0–25 surplus bonus (caps at +2 extra reps)
            s += (1.0 - min(repDecline, 1.0)) * 15.0             // 0–15 consistency bonus
            s += setCompletionRate >= 1.0 ? 10.0 : 0.0           // 10 completion bonus
            return s
        }

        var isClean: Bool { repHitRate >= 1.0 && setCompletionRate >= 1.0 }
        var isStrong: Bool { repSurplusAvg >= 1.0 && isClean }   // hit all reps AND had extra
        var isStruggling: Bool { repHitRate < 0.75 }
        var isStuck: Bool { repHitRate >= 0.75 && repHitRate < 1.0 }
    }

    // MARK: - Per-exercise analysis

    private struct ExerciseResult {
        let points: [FeedbackPoint]
        let recommendation: String?
    }

    private static func analyzeExercise(
        _ we: WorkoutExercise,
        history: [ExerciseSession]
    ) -> ExerciseResult {

        let name = we.exercise.name
        let completed = we.completedSets
        guard !completed.isEmpty else { return .init(points: [], recommendation: nil) }

        let currentWeight = completed.map(\.weight).max() ?? 0
        let increment: Double = we.exercise.isCompound ? 2.5 : 1.25

        let current = SessionQuality(sets: completed)
        let pastQuality = history.prefix(4).map(\.quality)

        // Consecutive clean sessions including current
        var consecutiveClean = current.isClean ? 1 : 0
        for q in pastQuality { if q.isClean { consecutiveClean += 1 } else { break } }

        // Consecutive struggling sessions (past only)
        var consecutiveStruggle = 0
        for q in pastQuality { if q.isStruggling { consecutiveStruggle += 1 } else { break } }

        // How many past sessions at same weight
        let pastWeights = history.prefix(5).compactMap { $0.sets.first?.weight }
        let sessionsAtWeight = pastWeights.prefix(while: { abs($0 - currentWeight) < 0.5 }).count

        // Rolling quality score (current + last 2)
        let recentScores = ([current] + Array(pastQuality.prefix(2))).map(\.score)
        let avgRecentScore = recentScores.reduce(0, +) / Double(recentScores.count)

        let lastWeight = history.first?.sets.first?.weight ?? currentWeight
        var points: [FeedbackPoint] = []
        var recommendation: String? = nil

        // ─── Decision tree ───────────────────────────────────────────────

        // DELOAD
        if consecutiveStruggle >= 2 || (sessionsAtWeight >= 3 && avgRecentScore < 45) {
            let deload = (currentWeight * 0.9 / increment).rounded() * increment
            points.append(.init(text: "\(name): missed reps \(consecutiveStruggle + 1) sessions in a row.", type: .warning))
            recommendation = "Drop \(name) to \(deload.weightFormatted) kg. Get clean reps at lighter weight before building back up."
        }

        // STRONG SIGNAL — add weight now
        else if current.isStrong && (pastQuality.first?.isClean ?? false) && current.setCompletionRate >= 1.0 {
            points.append(.init(text: "\(name): hit every set and had at least a rep to spare. Ready to go heavier.", type: .positive))
            recommendation = "Add \(increment.weightFormatted) kg to \(name) — you've been handling this weight too comfortably."
        }

        // STANDARD PROGRESSION
        else if consecutiveClean >= 2 && avgRecentScore >= 72 && current.setCompletionRate >= 1.0 {
            points.append(.init(text: "\(name): \(consecutiveClean) clean sessions at this weight. Time to move up.", type: .positive))
            recommendation = "Add \(increment.weightFormatted) kg to \(name) next session."
        }

        // CLOSE BUT NOT READY
        else if current.isClean && avgRecentScore >= 60 {
            points.append(.init(text: "\(name): clean this session, but the one before wasn't. One more to confirm.", type: .neutral))
            recommendation = "Hold \(name) at \(currentWeight.weightFormatted) kg. One more solid session and you move up."
        }

        // STAGNATION
        else if sessionsAtWeight >= 3 && current.isClean && avgRecentScore < 72 {
            points.append(.init(text: "\(name): \(sessionsAtWeight + 1) sessions at \(currentWeight.weightFormatted) kg — reps are there but not consistently clean enough to progress.", type: .neutral))
            recommendation = "Hold \(name). Hit every rep cleanly before adding weight."
        }

        // STRUGGLING
        else if current.isStruggling {
            points.append(.init(text: "\(name): only hit \(Int(current.repHitRate * 100))% of target reps.", type: .warning))
            if recommendation == nil {
                if currentWeight > lastWeight + 0.1 {
                    recommendation = "Roll back \(name) to \(lastWeight.weightFormatted) kg — the jump was too much. Rebuild from there."
                } else {
                    recommendation = "Keep \(name) at \(currentWeight.weightFormatted) kg. Hit your reps before adding weight."
                }
            }
        }

        // SHARP REP DECLINE within session
        if current.repDecline > 0.30 && points.isEmpty {
            points.append(.init(text: "\(name): dropped from \(Int(completed.first?.reps ?? 0)) to \(Int(completed.last?.reps ?? 0)) reps set to set — possible fatigue or form breakdown.", type: .warning))
        }

        // Weight increased and held
        if currentWeight > lastWeight + 0.1 && current.repHitRate >= 0.85 && recommendation == nil {
            points.append(.init(text: "\(name): up \((currentWeight - lastWeight).weightFormatted) kg vs last session and hit your reps.", type: .positive))
        }

        return .init(points: points, recommendation: recommendation)
    }

    // MARK: - Fallback

    private static func defaultRec(workout: WorkoutLogEntry) -> String {
        let allSets = workout.exercises.flatMap(\.sets)
        let rate = allSets.isEmpty ? 1.0 : Double(allSets.filter(\.isCompleted).count) / Double(allSets.count)
        return rate >= 1.0
            ? "Full session in the books. Keep showing up."
            : "Finish all your sets before you think about adding weight."
    }
}
