import Foundation

// MARK: - Muscle Physiology Data

enum MuscleGroup: String, CaseIterable {
    case quadriceps       = "Quadriceps"
    case gluteusMaximus   = "Glutes"
    case hamstrings       = "Hamstrings"
    case erectorSpinae    = "Erectors"
    case latissimus       = "Lats"
    case trapezius        = "Traps"
    case rhomboids        = "Rhomboids"
    case pectoralisMajor  = "Pectorals"
    case anteriorDeltoid  = "Ant. Delt"
    case lateralDeltoid   = "Lat. Delt"
    case posteriorDeltoid = "Post. Delt"
    case bicepsBrachii    = "Biceps"
    case tricepsBrachii   = "Triceps"
    case rectusAbdominis  = "Abs"
    case gastrocnemius    = "Calves"

    // Physiological Cross-Sectional Area (cm²) — normalized to 70 kg reference body.
    // Sources: Ward et al. (2009), Lieber & Fridén (2000), Gray's Anatomy.
    var pcsa: Double {
        switch self {
        case .quadriceps:       return 148.0
        case .gluteusMaximus:   return  80.0
        case .hamstrings:       return  75.0
        case .erectorSpinae:    return  90.0
        case .latissimus:       return  45.0
        case .trapezius:        return  35.0
        case .rhomboids:        return  20.0
        case .pectoralisMajor:  return  35.0
        case .anteriorDeltoid:  return  10.0
        case .lateralDeltoid:   return   8.0
        case .posteriorDeltoid: return   8.0
        case .bicepsBrachii:    return  15.0
        case .tricepsBrachii:   return  22.0
        case .rectusAbdominis:  return  15.0
        case .gastrocnemius:    return  25.0
        }
    }
}

struct MuscleActivation {
    let muscle: MuscleGroup
    let pctMVC: Double  // 0–1, EMG-derived % of Maximum Voluntary Contraction

    static func a(_ m: MuscleGroup, _ v: Double) -> MuscleActivation { .init(muscle: m, pctMVC: v) }
}

// MARK: - Score Result Types

struct PSIPoint: Identifiable {
    let id = UUID()
    let date: Date
    let rawFiberLoad: Double        // Σ (relIntensity^1.8 × reps × activationWeight), unnormalized
    let normalizedPSI: Double?      // rawFiberLoad / bodyWeight^0.67
    let leanPSI: Double?            // rawFiberLoad / leanMass^0.67
    let musclePSI: Double?          // rawFiberLoad / muscleMass^0.67
}

// Per-session fiber load for one movement pattern
struct PatternPSIPoint: Identifiable {
    let id = UUID()
    let date: Date
    let rawFiberLoad: Double        // Σ (rel^1.8 × reps × activationWeight) for exercises in this pattern
}

// PCSA-weighted strength snapshot + momentum for one PatternGroup
struct PatternStrengthResult {
    let group: PatternGroup
    let history: [PatternPSIPoint]  // one point per session where this pattern was trained
    // Level: Σ(activationWeight_i × latestE1RM_i/bestE1RM_i) / Σ(activationWeight_i), scaled 0–100
    let levelScore: Double
    // Momentum: OLS trend of rawFiberLoad → %/wk → mapped 0–100 (50 = flat)
    let momentumScore: Double
    let pctChangePerWeek: Double         // raw OLS %/wk for display (signed)
    let activationWeightTotal: Double    // Σ(pctMVC × PCSA) across exercises in this pattern
}

enum RelativeStrengthTier: String, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced     = "Advanced"
    case elite        = "Elite"

    var shortLabel: String {
        switch self {
        case .beginner:   return "Beg"
        case .intermediate: return "Int"
        case .advanced:     return "Adv"
        case .elite:        return "Elite"
        }
    }
}

struct StrengthThresholds {
    let beginner: Double      // top of Beginner range
    let intermediate: Double  // top of Intermediate range
    let advanced: Double      // top of Advanced range (above = Elite)
}

struct RelativeStrengthPoint: Identifiable {
    let id = UUID()
    let exercise: Exercise
    let e1RM: Double              // all-time best — used for tier threshold
    let recentE1RM: Double        // avg of last 3 sessions — drives displayed ratio
    let relativeStrength: Double  // recentE1RM / bodyWeight — updates every session
    let tier: RelativeStrengthTier
    let thresholds: StrengthThresholds  // body-weight-adjusted tier boundaries
}

struct BodyCompStrength {
    let leanMassKg: Double?
    let muscleMassKg: Double?
    let psiPerLeanMass: Double?     // latest rawFiberLoad / leanMass^0.67
    let psiPerMuscleMass: Double?   // latest rawFiberLoad / muscleMass^0.67
    let strengthToFatRatio: Double? // latest rawFiberLoad / bodyFatPercent
}

enum StrengthTier: String, Comparable {
    case beginner     = "Beginner"
    case intermediate = "Intermediate"
    case advanced     = "Advanced"
    case elite        = "Elite"

    private var order: Int {
        switch self {
        case .beginner: return 0; case .intermediate: return 1
        case .advanced: return 2; case .elite:        return 3
        }
    }
    static func < (lhs: StrengthTier, rhs: StrengthTier) -> Bool { lhs.order < rhs.order }

    var description: String {
        switch self {
        case .beginner:     return "Building your foundation"
        case .intermediate: return "Consistent progress"
        case .advanced:     return "Strong performer"
        case .elite:        return "Top-tier strength"
        }
    }

    var systemImage: String {
        switch self {
        case .beginner:     return "figure.strengthtraining.traditional"
        case .intermediate: return "bolt.fill"
        case .advanced:     return "flame.fill"
        case .elite:        return "crown.fill"
        }
    }
}

// MARK: - PPL Category

