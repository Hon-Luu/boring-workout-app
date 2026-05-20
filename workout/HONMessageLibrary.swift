import Foundation

enum HONMessageLibrary {

    // MARK: - Context

    struct MessageContext {
        var totalSessions: Int = 0
        var weeklyCount: Int = 0
        var consecutiveWeeks: Int = 0
        var daysGone: Int = 0
        var dayName: String = ""
        var confidence: Double = 0
        var rollingAvg: Double = 0
        var streakDays: Int = 0
    }

    // MARK: - Dispatch

    static func pick(
        kind: HONMessageKind,
        phase: HONPhase,
        userType: HONUserType,
        context: MessageContext,
        seed: Int
    ) -> (message: String, icon: String)? {
        switch kind {
        case .sessionMilestone:  return sessionMilestone(n: context.totalSessions, seed: seed)
        case .weeklyCount:       return weeklyCount(count: context.weeklyCount, seed: seed)
        case .consecutiveWeeks:  return consecutiveWeeks(n: context.consecutiveWeeks, seed: seed)
        case .returnAfterLapse:  return returnAfterLapse(daysGone: context.daysGone, seed: seed)
        case .patternFlag:       return patternFlag(dayName: context.dayName, confidence: context.confidence, seed: seed)
        case .rampDetection:     return rampDetection(count: context.weeklyCount, avg: context.rollingAvg, seed: seed)
        case .driftDetection:    return driftDetection(seed: seed)
        case .deloadDetection:   return deloadDetection(seed: seed)
        case .streakMilestone:   return streakMilestone(days: context.streakDays, seed: seed)
        case .specialMoment:     return specialMoment(seed: seed)
        }
    }

    // MARK: - Session Milestones

    static let milestoneValues = [1, 10, 25, 50, 100, 200, 365]

    private static func sessionMilestone(n: Int, seed: Int) -> (String, String)? {
        switch n {
        case 1:
            let pool = [
                "Session 1. Every consistent trainer started exactly here.",
                "One session logged. The habit doesn't exist yet — but the decision does.",
                "First one in the books. Now the only goal is to come back."
            ]
            return (pool[seed % pool.count], "1.circle")
        case 10:
            let pool = [
                "10 sessions in. You're past the drop-off point where most people quit.",
                "Session 10. Double digits — the habit is beginning to take shape.",
                "10 logged. The first stretch is the hardest. You're through it."
            ]
            return (pool[seed % pool.count], "trophy")
        case 25:
            let pool = [
                "25 sessions. A month's worth of consistent effort on the books.",
                "One in four people make it to 25. You're still here.",
                "Session 25. The habit is real — it just needs to become automatic."
            ]
            return (pool[seed % pool.count], "seal")
        case 50:
            let pool = [
                "50 sessions. Half a hundred. That's not a streak — that's a lifestyle forming.",
                "Session 50. Most habits are dead by now. This one kept going.",
                "50 in the books. The version of you that started this would be impressed."
            ]
            return (pool[seed % pool.count], "medal")
        case 100:
            let pool = [
                "100 sessions. Triple digits. Very few people get here.",
                "Session 100. One hundred deliberate choices to show up.",
                "100 logged. The data doesn't lie — this is who you are now."
            ]
            return (pool[seed % pool.count], "rosette")
        case 200:
            let pool = [
                "200 sessions. Two hundred times you chose the gym over everything else competing for that hour.",
                "Session 200. This isn't motivation anymore. This is identity.",
                "200 in. You've spent roughly 200 hours building a more durable version of yourself."
            ]
            return (pool[seed % pool.count], "star.circle")
        case 365:
            let pool = [
                "365 sessions. One for every day of the year.",
                "Session 365. A year's worth of effort, compressed into this number.",
                "365 logged. Some people try once a year. You showed up 365 times."
            ]
            return (pool[seed % pool.count], "crown")
        default:
            return nil
        }
    }

    // MARK: - Weekly Count

