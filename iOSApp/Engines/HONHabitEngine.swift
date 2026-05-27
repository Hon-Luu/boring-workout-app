import Foundation
import Observation

@Observable
final class HONHabitEngine {

    // MARK: - State

    var userRecord = HONUserRecord()
    var inAppMessage: HONPendingMessage? = nil

    private let recordKey = "hon_user_record_v1"

    // MARK: - Init

    init() { load() }

    // MARK: - Session Hook (called from WorkoutTabView on new strength session)

    func onSessionLogged(entry: WorkoutLogEntry, fullLog: [WorkoutLogEntry],
                         cardioLog: [CardioLogEntry] = [], generalLog: [GeneralActivityEntry] = []) {
        guard entry.id != userRecord.lastProcessedSessionId else { return }
        userRecord.lastProcessedSessionId = entry.id

        rebuildRecord(from: fullLog, cardioLog: cardioLog, generalLog: generalLog)
        let messages = generateMessages(for: entry, log: fullLog)
        enqueue(messages)
        if let next = nextUndelivered() {
            HONMessageScheduler.schedule(message: next)
        }
        save()
    }

    // MARK: - Cross-Modal Hook (called after cardio or general activity is saved)

    func onAnyActivityLogged(strengthLog: [WorkoutLogEntry],
                              cardioLog: [CardioLogEntry],
                              generalLog: [GeneralActivityEntry]) {
        rebuildRecord(from: strengthLog, cardioLog: cardioLog, generalLog: generalLog)
        save()
    }

    // MARK: - Weekly Check (call on app foreground)

    func checkForDriftOrDeload() {
        // Run at most once per calendar day so dismissing the banner is permanent until tomorrow
        let cal = Calendar.current
        if cal.isDateInToday(userRecord.lastDriftDeloadCheckDate) { return }
        guard !userRecord.weekRecords.isEmpty else { return }
        var messages: [HONPendingMessage] = []
        let phase    = userRecord.phase
        let userType = userRecord.userType
        let seed     = userRecord.totalSessions

        if HONPatternEngine.isDrifting(weekRecords: userRecord.weekRecords) {
            var driftCtx = HONMessageLibrary.MessageContext()
            driftCtx.driftCategoryName = userRecord.dominantMovementCategory
            if let (msg, icon) = HONMessageLibrary.pick(
                kind: .driftDetection, phase: phase, userType: userType,
                context: driftCtx, seed: seed
            ) {
                messages.append(HONPendingMessage(kind: .driftDetection, message: msg, icon: icon))
            }
        }

        if let lastWeek = userRecord.weekRecords.last {
            if HONPatternEngine.isDeloading(
                currentWeekVolume: lastWeek.totalVolume,
                weekRecords: userRecord.weekRecords
            ) {
                if let (msg, icon) = HONMessageLibrary.pick(
                    kind: .deloadDetection, phase: phase, userType: userType,
                    context: HONMessageLibrary.MessageContext(), seed: seed
                ) {
                    messages.append(HONPendingMessage(kind: .deloadDetection, message: msg, icon: icon))
                }
            }
        }

        userRecord.lastDriftDeloadCheckDate = Date()
        enqueue(messages)
        save()
    }

    // MARK: - In-App Delivery

    func dismissInAppMessage() {
        // Mark all pending messages as delivered at once so the banner doesn't chain
        let now = Date()
        for i in userRecord.pendingMessages.indices where userRecord.pendingMessages[i].deliveredAt == nil {
            userRecord.pendingMessages[i].deliveredAt = now
        }
        inAppMessage = nil
        save()
    }

    // MARK: - Debug / Reset

    func resetForDebug() {
        userRecord = HONUserRecord()
        inAppMessage = nil
        UserDefaults.standard.removeObject(forKey: recordKey)
    }

    func simulateLog(entries: [WorkoutLogEntry]) {
        guard let last = entries.max(by: { $0.startedAt < $1.startedAt }) else { return }
        userRecord.lastProcessedSessionId = nil
        onSessionLogged(entry: last, fullLog: entries)
    }

    // MARK: - Record Rebuild

