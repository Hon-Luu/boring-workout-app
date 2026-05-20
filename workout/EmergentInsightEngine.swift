import Foundation
import SwiftUI

// MARK: - EmergentInsightEngine
// Derives second-order insights from interactions between features.
// Each insight is a named state that does not exist in any single metric.

enum EmergentInsightEngine {

    static func compute(
        log: [WorkoutLogEntry],
        analyticsResult: AnalyticsResult,
        hrv: Double?,
        sleepHours: Double?,
        cardioLog: [CardioLogEntry] = []
    ) -> [EmergentInsight] {
        var insights: [EmergentInsight] = [
            mindBodyAlignment(log: log, hrv: hrv),
            trueAdaptationState(analytics: analyticsResult, log: log),
            programCalibration(log: log),
            netRecoveryCapacity(log: log, sleepHours: sleepHours),
            prAttemptQuality(analytics: analyticsResult, log: log),
            imbalanceTrajectory(analytics: analyticsResult),
            feelArchetype(log: log),
            loadTolerance(log: log),
        ]
        if !cardioLog.isEmpty {
            insights += CardioInsightEngine.compute(
                cardioLog: cardioLog,
                strengthLog: log,
                analyticsResult: analyticsResult
            )
        }
        return insights
    }

    // MARK: - 1. Mind-Body Alignment  (HRV × Feel)

    private static func mindBodyAlignment(log: [WorkoutLogEntry], hrv: Double?) -> EmergentInsight {
        let recentFeel = log.prefix(5).compactMap(\.feelRating)
        guard !recentFeel.isEmpty else {
            return placeholder(title: "Mind-Body Alignment", inputs: "HRV × Feel Rating")
        }

        let feelScore = recentFeel.prefix(3).map { feelNumeric($0) }.reduce(0, +)
            / Double(min(recentFeel.prefix(3).count, 3))
        let feelHigh = feelScore >= 0.5

        let hrvHigh: Bool
        if let hrv { hrvHigh = hrv >= 65 }
        else { let d = daysSinceLast(log); hrvHigh = d == 1 || d == 2 }

        let state: MindBodyAlignment = {
            switch (hrvHigh, feelHigh) {
            case (true,  true):  return .alignedPeak
            case (true,  false): return .suppressed
            case (false, true):  return .overconfident
            case (false, false): return .alignedDepleted
            }
        }()

        let hrvLabel = hrv.map { String(format: "HRV %.0f ms", $0) } ?? "Recovery proxy"
        let feelLabel = recentFeel.first.map { "Feel: \($0.rawValue)" } ?? ""

        return EmergentInsight(
            title: "Mind-Body Alignment",
            inputsLabel: hrv != nil ? "HRV × Feel Rating" : "Recovery × Feel Rating",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: state.implication,
            dataPoint: [hrvLabel, feelLabel].filter { !$0.isEmpty }.joined(separator: " · "),
            severity: state.severity,
            dataAvailable: true
        )
    }

    // MARK: - 2. True Adaptation State  (Velocity × TSB)

    private static func trueAdaptationState(analytics: AnalyticsResult, log: [WorkoutLogEntry]) -> EmergentInsight {
        guard let top = analytics.exerciseAnalytics.first(where: { $0.hasEnoughData }) else {
            return placeholder(title: "True Adaptation State", inputs: "Strength Velocity × Training Load")
        }

        let velocityUp  = top.slopePerWeek > 0.3
        let atl         = acuteLoad(log)
        let ctl         = chronicLoad(log)
        let tsbPositive = (ctl - atl) > 0

        let state: TrueAdaptationState = {
            switch (velocityUp, tsbPositive) {
            case (true,  true):  return .falseGains
            case (true,  false): return .trueAdaptation
            case (false, false): return .expectedSuppression
            case (false, true):  return .trueRegression
            }
        }()

        let sign = top.slopePerWeek >= 0 ? "+" : ""
        return EmergentInsight(
            title: "True Adaptation State",
            inputsLabel: "Strength Velocity × Training Load Balance",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: state.implication,
            dataPoint: "\(top.exercise.name) \(sign)\(String(format: "%.1f", top.slopePerWeek)) kg/wk · TSB \(tsbPositive ? "positive" : "negative")",
            severity: state.severity,
            dataAvailable: true
        )
    }

