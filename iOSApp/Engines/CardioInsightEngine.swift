import Foundation
import SwiftUI

// MARK: - CardioInsightEngine
// Derives 8 second-order insights from HIIT/circuit session data.
// Four are cardio-internal (round count, fatigue curve, density, consistency).
// Four are cross-domain (cardio × strength interference, sequencing, dual-mode, synergy).

enum CardioInsightEngine {

    static func compute(
        cardioLog: [CardioLogEntry],
        strengthLog: [WorkoutLogEntry],
        analyticsResult: AnalyticsResult
    ) -> [EmergentInsight] {
        guard !cardioLog.isEmpty else { return [] }
        return [
            hiitEnduranceTrend(cardioLog: cardioLog),
            fatigueResistance(cardioLog: cardioLog),
            workCapacityDensity(cardioLog: cardioLog),
            circuitConsistency(cardioLog: cardioLog),
            cardioStrengthInterference(cardioLog: cardioLog, strengthLog: strengthLog),
            modalitySequencing(cardioLog: cardioLog, strengthLog: strengthLog),
            dualModeFitnessIndex(cardioLog: cardioLog, analytics: analyticsResult),
            energySystemSynergy(cardioLog: cardioLog, strengthLog: strengthLog),
        ]
    }

    // MARK: - 1. HIIT Endurance Trend — Completed Rounds × Time

    private static func hiitEnduranceTrend(cardioLog: [CardioLogEntry]) -> EmergentInsight {
        let sessions = cardioLog.sorted { $0.startedAt < $1.startedAt }
        guard sessions.count >= 3 else {
            return placeholder(title: "HIIT Endurance Trend", inputs: "Completed Rounds × Time")
        }

        let rounds = sessions.map { Double($0.completedRounds) }
        let slope  = linearSlope(rounds)

        let state: HiitEnduranceTrend = {
            if slope >  0.15 { return .climbing }
            if slope < -0.10 { return .declining }
            return .plateau
        }()

        let recent    = sessions.suffix(3).map(\.completedRounds)
        let avgRecent = Double(recent.reduce(0, +)) / Double(recent.count)

        return EmergentInsight(
            title: "HIIT Endurance Trend",
            inputsLabel: "Completed Rounds × Time",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: state.implication,
            dataPoint: String(format: "Rounds slope: %+.2f/session · Recent avg: %.1f rounds (%d sessions)",
                              slope, avgRecent, sessions.count),
            severity: state.severity,
            dataAvailable: true
        )
    }

    // MARK: - 2. Fatigue Resistance — Round Progression × Rep Count

    private static func fatigueResistance(cardioLog: [CardioLogEntry]) -> EmergentInsight {
        let sessions = cardioLog.suffix(5)
        let fadePcts: [Double] = sessions.compactMap { entry -> Double? in
            let n = entry.completedRounds
            guard n >= 3 else { return nil }
            let third = max(1, n / 3)

            var repsByRound: [Int: Int] = [:]
            for r in entry.results { repsByRound[r.round, default: 0] += r.repsCompleted }
            let sortedRounds = repsByRound.keys.sorted()

            let earlyReps = sortedRounds.prefix(third).compactMap { repsByRound[$0] }.map(Double.init)
            let lateReps  = sortedRounds.suffix(third).compactMap { repsByRound[$0] }.map(Double.init)

            let earlyAvg = earlyReps.isEmpty ? 0 : earlyReps.reduce(0, +) / Double(earlyReps.count)
            let lateAvg  = lateReps.isEmpty  ? 0 : lateReps.reduce(0,  +) / Double(lateReps.count)

            guard earlyAvg > 0 else { return nil }
            return (earlyAvg - lateAvg) / earlyAvg * 100
        }

        guard fadePcts.count >= 2 else {
            return placeholder(title: "Fatigue Resistance", inputs: "Round Progression × Rep Count")
        }

        let avgFade = fadePcts.reduce(0, +) / Double(fadePcts.count)

        let state: FatigueResistanceState = {
            if avgFade < 5  { return .ironWall }
            if avgFade < 15 { return .normalFade }
            return .earlyCollapse
        }()

        return EmergentInsight(
            title: "Fatigue Resistance",
            inputsLabel: "Round Progression × Rep Count",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: state.implication,
            dataPoint: String(format: "Avg rep fade early→late rounds: %.1f%% (last %d sessions)",
                              avgFade, fadePcts.count),
            severity: state.severity,
            dataAvailable: true
        )
    }

