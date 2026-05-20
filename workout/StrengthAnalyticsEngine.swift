import Foundation

// MARK: - Result Types

struct SessionPoint: Identifiable {
    let id    = UUID()
    let date: Date
    let estimated1RM: Double
    let bestWeight: Double   // weight of the best-1RM set this session
    let bestReps: Int        // reps of the best-1RM set this session
    let feel: FeelRating?
}

struct PRPoint: Identifiable {
    let id    = UUID()
    let date: Date
    let estimated1RM: Double
}

struct ExerciseAnalytics: Identifiable {
    let id: UUID                        // matches exercise.id
    let exercise: Exercise
    let sessions: [SessionPoint]        // oldest first, one per workout session
    let rollingAvg: [SessionPoint]      // 5-session window, aligned to sessions
    let slopePerWeek: Double            // kg/week from linear regression (last 6 wks)
    let pctChangePerWeek: Double        // % per week relative to mean 1RM
    let prProgression: [PRPoint]        // step-chart data: only new-max sessions
    let isPlateau: Bool                 // slope < 0.5 kg/wk over last 4 wks with ≥ 3 sessions
    let hasEnoughData: Bool             // requires ≥ 3 total sessions
    // v2 metrics
    let latestRepDecay: Double?         // reps/set slope in last session; negative = fatiguing
    let latestINOL: Double?             // Σ reps/(100-intensity%) for last session
    let latestSessionCost: Double?      // fatigue-weighted session cost (feel-adjusted)
    let efficiencyScore: Double?        // Δe1RM_rolling / session_cost (latest session)
    let efficiencyHistory: [Double]     // efficiency for every session where computable
    let efficiencyLabel: String?        // quartile rank vs own history: Great / Average / Below avg
    let feelInsight: String?            // coaching note from consecutive feel streak
    // v3: fatigue-adjusted e1RM — upscales each set by e^(0.08×setIndex) to recover "fresh" capacity
    let sessionsFatigue: [SessionPoint]     // fatigue-adjusted best e1RM per session
    let rollingAvgFatigue: [SessionPoint]   // 5-session rolling avg of fatigue-adjusted
    let slopePerWeekFatigue: Double         // OLS slope of fatigue-adjusted trend (kg/wk)
    let pctChangePerWeekFatigue: Double     // %/wk of fatigue-adjusted trend
}

enum INOLZone: String {
    case insufficient = "Low"
    case moderate     = "Moderate"
    case optimal      = "Optimal"
    case heavy        = "Heavy"
    case overreaching = "Overreaching"

    init(inol: Double) {
        switch inol {
        case ..<0.4:  self = .insufficient
        case ..<0.8:  self = .moderate
        case ..<1.5:  self = .optimal
        case ..<2.0:  self = .heavy
        default:      self = .overreaching
        }
    }
}

enum EfficiencyClass: String {
    case efficient   = "Efficient"
    case inefficient = "Inefficient"
    case opportunity = "Opportunity"
    case lowPriority = "Low Priority"

    var icon: String {
        switch self {
        case .efficient:   return "checkmark.circle.fill"
        case .inefficient: return "exclamationmark.circle.fill"
        case .opportunity: return "arrow.up.right.circle.fill"
        case .lowPriority: return "minus.circle.fill"
        }
    }
}

struct CategoryAnalytics: Identifiable {
    let id = UUID()
    let pattern: MovementPattern
    let weeklyVolumeAvg: Double         // kg per week, averaged over last 6 weeks
    let improvementRatePerWeek: Double  // % per week, weighted avg across exercises
    let efficiency: EfficiencyClass     // quadrant classification
    let topExerciseName: String?        // most-logged exercise in this pattern
    let insightText: String
    let hasData: Bool
}

struct AnalyticsResult {
    let exerciseAnalytics: [ExerciseAnalytics]      // top 8 by session count
    let categoryAnalytics: [CategoryAnalytics]      // patterns with data, best improvement first
    let globalInsights: [String]                    // up to 3 key takeaways
    let strengthScore: StrengthScoreResult          // PSI, relative strength, body comp
    let compositeScore: CompositeStrengthResult     // blended overall strength gain score
    let computedAt: Date

