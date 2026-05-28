import SwiftUI
import Charts

// MARK: - Simple Progress View
// Six question-named sections, each answering a distinct user motivation.
// Advanced analytics remain in the "Advanced" tab.

struct SimpleProgressView: View {
    @Environment(SeedStore.self) private var store
    @Environment(HealthKitService.self) private var health

    @State private var strongerExpanded  = true
    @State private var whereExpanded     = true
    @State private var howExpanded       = true
    @State private var cardioExpanded    = false
    @State private var recoveryExpanded  = true
    @State private var signalsExpanded   = true

    @State private var liftDetail: ExerciseAnalytics? = nil
    @State private var sessionDetail: WorkoutLogEntry? = nil

    private var analytics: AnalyticsResult { store.analyticsCache }

    private var showCardio: Bool {
        !store.cardioLog.isEmpty &&
        (store.userProfile.trainingGoal == .endurance || store.userProfile.trainingGoal == .general)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if !store.isLoaded {
                        simpleLoadingSkeleton
                    } else {
                        CollapsibleDashSection(
                            title: "Am I Getting Stronger?",
                            icon: "chart.line.uptrend.xyaxis",
                            isExpanded: $strongerExpanded
                        ) {
                            StrengthTrendContent(
                                analytics: analytics,
                                personalRecords: store.personalRecords,
                                onLiftTap: { liftDetail = $0 }
                            )
                        }

                        CollapsibleDashSection(
                            title: "How Strong Am I?",
                            icon: "mappin.circle.fill",
                            isExpanded: $whereExpanded
                        ) {
                            StandardLiftsCard(
                                log: store.workoutLog,
                                bodyWeightKg: store.userProfile.bodyWeightKg
                            )
                        }

                        CollapsibleDashSection(
                            title: "How Do I Train?",
                            icon: "dumbbell.fill",
                            isExpanded: $howExpanded
                        ) {
                            TrainingPatternContent(
                                log: store.workoutLog,
                                categoryAnalytics: analytics.categoryAnalytics,
                                onSessionTap: { sessionDetail = $0 }
                            )
                        }

                        if showCardio {
                            CollapsibleDashSection(
                                title: "Am I Doing Cardio?",
                                icon: "bolt.heart.fill",
                                isExpanded: $cardioExpanded
                            ) {
                                CardioTrendContent(cardioLog: store.cardioLog)
                            }
                        }

                        CollapsibleDashSection(
                            title: "How Am I Recovering?",
                            icon: "waveform.path.ecg",
                            isExpanded: $recoveryExpanded
                        ) {
                            RecoveryTrendContent(
                                trendData: store.homeCache.readiness.trendData,
                                scoreHistory: store.readinessScoreHistory
                            )
                        }

                        CollapsibleDashSection(
                            title: "Emerging Signals",
                            icon: "sparkles",
                            isExpanded: $signalsExpanded
                        ) {
                            EmergingSignalsContent(
                                analytics: analytics,
                                log: store.workoutLog,
                                hrv: health.hrv,
                                sleepHours: health.sleepHours,
                                onLiftTap: { liftDetail = $0 }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(AppTheme.pageBG)
            .navigationTitle("Progress")
        }
        .sheet(item: $liftDetail) { lift in
            LiftDetailSheet(analytics: lift, log: store.workoutLog)
        }
        .sheet(item: $sessionDetail) { session in
            SessionLogSheet(session: session)
        }
    }

    private var simpleLoadingSkeleton: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.cardBG)
                    .frame(height: 80)
            }
        }
    }
}

// MARK: - Section 1: Am I Getting Stronger?

private struct StrengthTrendContent: View {
    let analytics: AnalyticsResult
    let personalRecords: [UUID: PersonalRecord]
    let onLiftTap: (ExerciseAnalytics) -> Void

    private var topLifts: [ExerciseAnalytics] {
        Array(
            analytics.exerciseAnalytics
                .filter { $0.exercise.isCompound && $0.sessions.count >= 2 }
                .prefix(5)
        )
    }

    private var recentPRs: [PersonalRecord] {
        Array(
            personalRecords.values
                .sorted { $0.date > $1.date }
                .prefix(6)
        )
    }