    // MARK: - 3. Program Calibration  (Set Success Rate × RPE)

    private static func programCalibration(log: [WorkoutLogEntry]) -> EmergentInsight {
        let sets = Array(log.prefix(10)).flatMap { $0.exercises.flatMap(\.completedSets) }
        guard sets.count >= 10 else {
            return placeholder(title: "Program Calibration", inputs: "Set Success Rate × RPE")
        }

        let withTargets = sets.filter { $0.targetReps > 0 }
        let successRate = withTargets.isEmpty ? 0.75
            : Double(withTargets.filter { $0.repOutcome != .missed }.count) / Double(withTargets.count)

        let rpes = sets.compactMap(\.rpe)
        let avgRPE = rpes.isEmpty ? 7.5 : rpes.reduce(0, +) / Double(rpes.count)

        let state: ProgramCalibrationState = {
            switch (successRate >= 0.80, avgRPE >= 7.5) {
            case (true,  false): return .sandbagging
            case (true,  true):  return .outpacingProgram
            case (false, false): return .disengaged
            case (false, true):  return .tooHeavy
            }
        }()

        return EmergentInsight(
            title: "Program Calibration",
            inputsLabel: "Set Success Rate × RPE",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: state.implication,
            dataPoint: String(format: "Success %.0f%% · Avg RPE %.1f (n=%d sets)", successRate * 100, avgRPE, sets.count),
            severity: state.severity,
            dataAvailable: true
        )
    }

    // MARK: - 4. Net Recovery Capacity  (Sleep × ATL)

    private static func netRecoveryCapacity(log: [WorkoutLogEntry], sleepHours: Double?) -> EmergentInsight {
        guard let sleep = sleepHours else {
            return placeholder(title: "Net Recovery Capacity", inputs: "Sleep × Acute Training Load")
        }

        let atl = acuteLoad(log)
        let state: NetRecoveryCapacity = {
            switch (sleep >= 7.0, atl > 55) {
            case (true,  false): return .surplus
            case (true,  true):  return .resilientWindow
            case (false, false): return .lifestyleConstrained
            case (false, true):  return .compoundedDeficit
            }
        }()

        return EmergentInsight(
            title: "Net Recovery Capacity",
            inputsLabel: "Sleep × Acute Training Load",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: state.implication,
            dataPoint: String(format: "Sleep %.1fh · Acute load index %d/100", sleep, Int(atl)),
            severity: state.severity,
            dataAvailable: true
        )
    }

    // MARK: - 5. PR Attempt Quality  (Feel Momentum × TSB × Velocity)

    private static func prAttemptQuality(analytics: AnalyticsResult, log: [WorkoutLogEntry]) -> EmergentInsight {
        guard let top = analytics.exerciseAnalytics.first(where: { $0.hasEnoughData }) else {
            return placeholder(title: "PR Attempt Quality", inputs: "Feel Momentum × Recovery × Velocity")
        }

        let velocityPositive = top.slopePerWeek > 0.5
        let tsbPositive      = (chronicLoad(log) - acuteLoad(log)) > 0

        let recentFeel = log.prefix(5).compactMap(\.feelRating)
        let feelMomentumUp: Bool = {
            let scores = recentFeel.prefix(3).map { feelNumericInt($0) }
            guard scores.count >= 2 else { return false }
            return scores[0] >= scores[1]  // most recent ≥ previous
        }()

        let state: PRAttemptQuality = {
            if !velocityPositive                       { return .notReady }
            if tsbPositive  && feelMomentumUp          { return .primeWindow }
            if tsbPositive  && !feelMomentumUp         { return .wastedWindow }
            if !tsbPositive && feelMomentumUp          { return .foolsGold }
            return .patientWindow
        }()

        return EmergentInsight(
            title: "PR Attempt Quality",
            inputsLabel: "Feel Momentum × TSB × Velocity",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: state.implication,
            dataPoint: "\(top.exercise.name) · TSB \(tsbPositive ? "+" : "−") · feel \(feelMomentumUp ? "↑" : "↓")",
            severity: state.severity,
            dataAvailable: true
        )
    }