enum PPLCategory: String, CaseIterable, Hashable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"

    var patterns: Set<MovementPattern> {
        switch self {
        case .push: return [.horizontalPush, .verticalPush]
        case .pull: return [.horizontalPull, .verticalPull, .hipHinge]
        case .legs: return [.kneeFlexion]
        }
    }

    var icon: String {
        switch self {
        case .push: return "arrow.up.circle.fill"
        case .pull: return "arrow.down.circle.fill"
        case .legs: return "figure.run"
        }
    }
}

// MARK: - Composite Strength Score

struct CompositeStrengthScore {
    let score: Double                        // 0–100, average of covered PPL categories
    let tier: StrengthTier                   // derived from score, possibly capped by coverage
    let pplScores: [PPLCategory: Double]     // per-category 0–100 scores
    let coveredCategories: Set<PPLCategory>  // categories that have logged compound data
    let isCoverageGated: Bool                // true when tier is capped by missing categories

    var missingCategories: [PPLCategory] {
        PPLCategory.allCases.filter { !coveredCategories.contains($0) }
    }

    var isComplete: Bool { coveredCategories.count == PPLCategory.allCases.count }
}

// MARK: - Score Result

struct StrengthScoreResult {
    let psiHistory: [PSIPoint]
    let currentRawPSI: Double?
    let currentNormalizedPSI: Double?
    let psiTrendPctPerWeek: Double
    let relativeStrengths: [RelativeStrengthPoint]
    let bodyCompStrength: BodyCompStrength?
    let compositeScore: CompositeStrengthScore?
    let patternBreakdown: [PatternGroup: PatternStrengthResult]

    // Backward-compatible accessor used by analytics and UI layers
    var overallTier: StrengthTier { compositeScore?.tier ?? .beginner }

    static let empty = StrengthScoreResult(
        psiHistory: [],
        currentRawPSI: nil,
        currentNormalizedPSI: nil,
        psiTrendPctPerWeek: 0,
        relativeStrengths: [],
        bodyCompStrength: nil,
        compositeScore: nil,
        patternBreakdown: [:]
    )
}

// MARK: - Engine

enum StrengthScoreEngine {

    // MARK: Entry Point

    static func compute(
        log: [WorkoutLogEntry],
        exercises: [Exercise],
        userProfile: UserProfile
    ) -> StrengthScoreResult {
        guard !log.isEmpty else { return .empty }

        let bw         = userProfile.bodyWeightKg
        let bfPct      = userProfile.bodyFatPercent
        let mmPct      = userProfile.muscleMassPercent
        let leanMass   = bw.flatMap { w in bfPct.map { f in w * (1.0 - f / 100.0) } }
        let muscleMass = bw.flatMap { w in mmPct.map { m in w * m / 100.0 } }

        let psiHistory  = computePSIHistory(log: log, bw: bw, leanMass: leanMass, muscleMass: muscleMass)
        let currentRaw  = psiHistory.last?.rawFiberLoad
        let currentNorm = psiHistory.last?.normalizedPSI
        let psiTrend    = computePSITrend(history: psiHistory)
        let relStrengths = computeRelativeStrengths(log: log, exercises: exercises, bodyWeight: bw, age: userProfile.age)
        let bodyComp    = computeBodyCompStrength(
            latestRaw: currentRaw, bw: bw, leanMass: leanMass, muscleMass: muscleMass, bfPct: bfPct
        )
        let composite = computeCompositeScore(relStrengths: relStrengths)
        let patternBreakdown = computePatternBreakdown(log: log, bodyWeight: bw)

        return StrengthScoreResult(
            psiHistory: psiHistory,
            currentRawPSI: currentRaw,
            currentNormalizedPSI: currentNorm,
            psiTrendPctPerWeek: psiTrend,
            relativeStrengths: relStrengths,
            bodyCompStrength: bodyComp,
            compositeScore: composite,
            patternBreakdown: patternBreakdown
        )
    }

    // MARK: PSI History

    private static func computePSIHistory(
        log: [WorkoutLogEntry],
        bw: Double?,
        leanMass: Double?,
        muscleMass: Double?
    ) -> [PSIPoint] {
        // Rolling best per exercise — avoids retroactive downscaling when a later PR is set.
        // Bodyweight exercises use the user's bodyweight as the effective load.
        var runningBest: [UUID: Double] = [:]
        return log.sorted { $0.startedAt < $1.startedAt }.map { entry in
            for we in entry.exercises {
                let best = effectiveBestE1RM(for: we, bodyWeight: bw)
                if best > 0 { runningBest[we.exercise.id] = max(runningBest[we.exercise.id, default: 0], best) }
            }
            var sessionLoad = 0.0
            for we in entry.exercises {
                let refE1RM = runningBest[we.exercise.id] ?? 0
                guard refE1RM > 0 else { continue }
                let profile = activationProfile(for: we.exercise)
                let activationWeight = profile.reduce(0.0) { $0 + $1.pctMVC * $1.muscle.pcsa }
                let isBodyweight = we.exercise.equipment == .bodyweight
                let isAssisted  = we.exercise.isAssistedCounterweight
                for set in we.completedSets where set.reps > 0 {
                    let setWeight: Double
                    if isBodyweight    { setWeight = bw ?? 0 }
                    else if isAssisted { setWeight = max(0, (bw ?? 0) - set.weight) }
                    else               { setWeight = set.weight }
                    guard setWeight > 0 else { continue }
                    let rel = min(setWeight / refE1RM, 1.0)
                    sessionLoad += pow(rel, 1.8) * Double(set.reps) * activationWeight
                }
            }
            return PSIPoint(
                date: entry.startedAt,
                rawFiberLoad: sessionLoad,
                normalizedPSI:   bw.map         { sessionLoad / pow($0, 0.67) },
                leanPSI:         leanMass.map   { sessionLoad / pow($0, 0.67) },
                musclePSI:       muscleMass.map { sessionLoad / pow($0, 0.67) }
            )
        }
    }

