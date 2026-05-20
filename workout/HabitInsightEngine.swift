import Foundation

// MARK: - Types

enum HabitTimeFrame {
    case weekly, monthly, quarterly, halfYear, annual
    var label: String {
        switch self {
        case .weekly:    return "this week"
        case .monthly:   return "this month"
        case .quarterly: return "this quarter"
        case .halfYear:  return "this half-year"
        case .annual:    return "this year"
        }
    }
}

enum HabitTrend {
    case newlyStarted   // first period, no prior baseline (true first-timer)
    case reactivated    // returning after a gap — has prior history
    case building       // current period clearly ahead of prior
    case consistent     // current ≈ prior (within ±15%)
    case recovering     // current < prior but not zero — came back
    case slipping       // nothing or very little in current period
}

struct HabitInsight {
    let timeFrame: HabitTimeFrame
    let trend: HabitTrend
    let message: String
    let icon: String            // SF Symbol name
    let currentCount: Int       // sessions in current period
    let priorCount: Int         // sessions in prior period
}

// MARK: - Engine

enum HabitInsightEngine {

    static func analyze(log: [WorkoutLogEntry], cardioLog: [CardioLogEntry] = []) -> HabitInsight? {
        let allDates = log.map(\.startedAt) + cardioLog.map(\.startedAt)
        guard !allDates.isEmpty else { return nil }

        guard let first = allDates.min() else { return nil }
        let ageWeeks = Int(Date().timeIntervalSince(first) / (7 * 86_400))

        // All time frames the user has enough history to evaluate
        let allFrames: [HabitTimeFrame] = [.weekly, .monthly, .quarterly, .halfYear, .annual]
        let applicable = allFrames.filter { isApplicable($0, ageWeeks: ageWeeks) }

        // Evaluate every frame up front
        typealias Candidate = (frame: HabitTimeFrame, current: Int, prior: Int, trend: HabitTrend)
        let candidates: [Candidate] = applicable.map { frame in
            let (current, prior) = sessionCounts(for: frame, dates: allDates)
            return (frame, current, prior, computeTrend(current: current, prior: prior))
        }

        // Selection priority — shortest frame wins within each tier so recent wins surface first:
        // 1. building   — celebrate the recent uptick
        // 2. slipping   — timely nudge (nothing logged yet in the period)
        // 3. recovering — acknowledge the comeback
        // 4. longest consistent / newlyStarted — big-picture story when everything is stable
        let selected: Candidate =
            candidates.first(where: { $0.trend == .building })    ??
            candidates.first(where: { $0.trend == .slipping })    ??
            candidates.first(where: { $0.trend == .recovering })  ??
            candidates.last!   // longest applicable frame — consistent or newlyStarted

        // Override newlyStarted → reactivated when the user has prior sessions outside the current window
        let resolvedTrend: HabitTrend
        if selected.trend == .newlyStarted && allDates.count > selected.current {
            resolvedTrend = .reactivated
        } else {
            resolvedTrend = selected.trend
        }

        let (message, icon) = copy(
            frame: selected.frame, trend: resolvedTrend,
            current: selected.current, prior: selected.prior, seed: allDates.count
        )

        return HabitInsight(
            timeFrame: selected.frame,
            trend: resolvedTrend,
            message: message,
            icon: icon,
            currentCount: selected.current,
            priorCount: selected.prior
        )
    }

    // MARK: - Applicability

    private static func isApplicable(_ frame: HabitTimeFrame, ageWeeks: Int) -> Bool {
        switch frame {
        case .weekly:    return true
        case .monthly:   return ageWeeks >= 4
        case .quarterly: return ageWeeks >= 13
        case .halfYear:  return ageWeeks >= 26
        case .annual:    return ageWeeks >= 52
        }
    }

    // MARK: - Trend computation

    private static func computeTrend(current: Int, prior: Int) -> HabitTrend {
        if prior == 0 && current > 0  { return .newlyStarted }
        if current == 0               { return .slipping }
        let ratio = Double(current) / Double(max(prior, 1))
        if ratio >= 1.15              { return .building }
        if ratio >= 0.85              { return .consistent }
        return .recovering
    }

    // MARK: - Period session counts