    private func rebuildRecord(from log: [WorkoutLogEntry],
                               cardioLog: [CardioLogEntry] = [],
                               generalLog: [GeneralActivityEntry] = []) {
        // Determine first-ever session date across all modalities
        let allDates: [Date] = log.map(\.startedAt) + cardioLog.map(\.startedAt) + generalLog.map(\.startedAt)
        guard let firstDate = allDates.min() else { return }
        let now = Date()
        let cal = Calendar.current

        userRecord.ageWeeks = Int(now.timeIntervalSince(firstDate) / (7 * 86_400))
        userRecord.phase    = HONPhase.from(ageWeeks: userRecord.ageWeeks)
        userRecord.totalSessions = log.count + cardioLog.count + generalLog.count

        // Build week records from first Monday through current Monday — all modalities
        var records: [HONWeekRecord] = []
        var cursor = mondayOf(firstDate)
        let thisMonday = mondayOf(now)
        while cursor <= thisMonday {
            records.append(HONWeekRecord(weekStart: cursor, strengthLog: log,
                                         cardioLog: cardioLog, generalLog: generalLog))
            cursor = cal.date(byAdding: .day, value: 7, to: cursor)!
        }
        userRecord.weekRecords = records
        userRecord.activeWeeks = records.filter { $0.sessionCount > 0 }.count

        // Pattern
        userRecord.dayProbabilities   = HONPatternEngine.computeDayProbabilities(weekRecords: records)
        userRecord.patternConfidence  = HONPatternEngine.computeConfidence(probabilities: userRecord.dayProbabilities)
        userRecord.userType           = HONPatternEngine.detectUserType(confidence: userRecord.patternConfidence)
        userRecord.consecutiveActiveWeeks = HONPatternEngine.computeConsecutiveActiveWeeks(weekRecords: records)

        // Lapse detection — use most recent activity across all modalities
        let sortedAll = allDates.sorted(by: >)
        if let mostRecent = sortedAll.first {
            let gap = now.timeIntervalSince(mostRecent) / 86_400
            userRecord.lapseStart = gap >= 6 ? mostRecent : nil
        } else {
            userRecord.lapseStart = nil
        }

        // Compute dominant movement category from the full log (for drift messages)
        userRecord.dominantMovementCategory = {
            var counts: [String: Int] = [:]
            for entry in log {
                for we in entry.exercises {
                    let label = we.exercise.movementPattern.rawValue
                    counts[label, default: 0] += 1
                }
            }
            return counts.max(by: { $0.value < $1.value })?.key ?? ""
        }()

        userRecord.lastUpdated = now
    }

    // MARK: - Message Generation

