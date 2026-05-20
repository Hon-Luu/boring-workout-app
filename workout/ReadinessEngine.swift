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

    /// Computes a readiness state purely from workout log data (no HealthKit required).
    static func compute(log: [WorkoutLogEntry]) -> ReadinessState {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // --- Days since last workout ---
        let daysSinceLast: Int = {
            guard let last = log.first else { return 99 }
            return calendar.dateComponents([.day], from: calendar.startOfDay(for: last.startedAt), to: today).day ?? 99
        }()

        // --- Workouts in last 7 days ---
        let recentWorkouts = log.filter {
            guard let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day else { return false }
            return days <= 7
        }

        // --- Volume trend (last 7 vs prior 7) ---
        let vol7 = recentWorkouts.reduce(0.0) { $0 + $1.totalVolume }
        let prior7 = log.filter {
            guard let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day else { return false }
            return days > 7 && days <= 14
        }.reduce(0.0) { $0 + $1.totalVolume }

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

        let freq = recentWorkouts.count
        if freq >= 4 { score += 5 } else if freq <= 1 { score -= 8 }

        if vol7 > 0 && prior7 > 0 {
            let ratio = vol7 / prior7
            if ratio < 0.7 { score += 6 }       // deload week
            else if ratio > 1.5 { score -= 6 }   // big spike
        }

        score = max(20, min(99, score))

        // --- 30-day baseline ---
        let baseline = computeBaseline(log: log, calendar: calendar, today: today)
        let delta = score - baseline

        // --- Confidence (based on data richness) ---
        let confidence: ReadinessState.Confidence = log.count >= 10 ? .high : log.count >= 3 ? .medium : .low

        // --- Narrative ---
        let (headline, subtitle, coachingNote) = narrative(score: score, delta: delta, daysSinceLast: daysSinceLast, freq: freq)

        // --- Trend (14 days) ---
        let trend = buildTrend(log: log, calendar: calendar, today: today, todayScore: Double(score))

        // --- Factors ---
        let factors = buildFactors(daysSinceLast: daysSinceLast, freq: freq, volRatio: prior7 > 0 ? vol7 / prior7 : 1.0, log: log)

        return ReadinessState(
            score: score,
            confidence: confidence,
            deltaFromBaseline: delta,
            headline: headline,
            subtitle: subtitle,
            coachingNote: coachingNote,
            trendLabel: trendLabel(trend: trend),
            trendData: trend,
            factors: factors
        )
    }

    // MARK: - Helpers

    private static func computeBaseline(log: [WorkoutLogEntry], calendar: Calendar, today: Date) -> Int {
        let last30 = log.filter {
            (calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day ?? 99) <= 30
        }
        guard !last30.isEmpty else { return 65 }
        return 65 + min(15, last30.count)
    }

    private static func narrative(score: Int, delta: Int, daysSinceLast: Int, freq: Int)
        -> (headline: String, subtitle: String, coachingNote: String)
    {
        switch score {
        case 80...:
            return (
                "Good momentum right now.",
                "Recovery is stacking up.",
                "You've been recovering well and the momentum is there. Don't hold back today — this is the kind of day you make progress on."
            )
        case 65..<80:
            return (
                "Ready to train.",
                "Nothing in the way today.",
                "Body feels balanced and you're in a good rhythm. Get your work in, stay focused, keep the streak alive."
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

    private static func buildTrend(log: [WorkoutLogEntry], calendar: Calendar, today: Date, todayScore: Double) -> [ReadinessState.TrendPoint] {
        var points: [ReadinessState.TrendPoint] = []
        var baseVal = max(todayScore - 8, 40.0)

        for i in 0..<14 {
            let dayOffset = i
            let daysAgo = 13 - i

            // Check if there was a workout on this day
            let hadWorkout = log.contains {
                (calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.startedAt), to: today).day ?? 99) == daysAgo
            }

            if hadWorkout { baseVal = min(baseVal + 4, 99) } else { baseVal = max(baseVal - 2, 30) }
            let val = dayOffset == 13 ? todayScore : max(30, min(99, baseVal))
            points.append(ReadinessState.TrendPoint(dayOffset: dayOffset, score: val))
        }
        return points
    }

    private static func trendLabel(trend: [ReadinessState.TrendPoint]) -> String {
        guard trend.count >= 7 else { return "Not enough data yet" }
        let first = trend.prefix(7).map(\.score).reduce(0, +) / 7
        let last  = trend.suffix(7).map(\.score).reduce(0, +) / 7
        let diff  = last - first
        if diff > 4  { return "Gradual upward slope · Past 14 days" }
        if diff < -4 { return "Gradual downward slope · Past 14 days" }
        return "Relatively stable · Past 14 days"
    }

    private static func buildFactors(daysSinceLast: Int, freq: Int, volRatio: Double, log: [WorkoutLogEntry]) -> [ReadinessState.Factor] {
        var factors: [ReadinessState.Factor] = []

        if daysSinceLast == 1 || daysSinceLast == 2 {
            factors.append(.init(text: "Workout timing is dialled in", isPositive: true))
        } else if daysSinceLast > 5 {
            factors.append(.init(text: "Been a while since your last session", isPositive: false))
        }

        if freq >= 3 {
            factors.append(.init(text: "Showing up consistently this week", isPositive: true))
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

        if log.count < 3 {
            factors.append(.init(text: "More sessions logged will sharpen this score", isPositive: false))
        } else {
            factors.append(.init(text: "Enough history to read your patterns reliably", isPositive: true))
        }

        return factors
    }
}