    private static func sessionCounts(for frame: HabitTimeFrame, dates: [Date]) -> (current: Int, prior: Int) {
        let cal = Calendar.current
        let now = Date()

        switch frame {

        case .weekly:
            let todayStart    = cal.startOfDay(for: now)
            let daysFromMon   = (cal.component(.weekday, from: todayStart) + 5) % 7
            let thisWeekStart = cal.date(byAdding: .day, value: -daysFromMon, to: todayStart)!
            let lastWeekStart = cal.date(byAdding: .day, value: -7, to: thisWeekStart)!
            let current = dates.filter { $0 >= thisWeekStart }.count
            let prior   = dates.filter { $0 >= lastWeekStart && $0 < thisWeekStart }.count
            return (current, prior)

        case .monthly:
            let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let lastMonthStart = cal.date(byAdding: .month, value: -1, to: thisMonthStart)!
            let current = dates.filter { $0 >= thisMonthStart }.count
            let prior   = dates.filter { $0 >= lastMonthStart && $0 < thisMonthStart }.count
            return (current, prior)

        case .quarterly:
            let q0 = now.addingTimeInterval(-90 * 86_400)
            let q1 = now.addingTimeInterval(-180 * 86_400)
            let current = dates.filter { $0 >= q0 }.count
            let prior   = dates.filter { $0 >= q1 && $0 < q0 }.count
            return (current, prior)

        case .halfYear:
            let h0 = now.addingTimeInterval(-183 * 86_400)
            let h1 = now.addingTimeInterval(-366 * 86_400)
            let current = dates.filter { $0 >= h0 }.count
            let prior   = dates.filter { $0 >= h1 && $0 < h0 }.count
            return (current, prior)

        case .annual:
            let thisYearStart = cal.date(from: cal.dateComponents([.year], from: now))!
            let lastYearStart = cal.date(byAdding: .year, value: -1, to: thisYearStart)!
            let current = dates.filter { $0 >= thisYearStart }.count
            let prior   = dates.filter { $0 >= lastYearStart && $0 < thisYearStart }.count
            return (current, prior)
        }
    }

    // MARK: - Message copy

