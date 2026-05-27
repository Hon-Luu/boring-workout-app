import Foundation

// MARK: - Result Types

struct CSSHistoryPoint: Identifiable {
    let id    = UUID()
    let date:  Date
    let score: Double           // 0–100 composite
    let level: Double           // 0–100 sub-score
    let momentum: Double        // 0–100 sub-score
    let process: Double         // 0–100 sub-score (nil-filled to 50 when insufficient data)
}

struct CompositeStrengthResult {
    let overallScore:    Double          // 0–100
    let levelScore:      Double          // 0–100
    let momentumScore:   Double          // 0–100
    let processScore:    Double          // 0–100
    let grade:           String          // S / A / B / C / D / F
    let gradeColor:      String          // "purple","green","blue","yellow","orange","red"
    let insight:         String          // single coaching sentence
    let history:         [CSSHistoryPoint]

    // Process sub-scores for detail view
    let inolSubScore:      Double?       // 0–100
    let efficiencySubScore: Double?      // 0–100
    let repDecaySubScore:  Double?       // 0–100

    // Level sub-scores for detail view
    let peakRetentionPct:  Double        // current e1RM as % of all-time best, avg across exercises
    let psiLevelScore:     Double?       // PSI as % of personal PSI best (0–100), nil if no BW

    static let empty = CompositeStrengthResult(
        overallScore: 0, levelScore: 0, momentumScore: 50, processScore: 50,
        grade: "—", gradeColor: "gray",
        insight: "Log at least 3 sessions to compute your Composite Strength Score.",
        history: [],
        inolSubScore: nil, efficiencySubScore: nil, repDecaySubScore: nil,
        peakRetentionPct: 0, psiLevelScore: nil
    )
}

// MARK: - Engine

enum CompositeStrengthEngine {

    // Pillar weights
    private static let wLevel:    Double = 0.35
    private static let wMomentum: Double = 0.40
    private static let wProcess:  Double = 0.25

    // MARK: - Entry Point

    static func compute(
        exerciseAnalytics:    [ExerciseAnalytics],
        psiHistory:           [PSIPoint],
        userProfile:          UserProfile,
        relativeStrengths:    [RelativeStrengthPoint] = [],
        experienceTier:       StrengthTier = .intermediate,
        isExpectedSuppression: Bool = false
    ) -> CompositeStrengthResult {
        guard !exerciseAnalytics.isEmpty else { return .empty }

        // ── Pillar 1: Level ──────────────────────────────────────────────
        let (levelScore, peakRetention, psiLevel) = computeLevel(
            exerciseAnalytics: exerciseAnalytics,
            psiHistory: psiHistory,
            relativeStrengths: relativeStrengths
        )

        // ── Pillar 2: Momentum ───────────────────────────────────────────
        let momentumScore = computeMomentum(
            exerciseAnalytics: exerciseAnalytics,
            tier: experienceTier
        )

        // ── Pillar 3: Process ────────────────────────────────────────────
        let (processScore, inolSub, effSub, decaySub) = computeProcess(
            exerciseAnalytics: exerciseAnalytics,
            tier: experienceTier
        )

        let overall = wLevel * levelScore + wMomentum * momentumScore + wProcess * processScore
        let (grade, gradeColor) = scoreToGrade(overall)

        let history = buildHistory(
            psiHistory: psiHistory,
            exerciseAnalytics: exerciseAnalytics
        )

        let insight = generateInsight(
            levelScore: levelScore,
            momentumScore: momentumScore,
            processScore: processScore,
            peakRetention: peakRetention,
            inolSub: inolSub,
            effSub: effSub,
            decaySub: decaySub,
            exerciseAnalytics: exerciseAnalytics,
            isExpectedSuppression: isExpectedSuppression
        )

        return CompositeStrengthResult(
            overallScore:       overall,
            levelScore:         levelScore,
            momentumScore:      momentumScore,
            processScore:       processScore,
            grade:              grade,
            gradeColor:         gradeColor,
            insight:            insight,
            history:            history,
            inolSubScore:       inolSub,
            efficiencySubScore: effSub,
            repDecaySubScore:   decaySub,
            peakRetentionPct:   peakRetention,
            psiLevelScore:      psiLevel
        )
    }