    // MARK: - 3. Work Capacity Density — Reps per Minute × Sessions

    private static func workCapacityDensity(cardioLog: [CardioLogEntry]) -> EmergentInsight {
        let sessions = cardioLog.sorted { $0.startedAt < $1.startedAt }
        guard sessions.count >= 3 else {
            return placeholder(title: "Work Capacity Density", inputs: "Reps per Minute × Sessions")
        }

        let densities = sessions.map { e -> Double in
            e.durationMinutes > 0 ? Double(e.totalReps) / Double(e.durationMinutes) : 0
        }
        let slope   = linearSlope(densities)
        let current = densities.last ?? 0

        let state: WorkCapacityTrend = {
            if slope >  0.30 { return .accelerating }
            if slope < -0.30 { return .dropping }
            return .holding
        }()

        return EmergentInsight(
            title: "Work Capacity Density",
            inputsLabel: "Reps per Minute × Sessions",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: state.implication,
            dataPoint: String(format: "Current: %.1f reps/min · Trend: %+.2f/session (%d sessions)",
                              current, slope, sessions.count),
            severity: state.severity,
            dataAvailable: true
        )
    }

    // MARK: - 4. Circuit Consistency — Rep Variance × Round Count

    private static func circuitConsistency(cardioLog: [CardioLogEntry]) -> EmergentInsight {
        let sessions = cardioLog.suffix(5)
        let stdDevs: [Double] = sessions.compactMap { entry -> Double? in
            guard entry.completedRounds >= 3 else { return nil }
            var repsByRound: [Int: Int] = [:]
            for r in entry.results { repsByRound[r.round, default: 0] += r.repsCompleted }
            let vals = repsByRound.values.map(Double.init)
            guard vals.count >= 3 else { return nil }
            return standardDeviation(vals)
        }

        guard stdDevs.count >= 2 else {
            return placeholder(title: "Circuit Consistency", inputs: "Rep Variance × Round Count")
        }

        let avgStdDev = stdDevs.reduce(0, +) / Double(stdDevs.count)

        let state: CircuitConsistencyState = {
            if avgStdDev < 2 { return .metronomic }
            if avgStdDev < 5 { return .variable }
            return .erratic
        }()

        return EmergentInsight(
            title: "Circuit Consistency",
            inputsLabel: "Rep Variance × Round Count",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: state.implication,
            dataPoint: String(format: "Avg per-round std dev: %.1f reps (last %d sessions)",
                              avgStdDev, stdDevs.count),
            severity: state.severity,
            dataAvailable: true
        )
    }

    // MARK: - 5. Cardio-Strength Interference — HIIT Timing × Strength Feel (48h window)