    /// Best e1RM for an exercise in a session.
    /// Uses dropAdjustedE1RM to match ExerciseAnalytics and give drop-set sessions full credit.
    /// Bodyweight exercises use bodyweight as effective load (Pull-Ups / Push-Ups).
    private static func effectiveBestE1RM(for we: WorkoutExercise, bodyWeight bw: Double?) -> Double {
        let eq = we.exercise.equipment
        if eq == .bodyweight, let bodyWt = bw, bodyWt > 0 {
            return we.completedSets
                .filter { $0.reps > 0 && $0.reps <= 20 }
                .map { SetRecord.e1RM(weight: bodyWt, reps: $0.reps) }
                .max() ?? 0
        }
        // Assisted machines log the counterbalance weight; effective load = BW − assist.
        // Higher assist = lighter work, so we look for the MINIMUM assist (hardest set).
        if we.exercise.isAssistedCounterweight, let bodyWt = bw, bodyWt > 0 {
            return we.completedSets
                .filter { $0.reps > 0 && $0.reps <= 20 && $0.weight < bodyWt }
                .map { SetRecord.e1RM(weight: bodyWt - $0.weight, reps: $0.reps) }
                .max() ?? 0
        }
        return we.completedSets
            .map { $0.dropAdjustedE1RM(equipment: eq) }
            .max() ?? 0
    }

    // MARK: PSI Trend (%/week OLS over last 6 weeks)

    private static func computePSITrend(history: [PSIPoint]) -> Double {
        guard history.count >= 3, let first = history.first else { return 0 }
        let cutoff = Date().addingTimeInterval(-6 * 7 * 86400)
        let recent = history.filter { $0.date >= cutoff }
        let pts = (recent.count >= 3 ? recent : history).map { pt in
            (x: pt.date.timeIntervalSince(first.date) / (7 * 86400), y: pt.rawFiberLoad)
        }
        guard pts.count >= 2 else { return 0 }
        let (slope, _) = StrengthAnalyticsEngine.linearRegression(pts)
        let mean = pts.map(\.y).reduce(0, +) / Double(pts.count)
        return mean > 0 ? slope / mean * 100 : 0
    }

    // MARK: Relative Strength

    private static func computeRelativeStrengths(
        log: [WorkoutLogEntry],
        exercises: [Exercise],
        bodyWeight: Double?,
        age: Int? = nil
    ) -> [RelativeStrengthPoint] {
        guard let bw = bodyWeight, bw > 0 else { return [] }
        var bestE1RM: [UUID: Double] = [:]
        var sessionHistory: [UUID: [Double]] = [:]
        for entry in log.sorted(by: { $0.startedAt < $1.startedAt }) {
            for we in entry.exercises {
                // Use bodyweight as effective load for bodyweight exercises (Pull-Ups, Push-Ups, etc.)
                let best = effectiveBestE1RM(for: we, bodyWeight: bw)
                guard best > 0 else { continue }
                bestE1RM[we.exercise.id] = max(bestE1RM[we.exercise.id, default: 0], best)
                sessionHistory[we.exercise.id, default: []].append(best)
            }
        }
        let exMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        return bestE1RM.compactMap { id, peakE1RM -> RelativeStrengthPoint? in
            guard peakE1RM > 0, let ex = exMap[id] else { return nil }
            let last3 = (sessionHistory[id] ?? []).suffix(3)
            let recentE1RM = last3.isEmpty ? peakE1RM : last3.reduce(0, +) / Double(last3.count)
            let t = thresholds(for: ex, bodyWeight: bw, age: age)
            // effectiveBestE1RM() returns bilateral-total e1RM for dumbbell exercises
            // (2 × per-hand × 0.92 bilateral-deficit factor). The exerciseMultiplier
            // thresholds are calibrated against per-dumbbell e1RM / BW, so we must
            // strip the bilateral factor before computing the relative-strength ratio.
            let displayE1RM: Double
            let peakRel: Double
            if ex.equipment == .dumbbell {
                let perHandE1RM = peakE1RM / (2.0 * 0.92)   // undo bilateral adjustment
                displayE1RM = perHandE1RM
                peakRel = perHandE1RM / bw
            } else {
                displayE1RM = peakE1RM
                peakRel = peakE1RM / bw
            }
            return RelativeStrengthPoint(
                exercise: ex,
                e1RM: displayE1RM,
                recentE1RM: ex.equipment == .dumbbell ? recentE1RM / (2.0 * 0.92) : recentE1RM,
                relativeStrength: peakRel,
                tier: relativeStrengthTier(rel: peakRel, thresholds: t),
                thresholds: t
            )
        }
        .sorted { $0.relativeStrength > $1.relativeStrength }
    }

    // MARK: Body Comp Strength

    private static func computeBodyCompStrength(
        latestRaw: Double?,
        bw: Double?,
        leanMass: Double?,
        muscleMass: Double?,
        bfPct: Double?
    ) -> BodyCompStrength? {
        guard latestRaw != nil || leanMass != nil || muscleMass != nil else { return nil }
        let raw = latestRaw ?? 0
        return BodyCompStrength(
            leanMassKg:          leanMass,
            muscleMassKg:        muscleMass,
            psiPerLeanMass:      leanMass.map   { raw / pow($0, 0.67) },
            psiPerMuscleMass:    muscleMass.map { raw / pow($0, 0.67) },
            strengthToFatRatio:  bfPct.map { pct in pct > 0 ? raw / pct : nil }.flatMap { $0 }
        )
    }

    // MARK: Composite Strength Score
    //
    // Replaces the old ordinal-average tier system. Design:
    //   1. Group compound lifts into PPL categories (Push/Pull/Legs).
    //   2. Convert each lift to a 0–100 tierScore using calibrated thresholds.
    //   3. Average scores within each category.
    //   4. Composite = average of covered categories (missing categories don't drag score).
    //   5. Coverage gate: Elite requires all 3 categories; Advanced requires ≥ 2; etc.
    //      Missing categories are shown as "incomplete" rather than silently penalising.
    //
    // Score bands: 0–20 Beginner · 20–50 Intermediate · 50–80 Advanced · 80–100 Elite