    // MARK: - Pillar 1: Level
    // How close to your own all-time peak is your current strength?
    // 100 = you are AT your all-time best right now across all exercises
    //
    // Three components, each 0–100:
    //   A. PCSA-weighted retention — Σ(activationWeight_i × blendedRetention_i) / Σ(activationWeight_i)
    //      where blendedRetention = 0.5 × standard + 0.5 × fatigue-adjusted (recovers "rested" capacity)
    //   B. PSI level — latest rawFiberLoad / all-time peak rawFiberLoad (requires body weight)
    //   C. Relative-strength anchor — tier score averaged across compound lifts (requires body weight)
    //      Developing=0, Intermediate=33, Advanced=67, Elite=100
    //
    // Blend:
    //   With body weight → 0.50 × A + 0.30 × B + 0.20 × C
    //   Without          → A only

    private static func computeLevel(
        exerciseAnalytics: [ExerciseAnalytics],
        psiHistory: [PSIPoint],
        relativeStrengths: [RelativeStrengthPoint]
    ) -> (score: Double, peakRetentionPct: Double, psiLevelScore: Double?) {

        // A. PCSA-weighted, fatigue-blended e1RM retention
        var weightedNumerator   = 0.0
        var weightedDenominator = 0.0
        for ea in exerciseAnalytics {
            guard let latestStd = ea.sessions.last?.estimated1RM,
                  let peakStd   = ea.sessions.map(\.estimated1RM).max(),
                  peakStd > 0 else { continue }
            let stdRetention = min(1.0, latestStd / peakStd)

            // Blend with fatigue-adjusted if available — recovers "rested" capacity implied
            // by performing work under accumulated intra-session fatigue.
            let retention: Double
            if let latestAdj = ea.sessionsFatigue.last?.estimated1RM,
               let peakAdj   = ea.sessionsFatigue.map(\.estimated1RM).max(),
               peakAdj > 0 {
                retention = 0.5 * stdRetention + 0.5 * min(1.0, latestAdj / peakAdj)
            } else {
                retention = stdRetention
            }

            let profile = StrengthScoreEngine.activationProfile(for: ea.exercise)
            let aw = profile.reduce(0.0) { $0 + $1.pctMVC * $1.muscle.pcsa }
            weightedNumerator   += aw * retention
            weightedDenominator += aw
        }
        let pcsaRetention = weightedDenominator > 0
            ? (weightedNumerator / weightedDenominator) * 100 : 50.0

        // B. PSI level: latest rawFiberLoad as % of all-time peak
        var psiLevelScore: Double? = nil
        if let latestRaw = psiHistory.last?.rawFiberLoad,
           let peakRaw   = psiHistory.map(\.rawFiberLoad).max(),
           peakRaw > 0 {
            psiLevelScore = min(100, latestRaw / peakRaw * 100)
        }

        // C. Relative-strength anchor: tier position on an absolute scale
        // Compounds only — isolation tier thresholds are much lower and would inflate the score.
        let tierScores: [Double] = relativeStrengths
            .filter { $0.exercise.isCompound }
            .map { pt -> Double in
                switch pt.tier {
                case .beginner:   return 0
                case .intermediate: return 33
                case .advanced:     return 67
                case .elite:        return 100
                }
            }
        let relAnchor: Double? = tierScores.isEmpty ? nil
            : tierScores.reduce(0, +) / Double(tierScores.count)

        // Blend
        let blendedLevel: Double
        if let psi = psiLevelScore, let rel = relAnchor {
            blendedLevel = 0.50 * pcsaRetention + 0.30 * psi + 0.20 * rel
        } else if let psi = psiLevelScore {
            blendedLevel = 0.65 * pcsaRetention + 0.35 * psi
        } else {
            blendedLevel = pcsaRetention
        }

        return (blendedLevel, pcsaRetention, psiLevelScore)
    }

    // MARK: - Experience-Level Constants
    // Sources: Rippetoe & Kilgore (2007) Practical Programming; Haff & Triplett NSCA (2016);
    // Stone et al. (2007) Periodization; Tuchscherer (2009) Reactive Training Manual;
    // Hristov INOL framework derived from Prilepin's Table (1974).

