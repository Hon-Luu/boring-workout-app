import Foundation

// MARK: - Phase

enum HONPhase: String, Codable, CaseIterable {
    case newUser      = "new_user"       // weeks 1–6
    case forming      = "forming"        // weeks 7–12
    case establishing = "establishing"   // weeks 13–26
    case established  = "established"    // weeks 27+

    static func from(ageWeeks: Int) -> HONPhase {
        switch ageWeeks {
        case ..<7:   return .newUser
        case 7..<13: return .forming
        case 13..<27: return .establishing
        default:     return .established
        }
    }

    var displayName: String {
        switch self {
        case .newUser:      return "New User (wks 1–6)"
        case .forming:      return "Forming (wks 7–12)"
        case .establishing: return "Establishing (wks 13–26)"
        case .established:  return "Established (wks 27+)"
        }
    }
}

// MARK: - User Type

enum HONUserType: String, Codable, CaseIterable {
    case typeA = "type_a"   // consistent/scheduled — predictable days, high pattern confidence
    case typeB = "type_b"   // flexible/spontaneous — varied schedule, lower confidence

    var displayName: String {
        switch self {
        case .typeA: return "Scheduled Trainer"
        case .typeB: return "Flexible Trainer"
        }
    }
}

// MARK: - Message Kind

enum HONMessageKind: String, Codable, CaseIterable {
    case sessionMilestone   // 1st, 10th, 25th, 50th, 100th, 200th, 365th session
    case weeklyCount        // multiple sessions in a week (≥2)
    case consecutiveWeeks   // N weeks in a row with ≥1 session
    case returnAfterLapse   // comeback after 7+ day gap
    case patternFlag        // training on your typical scheduled day
    case rampDetection      // significantly more sessions than usual
    case driftDetection     // sessions dropping below baseline
    case deloadDetection    // lighter volume week after heavy stretch
    case streakMilestone    // 7, 30, 100+ consecutive days
    case specialMoment      // rare / situational achievements

    var displayName: String {
        switch self {
        case .sessionMilestone:  return "Session Milestone"
        case .weeklyCount:       return "Weekly Count"
        case .consecutiveWeeks:  return "Consecutive Weeks"
        case .returnAfterLapse:  return "Return After Lapse"
        case .patternFlag:       return "Pattern Flag"
        case .rampDetection:     return "Ramp Detection"
        case .driftDetection:    return "Drift Detection"
        case .deloadDetection:   return "Deload Detection"
        case .streakMilestone:   return "Streak Milestone"
        case .specialMoment:     return "Special Moment"
        }
    }
}

// MARK: - Day Probability

struct HONDayProbability: Codable {
    let dayIndex: Int         // 0=Mon, 1=Tue, … 6=Sun
    let probability: Double   // fraction of rolling-window weeks that had a session on this day

    var dayName: String { ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][dayIndex] }
}

// MARK: - Week Record

struct HONWeekRecord: Codable {
    let weekStart: Date          // Monday midnight (local)
    let sessionCount: Int
    let sessionDays: [Int]       // 0=Mon..6=Sun
    let totalVolume: Double      // kg

    init(weekStart: Date, log: [WorkoutLogEntry]) {
        self.weekStart = weekStart
        let weekEnd = weekStart.addingTimeInterval(7 * 86_400)
        let week = log.filter { $0.startedAt >= weekStart && $0.startedAt < weekEnd }
        self.sessionCount = week.count
        let cal = Calendar.current
        self.sessionDays = Array(Set(week.map { e -> Int in
            let wd = cal.component(.weekday, from: e.startedAt)
            return (wd + 5) % 7
        })).sorted()
        self.totalVolume = week.reduce(0) { $0 + $1.totalVolume }
    }

    /// Multi-modal init: counts strength + cardio + general sessions in the week.
    init(weekStart: Date, strengthLog: [WorkoutLogEntry],
         cardioLog: [CardioLogEntry], generalLog: [GeneralActivityEntry]) {
        self.weekStart = weekStart
        let weekEnd = weekStart.addingTimeInterval(7 * 86_400)
        let cal = Calendar.current
        let wkStrength = strengthLog.filter { $0.startedAt >= weekStart && $0.startedAt < weekEnd }
        let wkCardio   = cardioLog.filter   { $0.startedAt >= weekStart && $0.startedAt < weekEnd }
        let wkGeneral  = generalLog.filter  { $0.startedAt >= weekStart && $0.startedAt < weekEnd }
        self.sessionCount = wkStrength.count + wkCardio.count + wkGeneral.count
        var days = Set<Int>()
        for e in wkStrength { days.insert((cal.component(.weekday, from: e.startedAt) + 5) % 7) }
        for e in wkCardio   { days.insert((cal.component(.weekday, from: e.startedAt) + 5) % 7) }
        for e in wkGeneral  { days.insert((cal.component(.weekday, from: e.startedAt) + 5) % 7) }
        self.sessionDays = days.sorted()
        self.totalVolume = wkStrength.reduce(0) { $0 + $1.totalVolume }
    }
}

// MARK: - Pending Message

struct HONPendingMessage: Codable, Identifiable {
    let id: UUID
    let kind: HONMessageKind
    let message: String
    let icon: String             // SF Symbol name
    let createdAt: Date
    var deliveredAt: Date?

    init(kind: HONMessageKind, message: String, icon: String) {
        self.id = UUID()
        self.kind = kind
        self.message = message
        self.icon = icon
        self.createdAt = Date()
        self.deliveredAt = nil
    }
}

// MARK: - User Record

struct HONUserRecord: Codable {
    var totalSessions: Int = 0
    var ageWeeks: Int = 0                          // weeks since first session
    var activeWeeks: Int = 0                       // weeks with ≥1 session
    var consecutiveActiveWeeks: Int = 0
    var weekRecords: [HONWeekRecord] = []
    var dayProbabilities: [HONDayProbability] = []
    var patternConfidence: Double = 0.0
    var userType: HONUserType = .typeB
    var phase: HONPhase = .newUser
    var lapseStart: Date? = nil
    var lastProcessedSessionId: UUID? = nil
    var pendingMessages: [HONPendingMessage] = []
    var shownSessionMilestones: [Int] = []
    var shownConsecutiveWeekMilestones: [Int] = []
    var lastPatternFlagDate: Date? = nil
    var lastDriftDeloadCheckDate: Date = .distantPast
    var lastUpdated: Date = .distantPast
}