    private static func copy(
        frame: HabitTimeFrame,
        trend: HabitTrend,
        current: Int,
        prior: Int,
        seed: Int
    ) -> (message: String, icon: String) {

        switch (frame, trend) {

        // ── WEEKLY ─────────────────────────────────────────────────────────

        case (.weekly, .newlyStarted):
            let pool = [
                "Session 1 done. The most important thing you can do this week is come back.",
                "You showed up. That's the whole first chapter.",
                "Week one. Every consistent trainer you admire started with this exact session."
            ]
            return (pool[seed % pool.count], "figure.walk")

        case (.weekly, .reactivated):
            let pool = [
                "Back this week after a break. The hardest session is always the return one.",
                "You're back. The gap is closed — what matters now is the next one.",
                "Returning is the hardest rep. You logged it."
            ]
            return (pool[seed % pool.count], "arrow.counterclockwise.circle")

        case (.weekly, .building):
            let pool = [
                "\(current) sessions this week vs \(prior) last — the habit is moving.",
                "More this week than last. Small deltas compound into real momentum.",
                "Up from \(prior) to \(current) sessions this week. That's the pattern forming."
            ]
            return (pool[seed % pool.count], "arrow.up.right")

        case (.weekly, .consistent):
            let pool = [
                "\(current) sessions this week, same rhythm as last. Boring is underrated.",
                "Showing up at the same pace as last week. Consistency is the rarest trait in a gym.",
                "Back again. Same week, same effort. That's how habits become identity."
            ]
            return (pool[seed % pool.count], "checkmark.circle")

        case (.weekly, .recovering):
            let pool = [
                "\(current) session\(current == 1 ? "" : "s") this week — that's the comeback. Last week is over.",
                "Life interrupted last week. You're back. That's all that matters.",
                "Fewer than last week, but you're still here. Returning is the skill."
            ]
            return (pool[seed % pool.count], "arrow.counterclockwise")

        case (.weekly, .slipping):
            let pool = [
                "Nothing logged yet this week. One session changes that.",
                "The week isn't over. Even 30 minutes today counts.",
                "No sessions this week yet. The habit remembers — one session gets it back."
            ]
            return (pool[seed % pool.count], "calendar")

        // ── MONTHLY ────────────────────────────────────────────────────────

        case (.monthly, .newlyStarted):
            let pool = [
                "\(current) session\(current == 1 ? "" : "s") this month — the habit is being written.",
                "Month one. This month is your baseline — every future month measures against it.",
                "\(current) session\(current == 1 ? "" : "s") in. The only month that matters right now is this one."
            ]
            return (pool[seed % pool.count], "calendar.badge.plus")

        case (.monthly, .reactivated):
            let pool = [
                "\(current) session\(current == 1 ? "" : "s") this month — a real comeback. Your history is still here.",
                "Back this month after a break. The data remembers. Pick up where you left off.",
                "Returning after a quiet stretch. \(current) session\(current == 1 ? "" : "s") in — the habit is alive."
            ]
            return (pool[seed % pool.count], "arrow.counterclockwise.circle")

        case (.monthly, .building):
            let pool = [
                "\(current) sessions this month vs \(prior) last. The trend is pointing up.",
                "More sessions than last month. Monthly growth is how the long-term story gets written.",
                "Up from \(prior) → \(current) sessions. Month-over-month is the metric that matters most early on."
            ]
            return (pool[seed % pool.count], "chart.line.uptrend.xyaxis")

        case (.monthly, .consistent):
            let pool = [
                "\(current) sessions this month, same as last. Most people fluctuate — you don't.",
                "Another month, same consistency. That's not a plateau — that's a habit.",
                "Matching last month's pace. Consistent months chain into a consistent year."
            ]
            return (pool[seed % pool.count], "checkmark.circle")

        case (.monthly, .recovering):
            let pool = [
                "\(current) sessions in — down from last month, but the month isn't over.",
                "Slower than last month. That happens. Finish this month strong.",
                "Last month was better, but you're still logging. The habit is still alive."
            ]
            return (pool[seed % pool.count], "arrow.counterclockwise")

        case (.monthly, .slipping):
            let pool = [
                "Nothing logged yet this month. One session resets the momentum.",
                "The month is still open. Even two sessions this month keeps the chain intact.",
                "A quiet month so far. The habit doesn't forget — it's waiting."
            ]
            return (pool[seed % pool.count], "calendar")

        // ── QUARTERLY ──────────────────────────────────────────────────────

        case (.quarterly, .newlyStarted):
            let pool = [
                "\(current) sessions in the books. Your first quarter is your foundation.",
                "Quarter underway with \(current) sessions. This is where the data starts to tell a real story.",
                "\(current) sessions this quarter — you're building the baseline everything else is measured against."
            ]
            return (pool[seed % pool.count], "calendar.badge.clock")

        case (.quarterly, .reactivated):
            let pool = [
                "\(current) sessions after a gap. The quarter still has time — make it count.",
                "Back in the gym after a quiet stretch. What you built before is still in you.",
                "Returning after a break. The quarter isn't written yet."
            ]
            return (pool[seed % pool.count], "arrow.counterclockwise.circle")

        case (.quarterly, .building):
            let pool = [
                "\(current) sessions this quarter vs \(prior) last — meaningful growth over 90 days.",
                "More sessions this quarter than the last. Three months of compounding is where habits become automatic.",
                "Quarter-over-quarter improvement. Most people track weeks — you're winning the quarter."
            ]
            return (pool[seed % pool.count], "chart.bar.fill")

        case (.quarterly, .consistent):
            let pool = [
                "\(current) sessions this quarter, close to last. Quarterly consistency is harder than it looks.",
                "Another solid quarter. This is the volume level your body has adapted to — protect it.",
                "Matching last quarter's pace. Three consistent months chain into a consistent year."
            ]
            return (pool[seed % pool.count], "checkmark.circle")

        case (.quarterly, .recovering):
            let pool = [
                "\(current) sessions this quarter, behind last. The quarter has time — keep going.",
                "Slower quarter than the last, but you're still here. Finishing above zero is a win.",
                "Off pace this quarter. One strong month left can still make it respectable."
            ]
            return (pool[seed % pool.count], "arrow.counterclockwise")

        case (.quarterly, .slipping):
            let pool = [
                "Quiet quarter so far. The next session is the one that matters most right now.",
                "Life happens. Even 4–5 sessions to close the quarter maintains the baseline.",
                "The quarter isn't over. A small cluster of sessions now still counts as showing up."
            ]
            return (pool[seed % pool.count], "calendar")

        // ── HALF-YEAR ──────────────────────────────────────────────────────

        case (.halfYear, .newlyStarted):
            let pool = [
                "\(current) sessions in the last 6 months. Half a year of showing up is not trivial.",
                "Six months in with \(current) sessions. Most people quit before they even reach this point.",
                "\(current) sessions logged in the last half-year. The habit is real now."
            ]
            return (pool[seed % pool.count], "medal")

        case (.halfYear, .reactivated):
            let pool = [
                "\(current) sessions this half-year after a gap. Everything you built is still in you.",
                "Back after time away. The gym never locks you out — you're back in.",
                "Returning after a break. Your history is here. Start building again."
            ]
            return (pool[seed % pool.count], "arrow.counterclockwise.circle")

        case (.halfYear, .building):
            let pool = [
                "\(current) sessions this half-year vs \(prior) last — you trained more in the second half than the first.",
                "More sessions in the last 6 months than the 6 before. That's a trajectory change.",
                "Six months of more. The best time to start was 6 months ago. The second-best is now — and you're doing it."
            ]
            return (pool[seed % pool.count], "chart.line.uptrend.xyaxis")

        case (.halfYear, .consistent):
            let pool = [
                "\(current) sessions this half-year, close to the last. Half-year consistency is rare.",
                "Matching the previous 6 months. You've made training a constant, not a phase.",
                "Two solid half-years. That's a year of showing up. That's not nothing — that's everything."
            ]
            return (pool[seed % pool.count], "checkmark.circle")

        case (.halfYear, .recovering):
            let pool = [
                "Behind the previous 6 months, but you've done \(current) sessions. That's still the habit alive.",
                "Slower second half, but you're still training. The habit survived — that's what matters.",
                "This half is quieter than the last. One consistent month to close it changes the story."
            ]
            return (pool[seed % pool.count], "arrow.counterclockwise")

        case (.halfYear, .slipping):
            let pool = [
                "Quiet stretch. The habit you built is waiting — one session at a time.",
                "The last 6 months have been off. Getting back now protects everything you put in.",
                "Life pulled you away. The gym will take you back no questions asked."
            ]
            return (pool[seed % pool.count], "arrow.counterclockwise.circle")

        // ── ANNUAL ─────────────────────────────────────────────────────────

        case (.annual, .newlyStarted):
            let pool = [
                "\(current) sessions so far this year. A year of training changes how you live.",
                "Year underway with \(current) sessions. By December, this number tells a full story.",
                "\(current) sessions this year. Annual consistency is the only metric that outlasts motivation."
            ]
            return (pool[seed % pool.count], "calendar.badge.clock")

        case (.annual, .reactivated):
            let pool = [
                "\(current) sessions this year after a gap. The year isn't over — finish it.",
                "Back after time away. Two years of data — the habit knows who you are.",
                "Returning this year. Every session from here rebuilds the baseline."
            ]
            return (pool[seed % pool.count], "arrow.counterclockwise.circle")

        case (.annual, .building):
            let pool = [
                "\(current) sessions this year vs \(prior) last. Year-over-year growth — the compounding effect is real.",
                "More sessions this year than last. That's the definition of a habit that's taken hold.",
                "Up from \(prior) → \(current) sessions year-over-year. This is the number your future self cares about."
            ]
            return (pool[seed % pool.count], "chart.line.uptrend.xyaxis")

        case (.annual, .consistent):
            let pool = [
                "\(current) sessions this year, matching last. Two consistent years is a lifestyle, not a routine.",
                "Year two at the same pace. The people who maintain this are the ones who look different in 5 years.",
                "Another year, same commitment. Consistency over years is the rarest thing in fitness."
            ]
            return (pool[seed % pool.count], "checkmark.seal")

        case (.annual, .recovering):
            let pool = [
                "Quieter than last year, but \(current) sessions is still real work. Finish strong.",
                "Behind last year's pace, but there's still year left. The habit knows the way back.",
                "Last year was better — but you're still logging. Every year that ends with a session matters."
            ]
            return (pool[seed % pool.count], "arrow.counterclockwise")

        case (.annual, .slipping):
            let pool = [
                "The year has time left. Even a strong finish makes this one worth counting.",
                "Off-year so far. Coming back now means next year starts from a real baseline.",
                "Life changed the plan. The habit is still in you — it just needs a door opened."
            ]
            return (pool[seed % pool.count], "arrow.counterclockwise.circle")
        }
    }
}
