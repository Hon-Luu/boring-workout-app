import Foundation
import SwiftUI

// MARK: - Models

struct ReadinessState {
    let score: Int
    let confidence: Confidence
    let deltaFromBaseline: Int
    let headline: String
    let subtitle: String
    let coachingNote: String
    let trendLabel: String
    let trendData: [TrendPoint]
    let factors: [Factor]
    var hasSleepData: Bool = false

    enum Confidence: String {
        case high = "High", medium = "Medium", low = "Low"

        var color: Color {
            switch self {
            case .high:   return HONTheme.positive
            case .medium: return HONTheme.warning
            case .low:    return HONTheme.negative
            }
        }
    }

    struct TrendPoint: Identifiable {
        let id = UUID()
        let dayOffset: Int   // 0 = oldest, 13 = today
        let score: Double
    }

    struct Factor: Identifiable {
        let id = UUID()
        let text: String
        let isPositive: Bool
    }
}

// MARK: - Engine

struct ReadinessEngine {

    /// Computes a readiness state from workout log data, optional cardio log data,
    /// optional general activity log, and optional step count from HealthKit.
    static func compute(
        log: [WorkoutLogEntry],
        cardioLog: [CardioLogEntry] = [],
        generalLog: [GeneralActivityEntry] = [],
        stepsToday: Int? = nil,
        sleepHours: Double? = nil,
        restingHR: Double? = nil,
        hrv: Double? = nil,
        hrvBaseline: Double? = nil,          // user's 30-day personal HRV median; nil during calibration
        scoreHistory: [String: Int] = [:]   // "yyyy-MM-dd" → stored score; used for real trend data
    ) -> ReadinessState {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // --- Merge all activity dates (strength + cardio + general) ---
        let allDates = log.map { $0.startedAt }
            + cardioLog.map { $0.startedAt }
            + generalLog.map { $0.startedAt }
        let sortedDates = allDates.sorted().reversed()

        // No data at all — return explicit low-confidence placeholder
        if log.isEmpty && cardioLog.isEmpty && generalLog.isEmpty {
            return ReadinessState(
                score: 0,
                confidence: .low,
                deltaFromBaseline: 0,
                headline: "Log your first session",
                subtitle: "Readiness unlocks after your first workout",
                coachingNote: "Complete your first workout to start building your readiness profile. After 3 sessions, you'll get a personalized score.",
                trendLabel: "—",
                trendData: [],
                factors: []
            )
        }

        // --- Days since last ANY activity ---
        let daysSinceLast: Int = {
            guard let last = sortedDates.first else { return 99 }
            return calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: today).day ?? 99
        }()

        // --- Recent sessions (last 7 days) — all modalities ---
        let recentStrength = log.filter {
            (calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day ?? 99) <= 7
        }
        let recentCardio = cardioLog.filter {
            (calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day ?? 99) <= 7
        }
        let recentGeneral = generalLog.filter {
            (calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day ?? 99) <= 7
        }.filter { $0.durationMinutes >= 10 }
        // General activities count fractionally based on intensity (vigorous = 1.0 session, moderate = 0.6, light = 0.3)
        let generalSessionEquivalent = recentGeneral.reduce(0.0) { $0 + $1.intensityLevel.readinessCredit }
        let recentAll = recentStrength.count + recentCardio.count + Int(generalSessionEquivalent.rounded())

        // --- Volume trend (last 7 vs prior 7) — all modalities ---
        let vol7Strength = recentStrength.reduce(0.0) { $0 + $1.totalVolume }
        let vol7Cardio   = recentCardio.reduce(0.0) { $0 + Double($1.totalReps) }
        let vol7General  = recentGeneral.reduce(0.0) { $0 + $1.intensityLevel.readinessCredit * Double($1.durationMinutes) }
        let vol7 = vol7Strength + vol7Cardio * 2.0 + vol7General

