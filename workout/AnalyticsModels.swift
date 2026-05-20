import Foundation
import SwiftUI

// MARK: - Aggregation Hierarchy

/// The level at which a metric is aggregated.
/// Dashboard auto-selects the finest tier that has ≥ 3 data points.
enum AggregationTier: String {
    case exercise         = "Exercise"
    case equivalenceGroup = "Group"
    case movementPattern  = "Pattern"
    case patternGroup     = "Push/Pull/Legs"
}

// MARK: - Exercise Coefficients
// Normalises e1RM from any exercise to its pattern's canonical free-weight barbell reference.
// Source: Saeterbakken (2011), Schwambeder (2020), Welsch (2005), population meta-analyses.

enum ExerciseCoefficients {

    static let canonicalReference: [MovementPattern: String] = [
        .horizontalPush: "Barbell Bench Press",
        .verticalPush:   "Overhead Press",
        .horizontalPull: "Barbell Row",
        .verticalPull:   "Pull-Up",
        .hipHinge:       "Deadlift",
        .kneeFlexion:    "Barbell Squat",
        .isolation:      "",
    ]

    /// Population-average coefficient: exerciseName → fraction of canonical reference e1RM.
    static let population: [String: Double] = [
        // ── Horizontal Push ──────────────────────
        "Barbell Bench Press":             1.00,
        "Smith Machine Bench Press":       0.93,
        "Dumbbell Bench Press":            0.87,
        "Chest Press Machine":             0.88,
        "Hammer Strength Chest Press":     0.88,
        "Incline Barbell Press":           0.82,
        "Incline Dumbbell Press":          0.75,
        "Smith Machine Incline Press":     0.78,
        "Incline Chest Press Machine":     0.80,
        "Decline Chest Press Machine":     0.96,
        "Dip":                             0.85,
        "Push-Up":                         0.64,
        // ── Vertical Push ────────────────────────
        "Overhead Press":                  1.00,
        "Dumbbell Shoulder Press":         0.86,
        "Machine Shoulder Press":          0.88,
        "Smith Machine Overhead Press":    0.91,
        "Arnold Press":                    0.82,
        "Hammer Strength Shoulder Press":  0.88,
        // ── Horizontal Pull ──────────────────────
        "Barbell Row":                     1.00,
        "Single-Arm Dumbbell Row":         0.85,
        "Seated Cable Row":                0.82,
        "T-Bar Row":                       0.90,
        "Chest-Supported Row Machine":     0.84,
        "Smith Machine Row":               0.88,
        "Hammer Strength Row":             0.86,
        "Low Row Machine":                 0.82,
        // ── Vertical Pull ────────────────────────
        "Pull-Up":                         1.00,
        "Chin-Up":                         1.04,
        "Assisted Pull-Up Machine":        0.80,
        "Lat Pulldown":                    0.78,
        "Reverse Grip Lat Pulldown":       0.80,
        "Hammer Strength Lat Pulldown":    0.78,
        // ── Hip Hinge ────────────────────────────
        "Deadlift":                        1.00,
        "Smith Machine Deadlift":          0.92,
        "Sumo Deadlift":                   0.98,
        "Romanian Deadlift":               0.80,
        "Smith Machine Romanian Deadlift": 0.76,
        "Hip Thrust":                      0.78,
        "Hip Thrust Machine":              0.80,
        // ── Knee Flexion ─────────────────────────
        "Barbell Squat":                   1.00,
        "Smith Machine Squat":             0.94,
        "Hack Squat Machine":              0.88,
        "Belt Squat Machine":              0.92,
        "Goblet Squat":                    0.70,
        "Leg Press":                       0.72,
        "Bulgarian Split Squat":           0.75,
        "Walking Lunge":                   0.65,
    ]

    static func coefficient(for name: String) -> Double? { population[name] }