    private func generateMessages(for entry: WorkoutLogEntry, log: [WorkoutLogEntry]) -> [HONPendingMessage] {
        var messages: [HONPendingMessage] = []
        let seed     = log.count
        let phase    = userRecord.phase
        let userType = userRecord.userType

        // 1. Return after lapse (highest priority if applicable)
        let sortedLog = log.sorted { $0.startedAt < $1.startedAt }
        if sortedLog.count >= 2 {
            let prev = sortedLog[sortedLog.count - 2]
            let gap  = Int(entry.startedAt.timeIntervalSince(prev.startedAt) / 86_400)
            if gap >= 6 {
                var ctx = HONMessageLibrary.MessageContext()
                ctx.daysGone = gap
                ctx.lastExerciseName = entry.exercises.first?.exercise.name ?? ""
                if let (msg, icon) = HONMessageLibrary.pick(kind: .returnAfterLapse, phase: phase, userType: userType, context: ctx, seed: seed) {
                    messages.append(HONPendingMessage(kind: .returnAfterLapse, message: msg, icon: icon))
                }
            }
        }

        // 2. Session milestone
        let n = userRecord.totalSessions
        if HONMessageLibrary.milestoneValues.contains(n) && !userRecord.shownSessionMilestones.contains(n) {
            userRecord.shownSessionMilestones.append(n)
            var ctx = HONMessageLibrary.MessageContext(); ctx.totalSessions = n
            if let (msg, icon) = HONMessageLibrary.pick(kind: .sessionMilestone, phase: phase, userType: userType, context: ctx, seed: seed) {
                messages.append(HONPendingMessage(kind: .sessionMilestone, message: msg, icon: icon))
            }
        }

        // 3. Weekly count (fires when ≥2 sessions in current week)
        let thisWeekCount = weeklyCount(for: entry.startedAt, log: log)
        if thisWeekCount >= 2 {
            var ctx = HONMessageLibrary.MessageContext(); ctx.weeklyCount = thisWeekCount
            if let (msg, icon) = HONMessageLibrary.pick(kind: .weeklyCount, phase: phase, userType: userType, context: ctx, seed: seed) {
                messages.append(HONPendingMessage(kind: .weeklyCount, message: msg, icon: icon))
            }
        }

        // 4. Consecutive weeks milestone
        let cw = userRecord.consecutiveActiveWeeks
        let cwMilestones = [2, 4, 8, 12, 26, 52]
        if cwMilestones.contains(cw) && !userRecord.shownConsecutiveWeekMilestones.contains(cw) {
            userRecord.shownConsecutiveWeekMilestones.append(cw)
            var ctx = HONMessageLibrary.MessageContext(); ctx.consecutiveWeeks = cw
            if let (msg, icon) = HONMessageLibrary.pick(kind: .consecutiveWeeks, phase: phase, userType: userType, context: ctx, seed: seed) {
                messages.append(HONPendingMessage(kind: .consecutiveWeeks, message: msg, icon: icon))
            }
        }

        // 5. Pattern flag — Type A, high confidence, not shown in past 4 weeks
        if userType == .typeA
            && HONPatternEngine.isHighConfidence(confidence: userRecord.patternConfidence, activeWeeks: userRecord.activeWeeks) {
            let fourWeeksAgo = Date().addingTimeInterval(-28 * 86_400)
            let canShow = userRecord.lastPatternFlagDate.map { $0 < fourWeeksAgo } ?? true
            if canShow {
                let cal = Calendar.current
                let wd  = cal.component(.weekday, from: entry.startedAt)
                let idx = (wd + 5) % 7
                if let prob = userRecord.dayProbabilities.first(where: { $0.dayIndex == idx }),
                   prob.probability >= 0.80 {
                    var ctx = HONMessageLibrary.MessageContext()
                    ctx.dayName = prob.dayName; ctx.confidence = prob.probability
                    if let (msg, icon) = HONMessageLibrary.pick(kind: .patternFlag, phase: phase, userType: userType, context: ctx, seed: seed) {
                        messages.append(HONPendingMessage(kind: .patternFlag, message: msg, icon: icon))
                        userRecord.lastPatternFlagDate = Date()
                    }
                }
            }
        }

        // 6. Ramp detection
        let priorRecords = Array(userRecord.weekRecords.dropLast())
        if HONPatternEngine.isRamping(currentWeekSessions: thisWeekCount, weekRecords: priorRecords) {
            var ctx = HONMessageLibrary.MessageContext()
            ctx.weeklyCount = thisWeekCount
            ctx.rollingAvg  = HONPatternEngine.rollingAverageSessionsPerWeek(weekRecords: priorRecords)
            if let (msg, icon) = HONMessageLibrary.pick(kind: .rampDetection, phase: phase, userType: userType, context: ctx, seed: seed) {
                messages.append(HONPendingMessage(kind: .rampDetection, message: msg, icon: icon))
            }
        }

        return messages
    }

    // MARK: - Queue Helpers

    private func enqueue(_ messages: [HONPendingMessage]) {
        userRecord.pendingMessages.append(contentsOf: messages)
        if inAppMessage == nil {
            inAppMessage = nextUndelivered()
        }
    }

    private func nextUndelivered() -> HONPendingMessage? {
        userRecord.pendingMessages.first { $0.deliveredAt == nil }
    }

    // MARK: - Date Helpers

    private func mondayOf(_ date: Date) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let wd    = cal.component(.weekday, from: start)
        let delta = (wd + 5) % 7
        return cal.date(byAdding: .day, value: -delta, to: start)!
    }

    private func weeklyCount(for date: Date, log: [WorkoutLogEntry]) -> Int {
        let start = mondayOf(date)
        let end   = start.addingTimeInterval(7 * 86_400)
        return log.filter { $0.startedAt >= start && $0.startedAt < end }.count
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(userRecord) else { return }
        UserDefaults.standard.set(data, forKey: recordKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: recordKey),
              let record = try? JSONDecoder().decode(HONUserRecord.self, from: data)
        else { return }
        userRecord = record
        // Don't auto-surface banners on load — only show after a workout session is logged
    }
}