        // Count consecutive days WITH activity (going backward from today or yesterday)
        let consecutiveActiveDays: Int = {
            var count = 0
            var checkDay = daysSinceLast == 0 ? today : calendar.date(byAdding: .day, value: -daysSinceLast, to: today) ?? today
            for _ in 0..<14 {
                let dayStart = calendar.startOfDay(for: checkDay)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                let hasActivity = allDates.contains { $0 >= dayStart && $0 < dayEnd }
                if hasActivity { count += 1 } else { break }
                checkDay = calendar.date(byAdding: .day, value: -1, to: checkDay) ?? checkDay
            }
            return count
        }()

        let prior7Strength = log.filter {
            let d = calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day ?? 99
            return d > 7 && d <= 14
        }.reduce(0.0) { $0 + $1.totalVolume }
        let prior7Cardio = cardioLog.filter {
            let d = calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day ?? 99
            return d > 7 && d <= 14
        }.reduce(0.0) { $0 + Double($1.totalReps) }
        let prior7General = generalLog.filter {
            let d = calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day ?? 99
            return d > 7 && d <= 14
        }.filter { $0.durationMinutes >= 10 }.reduce(0.0) { acc, entry in acc + entry.intensityLevel.readinessCredit * Double(entry.durationMinutes) }
        let prior7 = prior7Strength + prior7Cardio * 2.0 + prior7General

        // --- Step factor (QA-12) — minor modifier, weight 0.05 ---
        let stepFact = stepFactor(steps: stepsToday)

        // --- Score calculation ---
        var score = 68  // neutral baseline

        switch daysSinceLast {
        case 0:      score += 0    // worked out today already
        case 1:      score += 8    // fresh from yesterday
        case 2:      score += 12   // sweet spot
        case 3:      score += 6
        case 4...6:  score -= 4    // getting stale
        default:     score -= 14   // too long off
        }

        // Consecutive-day fatigue penalty
        switch consecutiveActiveDays {
        case 4:     score -= 8
        case 5:     score -= 14
        case 6...:  score -= 20
        default:    break
        }

        if recentAll >= 4 { score += 5 } else if recentAll <= 1 { score -= 8 }

        if vol7 > 0 && prior7 > 0 {
            let ratio = vol7 / prior7
            if ratio < 0.7 { score += 6 }       // deload week
            else if ratio > 1.5 { score -= 6 }   // big spike
        }

        // Apply step factor as a small adjustment (±3 points max at weight 0.05 of ~60 range)
        let stepAdjustment = Int(((stepFact - 0.5) * 2.0 * 0.05 * 60).rounded())
        score += stepAdjustment

        // Sleep factor — last night's sleep hours, primary recovery signal
        if let sleep = sleepHours {
            if sleep >= 7.5      { score += 5  }
            else if sleep >= 7.0  { score += 2  }
            else if sleep >= 6.0  { score -= 2 }  // sub-optimal: mild penalty
            else if sleep >= 5.0  { score -= 5 }
            else                  { score -= 10 }  // <5h: significant impairment
        }

        // Resting HR factor — elevated HR signals stress or incomplete recovery
        if let rhr = restingHR {
            if rhr < 55      { score += 3 }  // athletic / well-recovered
            else if rhr < 65 { }             // normal range, no adjustment
            else if rhr < 75 { score -= 3 }  // mildly elevated
            else             { score -= 6 }  // elevated — fatigue or illness signal
        }

        // HRV factor — personalized vs personal baseline when available, else population thresholds
        if let hrv {
            let lowHRV  = hrvBaseline.map { $0 * 0.88 } ?? 55.0
            let goodHRV = hrvBaseline.map { $0 * 1.02 } ?? 70.0
            if hrv < lowHRV       { score -= 5 }
            else if hrv >= goodHRV { score += 4 }
        }