    private static func weeklyCount(count: Int, seed: Int) -> (String, String)? {
        guard count >= 2 else { return nil }
        switch count {
        case 2:
            let pool = [
                "Two sessions this week. The minimum for consistency is in place.",
                "Back twice this week. That's the floor — keep it there.",
                "Two in. You're in the game this week."
            ]
            return (pool[seed % pool.count], "2.circle")
        case 3:
            let pool = [
                "Three sessions this week. That's a training week.",
                "3 this week — you showed up more than most people will all month.",
                "Three in. This is what building looks like."
            ]
            return (pool[seed % pool.count], "3.circle")
        case 4:
            let pool = [
                "Four sessions this week. Four opportunities taken. Four excuses rejected.",
                "4 this week. Every day except recovery. That's disciplined.",
                "Four in. Most programs are designed for exactly this."
            ]
            return (pool[seed % pool.count], "4.circle")
        default:
            let pool = [
                "\(count) sessions this week. High-frequency week — make sure recovery keeps pace.",
                "\(count) in this week. The volume is there. Match it with sleep.",
                "\(count) sessions. That's a committed week. Note how you feel by Sunday."
            ]
            return (pool[seed % pool.count], "flame")
        }
    }

    // MARK: - Consecutive Weeks

    private static func consecutiveWeeks(n: Int, seed: Int) -> (String, String)? {
        guard n >= 2 else { return nil }
        switch n {
        case 2:
            let pool = [
                "Two weeks in a row with a session. The habit is starting to recognize you.",
                "Back-to-back weeks. Streaks start with two.",
                "Two consecutive training weeks. The pattern is forming."
            ]
            return (pool[seed % pool.count], "checkmark.circle")
        case 4:
            let pool = [
                "A full month of training weeks. \(n) in a row.",
                "Four consecutive weeks without missing. That's a month of consistency.",
                "Four weeks straight. The habit is establishing its territory."
            ]
            return (pool[seed % pool.count], "checkmark.seal")
        case 8:
            let pool = [
                "8 weeks in a row. Two months without a missed week.",
                "\(n) consecutive training weeks. That's not motivation — that's a system.",
                "Eight straight weeks. The foundation is solid."
            ]
            return (pool[seed % pool.count], "calendar.badge.checkmark")
        case 12:
            let pool = [
                "12 consecutive weeks. A quarter of the year, not one missed.",
                "Three months straight. The research says habits lock in around now.",
                "\(n) in a row. The habit is becoming automatic."
            ]
            return (pool[seed % pool.count], "medal")
        case 26:
            let pool = [
                "Half a year of unbroken training weeks. \(n) in a row.",
                "26 consecutive weeks. Half a year, no missed weeks. This is rare.",
                "\(n) weeks — half a year without a gap. That's extraordinary."
            ]
            return (pool[seed % pool.count], "rosette")
        case 52...:
            let pool = [
                "\(n) consecutive weeks. Over a year without missing one. That's a lifestyle.",
                "A year of unbroken training weeks. Most coaches never see this.",
                "\(n) straight weeks. There is no longer any doubt about who you are."
            ]
            return (pool[seed % pool.count], "crown")
        default:
            let pool = [
                "\(n) weeks in a row with at least one session. The chain is alive.",
                "\(n) consecutive training weeks. Keep it unbroken.",
                "Week \(n) in a row. Momentum is its own kind of fuel."
            ]
            return (pool[seed % pool.count], "checkmark.circle")
        }
    }

    // MARK: - Return After Lapse

    private static func returnAfterLapse(daysGone: Int, seed: Int) -> (String, String) {
        let weeks = max(1, daysGone / 7)
        if daysGone < 14 {
            let pool = [
                "You're back. \(daysGone) days off, and you chose to return. That's the skill.",
                "Back after \(daysGone) days. The gym didn't go anywhere. Neither did you.",
                "\(daysGone)-day break — now closed. The habit knows the way back."
            ]
            return (pool[seed % pool.count], "arrow.counterclockwise")
        } else if daysGone < 30 {
            let pool = [
                "\(weeks) weeks away. Coming back is harder than it looks — you did it anyway.",
                "Two weeks off, and you walked back in. That's not easy. Most don't.",
                "Life interrupted. You un-paused it. This is session 1 again — the good kind."
            ]
            return (pool[seed % pool.count], "arrow.counterclockwise")
        } else if daysGone < 90 {
            let pool = [
                "\(weeks) weeks away. The muscle memory is still there — it's been waiting.",
                "A month or more gone. Most comebacks never happen. Yours did.",
                "Back after \(weeks) weeks. Start easy. Strength returns faster than you think."
            ]
            return (pool[seed % pool.count], "arrow.counterclockwise.circle")
        } else {
            let pool = [
                "It's been a while — \(weeks) weeks. This session is the most important one you'll log all year.",
                "Back after \(weeks) weeks. The gym never locks you out. You're in.",
                "\(weeks) weeks between sessions. Doesn't matter. You're here now. That's the only fact that counts."
            ]
            return (pool[seed % pool.count], "figure.walk")
        }
    }