    // Momentum ceiling: the %/wk that maps to score 100.
    // Novices can sustain 3%/wk; elite lifters achieving 0.5%/wk is exceptional.
    private static func momentumCeiling(for tier: StrengthTier) -> Double {
        switch tier {
        case .beginner:   return 3.0    // adds weight session-to-session; 2–5%/wk normal
        case .intermediate: return 2.0    // monthly progression; 0.5–2%/wk
        case .advanced:     return 1.0    // mesocycle-level gains; 0.25–1%/wk
        case .elite:        return 0.5    // macrocycle periodization; 0.1–0.5%/wk
        }
    }

    // INOL optimal centre: the INOL value that scores 100.
    // Prilepin's table was for elite Olympic lifters → shift zone down for lower tiers.
    private static func inolOptimalCenter(for tier: StrengthTier) -> Double {
        switch tier {
        case .beginner:   return 0.60   // zone 0.40–0.80
        case .intermediate: return 0.90   // zone 0.60–1.20
        case .advanced:     return 1.15   // zone 0.80–1.50 (Prilepin original)
        case .elite:        return 1.50   // zone 1.00–2.00
        }
    }

    // INOL penalty rate: 100 - |deviation from centre| × rate.
    // Derived so the zone boundary (half-width from centre) scores ≈80.
    // rate = 20 / half_width, where half_width = (zone_upper - zone_lower) / 2.
    private static func inolPenaltyRate(for tier: StrengthTier) -> Double {
        switch tier {
        case .beginner:   return 100.0   // half-width 0.20 → rate = 100
        case .intermediate: return  67.0   // half-width 0.30 → rate = 67
        case .advanced:     return  57.0   // half-width 0.35 → rate = 57
        case .elite:        return  40.0   // half-width 0.50 → rate = 40
        }
    }

    // MARK: - Pillar 2: Momentum
    // How fast are you improving right now?
    // Ceiling is experience-calibrated: 0%/wk always = 50; ceiling%/wk = 100; −ceiling = 0.

    private static func computeMomentum(
        exerciseAnalytics: [ExerciseAnalytics],
        tier: StrengthTier
    ) -> Double {
        let ceiling = momentumCeiling(for: tier)
        let slope   = 50.0 / ceiling     // maps ceiling%/wk → 100, −ceiling → 0

        var weightedSum  = 0.0
        var totalWeight  = 0.0

        for ea in exerciseAnalytics {
            // Blend standard + fatigue-adjusted signals equally; avoids always-optimistic max()
            let pct   = 0.5 * ea.pctChangePerWeek + 0.5 * ea.pctChangePerWeekFatigue
            let score = min(100, max(0, 50.0 + pct * slope))
            let w     = Double(ea.sessions.count)
            weightedSum += score * w
            totalWeight += w
        }

        guard totalWeight > 0 else { return 50.0 }
        return weightedSum / totalWeight
    }

    // MARK: - Pillar 3: Process
    // Is training quality (stimulus + recovery + efficiency) dialled in?
    // Sub-components: INOL (40%), Efficiency (40%), Rep Decay (20%)

    private static func computeProcess(
        exerciseAnalytics: [ExerciseAnalytics],
        tier: StrengthTier
    ) -> (score: Double, inol: Double?, efficiency: Double?, repDecay: Double?) {

        let inolCenter  = inolOptimalCenter(for: tier)
        let inolRate    = inolPenaltyRate(for: tier)

        // INOL sub-score — experience-calibrated optimal centre and penalty rate
        let inolScores: [Double] = exerciseAnalytics.compactMap { ea -> Double? in
            guard let inol = ea.latestINOL else { return nil }
            return max(0, 100.0 - abs(inol - inolCenter) * inolRate)
        }
        let inolSub: Double? = inolScores.isEmpty ? nil
            : inolScores.reduce(0, +) / Double(inolScores.count)

        // Efficiency sub-score (quartile position in own history)
        let effScores: [Double] = exerciseAnalytics.compactMap { ea -> Double? in
            guard ea.efficiencyHistory.count >= 4,
                  let latest = ea.efficiencyHistory.last else { return nil }
            let sorted = ea.efficiencyHistory.sorted()
            let n   = sorted.count
            let q1  = sorted[n / 4]
            let q3  = sorted[3 * n / 4]
            if latest >= q3 { return 90.0 }
            if latest >= q1 { return 60.0 }
            return 25.0
        }
        let effSub: Double? = effScores.isEmpty ? nil
            : effScores.reduce(0, +) / Double(effScores.count)

        // Rep Decay sub-score
        // Optimal: −1.5 to −0.5 reps/set (controlled fatigue, not too easy, not collapsing)
        let decayScores: [Double] = exerciseAnalytics.compactMap { ea -> Double? in
            guard let decay = ea.latestRepDecay else { return nil }
            switch decay {
            case -1.5 ... -0.5: return 100.0      // optimal decay
            case -2.5 ... -1.5: return 70.0        // moderately steep
            case -0.5 ..< 0.0:  return 65.0        // too consistent — sets too easy?
            case 0.0...:        return 40.0         // ascending or flat — warm-up sets or trivial
            default:            return 30.0         // extreme drop-off
            }
        }
        let decaySub: Double? = decayScores.isEmpty ? nil
            : decayScores.reduce(0, +) / Double(decayScores.count)

        // Blend sub-scores; if sub-score unavailable, substitute 50 (neutral)
        let inol = inolSub ?? 50.0
        let eff  = effSub  ?? 50.0
        let dec  = decaySub ?? 50.0
        let processScore = 0.40 * inol + 0.40 * eff + 0.20 * dec

        return (processScore, inolSub, effSub, decaySub)
    }