        // H-002: 3-day HRV trend (chronic suppression modifier)
        // scoreHistory is keyed "yyyy-MM-dd" → Int readiness, but we also use hrv value from the single reading
        // We use a simplified approach: check if HRV is below baseline for 3 consecutive days using scoreHistory
        if let baseline = hrvBaseline {
            let cal = Calendar.current
            // Look at hrv readings implied by readiness drops — use scoreHistory to detect chronic suppression
            // Count recent days with low readiness (< 55) as proxy for HRV suppression
            let recentKeys = (1...3).compactMap { daysAgo -> String? in
                guard let d = cal.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
                return Self.dateKeyFormatter.string(from: d)
            }
            let lowReadinessDays = recentKeys.filter { key in
                guard let s = scoreHistory[key] else { return false }
                return s < 55
            }.count
            if lowReadinessDays >= 3 {
                score -= 5  // chronic suppression — all 3 days below threshold
            } else if lowReadinessDays >= 2 {
                score -= 3  // HRV trending down
            }
            _ = baseline  // suppress unused warning when HRV baseline exists
        }

        // Volume spike penalty — if last session was high-volume, penalize next-day readiness
        if let lastSession = log.sorted(by: { $0.startedAt > $1.startedAt }).first {
            let sessionVolume = lastSession.totalVolume
            // median volume from last 4 sessions
            let recent4 = log.sorted(by: { $0.startedAt > $1.startedAt }).prefix(4).map(\.totalVolume)
            let medianVol = recent4.sorted()[max(0, recent4.count / 2 - 1)]
            if medianVol > 0 {
                let volRatio = sessionVolume / medianVol
                if volRatio > 1.8 { score -= 10 }    // massive session
                else if volRatio > 1.4 { score -= 5 } // big session
            }
            // RPE penalty — average RPE > 8 in last session tanks next-day score
            let rpeValues = lastSession.exercises.flatMap(\.sets).compactMap(\.rpe)
            if !rpeValues.isEmpty {
                let avgRPE = rpeValues.reduce(0.0, +) / Double(rpeValues.count)
                if avgRPE >= 9 { score -= 8 }
                else if avgRPE >= 8 { score -= 4 }
            }
        }

        // readinessBefore trend — user's self-reported pre-session state (1=Tired, 2=Normal, 3=Strong)
        let recentReadinessValues = log.sorted(by: { $0.startedAt > $1.startedAt })
            .prefix(5)
            .compactMap { $0.readinessBefore }
        let avgReadinessBefore: Double? = recentReadinessValues.isEmpty ? nil :
            Double(recentReadinessValues.reduce(0, +)) / Double(recentReadinessValues.count)
        if let avg = avgReadinessBefore {
            if avg <= 1.3       { score -= 5 }  // chronically Tired before sessions
            else if avg >= 2.7  { score += 4 }  // consistently feeling Strong
        }

        score = max(20, min(99, score))

        // --- 30-day baseline ---
        let baseline = computeBaseline(log: log, cardioLog: cardioLog, generalLog: generalLog, calendar: calendar, today: today)
        let delta = score - baseline

        // --- Confidence (based on ALL sessions) ---
        let totalSessions = log.count + cardioLog.count + generalLog.count
        let confidence: ReadinessState.Confidence = totalSessions >= 10 ? .high : totalSessions >= 3 ? .medium : .low

