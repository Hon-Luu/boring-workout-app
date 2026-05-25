import Foundation

// MARK: - UserCoachProfile

struct UserCoachProfile: Codable {
    // Average ratio of actual first-set weight to target weight.
    // < 0.95 = consistent under-loader; > 1.05 = consistent over-loader.
    var firstSetConservatism: Double? = nil

    // How often the user hits target reps on the very first session at a new weight.
    var newWeightFirstAttemptSuccessRate: Double? = nil

    // Average number of consecutive stuck sessions before a weight breakthrough occurs.
    var avgBreakthroughSessions: Double? = nil

    // Calendar weekday (1 = Sun … 7 = Sat) with the highest average set-completion rate.
    var bestWeekday: Int? = nil
    var bestWeekdayName: String? = nil
    var bestWeekdayCompletionRate: Double? = nil

    // Average number of sessions to return to pre-deload strength level.
    var deloadReturnSessions: Double? = nil

    var hasSufficientData: Bool = false     // requires >= 12 sessions
    var sessionCountAtCompute: Int = 0
    var computedAt: Date = .distantPast

    // MARK: Derived flags

    var isConservativeLoader: Bool { (firstSetConservatism ?? 1.0) < 0.95 }
    var isAggressiveLoader: Bool   { (firstSetConservatism ?? 1.0) > 1.05 }

    // < 55% success on first attempt at new weight — needs the anticipation warning
    var firstAttemptIsHard: Bool { (newWeightFirstAttemptSuccessRate ?? 1.0) < 0.55 }
}

// MARK: - Engine

enum UserCoachProfileEngine {
    private static let defaultsKey = "userCoachProfile_v2"
    private static let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // MARK: Persistence

    static func load() -> UserCoachProfile {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let profile = try? JSONDecoder().decode(UserCoachProfile.self, from: data)
        else { return UserCoachProfile() }
        return profile
    }

    static func save(_ profile: UserCoachProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    // Only recomputes when session count has changed since last compute.
    static func refreshIfNeeded(log: [WorkoutLogEntry]) {
        let current = load()
        guard log.count != current.sessionCountAtCompute else { return }
        save(compute(log: log))
    }

    // MARK: Compute

    static func compute(log: [WorkoutLogEntry]) -> UserCoachProfile {
        var profile = UserCoachProfile()
        profile.sessionCountAtCompute = log.count
        profile.computedAt = Date()
        profile.hasSufficientData = log.count >= 12

        guard log.count >= 4 else { return profile }

        let cal = Calendar.current

        // ── 1. First-set conservatism ──────────────────────────────────────────
        var ratios: [Double] = []
        for entry in log {
            for we in entry.exercises {
                if let first = we.completedSets.first,
                   first.targetWeight > 0, first.weight > 0 {
                    ratios.append(first.weight / first.targetWeight)
                }
            }
        }
        if ratios.count >= 10 {
            profile.firstSetConservatism = ratios.reduce(0, +) / Double(ratios.count)
        }

        // ── 2. New-weight first-attempt success rate ───────────────────────────
        // Build per-exercise session lists, oldest → newest
        var exerciseSessions: [UUID: [(sets: [SetRecord], date: Date)]] = [:]
        for entry in log.reversed() {
            for we in entry.exercises {
                let done = we.completedSets
                guard !done.isEmpty else { continue }
                exerciseSessions[we.exercise.id, default: []].append((done, entry.startedAt))
            }
        }

        var newWeightAttempts = 0, newWeightSuccesses = 0
        for sessions in exerciseSessions.values {
            guard sessions.count >= 2 else { continue }
            for i in 1..<sessions.count {
                let prevW = sessions[i - 1].sets.first?.weight ?? 0
                let currW = sessions[i].sets.first?.weight ?? 0
                guard prevW > 0, currW > prevW * 1.02 else { continue }
                newWeightAttempts += 1
                let hitTarget = sessions[i].sets.allSatisfy {
                    $0.targetReps > 0 ? $0.reps >= $0.targetReps : true
                }
                if hitTarget { newWeightSuccesses += 1 }
            }
        }
        if newWeightAttempts >= 5 {
            profile.newWeightFirstAttemptSuccessRate =
                Double(newWeightSuccesses) / Double(newWeightAttempts)
        }

        // ── 3. Average stuck sessions before breakthrough ──────────────────────
        var breakthroughLengths: [Int] = []
        for sessions in exerciseSessions.values {
            guard sessions.count >= 3 else { continue }
            var stuckRun = 0
            var prevWeight: Double = sessions[0].sets.first?.weight ?? 0
            for i in 1..<sessions.count {
                let w = sessions[i].sets.first?.weight ?? 0
                let allHit = sessions[i].sets.allSatisfy {
                    $0.targetReps > 0 ? $0.reps >= $0.targetReps : true
                }
                let sameWeight = prevWeight > 0 && abs(w - prevWeight) <= prevWeight * 0.02
                if sameWeight && !allHit {
                    stuckRun += 1
                } else {
                    if stuckRun > 0 && (allHit || w > prevWeight * 1.02) {
                        breakthroughLengths.append(stuckRun)
                    }
                    stuckRun = 0
                    prevWeight = w
                }
            }
        }
        if breakthroughLengths.count >= 3 {
            profile.avgBreakthroughSessions =
                Double(breakthroughLengths.reduce(0, +)) / Double(breakthroughLengths.count)
        }

        // ── 4. Best weekday ────────────────────────────────────────────────────
        var weekdayRates: [Int: [Double]] = [:]
        for entry in log {
            let weekday = cal.component(.weekday, from: entry.startedAt)
            var hits = 0, total = 0
            for we in entry.exercises {
                for s in we.completedSets where s.targetReps > 0 {
                    total += 1
                    if s.reps >= s.targetReps { hits += 1 }
                }
            }
            guard total > 0 else { continue }
            weekdayRates[weekday, default: []].append(Double(hits) / Double(total))
        }
        let qualifyingDays = weekdayRates.filter { $0.value.count >= 4 }
        if let best = qualifyingDays.max(by: { a, b in
            avgOf(a.value) < avgOf(b.value)
        }) {
            profile.bestWeekday = best.key
            profile.bestWeekdayName = dayNames[max(0, min(6, best.key - 1))]
            profile.bestWeekdayCompletionRate = avgOf(best.value)
        }

        // ── 5. Deload return sessions ──────────────────────────────────────────
        var deloadReturns: [Int] = []
        for sessions in exerciseSessions.values {
            guard sessions.count >= 6 else { continue }
            var i = 1
            while i < sessions.count {
                let prevW = sessions[i - 1].sets.first?.weight ?? 0
                let currW = sessions[i].sets.first?.weight ?? 0
                guard prevW > 0, currW < prevW * 0.92 else { i += 1; continue }
                // Deload at index i — find recovery
                var j = i + 1
                while j < sessions.count {
                    let retW = sessions[j].sets.first?.weight ?? 0
                    if retW >= prevW * 0.98 {
                        deloadReturns.append(j - i)
                        break
                    }
                    j += 1
                }
                i = max(i + 1, j)
            }
        }
        if deloadReturns.count >= 2 {
            profile.deloadReturnSessions =
                Double(deloadReturns.reduce(0, +)) / Double(deloadReturns.count)
        }

        return profile
    }

    private static func avgOf(_ arr: [Double]) -> Double {
        arr.isEmpty ? 0 : arr.reduce(0, +) / Double(arr.count)
    }
}