    var body: some View {
        VStack(spacing: 10) {
            if topLifts.isEmpty {
                Text("Log compound lifts across multiple sessions to see your strength trajectory here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topLifts.enumerated()), id: \.element.id) { idx, lift in
                        if idx > 0 { Divider().padding(.leading, 4) }
                        LiftTrendRow(analytics: lift, onTap: { onLiftTap(lift) })
                    }
                }
                .padding(14)
                .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
            }

            if !recentPRs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent PRs")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recentPRs) { pr in PRChip(pr: pr) }
                        }
                    }
                }
                .padding(14)
                .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

private struct LiftTrendRow: View {
    let analytics: ExerciseAnalytics
    let onTap: () -> Void

    private var trendColor: Color {
        if analytics.isPlateau { return HONTheme.warning }
        if analytics.slopePerWeek > 0.5 { return HONTheme.positive }
        return .secondary
    }

    private var trendLabel: String {
        if analytics.isPlateau { return "Plateau" }
        if analytics.slopePerWeek >= 1.0 { return String(format: "+%.1f kg/wk", analytics.slopePerWeek) }
        if analytics.slopePerWeek > 0.2  { return "↑ Progressing" }
        if analytics.slopePerWeek < -0.2 { return "↓ Declining" }
        return "→ Stable"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(analytics.exercise.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    if let latest = analytics.sessions.last {
                        Text(String(format: "e1RM %.0f kg", latest.estimated1RM))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 110, alignment: .leading)

                if analytics.sessions.count >= 2 {
                    MiniSparkline(
                        points: analytics.sessions.suffix(10).map(\.estimated1RM),
                        color: trendColor
                    )
                    .frame(height: 26)
                }

                Spacer(minLength: 4)

                Text(trendLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(trendColor)
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PRChip: View {
    let pr: PersonalRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(pr.exerciseName)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
            Text("\(pr.weight.weightFormatted) kg × \(pr.reps)")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(HONTheme.positive.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Section 3: How Do I Train?

private struct TrainingPatternContent: View {
    let log: [WorkoutLogEntry]
    let categoryAnalytics: [CategoryAnalytics]
    let onSessionTap: (WorkoutLogEntry) -> Void

    @State private var expandPatterns = false

    var body: some View {
        VStack(spacing: 12) {
            ConsistencyDotGrid(log: log, onSessionTap: onSessionTap)
                .padding(14)
                .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))

            PatternBalanceSection(
                categoryAnalytics: categoryAnalytics,
                expanded: $expandPatterns
            )
            .padding(14)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

private struct ConsistencyDotGrid: View {
    let log: [WorkoutLogEntry]
    let onSessionTap: (WorkoutLogEntry) -> Void

    private let weeks = 8
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    private func sessionDayMap() -> [Date: WorkoutLogEntry] {
        var map: [Date: WorkoutLogEntry] = [:]
        let cal = Calendar.current
        for entry in log {
            let day = cal.startOfDay(for: entry.startedAt)
            if map[day] == nil { map[day] = entry }
        }
        return map
    }

    private func weekGrid() -> [[Date]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        let thisMonday = cal.date(byAdding: .day, value: -daysSinceMonday, to: today)!
        return (0..<weeks).map { weekBack in
            let start = cal.date(byAdding: .day, value: -weekBack * 7, to: thisMonday)!
            return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sessions — last 8 weeks")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            let map   = sessionDayMap()
            let grid  = weekGrid()
            let today = Calendar.current.startOfDay(for: Date())

            HStack(spacing: 0) {
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(Array(grid.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        let isFuture = day > today
                        let session  = map[day]
                        Circle()
                            .fill(
                                isFuture  ? Color.clear :
                                session != nil ? HONTheme.accent :
                                Color.secondary.opacity(0.12)
                            )
                            .frame(width: 9, height: 9)
                            .frame(maxWidth: .infinity)
                            .onTapGesture { if let s = session { onSessionTap(s) } }
                    }
                }
            }
        }
    }
}

private struct PatternBalanceSection: View {
    let categoryAnalytics: [CategoryAnalytics]
    @Binding var expanded: Bool

    private var totalVolume: Double {
        categoryAnalytics.reduce(0) { $0 + $1.weeklyVolumeAvg }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3)) { expanded.toggle() }
            } label: {
                HStack {
                    Text("Movement Pattern Balance")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if totalVolume > 0 {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(categoryAnalytics.filter { $0.weeklyVolumeAvg > 0 }) { cat in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(patternColor(cat.pattern))
                                .frame(width: geo.size.width * CGFloat(cat.weeklyVolumeAvg / totalVolume))
                        }
                    }
                }
                .frame(height: 8)
            }

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(categoryAnalytics.sorted { $0.weeklyVolumeAvg > $1.weeklyVolumeAvg }) { cat in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(patternColor(cat.pattern))
                                .frame(width: 8, height: 8)
                            Text(cat.pattern.shortName)
                                .font(.system(size: 11))
                            Spacer()
                            if cat.weeklyVolumeAvg > 0 {
                                Text(String(format: "%.0f kg/wk", cat.weeklyVolumeAvg))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No data")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func patternColor(_ pattern: MovementPattern) -> Color {
        switch pattern {
        case .horizontalPush: return HONTheme.accent
        case .verticalPush:   return HONTheme.chartLavender
        case .horizontalPull: return HONTheme.chartSage
        case .verticalPull:   return HONTheme.chartSlate
        case .hipHinge:       return HONTheme.warning
        case .kneeFlexion:    return HONTheme.positive
        case .isolation:      return HONTheme.chartRose
        }
    }
}

// MARK: - Section 4: Am I Doing Cardio?

private struct CardioTrendContent: View {
    let cardioLog: [CardioLogEntry]

    private func weeklySessionCounts() -> [Double] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<8).reversed().map { weeksAgo in
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -weeksAgo, to: today),
                  let weekEnd   = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { return 0 }
            return Double(cardioLog.filter { $0.startedAt >= weekStart && $0.startedAt < weekEnd }.count)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let counts = weeklySessionCounts()
            let avg = counts.reduce(0, +) / Double(max(counts.count, 1))
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cardio sessions / week")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(String(format: "Avg %.1f", avg))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(cardioLog.count) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            MiniSparkline(points: counts, color: HONTheme.chartSage)
                .frame(height: 36)
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Section 5: How Am I Recovering?

private struct RecoveryTrendContent: View {
    let trendData: [ReadinessState.TrendPoint]
    let scoreHistory: [String: Int]

    private var thirtyDayPoints: [(date: Date, score: Double)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return (0..<30).reversed().compactMap { daysAgo -> (Date, Double)? in
            guard let d = cal.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            guard let score = scoreHistory[fmt.string(from: d)] else { return nil }
            return (d, Double(score))
        }
    }

    private var sparklinePoints: [Double] {
        let pts = thirtyDayPoints
        if pts.count >= 5 { return pts.map(\.score) }
        return trendData.map(\.score)
    }

    private var recentAvg: Double {
        let pts = sparklinePoints.suffix(7)
        guard !pts.isEmpty else { return 0 }
        return pts.reduce(0, +) / Double(pts.count)
    }

    private var trendString: String {
        let pts = sparklinePoints
        guard pts.count >= 14 else { return "Building trend data" }
        let recent = pts.suffix(7).reduce(0, +) / 7.0
        let prior  = pts.dropLast(7).suffix(7).reduce(0, +) / 7.0
        if recent > prior + 3 { return "Trending up ↑" }
        if recent < prior - 3 { return "Trending down ↓" }
        return "Stable →"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Readiness trend — 30 days")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(trendString)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f", recentAvg))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("7-day avg")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }

            MiniSparkline(points: sparklinePoints, color: HONTheme.chartSage)
                .frame(height: 44)

            Text("Today's readiness score is on Home. This shows your trend over time.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Section 6: Emerging Signals (text only, no charts)

private struct EmergingSignalsContent: View {
    let analytics: AnalyticsResult
    let log: [WorkoutLogEntry]
    let hrv: Double?
    let sleepHours: Double?
    let onLiftTap: (ExerciseAnalytics) -> Void

    private var topInsight: EmergentInsight? {
        EmergentInsightEngine.compute(log: log, analyticsResult: analytics, hrv: hrv, sleepHours: sleepHours)
            .filter { $0.dataAvailable && ($0.severity == .warning || $0.severity == .alert) }
            .first
    }

    private var stalledLifts: [ExerciseAnalytics] {
        analytics.exerciseAnalytics.filter { $0.isPlateau && $0.hasEnoughData }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if topInsight == nil && stalledLifts.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(HONTheme.positive)
                    Text("Nothing flagged — training looks on track.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
            } else {
                if let insight = topInsight {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(insight.severityColor)
                            Text(insight.title)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text(insight.implication)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if !insight.dataPoint.isEmpty {
                            Text(insight.dataPoint)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .italic()
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(insight.severityColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }

                if !stalledLifts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Stalled Lifts")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        ForEach(stalledLifts) { lift in
                            Button { onLiftTap(lift) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(lift.exercise.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.primary)
                                        Text("Flat for 4+ weeks")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("Review →")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(HONTheme.warning)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: - Lift Detail Sheet

struct LiftDetailSheet: View {
    let analytics: ExerciseAnalytics
    let log: [WorkoutLogEntry]

    @Environment(\.dismiss) private var dismiss

    private struct SessionEntry: Identifiable {
        let id = UUID()
        let date: Date
        let sets: [SetRecord]
    }

    private var sessionEntries: [SessionEntry] {
        Array(
            log.compactMap { entry -> SessionEntry? in
                guard let we = entry.exercises.first(where: { $0.exercise.id == analytics.id }),
                      !we.completedSets.isEmpty else { return nil }
                return SessionEntry(date: entry.startedAt, sets: we.completedSets)
            }
            .prefix(20)
        )
    }

    private var nextTargetText: String {
        guard let last = analytics.sessions.last else { return "No data yet" }
        let increment = analytics.exercise.isCompound ? 2.5 : 1.25
        return String(format: "%.1f kg × %d reps", last.bestWeight + increment, last.bestReps)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Suggested next target
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next session target")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(nextTargetText)
                            .font(.title2.bold())
                            .foregroundStyle(HONTheme.accent)
                        Text("Based on last session + standard progression increment.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HONTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                    // Plateau flag
                    if analytics.isPlateau {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(HONTheme.warning)
                                .font(.system(size: 14))
                            Text("Progress has been flat for 4+ weeks. Try changing rep range, adjusting load, or swapping to a variation exercise.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(HONTheme.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }

                    // e1RM sparkline
                    if analytics.sessions.count >= 2 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("e1RM trend")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            MiniSparkline(
                                points: analytics.sessions.map(\.estimated1RM),
                                color: analytics.isPlateau ? HONTheme.warning : HONTheme.positive
                            )
                            .frame(height: 60)
                        }
                        .padding(14)
                        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Raw session log
                    if !sessionEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Session Log")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(sessionEntries) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    ForEach(Array(entry.sets.enumerated()), id: \.offset) { idx, s in
                                        HStack {
                                            Text("Set \(idx + 1)")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.tertiary)
                                                .frame(width: 36, alignment: .leading)
                                            Text("\(s.weight.weightFormatted) kg × \(s.reps)")
                                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            Spacer()
                                            if let rpe = s.rpe {
                                                Text("RPE \(String(format: "%.0f", rpe))")
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                if entry.id != sessionEntries.last?.id { Divider() }
                            }
                        }
                        .padding(14)
                        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
            }
            .background(AppTheme.pageBG)
            .navigationTitle(analytics.exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Session Log Sheet

struct SessionLogSheet: View {
    let session: WorkoutLogEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Duration", value: session.formattedDuration)
                    LabeledContent("Sets", value: "\(session.totalSets)")
                    LabeledContent("Volume", value: "\(Int(session.totalVolume)) kg")
                    if let feel = session.feelRating {
                        LabeledContent("Feel", value: "\(feel.icon) \(feel.rawValue)")
                    }
                }
                Section("Exercises") {
                    ForEach(session.exercises) { we in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(we.exercise.name)
                                .font(.system(size: 13, weight: .semibold))
                            let done = we.completedSets
                            if !done.isEmpty {
                                Text(done.map { "\($0.weight.weightFormatted)×\($0.reps)" }.joined(separator: "  "))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No sets completed")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle(session.startedAt.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