        // Gap-return detection: user trained today, but prior session was > 10 days ago
        let isGapReturn: Bool = {
            guard daysSinceLast == 0 else { return false }
            let allSorted = allDates.sorted()
            guard allSorted.count >= 2 else { return false }
            let previousDate = allSorted[allSorted.count - 2]
            let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: previousDate), to: today).day ?? 0
            return gap > 10
        }()

        // CON-11: detect suppressed state (HRV good, feel low) for narrative override
        let recentFeelLow: Bool = {
            let recentFeel = log.prefix(3).compactMap(\.feelRating)
            guard !recentFeel.isEmpty else { return false }
            let avg = recentFeel.map { f -> Double in
                switch f { case .easy: return 0.0; case .strong: return 0.25; case .normal: return 0.5; case .tired: return 0.75; case .brutal: return 1.0 }
            }.reduce(0, +) / Double(recentFeel.count)
            return avg < 0.5
        }()

        // --- Narrative ---
        let (headline, subtitle, coachingNote) = narrative(score: score, delta: delta, daysSinceLast: daysSinceLast, freq: recentAll, isGapReturn: isGapReturn, hrv: hrv, hrvBaseline: hrvBaseline, recentFeelLow: recentFeelLow)

        // --- Trend (14 days) ---
        let trend = buildTrend(log: log, cardioLog: cardioLog, generalLog: generalLog, calendar: calendar, today: today, todayScore: Double(score), scoreHistory: scoreHistory)

        // --- Factors ---
        let factors = buildFactors(daysSinceLast: daysSinceLast, freq: recentAll, volRatio: prior7 > 0 ? vol7 / prior7 : 1.0, log: log, cardioCount: recentCardio.count, generalCount: recentGeneral.count, stepsToday: stepsToday, sleepHours: sleepHours, restingHR: restingHR, hrv: hrv, hrvBaseline: hrvBaseline, avgReadinessBefore: avgReadinessBefore)

        return ReadinessState(
            score: score,
            confidence: confidence,
            deltaFromBaseline: delta,
            headline: headline,
            subtitle: subtitle,
            coachingNote: coachingNote,
            trendLabel: trendLabel(trend: trend),
            trendData: trend,
            factors: factors,
            hasSleepData: sleepHours != nil
        )
    }

    // MARK: - Step Factor (QA-12)

    /// Maps daily step count to a readiness multiplier.
    /// - nil / 0: 0.5 (neutral — no data)
    /// - < 3000: 0.3 (sedentary, slightly negative)
    /// - 3000–7000: 0.5 (neutral)
    /// - 7000–10000: 0.7 (active)
    /// - > 10000: 0.85 (very active, not fatiguing)
    static func stepFactor(steps: Int?) -> Double {
        guard let steps, steps > 0 else { return 0.5 }
        switch steps {
        case ..<3000:         return 0.3
        case 3000..<7000:     return 0.5
        case 7000..<10000:    return 0.7
        default:              return 0.85
        }
    }

    // MARK: - Helpers

    private static func computeBaseline(
        log: [WorkoutLogEntry],
        cardioLog: [CardioLogEntry] = [],
        generalLog: [GeneralActivityEntry] = [],
        calendar: Calendar,
        today: Date
    ) -> Int {
        let last30strength = log.filter {
            (calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day ?? 99) <= 30
        }
        let last30cardio = cardioLog.filter {
            (calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day ?? 99) <= 30
        }
        let last30general = generalLog.filter {
            (calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day ?? 99) <= 30
        }
        let last30count = last30strength.count + last30cardio.count + last30general.count
        guard last30count > 0 else { return 65 }
        return 65 + min(15, last30count)
    }

    private static func narrative(score: Int, delta: Int, daysSinceLast: Int, freq: Int,
                                   isGapReturn: Bool = false, hrv: Double? = nil,
                                   hrvBaseline: Double? = nil,
                                   recentFeelLow: Bool = false)
        -> (headline: String, subtitle: String, coachingNote: String)
    {
        // Personalized HRV thresholds: use personal baseline if available (≥7 readings),
        // else fall back to population norms (55 ms suppressed / 65 ms normal).
        let lowHRVThreshold  = hrvBaseline.map { $0 * 0.88 } ?? 55.0
        let highHRVThreshold = hrvBaseline.map { $0 * 0.95 } ?? 65.0

        // Gap-return override — alignment with HON returnAfterLapse messaging (H-01/CON-02)
        if isGapReturn {
            return (
                "Good to be back.",
                "First session after the break.",
                "Good to be back after the break. First session back — treat it as a 70–75% effort day and see how the body responds before going full load."
            )
        }

        switch score {
        case 80...:
            // CON-01: HRV suppressed despite high score — temper the "go hard" recommendation
            if let hrv, hrv < lowHRVThreshold {
                return (
                    "Good momentum right now.",
                    "Watch the HRV today.",
                    "Recovery data looks solid but your HRV is below baseline. Aim for 80% effort today — your feel is running ahead of your physiology."
                )
            }
            return (
                "Good momentum right now.",
                "Recovery is stacking up.",
                "You've been recovering well and the momentum is there. Don't hold back today — this is the kind of day you make progress on."
            )
        case 65..<80:
            // CON-11: HRV says recovered but feel is low — acknowledge subjective-physiological gap
            if let hrv, hrv >= highHRVThreshold, recentFeelLow {
                return (
                    "Physically ready, mentally not quite there.",
                    "HRV says go — feel says otherwise.",
                    "Your body is recovered but subjective energy isn't matching the data. Something non-training — stress, sleep quality, or motivation — is the limiting factor. Train, but scale expectations. This usually resolves in 1–2 days."
                )
            }
            // CON-16: add fatigue framing to 65-79 band
            return (
                "Ready to train.",
                "Nothing in the way today.",
                "You're in a good rhythm. Get your work in with focus — if effort starts feeling disproportionate to load, that's early-fatigue signal worth noting."
            )
        case 50..<65:
            return (
                "Keep it controlled today.",
                "A bit of fatigue in the mix.",
                "There's some fatigue in the system. Keep the session focused — clean execution over big numbers today."
            )
        default:
            return (
                "Rest is training too.",
                "Your body is asking for a break.",
                "You're more run down than usual. A rest day right now will do more for your strength than grinding through a session would."
            )
        }
    }

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func buildTrend(
        log: [WorkoutLogEntry],
        cardioLog: [CardioLogEntry] = [],
        generalLog: [GeneralActivityEntry] = [],
        calendar: Calendar,
        today: Date,
        todayScore: Double,
        scoreHistory: [String: Int] = [:]
    ) -> [ReadinessState.TrendPoint] {
        var points: [ReadinessState.TrendPoint] = []
        // Seed the running estimate from today's known score so fallback interpolation
        // moves in the right direction on days without stored data.
        var runningEstimate = max(todayScore - 8, 40.0)

        for i in 0..<14 {
            let dayOffset = i
            let daysAgo   = 13 - i
            let pointDate = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            let dateKey   = dateKeyFormatter.string(from: pointDate)

            let val: Double
            if daysAgo == 0 {
                // Always use today's freshly-computed score
                val = todayScore
                runningEstimate = todayScore
            } else if let stored = scoreHistory[dateKey] {
                // We have a real historical score for this day — use it
                val = Double(stored)
                runningEstimate = Double(stored)
            } else {
                // No stored score: interpolate from session presence (same as before,
                // but only for days we don't have real data — not the whole chart)
                let hadWorkout = log.contains {
                    (calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day ?? 99) == daysAgo
                } || cardioLog.contains {
                    (calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day ?? 99) == daysAgo
                } || generalLog.contains {
                    (calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day ?? 99) == daysAgo
                }
                runningEstimate = hadWorkout
                    ? min(runningEstimate + 4, 99)
                    : max(runningEstimate - 2, 30)
                val = runningEstimate
            }
            points.append(ReadinessState.TrendPoint(dayOffset: dayOffset, score: val))
        }
        return points
    }

    private static func trendLabel(trend: [ReadinessState.TrendPoint]) -> String {
        guard trend.count >= 7 else { return "Not enough data yet" }
        let first = trend.prefix(7).map(\.score).reduce(0, +) / 7
        let last  = trend.suffix(7).map(\.score).reduce(0, +) / 7
        let diff  = last - first
        if diff > 4  { return "Trending up · Past 14 days" }
        if diff < -4 { return "Trending down · Past 14 days" }
        return "Stable · Past 14 days"
    }

    private static func buildFactors(
        daysSinceLast: Int,
        freq: Int,
        volRatio: Double,
        log: [WorkoutLogEntry],
        cardioCount: Int = 0,
        generalCount: Int = 0,
        stepsToday: Int? = nil,
        sleepHours: Double? = nil,
        restingHR: Double? = nil,
        hrv: Double? = nil,
        hrvBaseline: Double? = nil,
        avgReadinessBefore: Double? = nil
    ) -> [ReadinessState.Factor] {
        var factors: [ReadinessState.Factor] = []

        if daysSinceLast == 1 || daysSinceLast == 2 {
            factors.append(.init(text: "Workout timing is dialled in", isPositive: true))
        } else if daysSinceLast > 5 {
            factors.append(.init(text: "Been a while since your last session", isPositive: false))
        }

        if freq >= 3 {
            var note = "Showing up consistently this week"
            if cardioCount > 0 && generalCount > 0 {
                note = "Showing up consistently — strength, cardio + activity this week"
            } else if cardioCount > 0 {
                note = "Showing up consistently — strength + cardio this week"
            } else if generalCount > 0 {
                note = "Showing up consistently — strength + general activity this week"
            }
            factors.append(.init(text: note, isPositive: true))
        } else if freq <= 1 {
            factors.append(.init(text: "Light week so far — might be feeling a bit rusty", isPositive: false))
        }

        if volRatio < 0.8 {
            factors.append(.init(text: "Lighter load than usual — body is getting a breather", isPositive: true))
        } else if volRatio > 1.4 {
            factors.append(.init(text: "Volume jumped up vs last week — watch for accumulated fatigue", isPositive: false))
        } else {
            factors.append(.init(text: "Volume has been well managed", isPositive: true))
        }

        // Step factor note (QA-12)
        if let steps = stepsToday {
            switch steps {
            case ..<3000:
                factors.append(.init(text: "Low step count today — consider a short walk", isPositive: false))
            case 7000...:
                factors.append(.init(text: "Active day — good non-exercise movement", isPositive: true))
            default:
                break  // neutral range: no factor added
            }
        }

        // Sleep factor
        if let sleep = sleepHours {
            if sleep >= 7.5 {
                factors.append(.init(text: String(format: "%.1f hours sleep — recovery optimised", sleep), isPositive: true))
            } else if sleep >= 7.0 {
                factors.append(.init(text: String(format: "%.1f hours sleep — solid night", sleep), isPositive: true))
            } else if sleep < 7.0 {
                factors.append(.init(text: String(format: "%.1f hours sleep — aim for 7–9 h for full recovery", sleep), isPositive: false))
            }
        }

        // HRV factor — personalized label when baseline is available
        if let hrv {
            let lowHRV    = hrvBaseline.map { $0 * 0.88 } ?? 55.0
            let normalHRV = hrvBaseline.map { $0 * 0.95 } ?? 65.0
            let baseTag   = hrvBaseline.map { " (your avg: \(Int($0)) ms)" } ?? ""
            if hrv < lowHRV {
                factors.append(.init(text: String(format: "HRV %.0f ms — below your normal range\(baseTag)", hrv), isPositive: false))
            } else if hrv >= normalHRV {
                factors.append(.init(text: String(format: "HRV %.0f ms — within your normal range\(baseTag)", hrv), isPositive: true))
            }
        }

        // Resting HR factor
        if let rhr = restingHR {
            if rhr < 55 {
                factors.append(.init(text: String(format: "Resting HR %.0f bpm — well-recovered", rhr), isPositive: true))
            } else if rhr >= 75 {
                factors.append(.init(text: String(format: "Resting HR %.0f bpm — elevated; possible fatigue or stress", rhr), isPositive: false))
            }
        }

        // readinessBefore factor — subjective pre-session state from recent workouts
        if let avg = avgReadinessBefore {
            if avg <= 1.3 {
                factors.append(.init(text: "You've been rating yourself Tired before recent sessions — chronic fatigue signal", isPositive: false))
            } else if avg >= 2.7 {
                factors.append(.init(text: "You've been feeling Strong before recent sessions", isPositive: true))
            }
        }

        let totalSessions = log.count + cardioCount + generalCount
        if totalSessions < 3 {
            factors.append(.init(text: "More sessions logged will sharpen this score", isPositive: false))
        } else {
            factors.append(.init(text: "Enough history to read your patterns reliably", isPositive: true))
        }

        return factors
    }
}