    // MARK: - Historical CSS
    // Per-session composite using Level + Momentum only (process data per-session not stored historically)

    private static func buildHistory(
        psiHistory: [PSIPoint],
        exerciseAnalytics: [ExerciseAnalytics]
    ) -> [CSSHistoryPoint] {
        guard psiHistory.count >= 2 else { return [] }

        let maxRaw = psiHistory.map(\.rawFiberLoad).max() ?? 1

        return psiHistory.indices.map { i in
            let pt = psiHistory[i]

            // Level: raw PSI as % of all-time peak
            let level = min(100, pt.rawFiberLoad / maxRaw * 100)

            // Momentum: 3-session rolling slope of rawFiberLoad → mapped to 0-100
            let startIdx = max(0, i - 2)
            let window   = Array(psiHistory[startIdx...i])
            let momentum: Double
            if window.count >= 2 {
                let pts = window.enumerated().map { (x: Double($0.offset), y: $0.element.rawFiberLoad) }
                let (slope, _) = StrengthAnalyticsEngine.linearRegression(pts)
                let meanLoad = window.map(\.rawFiberLoad).reduce(0, +) / Double(window.count)
                let pctWk = meanLoad > 0 ? slope / meanLoad * 100 : 0
                momentum = min(100, max(0, 50.0 + pctWk * 25.0))
            } else {
                momentum = 50.0
            }

            // Process: no per-session process data in history — substitute 50
            let process = 50.0

            // Historical weights re-normalised without process variance
            let score = 0.47 * level + 0.53 * momentum

            return CSSHistoryPoint(
                date:     pt.date,
                score:    score,
                level:    level,
                momentum: momentum,
                process:  process
            )
        }
    }

    // MARK: - Grade

    /// Maps a composite score (0–100) to a (grade label, gradeColor string) pair.
    /// gradeColor strings are the canonical source of truth — all UI switch statements
    /// must handle: "purple", "green", "blue", "yellow", "orange", "gray".
    private static func scoreToGrade(_ score: Double) -> (grade: String, color: String) {
        switch score {
        case 90...:   return ("Peak",       "purple")
        case 80..<90: return ("Strong",     "green")
        case 70..<80: return ("Solid",      "blue")
        case 60..<70: return ("Building",   "yellow")
        case 50..<60: return ("Steady",     "orange")
        case 35..<50: return ("Developing", "orange")
        default:      return ("Starting",   "gray")
        }
    }

    /// Safe lookup from a stored gradeColor string to a SwiftUI Color.
    /// Use this instead of ad-hoc switch statements in views that only have access
    /// to CompositeStrengthEngine (not HONTheme). Views that already import HONTheme
    /// should continue using their local switch so they can apply branded colours.
    /// Valid gradeColor values: "purple", "green", "blue", "yellow", "orange", "gray".
    static func color(forGradeColor gradeColor: String) -> String {
        // Validate and pass through — the switch below acts as a compile-time-checkable
        // assertion that every string scoreToGrade can emit is covered.
        switch gradeColor {
        case "purple", "green", "blue", "yellow", "orange", "gray": return gradeColor
        default:
            assertionFailure("Unexpected gradeColor '\(gradeColor)' — not produced by scoreToGrade.")
            return "gray"
        }
    }