    static func computeCompositeScore(relStrengths: [RelativeStrengthPoint]) -> CompositeStrengthScore? {
        let compounds = relStrengths.filter { $0.exercise.isCompound }
        guard !compounds.isEmpty else { return nil }

        var pplScores: [PPLCategory: Double] = [:]
        for category in PPLCategory.allCases {
            let lifts = compounds.filter { category.patterns.contains($0.exercise.movementPattern) }
            guard !lifts.isEmpty else { continue }
            let scores = lifts.map { tierScore(relStrength: $0.relativeStrength, thresholds: $0.thresholds) }
            pplScores[category] = scores.reduce(0, +) / Double(scores.count)
        }

        guard !pplScores.isEmpty else { return nil }

        let covered = Set(pplScores.keys)
        let compositeScore = pplScores.values.reduce(0, +) / Double(pplScores.count)
        let rawTier = tierFromScore(compositeScore)

        // Coverage gate: each missing PPL category caps the maximum achievable tier
        //   3/3 covered → no cap
        //   2/3 covered → max Advanced
        //   1/3 covered → max Intermediate
        let coverageCap: StrengthTier
        switch covered.count {
        case 3:  coverageCap = .elite
        case 2:  coverageCap = .advanced
        default: coverageCap = .intermediate
        }

        let gatedTier = min(rawTier, coverageCap)
        let isCoverageGated = rawTier > coverageCap

        return CompositeStrengthScore(
            score: compositeScore,
            tier: gatedTier,
            pplScores: pplScores,
            coveredCategories: covered,
            isCoverageGated: isCoverageGated
        )
    }

    static func tierFromScore(_ score: Double) -> StrengthTier {
        if score < 20 { return .beginner }
        if score < 50 { return .intermediate }
        if score < 80 { return .advanced }
        return .elite
    }

    // MARK: Relative Strength Tiers — body-weight-adjusted thresholds (Lab system)
    //
    // This is the Lab's calculation path, separate from the Progress tab's standardLiftSections.
    // It covers every exercise via pattern + multiplier rather than named lift benchmarks.
    //
    // Brackets: <70 kg / 70–90 kg / 90–110 kg / >110 kg (heavier lifters face higher absolute loads).
    // Values are e1RM ÷ bodyWeight multipliers at the TOP of each tier (same convention as StrengthThresholds).
    // Base values derived from Symmetric Strength / ExRx population data for barbell reference exercises.
    // exerciseMultiplier() then scales thresholds up or down for non-reference movements.

    // Maps a relative strength ratio to 0–100 using asymmetric tier bands:
    //   0–20 = Beginner · 20–50 = Intermediate · 50–80 = Advanced · 80–100 = Elite
    // Wider intermediate and advanced bands reflect real population distribution.
    //
    // Elite ceiling = advanced × 1.30 — a proportional 30% extension above the
    // advanced threshold, consistent across all patterns. Previously used
    // (adv − inter) which produced different ceilings per lift (bench 2.05×,
    // deadlift 2.75× BW), making per-lift scores incomparable.
    static func tierScore(relStrength: Double, thresholds t: StrengthThresholds) -> Double {
        guard relStrength > 0 else { return 0 }
        let eliteRange = max(t.advanced * 0.30, 0.01)  // 30% above advanced = score 100
        if relStrength < t.beginner {
            return relStrength / t.beginner * 20
        } else if relStrength < t.intermediate {
            return 20 + (relStrength - t.beginner) / (t.intermediate - t.beginner) * 30
        } else if relStrength < t.advanced {
            return 50 + (relStrength - t.intermediate) / (t.advanced - t.intermediate) * 30
        } else {
            return min(100, 80 + (relStrength - t.advanced) / eliteRange * 20)
        }
    }

    static func thresholds(for pattern: MovementPattern, bodyWeight bw: Double) -> StrengthThresholds {
        // Each tuple: (beginner ceiling, intermediate ceiling, advanced ceiling)
        // Above advanced ceiling = Elite.
        // Base values from agreed PPL standards (Symmetric Strength / Greg Nuckols).
        // Heavier bodyweight brackets use slightly lower BW-relative thresholds.
        typealias T = (Double, Double, Double)
        let t: T
        switch pattern {
        case .horizontalPush:   // reference: Barbell Bench Press
            t = bw < 70  ? (0.85, 1.25, 1.70)
              : bw < 90  ? (0.80, 1.15, 1.60)
              : bw < 110 ? (0.72, 1.05, 1.45)
              :             (0.65, 0.95, 1.30)
        case .hipHinge:         // reference: Conventional Deadlift
            t = bw < 70  ? (1.35, 1.90, 2.40)
              : bw < 90  ? (1.25, 1.75, 2.25)
              : bw < 110 ? (1.10, 1.55, 2.00)
              :             (0.95, 1.40, 1.80)
        case .kneeFlexion:      // reference: Barbell Back Squat
            t = bw < 70  ? (1.10, 1.55, 2.05)
              : bw < 90  ? (1.00, 1.40, 1.90)
              : bw < 110 ? (0.90, 1.25, 1.70)
              :             (0.80, 1.10, 1.55)
        case .verticalPush:     // reference: Barbell Overhead Press
            t = bw < 70  ? (0.50, 0.72, 1.00)
              : bw < 90  ? (0.45, 0.65, 0.90)
              : bw < 110 ? (0.40, 0.58, 0.80)
              :             (0.35, 0.52, 0.72)
        case .horizontalPull:   // reference: Barbell Row
            t = bw < 70  ? (0.82, 1.10, 1.48)
              : bw < 90  ? (0.75, 1.00, 1.35)
              : bw < 110 ? (0.68, 0.92, 1.22)
              :             (0.60, 0.82, 1.10)
        case .verticalPull:     // reference: Weighted Pull-Up (added weight / BW)
            t = bw < 70  ? (0.60, 0.90, 1.25)
              : bw < 90  ? (0.55, 0.83, 1.15)
              : bw < 110 ? (0.48, 0.75, 1.05)
              :             (0.42, 0.65, 0.90)
        case .isolation:
            t = (0.35, 0.55, 0.80)
        }
        return StrengthThresholds(beginner: t.0, intermediate: t.1, advanced: t.2)
    }

