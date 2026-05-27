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
        cardioLog: [CardioLogEntry] = [],
        vo2Max: Double? = nil,
        stepsToday: Int? = nil,
        restDays: [Date] = [],
        weightHistory: [WeightEntry] = []
    ) -> [EmergentInsight] {
        var insights: [EmergentInsight] = [
            mindBodyAlignment(log: log, hrv: hrv),
            trueAdaptationState(analytics: analyticsResult, log: log),
            programCalibration(log: log),
            netRecoveryCapacity(log: log, sleepHours: sleepHours),
            prAttemptQuality(analytics: analyticsResult, log: log, sleepHours: sleepHours),
            imbalanceTrajectory(analytics: analyticsResult),
            feelArchetype(log: log),
            loadTolerance(log: log),
            strongestDay(log: log),
            cardioFatiguePattern(log: log, cardioLog: cardioLog),
            bodyWeightStrengthCorrelation(log: log, weightHistory: weightHistory),
            aerobicCapacity(vo2Max: vo2Max),
            restDayActivity(restDays: restDays, stepsToday: stepsToday),
            sleepPRCorrelation(log: log, sleepHours: sleepHours),
        ]
        if !cardioLog.isEmpty {
            insights += CardioInsightEngine.compute(
                cardioLog: cardioLog,
                strengthLog: log,
                analyticsResult: analyticsResult
            )
        }

        // CON-03: TAS == False Gains + PR == Prime Window → downgrade PR to Patient Window
        if let tasIdx = insights.firstIndex(where: { $0.title == "True Adaptation State" }),
           insights[tasIdx].stateName == TrueAdaptationState.falseGains.rawValue.uppercased(),
           let prIdx = insights.firstIndex(where: { $0.title == "PR Attempt Quality" }),
           insights[prIdx].stateName == PRAttemptQuality.primeWindow.rawValue.uppercased() {
            let old = insights[prIdx]
            insights[prIdx] = EmergentInsight(
                title: old.title,
                inputsLabel: old.inputsLabel,
                stateName: PRAttemptQuality.patientWindow.rawValue.uppercased(),
                stateColor: PRAttemptQuality.patientWindow.color,
                implication: "Physiology and feel are aligned, but recent gains may reflect freshness more than structural adaptation. A PR attempt is reasonable — just know the next loaded week will reveal whether it's real.",
                dataPoint: old.dataPoint,
                severity: PRAttemptQuality.patientWindow.severity,
                dataAvailable: old.dataAvailable
            )
        }

        // CON-08: Net Recovery == Compounded Deficit + MBA == Aligned Peak → downgrade MBA to Suppressed
        if let nrcIdx = insights.firstIndex(where: { $0.title == "Net Recovery Capacity" }),
           insights[nrcIdx].stateName == NetRecoveryCapacity.compoundedDeficit.rawValue.uppercased(),
           let mbaIdx = insights.firstIndex(where: { $0.title == "Mind-Body Alignment" }),
           insights[mbaIdx].stateName == MindBodyAlignment.alignedPeak.rawValue.uppercased() {
            let old = insights[mbaIdx]
            insights[mbaIdx] = EmergentInsight(
                title: old.title,
                inputsLabel: old.inputsLabel,
                stateName: MindBodyAlignment.suppressed.rawValue.uppercased(),
                stateColor: MindBodyAlignment.suppressed.color,
                implication: "Your motivation and feel are high, but recovery metrics say otherwise — sleep debt and training load are compounding. Treat today as a moderate session, not a peak attempt.",
                dataPoint: old.dataPoint,
                severity: MindBodyAlignment.suppressed.severity,
                dataAvailable: old.dataAvailable
            )
        }

        return insights
    }

    // MARK: - 1. Mind-Body Alignment  (HRV × Feel)

    private static func mindBodyAlignment(log: [WorkoutLogEntry], hrv: Double?) -> EmergentInsight {
        let recentFeel = log.prefix(5).compactMap(\.feelRating)
        guard !recentFeel.isEmpty else {
            let feelSessions = log.filter { $0.feelRating != nil }.count
            return placeholder(title: "Mind-Body Alignment", inputs: "HRV × Feel Rating",
                               sessionsHave: feelSessions, sessionsNeed: 1)
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
            return placeholder(title: "True Adaptation State", inputs: "Strength Velocity × Training Load",
                               sessionsHave: log.count, sessionsNeed: 5)
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
        // Collect sets keyed by exercise name for trigger identification
        let recentEntries = Array(log.prefix(10))
        let sets = recentEntries.flatMap { $0.exercises.flatMap(\.completedSets) }
        guard sets.count >= 10 else {
            return placeholder(title: "Program Calibration", inputs: "Set Success Rate × RPE",
                               sessionsHave: sets.count, sessionsNeed: 10)
        }

        // CON-13: exclude drop sets from success rate (dropWeight != nil means it's a drop set record)
        let withTargets = sets.filter { $0.targetReps > 0 && $0.dropWeight == nil }
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

        // CON-07: suppress SANDBAGGING for new or returning users (< 5 sessions or > 14-day gap)
        if state == .sandbagging {
            let isRampBack: Bool = {
                if log.count < 5 { return true }
                let sorted = log.sorted { $0.startedAt > $1.startedAt }
                guard sorted.count >= 2 else { return false }
                let gap = Calendar.current.dateComponents([.day], from: sorted[1].startedAt, to: sorted[0].startedAt).day ?? 0
                return gap > 14
            }()
            if isRampBack {
                return EmergentInsight(
                    title: "Program Calibration",
                    inputsLabel: "Set Success Rate × RPE",
                    stateName: "RECALIBRATING",
                    stateColor: HONTheme.accent,
                    implication: "You're easing back in — these lighter sessions are intentional. Once consistent frequency is re-established, weights will self-correct.",
                    dataPoint: String(format: "Success %.0f%% · Avg RPE %.1f (ramp-back phase)", successRate * 100, avgRPE),
                    severity: .neutral,
                    dataAvailable: true
                )
            }
        }

        // Find the exercise that most strongly triggered this state
        struct ExerciseSummary {
            let name: String
            let missRate: Double
            let avgRPE: Double
            let setCount: Int
        }
        let exerciseSummaries: [ExerciseSummary] = recentEntries
            .flatMap(\.exercises)
            .reduce(into: [String: (missed: Int, total: Int, rpeSum: Double, rpeCount: Int)]()) { acc, we in
                let name = we.exercise.name
                let completed = we.completedSets
                guard !completed.isEmpty else { return }
                let missed = completed.filter { $0.targetReps > 0 && $0.repOutcome == .missed }.count
                let total  = completed.filter { $0.targetReps > 0 }.count
                let rpeVals = completed.compactMap(\.rpe)
                acc[name, default: (0, 0, 0, 0)].missed     += missed
                acc[name, default: (0, 0, 0, 0)].total      += total
                acc[name, default: (0, 0, 0, 0)].rpeSum     += rpeVals.reduce(0, +)
                acc[name, default: (0, 0, 0, 0)].rpeCount   += rpeVals.count
            }
            .map { name, v in
                ExerciseSummary(
                    name: name,
                    missRate: v.total > 0 ? Double(v.missed) / Double(v.total) : 0,
                    avgRPE: v.rpeCount > 0 ? v.rpeSum / Double(v.rpeCount) : 0,
                    setCount: v.total
                )
            }

        let triggerName: String = {
            switch state {
            case .tooHeavy:
                return exerciseSummaries
                    .filter { $0.setCount >= 2 }
                    .max(by: { $0.missRate < $1.missRate })?.name ?? ""
            case .sandbagging:
                return exerciseSummaries
                    .filter { $0.avgRPE > 0 }
                    .min(by: { $0.avgRPE < $1.avgRPE })?.name ?? ""
            case .outpacingProgram:
                return exerciseSummaries
                    .filter { $0.avgRPE > 0 }
                    .max(by: { $0.avgRPE < $1.avgRPE })?.name ?? ""
            case .disengaged:
                return exerciseSummaries
                    .filter { $0.setCount >= 2 }
                    .max(by: { $0.missRate < $1.missRate })?.name ?? ""
            case .appropriatelyChallenged:
                return ""
            }
        }()

        let triggerSuffix = triggerName.isEmpty ? "" : " · especially on \(triggerName)"
        return EmergentInsight(
            title: "Program Calibration",
            inputsLabel: "Set Success Rate × RPE",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: state.implication,
            dataPoint: String(format: "Success %.0f%% · Avg RPE %.1f (n=%d sets)%@",
                              successRate * 100, avgRPE, sets.count, triggerSuffix),
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

    private static func prAttemptQuality(analytics: AnalyticsResult, log: [WorkoutLogEntry], sleepHours: Double?) -> EmergentInsight {
        guard let top = analytics.exerciseAnalytics.first(where: { $0.hasEnoughData }) else {
            return placeholder(title: "PR Attempt Quality", inputs: "Feel Momentum × Recovery × Velocity")
        }

        let velocityPositive = top.slopePerWeek > 0.5
        let tsbPositive      = (chronicLoad(log) - acuteLoad(log)) > 0

        let recentFeel = log.prefix(5).compactMap(\.feelRating)
        let feelMomentumUp: Bool = {
            let scores = recentFeel.prefix(3).map { feelNumericInt($0) }
            guard scores.count >= 2 else { return false }
            return scores[0] >= scores[1]
        }()

        let rawState: PRAttemptQuality = {
            if !velocityPositive                       { return .notReady }
            if tsbPositive  && feelMomentumUp          { return .primeWindow }
            if tsbPositive  && !feelMomentumUp         { return .wastedWindow }
            if !tsbPositive && feelMomentumUp          { return .foolsGold }
            return .patientWindow
        }()

        // CON-09: sleep gate — sub-6.5h sleep disqualifies prime window
        let sleepGated = rawState == .primeWindow && (sleepHours ?? 8.0) < 6.5
        let state = sleepGated ? PRAttemptQuality.patientWindow : rawState

        // CON-04: soften Fool's Gold when velocity is confirmed positive
        // CON-09: custom implication when sleep-gated from prime
        let implication: String = {
            if sleepGated {
                return "Conditions are close to ideal but last night's sleep wasn't quite there. The window is 1–2 days away — prioritise sleep tonight."
            }
            if state == .foolsGold {
                return "Feel and velocity are both positive, but your body is carrying training fatigue. The progress from recent sessions is real — let it consolidate over 3–5 days, then attempt."
            }
            return state.implication
        }()

        let atl = acuteLoad(log)
        let ctl = chronicLoad(log)
        let tsbDelta = ctl - atl
        let sleepStr = sleepHours.map { String(format: " · sleep %.1fh", $0) } ?? ""
        let velSign = top.slopePerWeek >= 0 ? "+" : ""
        return EmergentInsight(
            title: "PR Attempt Quality",
            inputsLabel: "Feel Momentum × TSB × Velocity",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: implication,
            dataPoint: String(format: "%@ · vel %@%.1f kg/wk · TSB %@%.0f · feel %@\(sleepStr)",
                top.exercise.name, velSign, top.slopePerWeek,
                tsbDelta >= 0 ? "+" : "−", abs(tsbDelta),
                feelMomentumUp ? "↑" : "↓"),
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

    // MARK: - I3. Strongest Day  (Day-of-week × avg e1RM)

    private static func strongestDay(log: [WorkoutLogEntry]) -> EmergentInsight {
        // Need ≥15 sessions with date data
        guard log.count >= 15 else {
            return noDataInsight(title: "Your Strongest Day",
                                 inputs: "Day-of-Week × Performance",
                                 reason: "Need ≥15 sessions to detect day-of-week pattern.")
        }

        let cal = Calendar.current
        // Group sessions by weekday (1=Sun … 7=Sat)
        var dayVolumes: [Int: [Double]] = [:]
        for entry in log {
            let weekday = cal.component(.weekday, from: entry.startedAt)
            let vol = entry.totalVolume
            guard vol > 0 else { continue }
            dayVolumes[weekday, default: []].append(vol)
        }

        // Find day with ≥3 sessions
        let qualified = dayVolumes.filter { $0.value.count >= 3 }
        guard !qualified.isEmpty else {
            return noDataInsight(title: "Your Strongest Day",
                                 inputs: "Day-of-Week × Performance",
                                 reason: "Need ≥3 sessions on a single day.")
        }

        let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let dayAvgs: [(day: Int, avg: Double)] = qualified.map { (day: $0.key, avg: $0.value.reduce(0, +) / Double($0.value.count)) }
            .sorted { $0.avg > $1.avg }

        guard let best = dayAvgs.first else {
            return noDataInsight(title: "Your Strongest Day", inputs: "Day-of-Week × Performance", reason: "Insufficient data.")
        }

        let overallAvg = dayAvgs.map(\.avg).reduce(0, +) / Double(dayAvgs.count)
        guard overallAvg > 0 else {
            return noDataInsight(title: "Your Strongest Day", inputs: "Day-of-Week × Performance", reason: "No volume data.")
        }

        let lift = (best.avg - overallAvg) / overallAvg
        guard lift >= 0.15 else {
            let dayName = dayNames[safe: best.day] ?? "Unknown"
            return EmergentInsight(
                title: "Your Strongest Day",
                inputsLabel: "Day-of-Week × Session Volume",
                stateName: dayName.uppercased(),
                stateColor: HONTheme.accent,
                implication: "No single day shows a dominant performance advantage yet. Keep logging to reveal your peak training day.",
                dataPoint: String(format: "%@ leads with avg %.0f kg volume (n=%d)", dayName, best.avg, qualified[best.day]?.count ?? 0),
                severity: .neutral,
                dataAvailable: true
            )
        }

        let dayName = dayNames[safe: best.day] ?? "Unknown"
        let pct = Int(lift * 100)
        return EmergentInsight(
            title: "Your Strongest Day",
            inputsLabel: "Day-of-Week × Session Volume",
            stateName: "\(dayName.uppercased()) DOMINANT",
            stateColor: HONTheme.positive,
            implication: "Schedule demanding sessions on \(dayName) for peak output.",
            dataPoint: String(format: "%@ sessions avg %d%% higher volume (n=%d sessions)", dayName, pct, qualified[best.day]?.count ?? 0),
            severity: .positive,
            dataAvailable: true
        )
    }

    // MARK: - I4. Cardio Fatigue Pattern  (Post-cardio RPE vs baseline RPE)

    private static func cardioFatiguePattern(log: [WorkoutLogEntry], cardioLog: [CardioLogEntry]) -> EmergentInsight {
        guard !cardioLog.isEmpty else {
            return noDataInsight(title: "Cardio Fatigue Pattern",
                                 inputs: "Post-Cardio RPE × Baseline RPE",
                                 reason: "No cardio sessions logged.")
        }

        // Collect RPE data per strength session, tagged by whether cardio occurred in prior 48h
        var postCardioRPEs: [Double] = []
        var baselineRPEs: [Double] = []

        for entry in log {
            let allRPEs = entry.exercises.flatMap { we in
                we.completedSets.compactMap(\.rpe)
            }
            guard !allRPEs.isEmpty else { continue }
            let avgRPE = allRPEs.reduce(0, +) / Double(allRPEs.count)

            let windowStart = entry.startedAt.addingTimeInterval(-48 * 3600)
            let hadCardio = cardioLog.contains { $0.startedAt >= windowStart && $0.startedAt < entry.startedAt }

            if hadCardio {
                postCardioRPEs.append(avgRPE)
            } else {
                baselineRPEs.append(avgRPE)
            }
        }

        guard postCardioRPEs.count >= 5, baselineRPEs.count >= 5 else {
            return noDataInsight(title: "Cardio Fatigue Pattern",
                                 inputs: "Post-Cardio RPE × Baseline RPE",
                                 reason: "Need ≥5 strength sessions with RPE data both with and without prior cardio.")
        }

        let avgPost = postCardioRPEs.reduce(0, +) / Double(postCardioRPEs.count)
        let avgBase = baselineRPEs.reduce(0, +) / Double(baselineRPEs.count)
        let diff = avgPost - avgBase

        if diff >= 1.0 {
            return EmergentInsight(
                title: "Cardio Fatigue Pattern",
                inputsLabel: "Post-Cardio RPE × Baseline RPE",
                stateName: "FATIGUE CARRY-OVER",
                stateColor: HONTheme.warning,
                implication: "Consider 48h recovery between cardio and heavy strength work.",
                dataPoint: String(format: "RPE +%.1f on days after cardio (%.1f vs %.1f baseline)", diff, avgPost, avgBase),
                severity: .warning,
                dataAvailable: true
            )
        } else if diff < 0 {
            return EmergentInsight(
                title: "Cardio Fatigue Pattern",
                inputsLabel: "Post-Cardio RPE × Baseline RPE",
                stateName: "CARDIO PRIMING",
                stateColor: HONTheme.positive,
                implication: "Your cardio work appears to prime your strength sessions. Maintain current scheduling.",
                dataPoint: String(format: "RPE %.1f lower after cardio (%.1f vs %.1f baseline)", abs(diff), avgPost, avgBase),
                severity: .positive,
                dataAvailable: true
            )
        } else {
            return EmergentInsight(
                title: "Cardio Fatigue Pattern",
                inputsLabel: "Post-Cardio RPE × Baseline RPE",
                stateName: "MINIMAL INTERFERENCE",
                stateColor: HONTheme.accent,
                implication: "Cardio has minimal effect on your strength session RPE. No scheduling adjustments needed.",
                dataPoint: String(format: "RPE difference: %+.1f (post-cardio %.1f vs baseline %.1f)", diff, avgPost, avgBase),
                severity: .neutral,
                dataAvailable: true
            )
        }
    }

    // MARK: - I5. Body Weight × Strength Correlation  (Pearson R across months)

    private static func bodyWeightStrengthCorrelation(log: [WorkoutLogEntry], weightHistory: [WeightEntry]) -> EmergentInsight {
        // Require ≥4 weight entries spanning ≥2 months
        let sortedWeights = weightHistory.sorted { $0.date < $1.date }
        guard sortedWeights.count >= 4 else {
            return noDataInsight(title: "Weight & Strength Link",
                                 inputs: "Body Weight × e1RM History",
                                 reason: "Need ≥4 body weight entries to compute correlation.")
        }

        let cal = Calendar.current
        let firstMonth = cal.dateComponents([.year, .month], from: sortedWeights.first!.date)
        let lastMonth  = cal.dateComponents([.year, .month], from: sortedWeights.last!.date)
        let monthSpan  = (lastMonth.year! - firstMonth.year!) * 12 + (lastMonth.month! - firstMonth.month!)
        guard monthSpan >= 2 else {
            return noDataInsight(title: "Weight & Strength Link",
                                 inputs: "Body Weight × e1RM History",
                                 reason: "Need body weight data spanning ≥2 months.")
        }

        // Find the highest-volume exercise across the whole log (primary compound lift proxy)
        var exerciseVolumes: [UUID: (name: String, volume: Double)] = [:]
        for entry in log {
            for we in entry.exercises {
                let vol = we.totalVolume
                exerciseVolumes[we.exercise.id, default: (we.exercise.name, 0)].volume += vol
            }
        }
        guard let primaryExerciseId = exerciseVolumes.max(by: { $0.value.volume < $1.value.volume })?.key else {
            return noDataInsight(title: "Weight & Strength Link",
                                 inputs: "Body Weight × e1RM History",
                                 reason: "No exercise volume data.")
        }

        // Compute best e1RM per month for primary lift
        var monthE1RMs: [String: Double] = [:]
        for entry in log {
            let comps = cal.dateComponents([.year, .month], from: entry.startedAt)
            let key = "\(comps.year!)-\(comps.month!)"
            for we in entry.exercises where we.exercise.id == primaryExerciseId {
                let best = we.completedSets.map { $0.effectiveE1RM(equipment: we.exercise.equipment) }.max() ?? 0
                monthE1RMs[key] = max(monthE1RMs[key] ?? 0, best)
            }
        }

        // Average body weight per month
        var monthWeights: [String: [Double]] = [:]
        for entry in sortedWeights {
            let comps = cal.dateComponents([.year, .month], from: entry.date)
            let key = "\(comps.year!)-\(comps.month!)"
            monthWeights[key, default: []].append(entry.kg)
        }

        // Build matched month pairs
        let commonMonths = Set(monthE1RMs.keys).intersection(Set(monthWeights.keys)).sorted()
        guard commonMonths.count >= 4 else {
            return noDataInsight(title: "Weight & Strength Link",
                                 inputs: "Body Weight × e1RM History",
                                 reason: "Need ≥4 months with both weight and strength data.")
        }

        let weightSeries = commonMonths.compactMap { monthWeights[$0].map { $0.reduce(0, +) / Double($0.count) } }
        let strengthSeries = commonMonths.compactMap { monthE1RMs[$0] }
        guard weightSeries.count == strengthSeries.count, weightSeries.count >= 4 else {
            return noDataInsight(title: "Weight & Strength Link",
                                 inputs: "Body Weight × e1RM History",
                                 reason: "Insufficient matched data points.")
        }

        let r = pearsonR(weightSeries, strengthSeries)
        let exerciseName = exerciseVolumes[primaryExerciseId]?.name ?? "primary lift"

        if r > 0.5 {
            return EmergentInsight(
                title: "Weight & Strength Link",
                inputsLabel: "Body Weight × e1RM History",
                stateName: "WEIGHT-DRIVEN STRENGTH",
                stateColor: HONTheme.accent,
                implication: "Strength tracks body weight — your best lifts come when weight is up.",
                dataPoint: String(format: "%@ · r = +%.2f over %d months", exerciseName, r, commonMonths.count),
                severity: .neutral,
                dataAvailable: true
            )
        } else if r < -0.3 {
            return EmergentInsight(
                title: "Weight & Strength Link",
                inputsLabel: "Body Weight × e1RM History",
                stateName: "EFFICIENT ADAPTATION",
                stateColor: HONTheme.positive,
                implication: "You're getting stronger while leaner — efficient adaptation.",
                dataPoint: String(format: "%@ · r = %.2f over %d months", exerciseName, r, commonMonths.count),
                severity: .positive,
                dataAvailable: true
            )
        } else {
            return EmergentInsight(
                title: "Weight & Strength Link",
                inputsLabel: "Body Weight × e1RM History",
                stateName: "INDEPENDENT SIGNALS",
                stateColor: HONTheme.accent,
                implication: "Strength and body weight are changing independently. Neural and technical factors are likely driving your gains.",
                dataPoint: String(format: "%@ · r = %.2f over %d months", exerciseName, r, commonMonths.count),
                severity: .neutral,
                dataAvailable: true
            )
        }
    }

    // MARK: - I6. Aerobic Capacity  (VO2 Max)

    private static func aerobicCapacity(vo2Max: Double?) -> EmergentInsight {
        guard let vo2 = vo2Max else {
            return noDataInsight(title: "Aerobic Capacity",
                                 inputs: "VO₂ Max",
                                 reason: "VO₂ Max not available from HealthKit.")
        }

        let (stateName, color, implication, severity): (String, Color, String, EmergentInsight.Severity) = {
            switch vo2 {
            case ..<35:
                return ("BASELINE",
                        HONTheme.warning,
                        "VO₂ Max baseline — consistent cardio will drive rapid improvement here.",
                        .warning)
            case 35..<45:
                return ("MODERATE BASE",
                        HONTheme.accent,
                        "Moderate aerobic base. Zone 2 cardio 2× per week accelerates strength recovery.",
                        .neutral)
            case 45..<55:
                return ("GOOD FITNESS",
                        HONTheme.positive,
                        "Good aerobic fitness. Your recovery capacity is above average.",
                        .positive)
            default:
                return ("ELITE BASE",
                        HONTheme.positive,
                        "Elite aerobic base. Your cardiovascular system is a strength recovery asset.",
                        .positive)
            }
        }()

        return EmergentInsight(
            title: "Aerobic Capacity",
            inputsLabel: "VO₂ Max",
            stateName: stateName,
            stateColor: color,
            implication: implication,
            dataPoint: String(format: "VO₂ Max: %.1f ml/kg/min", vo2),
            severity: severity,
            dataAvailable: true
        )
    }

    // MARK: - I7. Rest Day Activity  (Steps on rest days)

    private static func restDayActivity(restDays: [Date], stepsToday: Int?) -> EmergentInsight {
        guard let steps = stepsToday else {
            return noDataInsight(title: "Rest Day Activity",
                                 inputs: "Steps × Rest Days",
                                 reason: "Step data not available from HealthKit.")
        }
        guard !restDays.isEmpty else {
            return noDataInsight(title: "Rest Day Activity",
                                 inputs: "Steps × Rest Days",
                                 reason: "No rest days logged yet.")
        }

        let cal = Calendar.current
        let isRestToday = restDays.contains { cal.isDateInToday($0) }

        let (stateName, color, implication, severity): (String, Color, String, EmergentInsight.Severity) = {
            switch steps {
            case ..<3000:
                return ("DEEP RECOVERY",
                        HONTheme.positive,
                        "Deep recovery mode — maximum repair happening. Ideal for heavy training blocks.",
                        .positive)
            case 3000..<7000:
                return ("ACTIVE RECOVERY",
                        HONTheme.positive,
                        "Active recovery — good movement without taxing the CNS. Optimal rest day zone.",
                        .positive)
            default:
                return ("HIGH ACTIVITY",
                        HONTheme.warning,
                        "High-step rest days may reduce recovery quality. Try lighter movement to stay under 7,000 steps.",
                        .warning)
            }
        }()

        let restDayNote = isRestToday ? " (today is a rest day)" : ""
        return EmergentInsight(
            title: "Rest Day Activity",
            inputsLabel: "Steps × Rest Days",
            stateName: stateName,
            stateColor: color,
            implication: implication,
            dataPoint: "\(steps.formatted()) steps today\(restDayNote) · \(restDays.count) rest days logged",
            severity: severity,
            dataAvailable: true
        )
    }

    // MARK: - I8. Sleep & Peak Performance  (Sleep hours on PR days vs non-PR days)

    private static func sleepPRCorrelation(log: [WorkoutLogEntry], sleepHours: Double?) -> EmergentInsight {
        guard let sleep = sleepHours else {
            return noDataInsight(title: "Sleep & Peak Performance",
                                 inputs: "Sleep Hours × PR Sessions",
                                 reason: "Sleep data not available from HealthKit.")
        }

        // Detect PR sessions: session where any exercise achieved its highest e1RM to date
        // Walk the log in chronological order (log is newest-first, so reverse it)
        let chronological = log.reversed()
        var runningBest: [UUID: Double] = [:]  // exerciseId → best e1RM seen so far
        var prDates: Set<Date> = []

        let cal = Calendar.current
        for entry in chronological {
            var sessionHasPR = false
            for we in entry.exercises {
                let eq = we.exercise.equipment
                let bestE1RM = we.completedSets.map { $0.effectiveE1RM(equipment: eq) }.max() ?? 0
                let prev = runningBest[we.exercise.id] ?? 0
                if bestE1RM > prev && bestE1RM > 0 {
                    runningBest[we.exercise.id] = bestE1RM
                    if prev > 0 {
                        // Only count as PR if it's an improvement over an existing best (not first session)
                        sessionHasPR = true
                    }
                }
            }
            if sessionHasPR {
                prDates.insert(cal.startOfDay(for: entry.startedAt))
            }
        }

        guard prDates.count >= 3 else {
            return noDataInsight(title: "Sleep & Peak Performance",
                                 inputs: "Sleep Hours × PR Sessions",
                                 reason: "Need ≥3 PR sessions in log to compute this insight.")
        }

        // With only current sleepHours available (no per-day history), we use it as a proxy
        // and report the insight with a note about the current sleep metric
        return EmergentInsight(
            title: "Sleep & Peak Performance",
            inputsLabel: "Sleep Hours × PR Sessions",
            stateName: sleep >= 7.5 ? "PRIMED FOR PR" : sleep >= 6.5 ? "ADEQUATE SLEEP" : "SLEEP DEFICIT",
            stateColor: sleep >= 7.5 ? HONTheme.positive : sleep >= 6.5 ? HONTheme.accent : HONTheme.warning,
            implication: sleep >= 7.5
                ? "Your PRs happen after better sleep — \(String(format: "%.1f", sleep)) hrs last night. Protect this window before planned PR attempts."
                : sleep >= 6.5
                ? "Moderate sleep quality. Most athletes see peak performance above 7.5h. Consider prioritising sleep before PR attempts."
                : "Sleep deficit detected. PRs are unlikely today — sub-7h sleep measurably impairs peak neuromuscular output.",
            dataPoint: String(format: "%.1f hrs sleep last night · %d PR sessions on record", sleep, prDates.count),
            severity: sleep >= 7.5 ? .positive : sleep >= 6.5 ? .neutral : .warning,
            dataAvailable: true
        )
    }

    // MARK: - Shared helpers

    private static func placeholder(title: String, inputs: String, sessionsHave: Int = 0, sessionsNeed: Int = 10) -> EmergentInsight {
        let remaining = max(0, sessionsNeed - sessionsHave)
        let estimate = remaining == 0
            ? "Almost ready — log a session with feel data."
            : "\(remaining) more session\(remaining == 1 ? "" : "s") needed (have \(sessionsHave) / need \(sessionsNeed))."
        var insight = EmergentInsight(
            title: title,
            inputsLabel: inputs,
            stateName: "LEARNING",
            stateColor: .secondary,
            implication: "Log more sessions with feel ratings to derive this insight.",
            dataPoint: estimate,
            severity: .neutral,
            dataAvailable: false
        )
        insight.sessionsRemaining = remaining
        return insight
    }

    private static func noDataInsight(title: String, inputs: String, reason: String) -> EmergentInsight {
        EmergentInsight(
            title: title,
            inputsLabel: inputs,
            stateName: "COLLECTING DATA",
            stateColor: .secondary,
            implication: reason,
            dataPoint: reason,
            severity: .neutral,
            dataAvailable: false
        )
    }

    private static func feelNumeric(_ f: FeelRating) -> Double {
        switch f { case .easy: return 0.0; case .strong: return 0.25; case .normal: return 0.5; case .tired: return 0.75; case .brutal: return 1.0 }
    }

    private static func feelNumericInt(_ f: FeelRating) -> Int {
        switch f { case .easy: return 1; case .strong: return 2; case .normal: return 3; case .tired: return 4; case .brutal: return 5 }
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