    // MARK: - 6. Imbalance Trajectory  (Push Velocity × Pull Velocity)

    private static func imbalanceTrajectory(analytics: AnalyticsResult) -> EmergentInsight {
        let push: [MovementPattern] = [.horizontalPush, .verticalPush]
        let pull: [MovementPattern] = [.horizontalPull, .verticalPull]

        let pushRate = analytics.categoryAnalytics.filter { push.contains($0.pattern) }
            .map(\.improvementRatePerWeek).reduce(0, +)
        let pullRate = analytics.categoryAnalytics.filter { pull.contains($0.pattern) }
            .map(\.improvementRatePerWeek).reduce(0, +)

        guard analytics.categoryAnalytics.count >= 2 else {
            return placeholder(title: "Imbalance Trajectory", inputs: "Push Velocity × Pull Velocity")
        }

        let diff = pushRate - pullRate
        let state: ImbalanceTrajectory = {
            if diff >  0.3  { return .diverging }
            if diff < -0.3  { return .overcorrecting }
            if abs(diff) < 0.1 { return .stable }
            return .converging
        }()

        return EmergentInsight(
            title: "Imbalance Trajectory",
            inputsLabel: "Push Velocity × Pull Velocity",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: state.implication,
            dataPoint: String(format: "Push %+.1f%%/wk · Pull %+.1f%%/wk", pushRate, pullRate),
            severity: state.severity,
            dataAvailable: true
        )
    }

    // MARK: - 7. Feel Archetype  (Feel × Session Output)

    private static func feelArchetype(log: [WorkoutLogEntry]) -> EmergentInsight {
        let sessions = log.filter { $0.feelRating != nil && $0.totalVolume > 0 }
        guard sessions.count >= 6 else {
            return placeholder(title: "Feel Archetype", inputs: "Feel Rating × Session Output")
        }

        let pairs: [(feel: Double, vol: Double)] = sessions.prefix(20).compactMap { e in
            guard let f = e.feelRating else { return nil }
            return (feelNumeric(f), e.totalVolume)
        }

        let r = pearsonR(pairs.map(\.feel), pairs.map(\.vol))
        let meanVolHighFeel = pairs.filter { $0.feel > 0.5 }.map(\.vol).mean()
        let meanVolLowFeel  = pairs.filter { $0.feel <= 0.5 }.map(\.vol).mean()

        let archetype: FeelArchetype = {
            if sessions.count < 6                               { return .learning }
            if abs(r) < 0.2                                     { return .consistentPerformer }
            if r > 0.5                                          { return .moodDependent }
            if (meanVolLowFeel ?? 0) > (meanVolHighFeel ?? 0) * 1.1 { return .sandbagger }
            if (meanVolHighFeel ?? 0) > (meanVolLowFeel ?? 0) * 1.2 { return .optimist }
            return .consistentPerformer
        }()

        let color: Color = {
            switch archetype {
            case .consistentPerformer: return HONTheme.positive
            case .moodDependent:       return HONTheme.warning
            case .sandbagger:          return HONTheme.accent
            case .optimist:            return HONTheme.chartLavender
            case .learning:            return .secondary
            }
        }()

        return EmergentInsight(
            title: "Feel Archetype",
            inputsLabel: "Feel Rating × Session Output",
            stateName: archetype.rawValue.uppercased(),
            stateColor: color,
            implication: archetype.blurb,
            dataPoint: String(format: "Feel–performance r = %.2f (n=%d sessions)", r, pairs.count),
            severity: archetype == .consistentPerformer ? .positive
                    : archetype == .moodDependent ? .warning : .neutral,
            dataAvailable: true
        )
    }

    // MARK: - 8. Load Tolerance Profile  (Session Load Density × Feel)