    // Exercise-specific overload: stacks an exercise multiplier and age factor on top of pattern thresholds.
    static func thresholds(for exercise: Exercise, bodyWeight bw: Double, age: Int? = nil) -> StrengthThresholds {
        let base = thresholds(for: exercise.movementPattern, bodyWeight: bw)
        let m = exerciseMultiplier(for: exercise.name)
        let a = ageAdjustmentFactor(age: age)
        return StrengthThresholds(
            beginner:     base.beginner     * m * a,
            intermediate: base.intermediate * m * a,
            advanced:     base.advanced     * m * a
        )
    }

    // Per-exercise scaling relative to the barbell free-weight reference for each pattern.
    // Values > 1.0 mean the exercise typically yields heavier loads (e.g. leg press vs squat),
    // so thresholds are scaled up proportionally. Values < 1.0 mean the movement is harder
    // or lighter (e.g. Bulgarian split squat).
    // Sources: Symmetric Strength population data, ACE EMG studies, ExRx strength standards.
    // Per-exercise scaling relative to the barbell free-weight reference for each pattern.
    // Values > 1.0 → exercise yields heavier e1RM than the pattern reference (thresholds scale up).
    // Values < 1.0 → exercise yields lighter e1RM (thresholds scale down so tier is achievable).
    //
    // Dumbbell exercises follow per-dumbbell weight convention (standard in most apps):
    //   per-dumbbell e1RM / bodyWeight ≈ 0.25× the barbell equivalent, so multiplier ≈ 0.25.
    // Unilateral exercises (single-arm row, Bulgarian split squat) are also per-side.
    //
    // Sources: Symmetric Strength population percentiles, ExRx 1RM standards,
    //          Contreras EMG studies, NSCA Exercise Technique Manual.
    private static func exerciseMultiplier(for name: String) -> Double {
        switch name {

        // ══ KNEE FLEXION — reference: Barbell Squat = 1.0 ══════════════════

        case "Leg Press":
            return 1.80   // bilateral machine; ~1.8× squat e1RM/BW at matched relative intensities
        case "Single-Leg Press":
            return 1.10   // per-leg load; roughly 60–65% of bilateral squat total
        case "Hack Squat Machine":
            return 1.20   // guided path; reduced stabilisation demand vs free squat
        case "Smith Machine Squat":
            return 1.05   // fixed bar path removes lateral balance requirement
        case "Goblet Squat":
            return 0.68   // anterior load + grip limit how much can be held
        case "Bulgarian Split Squat":
            return 0.31   // per-dumbbell; rear foot elevated + single-leg balance
        case "Walking Lunge", "Smith Machine Lunge", "Smith Machine Split Squat":
            return 0.65
        case "Leg Extension":
            return 0.35   // quad isolation machine; ~35% of squat e1RM/BW at same tier

        // ══ HIP HINGE — reference: Conventional Deadlift = 1.0 ═════════════

        case "Smith Machine Deadlift":
            return 1.03
        case "Sumo Deadlift":
            return 1.05   // wider stance shortens moment arm slightly; comparable loads
        case "Romanian Deadlift":
            return 0.88   // partial ROM; hamstring stretch limits peak load
        case "Smith Machine Romanian Deadlift":
            return 0.90
        case "Hip Thrust", "Smith Machine Hip Thrust":
            return 1.40   // supine position + glute leverage enables far heavier loads
        case "Hip Thrust Machine":
            return 1.55   // machine removes setup friction; highest hip-hinge loads
        case "Back Extension Machine":
            return 0.30   // erector isolation; load is a small fraction of deadlift
        case "Leg Curl", "Seated Leg Curl", "Lying Leg Curl":
            return 0.22   // hamstring isolation machine; ~22% of deadlift e1RM/BW

        // ══ HORIZONTAL PUSH — reference: Barbell Bench Press = 1.0 ═════════

        case "Smith Machine Bench Press":
            return 1.03
        case "Dumbbell Bench Press":
            return 0.36   // per-dumbbell; calibrated to Symmetric Strength population percentiles
        case "Chest Press Machine", "Hammer Strength Chest Press":
            return 1.10   // machine removes scapular stabilisation; more load possible
        case "Decline Chest Press Machine":
            return 1.12   // decline angle + machine = highest horizontal press loads
        case "Incline Barbell Press":
            return 0.88   // steeper angle recruits weaker anterior delt more heavily
        case "Incline Chest Press Machine":
            return 1.00   // machine advantage offsets incline difficulty
        case "Smith Machine Incline Press":
            return 0.90
        case "Incline Dumbbell Press":
            return 0.29   // per-dumbbell + incline angle combined penalty
        case "Push-Up":
            return 0.55   // bodyweight movement; ~60–65% of BW is effective load
        case "Dip":
            return 0.82   // BW + added weight; shorter pec ROM than flat bench
        case "Close-Grip Bench Press", "Smith Machine Close-Grip Press":
            return 0.95   // slightly less pec recruitment; tricep-dominant
        case "Cable Fly", "Dumbbell Fly", "Pec Deck", "Cable Crossover":
            return 0.32   // chest isolation fly; weight is far lighter than any press

        // ══ VERTICAL PUSH — reference: Barbell Overhead Press = 1.0 ════════

        case "Smith Machine Overhead Press":
            return 1.02
        case "Dumbbell Shoulder Press":
            return 0.39   // per-dumbbell; calibrated to Symmetric Strength population percentiles
        case "Arnold Press":
            return 0.38   // rotation adds control demand; slightly lower loads than DB press
        case "Machine Shoulder Press", "Hammer Strength Shoulder Press":
            return 1.08   // machine removes core/balance demand; heavier loads
        case "Lateral Raise", "Cable Lateral Raise", "Machine Lateral Raise":
            return 0.20   // side delt isolation; load is a small fraction of OHP
        case "Rear Delt Fly", "Rear Delt Machine", "Cable Rear Delt Fly":
            return 0.18   // posterior delt isolation; lightest pressing-pattern movement

        // ══ HORIZONTAL PULL — reference: Barbell Row = 1.0 ═════════════════

        case "T-Bar Row":
            return 1.00   // very close to barbell row mechanics
        case "Smith Machine Row":
            return 1.02
        case "Seated Cable Row", "Low Row Machine":
            return 1.00   // cable row ≈ barbell row at matched load
        case "Chest-Supported Row Machine":
            return 1.05   // chest pad removes lower-back stabilisation; more load possible
        case "Hammer Strength Row":
            return 1.05
        case "Single-Arm Dumbbell Row":
            return 0.49   // per-arm; calibrated to Symmetric Strength population percentiles
        case "Face Pull":
            return 0.32   // rear delt + trap cable exercise; much lighter than a row

        // ══ VERTICAL PULL — reference: Strict Pull-Up = 1.0 ════════════════

        case "Assisted Pull-Up Machine":
            return 0.60   // counterweight removes a significant portion of BW resistance
        case "Lat Pulldown":
            return 0.92   // cable; no need to stabilise body; slightly less demand than pull-up
        case "Reverse Grip Lat Pulldown":
            return 0.90   // supinated grip shifts more load to biceps; slightly less lat
        case "High Row Machine":
            return 0.88   // machine high row; reduced core stabilisation demand
        case "Lat Pullover Machine":
            return 0.72   // lat isolation via shoulder extension; no bicep contribution

        // ══ ISOLATION — thresholds are already flat; multiplier stays 1.0 ══

        default:
            return 1.0
        }
    }