    /// Converts a raw e1RM to the canonical reference-equivalent for its pattern.
    static func normalizedE1RM(_ e1rm: Double, exerciseName: String) -> Double? {
        guard let c = coefficient(for: exerciseName), c > 0 else { return nil }
        return e1rm / c
    }
}

// MARK: - Derived Dimensions

/// Inferred from rep-range distribution across recent sessions.
enum TrainingArchetype: String, CaseIterable {
    case powerFocused      = "Power-Focused"
    case strengthBiased    = "Strength-Biased"
    case hypertrophyBiased = "Hypertrophy-Biased"
    case enduranceLite     = "Endurance-Lite"
    case balanced          = "Balanced"

    var color: Color {
        switch self {
        case .powerFocused:      return HONTheme.chartLavender
        case .strengthBiased:    return HONTheme.accent
        case .hypertrophyBiased: return HONTheme.positive
        case .enduranceLite:     return HONTheme.chartSage
        case .balanced:          return HONTheme.warning
        }
    }

    static func classify(log: [WorkoutLogEntry]) -> TrainingArchetype {
        let sets = log.prefix(10).flatMap { $0.exercises.flatMap(\.completedSets) }.filter { $0.reps > 0 }
        guard sets.count >= 10 else { return .balanced }
        let total = Double(sets.count)
        let power  = Double(sets.filter { $0.reps <= 3  }.count) / total
        let strength = Double(sets.filter { $0.reps >= 4 && $0.reps <= 6  }.count) / total
        let hyper    = Double(sets.filter { $0.reps >= 7 && $0.reps <= 12 }.count) / total
        let endurance = Double(sets.filter { $0.reps > 12 }.count) / total
        if power    > 0.30 { return .powerFocused }
        if strength > 0.40 { return .strengthBiased }
        if hyper    > 0.40 { return .hypertrophyBiased }
        if endurance > 0.40 { return .enduranceLite }
        return .balanced
    }
}

/// Inferred per-session from INOL and set density.
enum SessionType: String {
    case heavyDay    = "Heavy Day"
    case volumeDay   = "Volume Day"
    case deloadDay   = "Deload"
    case prAttempt   = "PR Attempt"
    case maintenance = "Maintenance"
}

/// Inferred from acute vs chronic load ratio.
enum FatigueState: String {
    case fresh        = "Fresh"
    case normal       = "Normal"
    case accumulated  = "Accumulated"
    case overreaching = "Functional Overreach"
    case overtrained  = "Overtraining Risk"

    var color: Color {
        switch self {
        case .fresh:        return HONTheme.positive
        case .normal:       return HONTheme.accent
        case .accumulated:  return HONTheme.warning
        case .overreaching: return HONTheme.warning
        case .overtrained:  return HONTheme.negative
        }
    }
}

/// Per-lift, inferred from 3-week velocity trend.
enum LiftPhase: String {
    case linearProgression = "Linear Progression"
    case plateau           = "Plateau"
    case peaking           = "Peaking"
    case declining         = "Declining"
    case deloading         = "Deloading"

    var color: Color {
        switch self {
        case .linearProgression: return HONTheme.positive
        case .plateau:           return HONTheme.warning
        case .peaking:           return HONTheme.accent
        case .declining:         return HONTheme.negative
        case .deloading:         return .secondary
        }
    }

    static func classify(_ analytics: ExerciseAnalytics) -> LiftPhase {
        if !analytics.hasEnoughData { return .deloading }
        if analytics.slopePerWeek < -0.5 { return .declining }
        if analytics.isPlateau { return .plateau }
        if analytics.slopePerWeek > 1.5 { return .peaking }
        if analytics.slopePerWeek > 0.3 { return .linearProgression }
        return .plateau
    }
}

/// Inferred from correlation of feel rating vs volume output.
enum FeelArchetype: String {
    case consistentPerformer = "Consistent Performer"
    case moodDependent       = "Mood-Dependent"
    case sandbagger          = "Sandbagger"
    case optimist            = "Optimist"
    case learning            = "Learning"