    private static func cardioStrengthInterference(
        cardioLog: [CardioLogEntry],
        strengthLog: [WorkoutLogEntry]
    ) -> EmergentInsight {
        guard !cardioLog.isEmpty && strengthLog.count >= 4 else {
            return placeholder(title: "Cardio-Strength Interference", inputs: "HIIT Timing × Strength Feel")
        }

        var afterCardioFeel: [Double] = []
        var baselineFeel:    [Double] = []

        for session in strengthLog.prefix(20) {
            guard let feel = session.feelRating else { continue }
            let score  = feelNumeric(feel)
            let window = session.startedAt.addingTimeInterval(-48 * 3600)
            let hadCardio = cardioLog.contains {
                $0.startedAt >= window && $0.startedAt < session.startedAt
            }
            if hadCardio { afterCardioFeel.append(score) }
            else         { baselineFeel.append(score) }
        }

        guard afterCardioFeel.count >= 2 && !baselineFeel.isEmpty else {
            return placeholder(title: "Cardio-Strength Interference", inputs: "HIIT Timing × Strength Feel")
        }

        let postMean = afterCardioFeel.reduce(0, +) / Double(afterCardioFeel.count)
        let baseMean = baselineFeel.reduce(0,    +) / Double(baselineFeel.count)
        let diff     = postMean - baseMean

        let state: CardioStrengthInterference = {
            if diff >  0.12 { return .synergistic }
            if diff < -0.12 { return .suppressive }
            return .neutral
        }()

        return EmergentInsight(
            title: "Cardio-Strength Interference",
            inputsLabel: "HIIT Timing × Strength Feel",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: state.implication,
            dataPoint: String(format: "Post-HIIT strength feel: %.0f%% vs baseline %.0f%% (n=%d HIIT-adjacent sessions)",
                              postMean * 100, baseMean * 100, afterCardioFeel.count),
            severity: state.severity,
            dataAvailable: true
        )
    }

    // MARK: - 6. Modality Sequencing — HIIT Frequency × Strength Scheduling

    private static func modalitySequencing(
        cardioLog: [CardioLogEntry],
        strengthLog: [WorkoutLogEntry]
    ) -> EmergentInsight {
        guard cardioLog.count >= 2 && strengthLog.count >= 2 else {
            return placeholder(title: "Modality Sequencing", inputs: "HIIT Frequency × Strength Scheduling")
        }

        let gaps: [Double] = cardioLog.prefix(10).compactMap { cardio -> Double? in
            let nextStrength = strengthLog
                .filter { $0.startedAt > cardio.startedAt }
                .min { $0.startedAt < $1.startedAt }
            guard let ns = nextStrength else { return nil }
            return ns.startedAt.timeIntervalSince(cardio.startedAt) / 86400.0
        }

        guard gaps.count >= 2 else {
            return placeholder(title: "Modality Sequencing", inputs: "HIIT Frequency × Strength Scheduling")
        }

        let avgGap = gaps.reduce(0, +) / Double(gaps.count)

        let state: ModalitySequencing = {
            if avgGap < 0.5  { return .stacked }
            if avgGap <= 2.0 { return .optimal }
            return .extendedGap
        }()

        return EmergentInsight(
            title: "Modality Sequencing",
            inputsLabel: "HIIT Frequency × Strength Scheduling",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: state.implication,
            dataPoint: String(format: "Avg HIIT→Strength gap: %.1f days (n=%d transitions)", avgGap, gaps.count),
            severity: state.severity,
            dataAvailable: true
        )
    }

    // MARK: - 7. Dual-Mode Fitness Index — Cardio Trend × Strength Momentum

    private static func dualModeFitnessIndex(
        cardioLog: [CardioLogEntry],
        analytics: AnalyticsResult
    ) -> EmergentInsight {
        guard cardioLog.count >= 3 else {
            return placeholder(title: "Dual-Mode Fitness Index", inputs: "Cardio Trend × Strength Momentum")
        }

        let cardioSorted = cardioLog.sorted { $0.startedAt < $1.startedAt }
        let roundsSlope  = linearSlope(cardioSorted.map { Double($0.completedRounds) })
        let cardioUp     = roundsSlope > 0.10

        let strengthUp = analytics.exerciseAnalytics
            .filter(\.hasEnoughData)
            .prefix(3)
            .contains { $0.slopePerWeek > 0.3 }

        let state: DualModeFitnessIndex = {
            switch (cardioUp, strengthUp) {
            case (true,  true):  return .dualModeAthlete
            case (false, true):  return .strengthLed
            case (true,  false): return .cardioLed
            case (false, false): return .bothStalled
            }
        }()

        let sign = roundsSlope >= 0 ? "+" : ""

        return EmergentInsight(
            title: "Dual-Mode Fitness Index",
            inputsLabel: "Cardio Trend × Strength Momentum",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: state.implication,
            dataPoint: "HIIT rounds \(sign)\(String(format: "%.2f", roundsSlope))/session · Strength \(strengthUp ? "progressing ↑" : "plateaued →")",
            severity: state.severity,
            dataAvailable: true
        )
    }