    // Thresholds scale DOWN with age: older lifters need to lift relatively less
    // to reach the same tier. Based on NSCA age-related strength decline data
    // (Metter et al., J Gerontol 1997; Harridge et al., Acta Physiol 1995).
    private static func ageAdjustmentFactor(age: Int?) -> Double {
        guard let age else { return 1.0 }
        switch age {
        case ..<40:   return 1.00
        case 40..<50: return 0.93
        case 50..<60: return 0.85
        default:      return 0.75
        }
    }

    private static func relativeStrengthTier(rel: Double, thresholds t: StrengthThresholds) -> RelativeStrengthTier {
        if rel < t.beginner   { return .beginner }
        if rel < t.intermediate { return .intermediate }
        if rel < t.advanced     { return .advanced }
        return .elite
    }

    // MARK: Pattern Breakdown (PCSA-weighted)
    // Same biomechanical framework as computePSIHistory, split by PatternGroup.
    // Level = Σ(activationWeight_i × latestE1RM_i/bestE1RM_i) / Σ(activationWeight_i)
    // Momentum = OLS of pattern rawFiberLoad over time → %/wk → 0–100 (50 = flat)

    private static func computePatternBreakdown(log: [WorkoutLogEntry], bodyWeight bw: Double? = nil) -> [PatternGroup: PatternStrengthResult] {
        guard !log.isEmpty else { return [:] }

        let sorted = log.sorted { $0.startedAt < $1.startedAt }

        // Build exercise registry and per-exercise best / latest e1RM.
        // Bodyweight exercises use the user's bodyweight as effective load.
        var exerciseRegistry: [UUID: Exercise] = [:]
        var bestE1RM:   [UUID: Double] = [:]
        var latestE1RM: [UUID: Double] = [:]  // overwritten each session → ends up as most-recent
        for entry in sorted {
            for we in entry.exercises {
                exerciseRegistry[we.exercise.id] = we.exercise
                let best = effectiveBestE1RM(for: we, bodyWeight: bw)
                if best > 0 {
                    bestE1RM[we.exercise.id]   = max(bestE1RM[we.exercise.id, default: 0], best)
                    latestE1RM[we.exercise.id] = best
                }
            }
        }

        // Per-session fiber load — rolling best prevents retroactive recalculation on new PRs.
        // Bodyweight exercises use the user's bodyweight as effective load.
        var rollingBest: [UUID: Double] = [:]
        var rawHistory: [PatternGroup: [(date: Date, load: Double)]] = [:]
        for entry in sorted {
            for we in entry.exercises {
                let best = effectiveBestE1RM(for: we, bodyWeight: bw)
                if best > 0 { rollingBest[we.exercise.id] = max(rollingBest[we.exercise.id, default: 0], best) }
            }
            var sessionLoads: [PatternGroup: Double] = [:]
            for we in entry.exercises {
                let refE1RM = rollingBest[we.exercise.id] ?? 0
                guard refE1RM > 0 else { continue }
                guard let group = PatternGroup.allCases.first(where: { $0.patterns.contains(we.exercise.movementPattern) }) else { continue }
                let profile = activationProfile(for: we.exercise)
                let aw = profile.reduce(0.0) { $0 + $1.pctMVC * $1.muscle.pcsa }
                let isBodyweight = we.exercise.equipment == .bodyweight
                let isAssisted  = we.exercise.isAssistedCounterweight
                for set in we.completedSets where set.reps > 0 {
                    let setWeight: Double
                    if isBodyweight    { setWeight = bw ?? 0 }
                    else if isAssisted { setWeight = max(0, (bw ?? 0) - set.weight) }
                    else               { setWeight = set.weight }
                    guard setWeight > 0 else { continue }
                    let rel = min(setWeight / refE1RM, 1.0)
                    sessionLoads[group, default: 0] += pow(rel, 1.8) * Double(set.reps) * aw
                }
            }
            for (group, load) in sessionLoads {
                rawHistory[group, default: []].append((date: entry.startedAt, load: load))
            }
        }

        // PCSA-weighted Level per pattern:
        // Each exercise contributes proportionally to the muscle mass it recruits.
        // Weight = Σ(pctMVC × PCSA) for that exercise's activation profile.
        var patternNumerator:   [PatternGroup: Double] = [:]
        var patternDenominator: [PatternGroup: Double] = [:]
        for (id, latest) in latestE1RM {
            guard let ex   = exerciseRegistry[id],
                  let best = bestE1RM[id], best > 0,
                  let group = PatternGroup.allCases.first(where: { $0.patterns.contains(ex.movementPattern) })
            else { continue }
            let profile = activationProfile(for: ex)
            let aw = profile.reduce(0.0) { $0 + $1.pctMVC * $1.muscle.pcsa }
            patternNumerator[group,   default: 0] += aw * (latest / best)
            patternDenominator[group, default: 0] += aw
        }

        // Build results
        var result: [PatternGroup: PatternStrengthResult] = [:]
        for group in PatternGroup.allCases {
            guard let history = rawHistory[group], !history.isEmpty else { continue }

            let psiHistory = history.map { PatternPSIPoint(date: $0.date, rawFiberLoad: $0.load) }

            let num = patternNumerator[group]   ?? 0
            let den = patternDenominator[group] ?? 0
            let levelScore = den > 0 ? (num / den) * 100 : 50.0

            // OLS trend of rawFiberLoad → %/week → clamped to 0–100 around 50 (flat)
            // Windowed to 8 weeks so that new sessions meaningfully move the score.
            let pctPerWeek: Double
            let cutoff = Date().addingTimeInterval(-8 * 7 * 86400)
            let window = history.filter { $0.date >= cutoff }
            let trendSrc = window.count >= 3 ? window : history
            if trendSrc.count >= 2, let first = trendSrc.first {
                let pts = trendSrc.map { (x: $0.date.timeIntervalSince(first.date) / (7 * 86400), y: $0.load) }
                let (slope, _) = StrengthAnalyticsEngine.linearRegression(pts)
                let mean = pts.map(\.y).reduce(0, +) / Double(pts.count)
                pctPerWeek = mean > 0 ? slope / mean * 100 : 0
            } else {
                pctPerWeek = 0
            }
            let momentumScore = min(100, max(0, 50.0 + pctPerWeek * 25.0))

            result[group] = PatternStrengthResult(
                group: group,
                history: psiHistory,
                levelScore: levelScore,
                momentumScore: momentumScore,
                pctChangePerWeek: pctPerWeek,
                activationWeightTotal: den
            )
        }
        return result
    }

