import Foundation

enum HONPatternEngine {

    static let rollingWindowWeeks    = 8
    static let expectedDayThreshold  = 0.50   // days with P ≥ this are "expected" training days
    static let highConfidenceThreshold = 0.70
    static let minWeeksForConfidence = 12

    // MARK: - Day Probabilities (rolling 8-week window)

    static func computeDayProbabilities(weekRecords: [HONWeekRecord]) -> [HONDayProbability] {
        let window = Array(weekRecords.suffix(rollingWindowWeeks))
        guard !window.isEmpty else { return [] }
        let n = Double(window.count)
        return (0..<7).map { day in
            let count = window.filter { $0.sessionDays.contains(day) }.count
            return HONDayProbability(dayIndex: day, probability: Double(count) / n)
        }
    }

    // MARK: - Pattern Confidence

    /// Average probability across "expected" days (P ≥ 0.50)
    static func computeConfidence(probabilities: [HONDayProbability]) -> Double {
        let expected = probabilities.filter { $0.probability >= expectedDayThreshold }
        guard !expected.isEmpty else { return 0.0 }
        return expected.reduce(0) { $0 + $1.probability } / Double(expected.count)
    }

    static func isHighConfidence(confidence: Double, activeWeeks: Int) -> Bool {
        confidence >= highConfidenceThreshold && activeWeeks >= minWeeksForConfidence
    }

    // MARK: - User Type

    static func detectUserType(confidence: Double) -> HONUserType {
        confidence >= highConfidenceThreshold ? .typeA : .typeB
    }

    // MARK: - Consecutive Active Weeks

    static func computeConsecutiveActiveWeeks(weekRecords: [HONWeekRecord]) -> Int {
        let sorted = weekRecords.sorted { $0.weekStart > $1.weekStart }
        var count = 0
        for record in sorted {
            if record.sessionCount > 0 { count += 1 } else { break }
        }
        return count
    }

    // MARK: - Rolling Average

    static func rollingAverageSessionsPerWeek(weekRecords: [HONWeekRecord]) -> Double {
        let window = Array(weekRecords.suffix(rollingWindowWeeks))
        guard !window.isEmpty else { return 0 }
        return Double(window.reduce(0) { $0 + $1.sessionCount }) / Double(window.count)
    }

    // MARK: - Ramp Detection

    /// True when current week ≥ 2× rolling prior average
    static func isRamping(currentWeekSessions: Int, weekRecords: [HONWeekRecord]) -> Bool {
        let prior = Array(weekRecords.dropLast().suffix(rollingWindowWeeks))
        guard prior.count >= 3 else { return false }
        let avg = Double(prior.reduce(0) { $0 + $1.sessionCount }) / Double(prior.count)
        guard avg > 0 else { return false }
        return Double(currentWeekSessions) >= avg * 2.0
    }

    // MARK: - Drift Detection

    /// True when the last 2 weeks average < 50% of the prior rolling average
    static func isDrifting(weekRecords: [HONWeekRecord]) -> Bool {
        guard weekRecords.count >= 4 else { return false }
        let sorted = weekRecords.sorted { $0.weekStart < $1.weekStart }
        let recent = Array(sorted.suffix(2))
        let prior  = Array(sorted.dropLast(2).suffix(rollingWindowWeeks))
        guard prior.count >= 2 else { return false }
        let recentAvg = Double(recent.reduce(0) { $0 + $1.sessionCount }) / Double(recent.count)
        let priorAvg  = Double(prior.reduce(0) { $0 + $1.sessionCount }) / Double(prior.count)
        guard priorAvg > 0 else { return false }
        return recentAvg < priorAvg * 0.5 && recentAvg < 2.0
    }

    // MARK: - Deload Detection

    /// True when current week volume ≤ 60% of the prior 4-week average
    static func isDeloading(currentWeekVolume: Double, weekRecords: [HONWeekRecord]) -> Bool {
        let priorWindow = Array(weekRecords.dropLast().suffix(4))
        guard priorWindow.count >= 2 else { return false }
        let avgVolume = priorWindow.reduce(0) { $0 + $1.totalVolume } / Double(priorWindow.count)
        guard avgVolume > 0 else { return false }
        return currentWeekVolume <= avgVolume * 0.60
    }
}