    static let empty = AnalyticsResult(
        exerciseAnalytics: [],
        categoryAnalytics: [],
        globalInsights: [],
        strengthScore: .empty,
        compositeScore: .empty,
        computedAt: .distantPast
    )
}

// MARK: - Engine

enum StrengthAnalyticsEngine {

    private static let rollingWindow    = 5      // sessions
    private static let trendWeekSpan    = 6.0    // weeks used for regression
    private static let plateauWeekSpan  = 4.0    // weeks for plateau check
    private static let minReps          = 1      // 1-rep sets are exact; include them
    private static let maxReps          = 20     // Mayhew formula is valid through 20 reps
    private static let plateauThreshold = 0.5    // kg/week below which = plateau

    // MARK: - Entry Point

    static func compute(
        log: [WorkoutLogEntry],
        exercises: [Exercise],
        userProfile: UserProfile = UserProfile()
    ) -> AnalyticsResult {
        guard !log.isEmpty else { return .empty }

        let patternMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.movementPattern) })

        // Compute strengthScore FIRST — it is independent of exerciseAnalytics and
        // provides overallTier, which we use to select experience-appropriate constants
        // (fatigue decay α, momentum ceiling, INOL zone) for the exercise pass below.
        let strengthScore = StrengthScoreEngine.compute(
            log: log,
            exercises: exercises,
            userProfile: userProfile
        )

        // When body weight is absent, overallTier defaults to .beginner because
        // relative strength can't be computed. Fall back to .intermediate so unknown
        // users don't get beginner-biased constants.
        let experienceTier: StrengthTier = userProfile.bodyWeightKg == nil
            ? .intermediate
            : strengthScore.overallTier

        // Fatigue decay constant α — rate at which rep output decays across sets.
        // Source: Willardson (2005), Ratamess (2007), Schoenfeld (2016).
        // Developing lifters use shorter rests and have less work capacity → faster decay.
        // Elite lifters use 5+ min rests and have superior phosphocreatine recovery → slower decay.
        let fatigueDecay: Double = {
            switch experienceTier {
            case .beginner:   return 0.10   // ~1–2 min rest; ~25% rep decline by set 3
            case .intermediate: return 0.08   // ~2 min rest  (prior default)
            case .advanced:     return 0.05   // ~3 min rest; ~12% decline by set 4
            case .elite:        return 0.03   // 5+ min rest; <8% decline by set 4
            }
        }()

        // Collect and sort sessions per exercise (oldest first), carrying feel rating
        var raw: [UUID: (exercise: Exercise, sessions: [(date: Date, sets: [SetRecord], feel: FeelRating?)])] = [:]
        for entry in log {
            for we in entry.exercises {
                let exId = we.exercise.id
                let eq = we.exercise.equipment
                // Use effectiveWeight so barbell sets logged as 0 (= empty bar) aren't excluded
                var sets = we.completedSets.filter { $0.reps >= minReps && $0.reps <= maxReps && eq.effectiveWeight($0.weight) > 0 }
                if sets.isEmpty { sets = we.completedSets.filter { eq.effectiveWeight($0.weight) > 0 } }
                guard !sets.isEmpty else { continue }
                if raw[exId] == nil { raw[exId] = (we.exercise, []) }
                raw[exId]!.sessions.append((entry.startedAt, sets, entry.feelRating))
            }
        }
        for k in raw.keys { raw[k]!.sessions.sort { $0.date < $1.date } }

        let exerciseAnalytics: [ExerciseAnalytics] = raw.values
            .map { computeExercise(exercise: $0.exercise, sessions: $0.sessions, fatigueDecay: fatigueDecay) }
            .sorted { $0.sessions.count > $1.sessions.count }
            .prefix(8).map { $0 }

        let categoryAnalytics = computeCategories(
            exerciseAnalytics: exerciseAnalytics,
            log: log,
            patternMap: patternMap
        )

        let compositeScore = CompositeStrengthEngine.compute(
            exerciseAnalytics: exerciseAnalytics,
            psiHistory: strengthScore.psiHistory,
            userProfile: userProfile,
            relativeStrengths: strengthScore.relativeStrengths,
            experienceTier: experienceTier
        )

        return AnalyticsResult(
            exerciseAnalytics: exerciseAnalytics,
            categoryAnalytics: categoryAnalytics,
            globalInsights: generateGlobalInsights(exercises: exerciseAnalytics, categories: categoryAnalytics),
            strengthScore: strengthScore,
            compositeScore: compositeScore,
            computedAt: Date()
        )
    }

    // MARK: - Per-Exercise Computation

    private static func computeExercise(
        exercise: Exercise,
        sessions: [(date: Date, sets: [SetRecord], feel: FeelRating?)],
        fatigueDecay: Double = 0.08
    ) -> ExerciseAnalytics {

        let eq = exercise.equipment
        let pts: [SessionPoint] = sessions.map { s in
            // Use dropAdjustedE1RM: takes max of main set and drop set e1RM so drop-set
            // training sessions don't create false regressions in e1RM tracking.
            // Also applies 0.92× bilateral deficit correction for dumbbell (Botton et al., 2016).
            let best = s.sets.max(by: { $0.dropAdjustedE1RM(equipment: eq) < $1.dropAdjustedE1RM(equipment: eq) })
            return SessionPoint(
                date: s.date,
                estimated1RM: best?.dropAdjustedE1RM(equipment: eq) ?? 0,
                bestWeight: best.map { eq.effectiveWeight($0.weight) } ?? 0,
                bestReps: best?.reps ?? 0,
                feel: s.feel
            )
        }

        let rollingAvg: [SessionPoint] = pts.indices.map { i in
            let start = max(0, i - rollingWindow + 1)
            let window = pts[start...i]
            let avg = window.map(\.estimated1RM).reduce(0, +) / Double(window.count)
            return SessionPoint(date: pts[i].date, estimated1RM: avg,
                                bestWeight: pts[i].bestWeight, bestReps: pts[i].bestReps,
                                feel: pts[i].feel)
        }

        // PR step-chart: emit a point only when a new all-time max is set
        var runningMax = 0.0
        let prProgression: [PRPoint] = pts.compactMap { pt in
            guard pt.estimated1RM > runningMax else { return nil }
            runningMax = pt.estimated1RM
            return PRPoint(date: pt.date, estimated1RM: pt.estimated1RM)
        }

        // Linear regression over recent sessions (last 6 weeks only).
        // If fewer than 3 recent points, treat momentum as unknown (0) rather than
        // falling back to all-time history, which gives ghost gains to detrained users.
        let trendCutoff = Date().addingTimeInterval(-trendWeekSpan * 7 * 86400)
        let recentPts   = pts.filter { $0.date >= trendCutoff }
        let slope: Double
        let pctChange: Double
        if recentPts.count >= 3 {
            let (s, _) = linearRegression(asWeeks(recentPts))
            let mean1RM = recentPts.map(\.estimated1RM).reduce(0, +) / Double(recentPts.count)
            slope     = s
            pctChange = mean1RM > 0 ? s / mean1RM * 100 : 0
        } else {
            slope     = 0
            pctChange = 0
        }

        // Plateau: low slope over the last 4 weeks with enough data
        let plateauCutoff = Date().addingTimeInterval(-plateauWeekSpan * 7 * 86400)
        let plateauPts    = pts.filter { $0.date >= plateauCutoff }
        let isPlateau: Bool = {
            guard plateauPts.count >= 3 else { return false }
            let (s, _) = linearRegression(asWeeks(plateauPts))
            return s < plateauThreshold
        }()

        // Stable reference 1RM used by INOL and cost model
        let refE1RM = pts.map(\.estimated1RM).max() ?? 0

        // Rep decay slope: OLS of (set_index → reps) for the last session
        let lastSets = sessions.last?.sets.filter { $0.isCompleted && $0.reps > 0 } ?? []
        let latestRepDecay: Double? = {
            guard lastSets.count >= 2 else { return nil }
            let regPts = lastSets.enumerated().map { (x: Double($0.offset), y: Double($0.element.reps)) }
            return linearRegression(regPts).slope
        }()

        // INOL for last session — includes drop set reps so drop-set training
        // isn't underreported in fatigue load
        let latestINOL: Double? = {
            guard refE1RM > 0, let lastSession = sessions.last else { return nil }
            let validSets = lastSession.sets.filter { $0.isCompleted && $0.weight > 0 && $0.reps > 0 }
            guard !validSets.isEmpty else { return nil }
            return validSets.reduce(0.0) { acc, s in
                let intensityPct = min(eq.effectiveWeight(s.weight) / refE1RM * 100, 97.5)
                var contribution = Double(s.reps) / (100.0 - intensityPct)
                // Add drop set contribution
                if s.isDropCompleted, let dw = s.dropWeight, dw > 0, let dr = s.dropReps, dr > 0 {
                    let dropPct = min(eq.effectiveWeight(dw) / refE1RM * 100, 97.5)
                    contribution += Double(dr) / (100.0 - dropPct)
                }
                return acc + contribution
            }
        }()

        // Per-session cost for every session (needed for efficiency history)
        func sessionCost(for s: (date: Date, sets: [SetRecord], feel: FeelRating?)) -> Double? {
            guard refE1RM > 0 else { return nil }
            let valid = s.sets.filter { $0.isCompleted && $0.weight > 0 && $0.reps > 0 }
            guard !valid.isEmpty else { return nil }
            let feelMul = s.feel?.costMultiplier ?? 1.0
            let raw = valid.enumerated().reduce(0.0) { acc, pair in
                let (i, set) = pair
                let mainCost = Double(set.reps) * pow(set.bilateralAdjustedE1RM(equipment: eq) / refE1RM, 1.8) * min(exp(fatigueDecay * Double(i)), 1.35)
                // Drop set adds its own fatigue cost (no set-index multiplier — it follows the main)
                var dropCost = 0.0
                if set.isDropCompleted, let dw = set.dropWeight, dw > 0, let dr = set.dropReps, dr > 0 {
                    let dropRaw = SetRecord.e1RM(weight: eq.effectiveWeight(dw), reps: dr)
                    let dropE1RM = eq == .dumbbell ? dropRaw * 0.92 : dropRaw
                    if dropE1RM > 0 {
                        dropCost = Double(dr) * pow(dropE1RM / refE1RM, 1.8)
                    }
                }
                return acc + mainCost + dropCost
            }
            return raw * feelMul
        }

        let allCosts: [Double?] = sessions.map { sessionCost(for: $0) }
        let latestSessionCost: Double? = allCosts.last.flatMap { $0 }

        // Efficiency history: Δrolling_avg / cost for each session with enough context
        let efficiencyHistory: [Double] = rollingAvg.indices.dropFirst().compactMap { i in
            guard let cost = allCosts[i], cost > 0 else { return nil }
            let delta = rollingAvg[i].estimated1RM - rollingAvg[i - 1].estimated1RM
            return delta / cost
        }

        let efficiencyScore: Double? = efficiencyHistory.last

        // Quartile label relative to own history
        let efficiencyLabel: String? = {
            guard efficiencyHistory.count >= 4, let latest = efficiencyHistory.last else { return nil }
            let sorted = efficiencyHistory.sorted()
            let n = sorted.count
            let q1 = sorted[n / 4]
            let q3 = sorted[3 * n / 4]
            if latest >= q3 { return "Great" }
            if latest >= q1 { return "Average" }
            return "Below avg"
        }()

        // Feel streak coaching insight
        let feelInsight: String? = {
            let recentFeels = pts.compactMap(\.feel)
            guard let lastFeel = recentFeels.last else { return nil }
            var streak = 0
            for feel in recentFeels.reversed() {
                guard feel == lastFeel else { break }
                streak += 1
            }
            guard streak >= 2 else { return nil }
            switch lastFeel {
            case .strong:
                return streak >= 3
                    ? "\(streak) strong sessions in a row — your body is primed. Consider adding load next time."
                    : "2 strong sessions back-to-back — a small weight increase may be warranted."
            case .tired:
                return streak >= 3
                    ? "\(streak) consecutive tired sessions — prioritise sleep and consider a deload week."
                    : "2 tired sessions in a row — check recovery before your next session."
            case .normal:
                return nil
            }
        }()

        // MARK: Fatigue-adjusted e1RM
        // For each set at index i, adjusted = epley_e1RM × e^(0.08 × i).
        // This recovers the "rested" capacity implied by performing that output under accumulated fatigue.
        let ptsAdj: [SessionPoint] = sessions.map { s in
            let valid = s.sets.filter { $0.weight > 0 && $0.reps > 0 }
            var bestAdjE1RM = 0.0
            var bestWeight  = 0.0
            var bestReps    = 0
            for (i, set) in valid.enumerated() {
                let adj = set.dropAdjustedE1RM(equipment: eq) * min(exp(fatigueDecay * Double(i)), 1.35)
                if adj > bestAdjE1RM {
                    bestAdjE1RM = adj
                    bestWeight  = eq.effectiveWeight(set.weight)
                    bestReps    = set.reps
                }
            }
            return SessionPoint(date: s.date, estimated1RM: bestAdjE1RM,
                                bestWeight: bestWeight, bestReps: bestReps, feel: s.feel)
        }

        let rollingAvgFatigue: [SessionPoint] = ptsAdj.indices.map { i in
            let start = max(0, i - rollingWindow + 1)
            let window = ptsAdj[start...i]
            let avg = window.map(\.estimated1RM).reduce(0, +) / Double(window.count)
            return SessionPoint(date: ptsAdj[i].date, estimated1RM: avg,
                                bestWeight: ptsAdj[i].bestWeight, bestReps: ptsAdj[i].bestReps,
                                feel: ptsAdj[i].feel)
        }

        let recentAdj = ptsAdj.filter { $0.date >= trendCutoff }
        let slopeAdj: Double
        let pctAdj: Double
        if recentAdj.count >= 3 {
            let (s, _) = linearRegression(asWeeks(recentAdj))
            let meanAdj = recentAdj.map(\.estimated1RM).reduce(0, +) / Double(recentAdj.count)
            slopeAdj = s
            pctAdj   = meanAdj > 0 ? s / meanAdj * 100 : 0
        } else {
            slopeAdj = 0
            pctAdj   = 0
        }

        return ExerciseAnalytics(
            id: exercise.id,
            exercise: exercise,
            sessions: pts,
            rollingAvg: rollingAvg,
            slopePerWeek: slope,
            pctChangePerWeek: pctChange,
            prProgression: prProgression,
            isPlateau: isPlateau,
            hasEnoughData: pts.count >= 3,
            latestRepDecay: latestRepDecay,
            latestINOL: latestINOL,
            latestSessionCost: latestSessionCost,
            efficiencyScore: efficiencyScore,
            efficiencyHistory: efficiencyHistory,
            efficiencyLabel: efficiencyLabel,
            feelInsight: feelInsight,
            sessionsFatigue: ptsAdj,
            rollingAvgFatigue: rollingAvgFatigue,
            slopePerWeekFatigue: slopeAdj,
            pctChangePerWeekFatigue: pctAdj
        )
    }

    // MARK: - Per-Category Computation

    private static func computeCategories(
        exerciseAnalytics: [ExerciseAnalytics],
        log: [WorkoutLogEntry],
        patternMap: [UUID: MovementPattern]
    ) -> [CategoryAnalytics] {

        var byPattern: [MovementPattern: [ExerciseAnalytics]] = [:]
        for ea in exerciseAnalytics {
            let p = patternMap[ea.exercise.id] ?? ea.exercise.movementPattern
            byPattern[p, default: []].append(ea)
        }
        guard !byPattern.isEmpty else { return [] }

        let sixWeeksAgo = Date().addingTimeInterval(-trendWeekSpan * 7 * 86400)
        var volByPattern: [MovementPattern: Double] = [:]
        for entry in log where entry.startedAt >= sixWeeksAgo {
            for we in entry.exercises {
                let p = patternMap[we.exercise.id] ?? we.exercise.movementPattern
                volByPattern[p, default: 0] += we.totalVolume
            }
        }
        for k in volByPattern.keys { volByPattern[k]! /= trendWeekSpan }

        var impByPattern: [MovementPattern: Double] = [:]
        for (p, list) in byPattern {
            let totalSessions = list.map { $0.sessions.count }.reduce(0, +)
            guard totalSessions > 0 else { continue }
            impByPattern[p] = list.reduce(0.0) {
                $0 + $1.pctChangePerWeek * Double($1.sessions.count) / Double(totalSessions)
            }
        }

        let medVol = median(Array(volByPattern.values))
        let medImp = median(Array(impByPattern.values))

        return byPattern.keys
            .sorted { $0.rawValue < $1.rawValue }
            .compactMap { pattern -> CategoryAnalytics? in
                guard let exercises = byPattern[pattern], !exercises.isEmpty else { return nil }
                let vol = volByPattern[pattern] ?? 0
                let imp = impByPattern[pattern] ?? 0
                let efficiency: EfficiencyClass = {
                    switch (vol >= medVol, imp >= medImp) {
                    case (true,  true):  return .efficient
                    case (true,  false): return .inefficient
                    case (false, true):  return .opportunity
                    case (false, false): return .lowPriority
                    }
                }()
                let top = exercises.max { $0.sessions.count < $1.sessions.count }
                return CategoryAnalytics(
                    pattern: pattern,
                    weeklyVolumeAvg: vol,
                    improvementRatePerWeek: imp,
                    efficiency: efficiency,
                    topExerciseName: top?.exercise.name,
                    insightText: categoryInsight(pattern: pattern, imp: imp, efficiency: efficiency),
                    hasData: true
                )
            }
            .sorted { $0.improvementRatePerWeek > $1.improvementRatePerWeek }
    }

    // MARK: - Math Primitives

    /// Ordinary least-squares on (x, y) pairs. Returns (slope, intercept).
    static func linearRegression(_ points: [(x: Double, y: Double)]) -> (slope: Double, intercept: Double) {
        let n = Double(points.count)
        guard n >= 2 else { return (0, points.first?.y ?? 0) }
        let sx  = points.map(\.x).reduce(0, +)
        let sy  = points.map(\.y).reduce(0, +)
        let sxy = points.map { $0.x * $0.y }.reduce(0, +)
        let sx2 = points.map { $0.x * $0.x }.reduce(0, +)
        let d   = n * sx2 - sx * sx
        guard abs(d) > 1e-10 else { return (0, sy / n) }
        let slope = (n * sxy - sx * sy) / d
        return (slope, (sy - slope * sx) / n)
    }

    /// Convert SessionPoints to (weeks-from-first, 1RM) pairs for regression.
    private static func asWeeks(_ pts: [SessionPoint]) -> [(x: Double, y: Double)] {
        guard let first = pts.first else { return [] }
        return pts.map { (x: $0.date.timeIntervalSince(first.date) / (7 * 86400), y: $0.estimated1RM) }
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let s = values.sorted()
        let mid = s.count / 2
        return s.count.isMultiple(of: 2) ? (s[mid - 1] + s[mid]) / 2 : s[mid]
    }

    // MARK: - Insight Text

    private static func generateGlobalInsights(
        exercises: [ExerciseAnalytics],
        categories: [CategoryAnalytics]
    ) -> [String] {
        var out: [String] = []

        if let best = categories.first(where: { $0.improvementRatePerWeek > 0.1 }) {
            let pct = formatted(best.improvementRatePerWeek)
            out.append("\(best.pattern.rawValue) improving fastest at +\(pct)%/wk.")
        }
        if let slow = categories.first(where: { $0.efficiency == .inefficient }) {
            out.append("\(slow.pattern.rawValue): high volume but slow gains — cut sets, raise intensity.")
        }
        let stalled = exercises.filter(\.isPlateau)
        if !stalled.isEmpty {
            let names = stalled.prefix(2).map(\.exercise.name).joined(separator: " & ")
            out.append("\(names) stalled — vary rep range or add load.")
        }
        if let opp = categories.first(where: { $0.efficiency == .opportunity }) {
            out.append("\(opp.pattern.rawValue) responding well — more volume here could accelerate gains.")
        }

        return Array(out.prefix(3))
    }

    private static func categoryInsight(
        pattern: MovementPattern,
        imp: Double,
        efficiency: EfficiencyClass
    ) -> String {
        let pct  = formatted(abs(imp))
        let name = pattern.rawValue
        switch efficiency {
        case .efficient:
            return imp > 0
                ? "+\(pct)%/wk — volume and intensity are dialled in."
                : "Holding steady — maintain current approach."
        case .inefficient:
            return "High volume but only +\(pct)%/wk — consider fewer, heavier sets."
        case .opportunity:
            return "+\(pct)%/wk with low volume — adding a session here could compound fast."
        case .lowPriority:
            return imp >= 0
                ? "Progressing slowly on \(name) — increase frequency or load."
                : "Strength declining on \(name) — address recovery or deload."
        }
    }

    private static func formatted(_ v: Double) -> String { String(format: "%.1f", v) }
}