    var blurb: String {
        switch self {
        case .consistentPerformer:
            return "You perform at a high level regardless of how you feel. Mental discipline is strong."
        case .moodDependent:
            return "Performance closely tracks feel rating. Mindset work may help on low-feel days."
        case .sandbagger:
            return "You frequently underestimate your readiness. On low-feel days you still perform well — trust your body."
        case .optimist:
            return "Feel often outpaces actual performance. Manage expectations on high-feel days."
        case .learning:
            return "Log more workouts with feel ratings to unlock this insight."
        }
    }
}

/// Inferred from push vs pull volume ratio.
enum MovementBias: String {
    case anteriorDominant  = "Anterior-Dominant"
    case posteriorDominant = "Posterior-Dominant"
    case balanced          = "Balanced"

    var riskNote: String {
        switch self {
        case .anteriorDominant:
            return "Anterior chain dominance increases shoulder impingement risk over time. Add horizontal pull volume."
        case .posteriorDominant:
            return "Posterior dominance is rare. Monitor anterior-chain sport/daily performance."
        case .balanced:
            return "Push/pull balance is good. Maintain as you increase load."
        }
    }
}

// MARK: - Emergent Constructs

enum MindBodyAlignment: String {
    case alignedPeak     = "Aligned — Peak"
    case suppressed      = "Suppressed"
    case overconfident   = "Overconfident"
    case alignedDepleted = "Aligned — Depleted"

    var implication: String {
        switch self {
        case .alignedPeak:
            return "Body and mind are both signaling readiness. Optimal window for PR attempts and high-intensity work."
        case .suppressed:
            return "HRV says you're recovered but feel is low. Non-training stressors — sleep quality, life load, or motivation — are the block, not the program."
        case .overconfident:
            return "Feel is high but physiology says otherwise. High failure risk on PR attempts. Athletes get hurt in this state."
        case .alignedDepleted:
            return "Both signals say back off. Grinding through will underperform and delay recovery by 24–48h."
        }
    }

    var recommendation: String {
        switch self {
        case .alignedPeak:     return "Go for it. This is the window you've been building toward."
        case .suppressed:      return "Address external stressors. Keep training but reset intensity expectations."
        case .overconfident:   return "Train at 80% today. Schedule the PR attempt once HRV recovers."
        case .alignedDepleted: return "Active recovery or full rest. Plan a reload session in 2–3 days."
        }
    }

    var color: Color {
        switch self {
        case .alignedPeak:     return HONTheme.positive
        case .suppressed:      return HONTheme.chartLavender
        case .overconfident:   return HONTheme.negative
        case .alignedDepleted: return HONTheme.warning
        }
    }

    var severity: EmergentInsight.Severity {
        switch self {
        case .alignedPeak:     return .positive
        case .suppressed:      return .warning
        case .overconfident:   return .alert
        case .alignedDepleted: return .warning
        }
    }
}

enum TrueAdaptationState: String {
    case falseGains          = "False Gains"
    case trueAdaptation      = "True Adaptation"
    case expectedSuppression = "Expected Suppression"
    case trueRegression      = "True Regression"

    var implication: String {
        switch self {
        case .falseGains:
            return "You're performing well because you're fresh (positive TSB), not structural adaptation. Don't mistake freshness for a trend."
        case .trueAdaptation:
            return "Strength is rising despite accumulated fatigue — this is genuine adaptation. Gains will compound further after a deload."
        case .expectedSuppression:
            return "Performance is temporarily suppressed by fatigue. Normal during a loading block. Hold course — the gains are being banked."
        case .trueRegression:
            return "You're fresh and still getting weaker. Alarming signal — possible neural fatigue, technique breakdown, or systemic issue requiring investigation."
        }
    }

    var color: Color {
        switch self {
        case .falseGains:          return HONTheme.warning
        case .trueAdaptation:      return HONTheme.positive
        case .expectedSuppression: return HONTheme.accent
        case .trueRegression:      return HONTheme.negative
        }
    }