    // MARK: - Pattern Flag

    private static func patternFlag(dayName: String, confidence: Double, seed: Int) -> (String, String) {
        let pct = Int(confidence * 100)
        let pool = [
            "\(dayName) is your day. You show up here \(pct)% of the time. Reliable.",
            "Pattern confirmed: \(dayName) is when you train. The habit has a schedule now.",
            "You've made \(dayName) yours — \(pct)% consistency on this day."
        ]
        return (pool[seed % pool.count], "calendar.badge.clock")
    }

    // MARK: - Ramp Detection

    private static func rampDetection(count: Int, avg: Double, seed: Int) -> (String, String) {
        let pool = [
            "\(count) sessions this week — well above your \(String(format: "%.1f", avg)) average. High-volume weeks are great; recovery keeps pace with them.",
            "Ramping up: \(count) this week vs your \(String(format: "%.1f", avg)) average. The effort is there — protect the sleep.",
            "Big week with \(count) sessions. Your baseline is \(String(format: "%.1f", avg)). Follow this with a normal week, not another surge."
        ]
        return (pool[seed % pool.count], "flame.fill")
    }

    // MARK: - Drift Detection

    private static func driftDetection(seed: Int) -> (String, String) {
        let pool = [
            "Volume is down the last two weeks. Schedules shift — one session resets the direction.",
            "Fewer sessions than your usual pace lately. The habit isn't gone — it's waiting.",
            "Two quieter weeks in a row. This is where habits either reset or disappear. One session makes the difference."
        ]
        return (pool[seed % pool.count], "arrow.down.circle")
    }

    // MARK: - Deload Detection

    private static func deloadDetection(seed: Int) -> (String, String) {
        let pool = [
            "Light week by the numbers — intentional or not, the body needed it. Show up next week.",
            "Lower volume than your recent average. Good. Deloads are part of the plan.",
            "Easy week logged. Recovery is training. Come back ready next week."
        ]
        return (pool[seed % pool.count], "zzz")
    }

    // MARK: - Streak Milestones

    private static func streakMilestone(days: Int, seed: Int) -> (String, String) {
        switch days {
        case 7:
            let pool = [
                "7-day streak. One full week of showing up every day.",
                "A week straight. Seven for seven.",
                "7 days in a row. The week didn't break the chain."
            ]
            return (pool[seed % pool.count], "flame")
        case 30:
            let pool = [
                "30-day streak. A full month without missing.",
                "30 in a row. Most months have a reason to skip. You didn't take it.",
                "Month-long streak. Thirty days of showing up."
            ]
            return (pool[seed % pool.count], "flame.fill")
        case 100:
            let pool = [
                "100-day streak. Triple digits. This one is genuinely rare.",
                "100 days in a row. One hundred. Most people never get here.",
                "Day 100. The three-digit streak. You're in a very small group."
            ]
            return (pool[seed % pool.count], "crown")
        default:
            let pool = [
                "\(days)-day streak. The chain keeps going.",
                "\(days) days in a row and counting.",
                "Day \(days). Still here, still logging."
            ]
            return (pool[seed % pool.count], "flame")
        }
    }

    // MARK: - Special Moment

    private static func specialMoment(seed: Int) -> (String, String) {
        let pool = [
            "Something's different about today's session. Noted.",
            "This one goes in the record.",
            "Sessions like this are the ones you remember."
        ]
        return (pool[seed % pool.count], "star")
    }
}