    private static func loadTolerance(log: [WorkoutLogEntry]) -> EmergentInsight {
        let sessions = log.filter { $0.feelRating != nil && $0.duration > 60 }
        guard sessions.count >= 5 else {
            return placeholder(title: "Load Tolerance Profile", inputs: "Session Load Density × Feel")
        }

        let pairs: [(load: Double, feel: Double)] = sessions.prefix(15).compactMap { e in
            guard let f = e.feelRating, e.duration > 0 else { return nil }
            return (e.totalVolume / (e.duration / 60.0), feelNumeric(f))
        }
        guard pairs.count >= 4 else {
            return placeholder(title: "Load Tolerance Profile", inputs: "Session Load Density × Feel")
        }

        let median = pairs.map(\.load).sorted()[pairs.count / 2]
        let highFeel = pairs.filter { $0.load >= median }.map(\.feel).mean() ?? 0
        let lowFeel  = pairs.filter { $0.load <  median }.map(\.feel).mean() ?? 0

        let (state, implication, severity): (String, String, EmergentInsight.Severity) = {
            if highFeel > 0.60 {
                return ("VOLUME RESPONDER",
                        "You report feeling better on high-density sessions. Thrives under load — high INOL is a psychological positive for you.",
                        .positive)
            } else if highFeel < 0.35 {
                return ("LOAD-SENSITIVE",
                        "High-density sessions correlate with worse feel. Distribute load across more sessions at lower per-session volume to maintain quality.",
                        .warning)
            } else {
                return ("LOAD-NEUTRAL",
                        "Feel doesn't shift significantly with session density. Volume can be periodised freely without impacting subjective readiness.",
                        .neutral)
            }
        }()

        return EmergentInsight(
            title: "Load Tolerance Profile",
            inputsLabel: "Session Load Density × Feel Rating",
            stateName: state,
            stateColor: severity == .positive ? HONTheme.positive : severity == .warning ? HONTheme.warning : HONTheme.accent,
            implication: implication,
            dataPoint: String(format: "High-load feel %.0f%% · Low-load feel %.0f%%", highFeel * 100, lowFeel * 100),
            severity: severity,
            dataAvailable: true
        )
    }

    // MARK: - Shared helpers

    private static func placeholder(title: String, inputs: String) -> EmergentInsight {
        EmergentInsight(
            title: title,
            inputsLabel: inputs,
            stateName: "LEARNING",
            stateColor: .secondary,
            implication: "Log more sessions with feel ratings to derive this insight.",
            dataPoint: "Needs 5–10 sessions with feel data.",
            severity: .neutral,
            dataAvailable: false
        )
    }

    private static func feelNumeric(_ f: FeelRating) -> Double {
        switch f { case .tired: return 0.0; case .normal: return 0.5; case .strong: return 1.0 }
    }

    private static func feelNumericInt(_ f: FeelRating) -> Int {
        switch f { case .tired: return 1; case .normal: return 2; case .strong: return 3 }
    }

    private static func daysSinceLast(_ log: [WorkoutLogEntry]) -> Int {
        guard let last = log.first else { return 99 }
        return Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: last.startedAt),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 99
    }

    /// Proxy for 7-day acute training load (0–100).
    private static func acuteLoad(_ log: [WorkoutLogEntry]) -> Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let vol = log.filter { $0.startedAt >= cutoff }.reduce(0.0) { $0 + $1.totalVolume }
        return min(100, vol / 800)
    }

    /// Proxy for 42-day chronic training load (0–100).
    private static func chronicLoad(_ log: [WorkoutLogEntry]) -> Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -42, to: Date())!
        let vol = log.filter { $0.startedAt >= cutoff }.reduce(0.0) { $0 + $1.totalVolume } / 6
        return min(100, vol / 800)
    }

    private static func pearsonR(_ x: [Double], _ y: [Double]) -> Double {
        let n = Double(x.count)
        guard n > 1 else { return 0 }
        let mx = x.reduce(0, +) / n, my = y.reduce(0, +) / n
        let cov = zip(x, y).map { ($0 - mx) * ($1 - my) }.reduce(0, +) / n
        let sx = sqrt(x.map { pow($0 - mx, 2) }.reduce(0, +) / n)
        let sy = sqrt(y.map { pow($0 - my, 2) }.reduce(0, +) / n)
        return (sx > 0 && sy > 0) ? cov / (sx * sy) : 0
    }
}

private extension Array where Element == Double {
    func mean() -> Double? {
        isEmpty ? nil : reduce(0, +) / Double(count)
    }
}