    // MARK: - Insight

    private static func generateInsight(
        levelScore: Double,
        momentumScore: Double,
        processScore: Double,
        peakRetention: Double,
        inolSub: Double?,
        effSub: Double?,
        decaySub: Double?,
        exerciseAnalytics: [ExerciseAnalytics],
        isExpectedSuppression: Bool = false
    ) -> String {
        // Find weakest pillar
        let pillars: [(String, Double)] = [
            ("level",    levelScore),
            ("momentum", momentumScore),
            ("process",  processScore)
        ]
        let weakest = pillars.min(by: { $0.1 < $1.1 })?.0 ?? "momentum"

        switch weakest {
        case "level":
            let pct = Int(peakRetention)
            if pct >= 95 {
                return "You're at your all-time strength peak right now. Push for a PR on your next session."
            } else if pct >= 80 {
                return "Strength is at \(pct)% of your personal best. A few consistent sessions should close the gap."
            } else {
                return "Strength is at \(pct)% of your peak — signs of detraining or an extended lighter block. Prioritise consistency."
            }

        case "momentum":
            // CON-14: when TAS is expectedSuppression, low momentum is intended — hold course
            if isExpectedSuppression {
                return "Momentum is lower right now, but training load is elevated — that's expected suppression, not a problem. Hold the current program and let the work consolidate."
            }
            let stalledNames = exerciseAnalytics
                .filter { $0.isPlateau }
                .prefix(2)
                .map(\.exercise.name)
            if !stalledNames.isEmpty {
                return "\(stalledNames.joined(separator: " & ")) stalled. Vary rep range, add load, or deload for a week."
            }
            let avgPct = exerciseAnalytics.map { max($0.pctChangePerWeek, $0.pctChangePerWeekFatigue) }.reduce(0, +)
                / Double(max(1, exerciseAnalytics.count))
            if avgPct < 0 {
                return "Average trend is declining (\(String(format: "%.1f", avgPct))%/wk). Review recovery and programming."
            }
            return "Progress rate is low. Add progressive overload — try adding 2.5 kg or one extra set on main lifts."

        case "process":
            if let inol = inolSub, inol < 50 {
                // Find the exercise with the lowest INOL to name it specifically
                let lowestINOLExercise = exerciseAnalytics
                    .compactMap { ea -> (String, Double)? in
                        guard let v = ea.latestINOL else { return nil }
                        return (ea.exercise.name, v)
                    }
                    .min(by: { $0.1 < $1.1 })
                let topINOLExercise = exerciseAnalytics
                    .compactMap { ea -> (String, Double)? in
                        guard let v = ea.latestINOL else { return nil }
                        return (ea.exercise.name, v)
                    }
                    .max(by: { $0.1 < $1.1 })
                if let (name, latest) = lowestINOLExercise {
                    if latest < 0.8 {
                        return "Process score is \(Int(inol))/100 because training load (INOL) is only \(String(format: "%.2f", latest)) on \(name) — below the 0.8 optimal floor. Add 1–2 sets or push 2.5 kg heavier to lift stimulus into the productive zone."
                    } else if let (highName, highVal) = topINOLExercise, highVal > 2.0 {
                        if momentumScore >= 55 {
                            return "INOL on \(highName) is \(String(format: "%.2f", highVal)) — high load, but e1RM is still climbing so you're recovering well. Plan a deload week if progress stalls."
                        } else {
                            return "INOL on \(highName) is \(String(format: "%.2f", highVal)) and momentum has plateaued — your body is not recovering fully. Drop one set per exercise for a week."
                        }
                    }
                }
            }
            if let eff = effSub, eff < 40 {
                return "Rep efficiency is \(Int(eff))/100 — e1RM gains per unit of training effort are below your own average. Log feel ratings and ensure ≥7h sleep; both directly predict efficiency score."
            }
            if let decay = decaySub, decay < 50 {
                return "Set-to-set rep decay is high (score \(Int(decaySub ?? 0))/100) — fatigue is building faster than recovery allows. Extend rest between sets by 30–60 s or reduce total set count."
            }
            return "Log a few more sessions to get full training quality feedback."

        default:
            return "Keep training consistently. Score will improve as more sessions are logged."
        }
    }
}