    // MARK: Activation Profiles (EMG-derived, Bret Contreras / ACE research)

    static func activationProfile(for exercise: Exercise) -> [MuscleActivation] {
        let a = MuscleActivation.a
        switch exercise.name {

        // ── CHEST ────────────────────────────────────────────────────────────
        case "Barbell Bench Press", "Smith Machine Bench Press":
            return [a(.pectoralisMajor, 0.85), a(.anteriorDeltoid, 0.70), a(.tricepsBrachii, 0.75)]
        case "Incline Barbell Press", "Incline Chest Press Machine",
             "Smith Machine Incline Press", "Incline Dumbbell Press":
            return [a(.pectoralisMajor, 0.75), a(.anteriorDeltoid, 0.85), a(.tricepsBrachii, 0.70)]
        case "Dumbbell Bench Press", "Chest Press Machine",
             "Hammer Strength Chest Press", "Decline Chest Press Machine":
            return [a(.pectoralisMajor, 0.80), a(.anteriorDeltoid, 0.65), a(.tricepsBrachii, 0.70)]
        case "Push-Up":
            return [a(.pectoralisMajor, 0.70), a(.anteriorDeltoid, 0.65), a(.tricepsBrachii, 0.65)]
        case "Dip":
            return [a(.pectoralisMajor, 0.75), a(.anteriorDeltoid, 0.60), a(.tricepsBrachii, 0.80)]
        case "Cable Fly", "Dumbbell Fly", "Pec Deck", "Cable Crossover":
            return [a(.pectoralisMajor, 0.90), a(.anteriorDeltoid, 0.30)]

        // ── BACK ─────────────────────────────────────────────────────────────
        case "Deadlift", "Smith Machine Deadlift":
            return [a(.erectorSpinae, 0.85), a(.gluteusMaximus, 0.80), a(.hamstrings, 0.75),
                    a(.quadriceps, 0.50), a(.trapezius, 0.60), a(.latissimus, 0.55)]
        case "Barbell Row", "T-Bar Row", "Smith Machine Row":
            return [a(.latissimus, 0.80), a(.trapezius, 0.70), a(.rhomboids, 0.75),
                    a(.posteriorDeltoid, 0.55), a(.bicepsBrachii, 0.65)]
        case "Seated Cable Row", "Low Row Machine", "Chest-Supported Row Machine":
            return [a(.latissimus, 0.75), a(.trapezius, 0.65), a(.rhomboids, 0.70),
                    a(.posteriorDeltoid, 0.50), a(.bicepsBrachii, 0.60)]
        case "Single-Arm Dumbbell Row", "Hammer Strength Row":
            return [a(.latissimus, 0.82), a(.trapezius, 0.60), a(.rhomboids, 0.65),
                    a(.posteriorDeltoid, 0.45), a(.bicepsBrachii, 0.55)]
        case "Pull-Up", "Assisted Pull-Up Machine":
            return [a(.latissimus, 0.88), a(.bicepsBrachii, 0.72),
                    a(.trapezius, 0.50), a(.posteriorDeltoid, 0.40)]
        case "Lat Pulldown", "Reverse Grip Lat Pulldown",
             "High Row Machine", "Lat Pullover Machine":
            return [a(.latissimus, 0.85), a(.bicepsBrachii, 0.65),
                    a(.trapezius, 0.45), a(.posteriorDeltoid, 0.35)]
        case "Face Pull":
            return [a(.posteriorDeltoid, 0.85), a(.trapezius, 0.70), a(.rhomboids, 0.65)]

        // ── SHOULDERS ────────────────────────────────────────────────────────
        case "Overhead Press", "Smith Machine Overhead Press":
            return [a(.anteriorDeltoid, 0.90), a(.lateralDeltoid, 0.65),
                    a(.tricepsBrachii, 0.65), a(.trapezius, 0.45)]
        case "Dumbbell Shoulder Press", "Arnold Press",
             "Machine Shoulder Press", "Hammer Strength Shoulder Press":
            return [a(.anteriorDeltoid, 0.85), a(.lateralDeltoid, 0.70), a(.tricepsBrachii, 0.60)]
        case "Lateral Raise", "Cable Lateral Raise", "Machine Lateral Raise":
            return [a(.lateralDeltoid, 0.85), a(.anteriorDeltoid, 0.30), a(.trapezius, 0.20)]
        case "Rear Delt Fly", "Rear Delt Machine", "Cable Rear Delt Fly":
            return [a(.posteriorDeltoid, 0.90), a(.trapezius, 0.50), a(.rhomboids, 0.55)]

        // ── ARMS ─────────────────────────────────────────────────────────────
        case "Barbell Curl", "Dumbbell Curl", "Hammer Curl", "Cable Curl",
             "Machine Bicep Curl", "Preacher Curl Machine",
             "Cable Hammer Curl", "Reverse Curl":
            return [a(.bicepsBrachii, 0.85)]
        case "Tricep Pushdown", "Rope Pushdown", "Tricep Machine":
            return [a(.tricepsBrachii, 0.85)]
        case "Skull Crusher", "Overhead Tricep Extension",
             "Cable Overhead Tricep Extension":
            return [a(.tricepsBrachii, 0.88)]
        case "Close-Grip Bench Press", "Smith Machine Close-Grip Press":
            return [a(.tricepsBrachii, 0.82), a(.pectoralisMajor, 0.55), a(.anteriorDeltoid, 0.50)]

        // ── LEGS ─────────────────────────────────────────────────────────────
        case "Barbell Squat", "Smith Machine Squat", "Goblet Squat":
            return [a(.quadriceps, 0.88), a(.gluteusMaximus, 0.72),
                    a(.hamstrings, 0.42), a(.erectorSpinae, 0.55)]
        case "Hack Squat Machine":
            return [a(.quadriceps, 0.90), a(.gluteusMaximus, 0.60), a(.hamstrings, 0.35)]
        case "Leg Press", "Single-Leg Press":
            return [a(.quadriceps, 0.85), a(.gluteusMaximus, 0.65), a(.hamstrings, 0.40)]
        case "Romanian Deadlift", "Smith Machine Romanian Deadlift":
            return [a(.hamstrings, 0.85), a(.gluteusMaximus, 0.70), a(.erectorSpinae, 0.65)]
        case "Sumo Deadlift":
            return [a(.erectorSpinae, 0.75), a(.gluteusMaximus, 0.85), a(.hamstrings, 0.70),
                    a(.quadriceps, 0.65), a(.trapezius, 0.50)]
        case "Hip Thrust", "Smith Machine Hip Thrust", "Hip Thrust Machine":
            return [a(.gluteusMaximus, 0.95), a(.hamstrings, 0.55), a(.quadriceps, 0.30)]
        case "Bulgarian Split Squat", "Walking Lunge",
             "Smith Machine Lunge", "Smith Machine Split Squat":
            return [a(.quadriceps, 0.82), a(.gluteusMaximus, 0.75), a(.hamstrings, 0.45)]
        case "Leg Curl", "Seated Leg Curl", "Lying Leg Curl":
            return [a(.hamstrings, 0.90)]
        case "Leg Extension":
            return [a(.quadriceps, 0.92)]
        case "Standing Calf Raise", "Seated Calf Raise":
            return [a(.gastrocnemius, 0.90)]
        case "Hip Abduction Machine":
            return [a(.gluteusMaximus, 0.65)]
        case "Hip Adduction Machine":
            return [a(.gluteusMaximus, 0.45)]
        case "Glute Kickback Machine":
            return [a(.gluteusMaximus, 0.88)]

        // ── CORE ─────────────────────────────────────────────────────────────
        case "Plank", "Dead Bug":
            return [a(.rectusAbdominis, 0.50), a(.erectorSpinae, 0.40)]
        case "Cable Crunch", "Machine Crunch":
            return [a(.rectusAbdominis, 0.85)]
        case "Hanging Leg Raise", "Ab Wheel Rollout":
            return [a(.rectusAbdominis, 0.80), a(.erectorSpinae, 0.30)]
        case "Russian Twist", "Seated Oblique Machine", "Cable Woodchop":
            return [a(.rectusAbdominis, 0.65)]
        case "Back Extension Machine":
            return [a(.erectorSpinae, 0.80), a(.gluteusMaximus, 0.45)]

        default:
            return patternFallback(pattern: exercise.movementPattern)
        }
    }

    private static func patternFallback(pattern: MovementPattern) -> [MuscleActivation] {
        let a = MuscleActivation.a
        switch pattern {
        case .horizontalPush:
            return [a(.pectoralisMajor, 0.75), a(.anteriorDeltoid, 0.60), a(.tricepsBrachii, 0.65)]
        case .verticalPush:
            return [a(.anteriorDeltoid, 0.75), a(.lateralDeltoid, 0.55), a(.tricepsBrachii, 0.60)]
        case .horizontalPull:
            return [a(.latissimus, 0.70), a(.trapezius, 0.60), a(.rhomboids, 0.55), a(.bicepsBrachii, 0.55)]
        case .verticalPull:
            return [a(.latissimus, 0.80), a(.bicepsBrachii, 0.65), a(.trapezius, 0.45)]
        case .hipHinge:
            return [a(.erectorSpinae, 0.75), a(.gluteusMaximus, 0.70), a(.hamstrings, 0.65)]
        case .kneeFlexion:
            return [a(.quadriceps, 0.80), a(.gluteusMaximus, 0.60), a(.hamstrings, 0.40)]
        case .isolation:
            return [a(.pectoralisMajor, 0.50)]
        }
    }
}