    var severity: EmergentInsight.Severity {
        switch self {
        case .trueAdaptation:      return .positive
        case .expectedSuppression: return .neutral
        case .falseGains:          return .warning
        case .trueRegression:      return .alert
        }
    }
}

enum ProgramCalibrationState: String {
    case sandbagging             = "Sandbagging"
    case outpacingProgram        = "Outpacing Program"
    case appropriatelyChallenged = "On Point"
    case disengaged              = "Disengaged"
    case tooHeavy                = "Too Heavy"

    var implication: String {
        switch self {
        case .sandbagging:
            return "Hitting all targets without apparent effort. Weights are due for a bump — current loads are no longer a stimulus."
        case .outpacingProgram:
            return "Crushing targets but working hard for it. You've outgrown the current loads. Increase them next cycle."
        case .appropriatelyChallenged:
            return "Good match between program difficulty and current capacity. This is the zone where adaptation is fastest."
        case .disengaged:
            return "Missing reps without apparent effort. Check for lack of focus, early-session form breakdown, or ego-loading that collapses mid-set."
        case .tooHeavy:
            return "Struggling to hit targets and pushing very hard to get close. Reduce loads — this is survival training, not stimulus training."
        }
    }

    var color: Color {
        switch self {
        case .sandbagging:             return HONTheme.warning
        case .outpacingProgram:        return HONTheme.accent
        case .appropriatelyChallenged: return HONTheme.positive
        case .disengaged:              return HONTheme.negative
        case .tooHeavy:                return HONTheme.negative
        }
    }

    var severity: EmergentInsight.Severity {
        switch self {
        case .appropriatelyChallenged:             return .positive
        case .outpacingProgram, .sandbagging:      return .warning
        case .disengaged, .tooHeavy:               return .alert
        }
    }
}

enum ImbalanceTrajectory: String {
    case diverging      = "Diverging"
    case converging     = "Converging"
    case stable         = "Stable"
    case overcorrecting = "Overcorrecting"

    var implication: String {
        switch self {
        case .diverging:
            return "Push patterns gaining faster than pull. Anterior-chain dominance is actively widening. Add horizontal pull volume now before the gap creates injury risk."
        case .converging:
            return "Lagging pull patterns are catching up. Intentional or self-correcting — either way, this is the right direction."
        case .stable:
            return "Push and pull velocity are matched. Existing imbalance isn't worsening — but it isn't improving either."
        case .overcorrecting:
            return "Pull patterns now outpacing push. Watch for the pendulum swinging too far — shoulder health depends on balance in both directions."
        }
    }

    var color: Color {
        switch self {
        case .diverging:      return HONTheme.negative
        case .converging:     return HONTheme.positive
        case .stable:         return HONTheme.accent
        case .overcorrecting: return HONTheme.warning
        }
    }

    var severity: EmergentInsight.Severity {
        switch self {
        case .converging:     return .positive
        case .stable:         return .neutral
        case .overcorrecting: return .warning
        case .diverging:      return .alert
        }
    }
}

enum NetRecoveryCapacity: String {
    case surplus              = "Surplus"
    case resilientWindow      = "Resilient Window"
    case lifestyleConstrained = "Lifestyle-Constrained"
    case compoundedDeficit    = "Compounded Deficit"

    var implication: String {
        switch self {
        case .surplus:
            return "Recovery bank is full. Can absorb a significant loading spike without consequence. Good time to start a new block."
        case .resilientWindow:
            return "High training load backed by quality sleep. Adaptation is actively happening. Stay on this path."
        case .lifestyleConstrained:
            return "Recovery is failing even without high training load. The program isn't the problem — sleep and life stress are. Changing the program won't help."
        case .compoundedDeficit:
            return "Sleep debt and training debt simultaneously active. Recovery capacity is critically low. A deload is not optional — it's structural."
        }
    }