    // MARK: - 8. Energy System Synergy — HIIT Load × Strength Feel (24h window)

    private static func energySystemSynergy(
        cardioLog: [CardioLogEntry],
        strengthLog: [WorkoutLogEntry]
    ) -> EmergentInsight {
        guard cardioLog.count >= 2 && strengthLog.count >= 4 else {
            return placeholder(title: "Energy System Synergy", inputs: "HIIT Load × Strength Feel")
        }

        var postCardioFeel: [Double] = []
        var baselineFeel:   [Double] = []

        for session in strengthLog.prefix(20) {
            guard let feel = session.feelRating else { continue }
            let score  = feelNumeric(feel)
            let window = session.startedAt.addingTimeInterval(-24 * 3600)
            let hadCardio = cardioLog.contains {
                $0.startedAt >= window && $0.startedAt < session.startedAt
            }
            if hadCardio { postCardioFeel.append(score) }
            else         { baselineFeel.append(score) }
        }

        guard postCardioFeel.count >= 2 && !baselineFeel.isEmpty else {
            return placeholder(title: "Energy System Synergy", inputs: "HIIT Load × Strength Feel")
        }

        let postMean = postCardioFeel.reduce(0, +) / Double(postCardioFeel.count)
        let baseMean = baselineFeel.reduce(0,   +) / Double(baselineFeel.count)
        let diff     = postMean - baseMean

        let state: EnergySystemSynergy = {
            if diff >  0.10 { return .boosting }
            if diff < -0.10 { return .draining }
            return .neutral
        }()

        return EmergentInsight(
            title: "Energy System Synergy",
            inputsLabel: "HIIT Load × Strength Feel",
            stateName: state.rawValue.uppercased(),
            stateColor: state.color,
            implication: state.implication,
            dataPoint: String(format: "Strength feel post-HIIT: %.0f%% vs baseline %.0f%%",
                              postMean * 100, baseMean * 100),
            severity: state.severity,
            dataAvailable: true
        )
    }

    // MARK: - Shared Helpers

    private static func placeholder(title: String, inputs: String) -> EmergentInsight {
        EmergentInsight(
            title: title,
            inputsLabel: inputs,
            stateName: "LEARNING",
            stateColor: .secondary,
            implication: "Log more HIIT sessions to derive this insight.",
            dataPoint: "Needs 3+ cardio sessions to unlock.",
            severity: .neutral,
            dataAvailable: false
        )
    }

    private static func feelNumeric(_ f: FeelRating) -> Double {
        switch f { case .easy: return 0.0; case .strong: return 0.25; case .normal: return 0.5; case .tired: return 0.75; case .brutal: return 1.0 }
    }

    static func linearSlope(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n > 1 else { return 0 }
        let xs  = (0..<values.count).map(Double.init)
        let mx  = xs.reduce(0, +) / n
        let my  = values.reduce(0, +) / n
        let cov = zip(xs, values).map { ($0 - mx) * ($1 - my) }.reduce(0, +)
        let varX = xs.map { pow($0 - mx, 2) }.reduce(0, +)
        return varX > 0 ? cov / varX : 0
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n > 1 else { return 0 }
        let mean     = values.reduce(0, +) / n
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / n
        return sqrt(variance)
    }
}