    var color: Color {
        switch self {
        case .surplus:              return HONTheme.positive
        case .resilientWindow:      return HONTheme.accent
        case .lifestyleConstrained: return HONTheme.warning
        case .compoundedDeficit:    return HONTheme.negative
        }
    }

    var severity: EmergentInsight.Severity {
        switch self {
        case .surplus:              return .positive
        case .resilientWindow:      return .neutral
        case .lifestyleConstrained: return .warning
        case .compoundedDeficit:    return .alert
        }
    }
}

enum PRAttemptQuality: String {
    case primeWindow   = "Prime Window"
    case wastedWindow  = "Wasted Window"
    case foolsGold     = "Fool's Gold"
    case patientWindow = "Patient Window"
    case notReady      = "Not Ready"

    var implication: String {
        switch self {
        case .primeWindow:
            return "All three signals aligned — fresh, motivated, and strength velocity positive. Highest PR success probability of the training block."
        case .wastedWindow:
            return "Physiologically primed but motivation is low. Non-training factors are suppressing the window. Address those, then attempt."
        case .foolsGold:
            return "Feel great, but body is fatigued. A PR attempt carries high failure risk and heightened injury exposure. Wait 3–5 days."
        case .patientWindow:
            return "Strength trajectory is positive but freshness or motivation isn't aligned yet. The PR is coming — probably within 1–2 weeks."
        case .notReady:
            return "No PR window active. Focus on building the foundation — volume and consistency now, peaks will come."
        }
    }

    var color: Color {
        switch self {
        case .primeWindow:   return HONTheme.positive
        case .wastedWindow:  return HONTheme.chartLavender
        case .foolsGold:     return HONTheme.negative
        case .patientWindow: return HONTheme.accent
        case .notReady:      return Color.secondary
        }
    }

    var severity: EmergentInsight.Severity {
        switch self {
        case .primeWindow:   return .positive
        case .patientWindow: return .neutral
        case .wastedWindow:  return .warning
        case .foolsGold:     return .alert
        case .notReady:      return .neutral
        }
    }
}

// MARK: - HIIT / Cardio Insight States

enum HiitEnduranceTrend: String {
    case climbing  = "Climbing"
    case plateau   = "Plateau"
    case declining = "Declining"

    var color: Color {
        switch self {
        case .climbing:  return HONTheme.positive
        case .plateau:   return HONTheme.warning
        case .declining: return HONTheme.negative
        }
    }

    var implication: String {
        switch self {
        case .climbing:
            return "Your aerobic capacity is growing — you're completing more rounds in the same time window. This is the HIIT equivalent of linear progression. Push a little harder each session."
        case .plateau:
            return "Round count has stabilized. Your current circuit intensity has become a maintenance stimulus. Increase density, add an exercise, or shorten rest windows to restart adaptation."
        case .declining:
            return "Completing fewer rounds over time despite consistent effort. Possible causes: accumulated fatigue, cumulative sleep debt, or the circuit no longer matching your current state. Consider a lighter week."
        }
    }

    var severity: EmergentInsight.Severity {
        switch self {
        case .climbing:  return .positive
        case .plateau:   return .neutral
        case .declining: return .warning
        }
    }
}

enum FatigueResistanceState: String {
    case ironWall      = "Iron Wall"
    case normalFade    = "Normal Fade"
    case earlyCollapse = "Early Collapse"

    var color: Color {
        switch self {
        case .ironWall:      return HONTheme.positive
        case .normalFade:    return HONTheme.accent
        case .earlyCollapse: return HONTheme.negative
        }
    }

    var implication: String {
        switch self {
        case .ironWall:
            return "Rep output holds nearly constant from first round to last. Your aerobic threshold is well above the working intensity — you could likely push harder early in the session."
        case .normalFade:
            return "Output drops 5–15% from early to late rounds. This is the adaptation zone — you're stressed enough to improve but not collapsing. Stay here."
        case .earlyCollapse:
            return "Output drops more than 15% in the second half of sessions. Your anaerobic threshold is below the working intensity. Reduce load or pace the first rounds more conservatively."
        }
    }

    var severity: EmergentInsight.Severity {
        switch self {
        case .ironWall:      return .neutral
        case .normalFade:    return .positive
        case .earlyCollapse: return .warning
        }
    }
}

enum WorkCapacityTrend: String {
    case accelerating = "Accelerating"
    case holding      = "Holding"
    case dropping     = "Dropping"

    var color: Color {
        switch self {
        case .accelerating: return HONTheme.positive
        case .holding:      return HONTheme.accent
        case .dropping:     return HONTheme.negative
        }
    }

    var implication: String {
        switch self {
        case .accelerating:
            return "Reps per minute is climbing across sessions — your metabolic engine is getting more efficient. You're fitting more work into the same time window."
        case .holding:
            return "Work density is stable. You're maintaining capacity but not growing it. Fine during a loading block, but after 3–4 weeks signals a need for progression."
        case .dropping:
            return "Doing less work per minute over time. Fatigue accumulation, poor pacing, or reduced motivation are the typical causes. Investigate recovery quality before increasing effort."
        }
    }

    var severity: EmergentInsight.Severity {
        switch self {
        case .accelerating: return .positive
        case .holding:      return .neutral
        case .dropping:     return .warning
        }
    }
}

enum CircuitConsistencyState: String {
    case metronomic = "Metronomic"
    case variable   = "Variable"
    case erratic    = "Erratic"

    var color: Color {
        switch self {
        case .metronomic: return HONTheme.positive
        case .variable:   return HONTheme.accent
        case .erratic:    return HONTheme.warning
        }
    }

    var implication: String {
        switch self {
        case .metronomic:
            return "Rep count varies less than 2 per round. Excellent pacing discipline — you know your limits and execute precisely. Ideal for EMOM formats and PR tracking."
        case .variable:
            return "Moderate rep variance per round. Likely front-loading effort and fading slightly. Worth working on even pacing to improve total output."
        case .erratic:
            return "High round-to-round rep variance. Possible causes: inconsistent rest, pacing problems, or going out too hard and crashing. Try holding back in the first 3 rounds."
        }
    }

    var severity: EmergentInsight.Severity {
        switch self {
        case .metronomic: return .positive
        case .variable:   return .neutral
        case .erratic:    return .warning
        }
    }
}

// MARK: - Cross-Domain (Cardio × Strength) States

enum CardioStrengthInterference: String {
    case synergistic = "Synergistic"
    case neutral     = "Neutral"
    case suppressive = "Suppressive"

    var color: Color {
        switch self {
        case .synergistic: return HONTheme.positive
        case .neutral:     return HONTheme.accent
        case .suppressive: return HONTheme.negative
        }
    }

    var implication: String {
        switch self {
        case .synergistic:
            return "You feel better in strength sessions that follow a HIIT session. Your cardio is priming strength readiness — a sign your training load and aerobic base are well-calibrated."
        case .neutral:
            return "Cardio doesn't measurably affect how you feel in subsequent strength sessions. The modalities are co-existing without significant interference. Keep the current scheduling approach."
        case .suppressive:
            return "Strength sessions after HIIT show worse feel ratings. Cardio volume or timing is creating carry-over fatigue. Increase the gap between modalities or reduce cardio intensity."
        }
    }

    var severity: EmergentInsight.Severity {
        switch self {
        case .synergistic: return .positive
        case .neutral:     return .neutral
        case .suppressive: return .alert
        }
    }
}

enum ModalitySequencing: String {
    case optimal     = "Optimal Spacing"
    case stacked     = "Stacked Sessions"
    case extendedGap = "Extended Gap"

    var color: Color {
        switch self {
        case .optimal:     return HONTheme.positive
        case .stacked:     return HONTheme.warning
        case .extendedGap: return HONTheme.accent
        }
    }

    var implication: String {
        switch self {
        case .optimal:
            return "HIIT and strength sessions are typically 1–2 days apart. This spacing allows partial recovery from cardio stress before the next strength session, minimizing interference while maintaining frequency."
        case .stacked:
            return "HIIT and strength are happening the same day or within hours of each other. This can work if cardio precedes strength by several hours, but risks compounding fatigue. Monitor feel ratings closely."
        case .extendedGap:
            return "More than 2 days typically separate your HIIT and strength sessions. The modalities aren't competing, but you may be missing the aerobic-strength synergy window."
        }
    }

    var severity: EmergentInsight.Severity {
        switch self {
        case .optimal:     return .positive
        case .stacked:     return .warning
        case .extendedGap: return .neutral
        }
    }
}

enum DualModeFitnessIndex: String {
    case dualModeAthlete = "Dual-Mode Athlete"
    case strengthLed     = "Strength-Led"
    case cardioLed       = "Cardio-Led"
    case bothStalled     = "Both Stalled"

    var color: Color {
        switch self {
        case .dualModeAthlete: return HONTheme.positive
        case .strengthLed:     return HONTheme.accent
        case .cardioLed:       return HONTheme.chartSage
        case .bothStalled:     return HONTheme.warning
        }
    }

    var implication: String {
        switch self {
        case .dualModeAthlete:
            return "Both HIIT endurance and strength lifts are trending upward simultaneously. This is rare — most athletes experience interference at high volumes. Your programming balance is working."
        case .strengthLed:
            return "Strength is progressing but HIIT performance has plateaued or declined. Cardio may be maintenance-level or suppressed by strength fatigue. Fine if strength is the priority."
        case .cardioLed:
            return "HIIT is improving but strength has plateaued. Cardio volume may be competing with strength adaptation signals. Temporarily reduce cardio frequency or intensity to unlock strength gains."
        case .bothStalled:
            return "Neither modality is trending upward. This typically signals overreach, under-recovery, or a programming dead end. A structured deload followed by a new block is the most reliable reset."
        }
    }

    var severity: EmergentInsight.Severity {
        switch self {
        case .dualModeAthlete: return .positive
        case .strengthLed:     return .neutral
        case .cardioLed:       return .neutral
        case .bothStalled:     return .warning
        }
    }
}

enum EnergySystemSynergy: String {
    case boosting = "Boosting"
    case neutral  = "Neutral"
    case draining = "Draining"

    var color: Color {
        switch self {
        case .boosting: return HONTheme.positive
        case .neutral:  return HONTheme.accent
        case .draining: return HONTheme.negative
        }
    }

    var implication: String {
        switch self {
        case .boosting:
            return "Strength sessions within 24h of HIIT show higher feel ratings than baseline. Your cardiovascular training is priming nervous system activation and energy availability for strength work."
        case .neutral:
            return "Strength readiness is similar whether or not you've done cardio in the prior 24h. No synergy, but no interference. Continue the current approach."
        case .draining:
            return "Strength sessions within 24h of HIIT feel worse than usual. Your recovery window is too short. Aim for 24–36h between a HIIT session and your next heavy strength day."
        }
    }

    var severity: EmergentInsight.Severity {
        switch self {
        case .boosting: return .positive
        case .neutral:  return .neutral
        case .draining: return .alert
        }
    }
}

// MARK: - Emergent Insight (surface type for UI)

struct EmergentInsight: Identifiable {
    let id = UUID()
    let title: String
    let inputsLabel: String   // "HRV × Feel Rating"
    let stateName: String     // "SUPPRESSED"
    let stateColor: Color
    let implication: String
    let dataPoint: String     // brief factual line supporting the state
    let severity: Severity
    let dataAvailable: Bool

    enum Severity { case positive, neutral, warning, alert }

    var severityColor: Color {
        switch severity {
        case .positive: return HONTheme.positive
        case .neutral:  return HONTheme.accent
        case .warning:  return HONTheme.warning
        case .alert:    return HONTheme.negative
        }
    }
}
