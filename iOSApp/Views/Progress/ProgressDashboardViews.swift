import SwiftUI
import Charts

// MARK: - Expandable Chart Infrastructure

private struct ExpandedChartKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var expandedChart: Bool {
        get { self[ExpandedChartKey.self] }
        set { self[ExpandedChartKey.self] = newValue }
    }
}

/// Wraps any chart card; tap opens a full-screen sheet with the same content.
struct ExpandableChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @State private var showFull = false

    var body: some View {
        content()
            .overlay(alignment: .topTrailing) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(8)
            }
            .contentShape(Rectangle())
            .onTapGesture { showFull = true }
            .sheet(isPresented: $showFull) {
                NavigationStack {
                    ScrollView {
                        content()
                            .environment(\.expandedChart, true)
                            .padding(20)
                    }
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showFull = false }
                        }
                    }
                    .background(AppTheme.pageBG)
                }
            }
    }
}

/// Applies a larger frame height when rendered inside an `ExpandableChartCard` sheet.
private struct ExpandingFrameView<Content: View>: View {
    let content: Content
    let normalHeight: CGFloat
    let expandedHeight: CGFloat
    @Environment(\.expandedChart) private var isExpanded

    var body: some View {
        content.frame(height: isExpanded ? expandedHeight : normalHeight)
    }
}

extension View {
    func expandingFrame(normal: CGFloat, expanded: CGFloat) -> some View {
        ExpandingFrameView(content: self, normalHeight: normal, expandedHeight: expanded)
    }
}

// MARK: - Collapsible Section Shell

struct CollapsibleDashSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(HONTheme.accent)
                        .frame(width: 26, height: 26)
                        .background(HONTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .kerning(0.4)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 12) {
                    content()
                }
                .padding(.top, 8)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
    }
}

// MARK: - Habit Insight Banner

struct HabitInsightBanner: View {
    let insight: HabitInsight

    private var accentColor: Color {
        switch insight.trend {
        case .building, .consistent, .newlyStarted: return HONTheme.accent
        case .reactivated:                           return HONTheme.chartSage
        case .recovering:                            return HONTheme.chartSage
        case .slipping:                              return HONTheme.textSecondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insight.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accentColor.opacity(0.8))
                .frame(width: 16)
                .padding(.top, 1)
            Text(insight.message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentColor.opacity(0.06), in: Rectangle())
    }
}

// MARK: - Hero Card

struct DashboardHeroCard: View {
    let composite: CompositeStrengthResult
    let strengthScore: CompositeStrengthScore?
    let relativeStrengths: [RelativeStrengthPoint]
    let log: [WorkoutLogEntry]
    let cardioLog: [CardioLogEntry]
    let userProfile: UserProfile
    var exerciseAnalytics: [ExerciseAnalytics] = []

    @State private var showDetail = false

    private var sessionCount: Int { log.count }
    private var isCardioOnly: Bool { log.isEmpty && !cardioLog.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            if isCardioOnly {
                cardioHeroHeader
            } else {
                strengthHeroHeader
            }

            Divider().padding(.horizontal, 16)

            if let habit = HabitInsightEngine.analyze(log: log, cardioLog: cardioLog) {
                HabitInsightBanner(insight: habit)
            }

            Divider().padding(.horizontal, 16)

            if isCardioOnly {
                cardioStatChips
            } else {
                strengthStatChips
            }
        }
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HONTheme.textSecondary.opacity(0.4))
                .padding(12)
        }
        .contentShape(Rectangle())
        .onTapGesture { if !isCardioOnly { showDetail = true } }
        .sheet(isPresented: $showDetail) {
            HeroCardDetailSheet(
                composite:         composite,
                strengthScore:     strengthScore,
                relativeStrengths: relativeStrengths,
                log:               log,
                exerciseAnalytics: exerciseAnalytics
            )
        }
    }

    // MARK: - Strength hero sub-views

    private var strengthHeroHeader: some View {
        Group {
            if sessionCount < 3 {
                lockedStrengthHeader
            } else {
                HStack(alignment: .center, spacing: 20) {
                    ScoreGauge(score: composite.overallScore, grade: "")
                        .frame(width: 130, height: 130)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("STRENGTH SCORE")
                            .font(.microLabel).foregroundStyle(.secondary).kerning(0.8)
                        if let ss = strengthScore {
                            Text(ss.tier.rawValue.uppercased())
                                .font(.heroRounded(26))
                                .foregroundStyle(AppTheme.tier(ss.tier))
                                .lineLimit(1).minimumScaleFactor(0.7)
                            if sessionCount > 0 && sessionCount < 10 {
                                Text("Building baseline · \(10 - sessionCount) to go")
                                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            Text("CALIBRATING").font(.heroRounded(20)).foregroundStyle(.secondary)
                            Text("Add body weight in Settings")
                                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        // Composite insight
                        Text(composite.insight)
                            .font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(1.5)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
            }
        }
    }

    private var lockedStrengthHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Strength Score")
                        .font(.subheadline.bold())
                    Text("\(3 - sessionCount) more session\(3 - sessionCount == 1 ? "" : "s") to unlock your score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }

    private var sessionsThisWeek: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let daysFromMon = (cal.component(.weekday, from: today) + 5) % 7
        let weekStart = cal.date(byAdding: .day, value: -daysFromMon, to: today)!
        return log.filter { $0.startedAt >= weekStart }.count
    }

    private var strengthStatChips: some View {
        HStack(spacing: 0) {
            statChip("\(sessionCount)", "Sessions", "figure.strengthtraining.traditional", HONTheme.accent)
            Divider().frame(height: 32)
            statChip("\(sessionsThisWeek)", "This Week", "calendar.badge.checkmark", HONTheme.positive)
            Divider().frame(height: 32)
            statChip("\(strengthScore?.coveredCategories.count ?? 0)/3", "Lifts", "checkmark.circle.fill", HONTheme.chartLavender)
            Divider().frame(height: 32)
            statChip(momentumLabel, "Trend", "bolt.fill", HONTheme.chartLavender)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Cardio hero sub-views

    private var cardioTotalRounds: Int {
        cardioLog.reduce(0) { $0 + $1.completedRounds }
    }

    private var cardioAvgRepsPerMin: Double {
        let entries = cardioLog.filter { $0.durationMinutes > 0 }
        guard !entries.isEmpty else { return 0 }
        let total = entries.reduce(0.0) { $0 + Double($1.totalReps) / Double($1.durationMinutes) }
        return total / Double(entries.count)
    }

    private var cardioHeroHeader: some View {
        HStack(alignment: .center, spacing: 20) {
            ZStack {
                Circle()
                    .stroke(HONTheme.warning.opacity(0.15), lineWidth: 10)
                    .frame(width: 130, height: 130)
                VStack(spacing: 4) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(HONTheme.warning)
                    Text("\(cardioLog.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(HONTheme.warning)
                    Text("sessions")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("CARDIO TRAINING")
                    .font(.microLabel).foregroundStyle(.secondary).kerning(0.8)
                Text("ACTIVE")
                    .font(.heroRounded(26)).foregroundStyle(HONTheme.warning)
                if cardioTotalRounds > 0 {
                    Text("\(cardioTotalRounds) total rounds logged")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                if cardioAvgRepsPerMin > 0 {
                    Text(String(format: "%.0f avg reps/min", cardioAvgRepsPerMin))
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var cardioStatChips: some View {
        let thisWeekStart: Date = {
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let days = (cal.component(.weekday, from: today) + 5) % 7
            return cal.date(byAdding: .day, value: -days, to: today)!
        }()
        let weekSessions = cardioLog.filter { $0.startedAt >= thisWeekStart }.count
        let avgDuration = cardioLog.isEmpty ? 0 : cardioLog.reduce(0) { $0 + $1.durationMinutes } / cardioLog.count

        return HStack(spacing: 0) {
            statChip("\(cardioLog.count)", "Sessions", "bolt.heart.fill", HONTheme.warning)
            Divider().frame(height: 32)
            statChip("\(cardioTotalRounds)", "Rounds", "arrow.clockwise.circle.fill", HONTheme.accent)
            Divider().frame(height: 32)
            statChip("\(weekSessions)", "This Week", "calendar", HONTheme.positive)
            Divider().frame(height: 32)
            statChip("\(avgDuration)m", "Avg Length", "clock.fill", HONTheme.chartLavender)
        }
        .padding(.vertical, 12)
    }

    private var momentumLabel: String {
        let history = composite.history
        if history.count >= 2 {
            let latest = history.last!.score
            let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
            if let prev = history.last(where: { $0.date <= cutoff }) {
                let delta = latest - prev.score
                let sign = delta >= 0 ? "+" : ""
                return "\(sign)\(String(format: "%.0f", delta)) WoW"
            }
        }
        let m = composite.momentumScore
        if m >= 70 { return "↑ Strong" }
        if m >= 45 { return "→ Steady" }
        return "↓ Lagging"
    }

    private func percentile(for rp: RelativeStrengthPoint) -> Double {
        let rs = rp.relativeStrength
        let t  = rp.thresholds
        switch rp.tier {
        case .beginner:
            return 20.0 * min(rs / max(t.beginner, 0.01), 1.0)
        case .intermediate:
            let frac = (rs - t.beginner) / max(t.intermediate - t.beginner, 0.01)
            return 20.0 + 30.0 * min(max(frac, 0), 1.0)
        case .advanced:
            let frac = (rs - t.intermediate) / max(t.advanced - t.intermediate, 0.01)
            return 50.0 + 30.0 * min(max(frac, 0), 1.0)
        case .elite:
            let frac = (rs - t.advanced) / max(t.advanced * 0.3, 0.01)
            return 80.0 + 20.0 * min(max(frac, 0), 1.0)
        }
    }

    private func tierColor(_ tier: RelativeStrengthTier) -> Color {
        switch tier {
        case .beginner:     return HONTheme.tierBeginner
        case .intermediate: return HONTheme.tierIntermediate
        case .advanced:     return HONTheme.tierAdvanced
        case .elite:        return HONTheme.chartAmber
        }
    }

    private func statChip(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Compact per-lift percentile bar used inside DashboardHeroCard
private struct CompactPercentileBar: View {
    let percentile: Double
    let tierColor: Color

    var body: some View {
        GeometryReader { geo in
            let w   = geo.size.width
            let markerX = w * CGFloat(percentile / 100.0)
            ZStack(alignment: .leading) {
                LinearGradient(
                    colors: [HONTheme.tierBeginner, HONTheme.tierIntermediate,
                             HONTheme.tierAdvanced, HONTheme.tierElite],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(0.25)
                .clipShape(RoundedRectangle(cornerRadius: 3))

                Rectangle()
                    .fill(tierColor)
                    .frame(width: 3, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
                    .offset(x: max(0, markerX - 1.5))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Score Gauge (circular arc)

struct ScoreGauge: View {
    let score: Double  // 0–100
    var grade: String = ""  // unused — kept for call-site compatibility during transition

    private var fraction: Double { min(1, max(0, score / 100)) }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.secondary.opacity(0.15),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(135))

            // Fill
            Circle()
                .trim(from: 0, to: 0.75 * fraction)
                .stroke(
                    LinearGradient(
                        colors: [HONTheme.accent, HONTheme.chartLavender],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .animation(.spring(response: 0.9, dampingFraction: 0.7), value: fraction)

            VStack(spacing: 1) {
                Text("\(Int(score.rounded()))")
                    .font(.heroRounded(30))
                    .foregroundStyle(
                        LinearGradient(colors: [HONTheme.accent, HONTheme.chartLavender],
                                       startPoint: .top, endPoint: .bottom)
                    )
                Text("/ 100")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - WHERE Section

struct WhereSectionContent: View {
    let log: [WorkoutLogEntry]
    let analytics: AnalyticsResult
    let bodyWeightKg: Double?
    @State private var showDevelopmentDetail = false

    var body: some View {
        VStack(spacing: 12) {
            // Movement pattern radar
            HStack(alignment: .top, spacing: 12) {
                ExpandableChartCard(title: "Movement Pattern Strength") { patternRadarCard }
                muscleGridCard
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(8)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { showDevelopmentDetail = true }
                    .sheet(isPresented: $showDevelopmentDetail) {
                        DevelopmentTierDetailSheet(analytics: analytics)
                    }
            }

            // Standard lift tier bars
            StandardLiftsCard(log: log, bodyWeightKg: bodyWeightKg)

            // Strength retention rings — only show once at least one exercise has ≥ 2 sessions
            let qualifiedForRings = analytics.exerciseAnalytics.filter { $0.sessions.count >= 2 }
            if !qualifiedForRings.isEmpty {
                StrengthRetentionRingsCard(exerciseAnalytics: qualifiedForRings)
            }
        }
    }

    // Radar card — delegated to a dedicated struct so it can read expandedChart
    private var patternRadarCard: some View {
        MovementPatternRadarCard(categoryAnalytics: analytics.categoryAnalytics)
    }

    // Muscle group heat grid — maxHeight must come BEFORE .background so the fill stretches to match the radar card
    private var muscleGridCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Development Tier")
                .font(.cardTitle)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(muscleData, id: \.name) { item in
                    VStack(spacing: 3) {
                        Text(item.name)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(item.rateLabel)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(item.color)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(item.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private struct MuscleItem { let name: String; let rateLabel: String; let color: Color }

    private var muscleData: [MuscleItem] {
        let patterns = Dictionary(
            analytics.categoryAnalytics.map { ($0.pattern, $0.improvementRatePerWeek) },
            uniquingKeysWith: { a, _ in a }
        )
        func rateLabel(_ rate: Double?) -> (String, Color) {
            guard let r = rate else { return ("—", .secondary) }
            if r > 1.0 { return ("+\(String(format: "%.1f", r))%/wk", HONTheme.positive) }
            if r > 0.5 { return ("+\(String(format: "%.1f", r))%/wk", HONTheme.accent) }
            if r > 0.0 { return ("+\(String(format: "%.1f", r))%/wk", HONTheme.warning) }
            return ("\(String(format: "%.1f", r))%/wk", HONTheme.negative)
        }
        let push = rateLabel(patterns[.horizontalPush])
        let pull = rateLabel(patterns[.verticalPull])
        let ohp  = rateLabel(patterns[.verticalPush])
        let sq   = rateLabel(patterns[.kneeFlexion])
        let dl   = rateLabel(patterns[.hipHinge])
        let iso  = rateLabel(patterns[.isolation])
        return [
            MuscleItem(name: "Chest / Push",  rateLabel: push.0, color: push.1),
            MuscleItem(name: "Back / Pull",   rateLabel: pull.0, color: pull.1),
            MuscleItem(name: "Shoulders",     rateLabel: ohp.0,  color: ohp.1),
            MuscleItem(name: "Squat",         rateLabel: sq.0,   color: sq.1),
            MuscleItem(name: "Hinge / Hip",   rateLabel: dl.0,   color: dl.1),
            MuscleItem(name: "Isolation",     rateLabel: iso.0,  color: iso.1),
        ]
    }
}

// MARK: - Movement Pattern Radar Card (F-11: expanded view adds WoW rows + coaching)

struct MovementPatternRadarCard: View {
    let categoryAnalytics: [CategoryAnalytics]
    @Environment(\.expandedChart) private var isExpanded

    private func coachingNote(_ cat: CategoryAnalytics) -> String {
        let rate = cat.improvementRatePerWeek
        if rate > 1.0 { return "Strong progress — keep load increasing" }
        if rate > 0.2 { return "Improving — add reps or 2.5 kg each session" }
        if rate > 0   { return "Slow progress — consider adding a set or frequency" }
        return "Stalled — change rep range, load, or add volume"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Movement Pattern Strength")
                .font(.cardTitle)
            PatternRadarView(categoryAnalytics: categoryAnalytics)
            Text("Cumulative improvement rate across all sessions. Outer ring = Elite.")
                .font(.appFootnote)
                .foregroundStyle(.secondary)

            if categoryAnalytics.contains(where: { $0.improvementRatePerWeek <= 0 }) {
                let weak = categoryAnalytics
                    .filter { $0.improvementRatePerWeek <= 0 }
                    .map { $0.pattern.shortName }
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9)).foregroundStyle(HONTheme.warning)
                    Text("\(weak.joined(separator: ", ")) show no upward trend. Add volume or load in those patterns.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isExpanded && !categoryAnalytics.isEmpty {
                Divider().padding(.vertical, 4)
                Text("PER-PATTERN BREAKDOWN")
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).kerning(0.5)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(categoryAnalytics) { cat in
                        let rate = cat.improvementRatePerWeek
                        let isPos = rate > 0.1
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Image(systemName: isPos ? "arrow.up.right" : (rate < -0.1 ? "arrow.down.right" : "minus"))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(isPos ? HONTheme.positive : (rate < -0.1 ? HONTheme.negative : HONTheme.warning))
                                    .frame(width: 14)
                                Text(cat.pattern.shortName)
                                    .font(.system(size: 11, weight: .semibold))
                                Spacer()
                                let sign = rate >= 0 ? "+" : ""
                                Text("\(sign)\(String(format: "%.2f", rate))%/wk")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(isPos ? HONTheme.positive : HONTheme.warning)
                            }
                            Text(coachingNote(cat))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Spider / Radar Chart

struct PatternRadarView: View {
    let categoryAnalytics: [CategoryAnalytics]

    private struct Axis { let label: String; let value: Double }

    private var axes: [Axis] {
        let patterns: [(MovementPattern, String)] = [
            (.horizontalPush, "Push"),
            (.verticalPull,   "Pull"),
            (.verticalPush,   "Press"),
            (.hipHinge,       "Hinge"),
            (.kneeFlexion,    "Squat"),
            (.horizontalPull, "Row"),
        ]
        let rateMap = Dictionary(
            categoryAnalytics.map { ($0.pattern, max(0, $0.improvementRatePerWeek)) },
            uniquingKeysWith: { a, _ in a }
        )
        let maxRate = (rateMap.values.max() ?? 1.0).clamped(to: 0.1...100)
        return patterns.map { pattern, label in
            Axis(label: label, value: ((rateMap[pattern] ?? 0) / maxRate).clamped(to: 0...1))
        }
    }

    private var allGroupsCovered: Bool { axes.allSatisfy { $0.value > 0 } }

    var body: some View {
        Canvas { ctx, size in
            guard !axes.isEmpty else { return }
            let cx = size.width / 2, cy = size.height / 2
            let r  = min(cx, cy) * 0.72
            let n  = axes.count

            func point(_ i: Int, _ ratio: Double) -> CGPoint {
                let angle = (Double(i) / Double(n)) * 2 * .pi - (.pi / 2)
                return CGPoint(x: cx + cos(angle) * r * ratio,
                               y: cy + sin(angle) * r * ratio)
            }

            // Background rings
            for ring in stride(from: 0.25, through: 1.0, by: 0.25) {
                var path = Path()
                for i in 0..<n {
                    let pt = point(i, ring)
                    i == 0 ? path.move(to: pt) : path.addLine(to: pt)
                }
                path.closeSubpath()
                ctx.stroke(path, with: .color(.secondary.opacity(ring == 1.0 ? 0.25 : 0.1)), lineWidth: 1)
            }

            // Spokes
            for i in 0..<n {
                var path = Path()
                path.move(to: CGPoint(x: cx, y: cy))
                path.addLine(to: point(i, 1.0))
                ctx.stroke(path, with: .color(.secondary.opacity(0.18)), lineWidth: 1)
            }

            // Data polygon
            var dataPath = Path()
            for i in 0..<n {
                let pt = point(i, axes[i].value)
                i == 0 ? dataPath.move(to: pt) : dataPath.addLine(to: pt)
            }
            dataPath.closeSubpath()
            ctx.fill(dataPath, with: .color(HONTheme.accent.opacity(0.15)))
            ctx.stroke(dataPath, with: .color(HONTheme.accent), lineWidth: 2)

            // Dots
            for i in 0..<n {
                let pt = point(i, axes[i].value)
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)),
                         with: .color(HONTheme.accent))
            }
        }
        .overlay(alignment: .center) {
            // Axis labels (positioned via GeometryReader so they float outside the canvas)
            GeometryReader { geo in
                let cx = geo.size.width / 2, cy = geo.size.height / 2
                let r  = min(cx, cy) * 0.72
                let n  = axes.count
                ForEach(Array(axes.enumerated()), id: \.offset) { i, axis in
                    let angle = (Double(i) / Double(n)) * 2 * .pi - (.pi / 2)
                    let lx = cx + cos(angle) * (r + 20)
                    let ly = cy + sin(angle) * (r + 16)
                    Text(axis.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .position(x: lx, y: ly)
                }
                // Outer ring label so users know the boundary means Elite
                Text("ELITE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(HONTheme.chartAmber.opacity(0.7))
                    .kerning(0.5)
                    .position(x: cx, y: cy - r + 4)
            }
        }
        .expandingFrame(normal: 160, expanded: 280)
        .spiderGlow(allGroupsCovered: allGroupsCovered)
    }
}

// MARK: - Training Load Card

struct TrainingLoadCard: View {
    let inolExercises: [(String, Double)]          // compound-only on card
    var allInolExercises: [(String, Double)] = []  // full list shown in expanded view
    var exerciseAnalytics: [ExerciseAnalytics] = []
    @Environment(\.expandedChart) private var isExpanded
    @State private var showINOLExplainer = false

    private var displayedExercises: [(String, Double)] {
        isExpanded && !allInolExercises.isEmpty ? allInolExercises : inolExercises
    }

    private func inolColor(_ v: Double) -> Color {
        if v < 0.4 { return HONTheme.chartSlate }
        if v < 0.8 { return HONTheme.warning }
        if v <= 1.5 { return HONTheme.positive }
        if v <= 2.5 { return HONTheme.chartAmber }
        return HONTheme.negative
    }

    private func inolLabel(_ v: Double) -> String {
        if v < 0.4 { return "Very Low" }
        if v < 0.8 { return "Low" }
        if v <= 1.5 { return "Optimal" }
        if v <= 2.5 { return "High" }
        return "Very High"
    }

    private var summary: String {
        let optimal = inolExercises.filter { $0.1 >= 0.8 && $0.1 <= 1.5 }
        let low = inolExercises.filter { $0.1 < 0.8 }
        let high = inolExercises.filter { $0.1 > 1.5 }
        var parts: [String] = []
        if !optimal.isEmpty { parts.append("\(optimal.count) in optimal zone") }
        if !low.isEmpty { parts.append("\(low.count) under-stimulated") }
        if !high.isEmpty { parts.append("\(high.count) overloaded") }
        return parts.joined(separator: " · ")
    }

    private var actionableRecommendation: (text: String, icon: String, color: Color)? {
        let vals = inolExercises.map(\.1)
        guard !vals.isEmpty else { return nil }
        let veryHigh = vals.filter { $0 > 2.5 }
        let high     = vals.filter { $0 > 1.5 && $0 <= 2.5 }
        let low      = vals.filter { $0 < 0.8 }
        let veryLow  = vals.filter { $0 < 0.4 }
        let optimal  = vals.filter { $0 >= 0.8 && $0 <= 1.5 }
        // Priority order: worst zone first
        if !veryHigh.isEmpty {
            let names = inolExercises.filter { $0.1 > 2.5 }.map(\.0).prefix(2).joined(separator: " & ")
            return ("Schedule a deload on \(names). INOL > 2.5 risks accumulated fatigue — cut volume 40% this week.", "exclamationmark.triangle.fill", HONTheme.negative)
        }
        if high.count >= Int(ceil(Double(vals.count) / 2)) {
            return ("Session load is high across most lifts. Prioritise 7–9h sleep and keep next session shorter or lower intensity.", "moon.fill", HONTheme.chartAmber)
        }
        if !veryLow.isEmpty && optimal.isEmpty {
            let names = inolExercises.filter { $0.1 < 0.4 }.map(\.0).prefix(2).joined(separator: " & ")
            return ("Add at least 2 sets on \(names) — INOL < 0.4 is below the minimum stimulus threshold. You're leaving gains on the table.", "plus.circle.fill", HONTheme.chartSlate)
        }
        if low.count > optimal.count {
            return ("Most lifts are under-stimulated. Aim to add 1–2 sets or increase weight by 2.5 kg on your next session.", "arrow.up.circle.fill", HONTheme.warning)
        }
        if optimal.count == vals.count {
            return ("All lifts in optimal load range. Maintain this stimulus and focus on progressive overload each session.", "checkmark.circle.fill", HONTheme.positive)
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Training Load (INOL)")
                        .font(.cardTitle)
                    Button {
                        showINOLExplainer = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showINOLExplainer) {
                        AnalyticsExplainerSheet()
                    }
                }
                Text(isExpanded ? summary : (allInolExercises.isEmpty ? summary : "Compound lifts · tap to see all"))
                    .font(.appFootnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(displayedExercises, id: \.0) { name, val in
                let color = inolColor(val)
                let ea = exerciseAnalytics.first { $0.exercise.name == name }
                let slope = ea?.slopePerWeek ?? 0
                // Context note: low INOL might be a lighter day even if the lift is trending up
                let contextNote: String? = {
                    if val < 0.8 && slope > 0.3 {
                        return String(format: "Light session — trending +%.1f kg/wk", slope)
                    } else if val < 0.4 {
                        return "Very light day — boost reps or load"
                    }
                    return nil
                }()
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                            Text(inolLabel(val))
                                .font(.system(size: 9))
                                .foregroundStyle(color)
                        }
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.1))
                                Capsule().fill(color.opacity(0.7))
                                    .frame(width: geo.size.width * CGFloat(min(1, val / 2.5)))
                            }
                        }
                        .frame(width: 70, height: 6)
                        Text(String(format: "%.2f", val))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                            .frame(width: 34, alignment: .trailing)
                    }
                    if let note = contextNote {
                        Text(note)
                            .font(.system(size: 9))
                            .foregroundStyle(HONTheme.positive.opacity(0.8))
                            .padding(.leading, 2)
                    }
                }
            }

            // Plain-English recommendation (F-20)
            if let rec = actionableRecommendation {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: rec.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(rec.color)
                        .padding(.top, 1)
                    Text(rec.text)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(rec.color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            }

            if isExpanded {
                Divider().padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 8) {
                    Text("WHAT IS INOL?")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).kerning(0.5)
                    Text("INOL (Intensity of Normal Load) = Reps ÷ (100 − %1RM). It measures how hard you actually trained, combining both intensity and volume into one number.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineSpacing(2).fixedSize(horizontal: false, vertical: true)

                    let zones: [(String, String, Color)] = [
                        ("< 0.4", "Very Low — barely a stimulus. Add reps or weight.", HONTheme.chartSlate),
                        ("0.4–0.8", "Low — below the productive range. Increase stimulus.", HONTheme.warning),
                        ("0.8–1.5", "Optimal — drives best strength and hypertrophy adaptation.", HONTheme.positive),
                        ("1.5–2.5", "High — hard session. Ensure adequate recovery.", HONTheme.chartAmber),
                        ("> 2.5", "Very High — risk of accumulated fatigue. Plan a deload.", HONTheme.negative),
                    ]
                    ForEach(zones, id: \.0) { range, desc, color in
                        HStack(alignment: .top, spacing: 8) {
                            Text(range)
                                .font(.system(size: 10, weight: .bold)).foregroundStyle(color)
                                .frame(width: 60, alignment: .leading)
                            Text(desc)
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - GETTING STRONGER Section

struct StrongerSectionContent: View {
    let exerciseAnalytics: [ExerciseAnalytics]
    @State private var selectedVelocityExercise: ExerciseAnalytics? = nil
    @State private var selectedPRExercise: ExerciseAnalytics? = nil

    private var prExercises: [ExerciseAnalytics] {
        exerciseAnalytics.filter { $0.prProgression.count >= 2 }
    }

    var body: some View {
        VStack(spacing: 12) {
            MomentumChipsCard(exerciseAnalytics: exerciseAnalytics)

            // INOL — card shows compound lifts only; expanded sheet shows all (F-14)
            let allInolExercises = exerciseAnalytics.compactMap { ea -> (String, Double)? in
                guard let v = ea.latestINOL else { return nil }
                return (ea.exercise.name, v)
            }
            let compoundInolExercises = exerciseAnalytics.compactMap { ea -> (String, Double)? in
                guard ea.exercise.isCompound, let v = ea.latestINOL else { return nil }
                return (ea.exercise.name, v)
            }
            let cardInolExercises = compoundInolExercises.isEmpty ? allInolExercises : compoundInolExercises
            if !allInolExercises.isEmpty {
                ExpandableChartCard(title: "Training Load (INOL)") {
                    TrainingLoadCard(
                        inolExercises: cardInolExercises,
                        allInolExercises: allInolExercises,
                        exerciseAnalytics: exerciseAnalytics
                    )
                }
            }

            OverloadScoreboardCard(exerciseAnalytics: exerciseAnalytics)

            velocityCard
                .sheet(item: $selectedVelocityExercise) { ex in
                    VelocityDetailSheet(analytics: ex)
                }

            if !prExercises.isEmpty {
                let displayed = selectedPRExercise ?? prExercises[0]
                VStack(alignment: .leading, spacing: 8) {
                    if prExercises.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(prExercises) { ex in
                                    let isSel = ex.id == displayed.id
                                    Button { selectedPRExercise = ex } label: {
                                        Text(ex.exercise.name)
                                            .font(.caption.bold())
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(isSel ? HONTheme.positive : Color.secondary.opacity(0.15), in: Capsule())
                                            .foregroundStyle(isSel ? HONTheme.textPrimary : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    ExpandableChartCard(title: "PR Timeline — \(displayed.exercise.name)") {
                        prStepCard(for: displayed)
                    }
                }
            }

            PlateauRiskCard(exerciseAnalytics: exerciseAnalytics)
            PRWindowForecastCard(exerciseAnalytics: exerciseAnalytics)
        }
    }

    private var velocityCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Strength Velocity")
                .font(.cardTitle)
                .padding(.bottom, 10)

            ForEach(exerciseAnalytics.prefix(5)) { ex in
                Button { selectedVelocityExercise = ex } label: {
                    HStack {
                        VelocityRow(analytics: ex)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                if ex.id != exerciseAnalytics.prefix(5).last?.id {
                    Divider().padding(.vertical, 2)
                }
            }

            if exerciseAnalytics.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                    Text("Velocity appears after 3 sessions per exercise.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private func prStepCard(for ex: ExerciseAnalytics) -> some View {
        let currentMax = ex.sessions.map(\.estimated1RM).max() ?? 0
        let nextMilestone = ceil(currentMax / 5) * 5
        let kgNeeded = max(0, nextMilestone - currentMax)
        let weeksNeeded = ex.slopePerWeek > 0.1
            ? Int((kgNeeded / ex.slopePerWeek).rounded(.up))
            : nil

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PR Timeline — \(ex.exercise.name)")
                    .font(.cardTitle)
                Spacer()
                Text("e1RM kg")
                    .font(.appFootnote)
                    .foregroundStyle(.secondary)
            }

            Chart {
                // Smoothed rolling average (background trend) — separate series to avoid zigzag
                ForEach(ex.rollingAvg) { pt in
                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value("e1RM", pt.estimated1RM),
                        series: .value("Type", "Trend")
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(HONTheme.chartSage.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
                // PR step chart (foreground) — separate series
                ForEach(ex.prProgression) { pr in
                    LineMark(
                        x: .value("Date", pr.date),
                        y: .value("e1RM", pr.estimated1RM),
                        series: .value("Type", "PR")
                    )
                    .interpolationMethod(.stepStart)
                    .foregroundStyle(HONTheme.chartSage)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("Date", pr.date),
                        y: .value("e1RM", pr.estimated1RM)
                    )
                    .interpolationMethod(.stepStart)
                    .foregroundStyle(HONTheme.chartSage.opacity(0.10))

                    PointMark(
                        x: .value("Date", pr.date),
                        y: .value("e1RM", pr.estimated1RM)
                    )
                    .foregroundStyle(HONTheme.chartSage)
                    .symbolSize(40)
                }
            }
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 8))
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisValueLabel()
                        .font(.system(size: 8))
                    AxisGridLine()
                }
            }
            .expandingFrame(normal: 140, expanded: 300)

            // Projection line
            if let weeks = weeksNeeded, weeks > 0, weeks < 52, currentMax > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(HONTheme.positive.opacity(0.8))
                    Text("At \(String(format: "+%.1f", ex.slopePerWeek)) kg/wk → \(Int(nextMilestone)) kg e1RM in ~\(weeks) week\(weeks == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            } else if ex.slopePerWeek <= 0.1 {
                HStack(spacing: 5) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(HONTheme.warning.opacity(0.8))
                    Text("No recent upward trend — projection unavailable.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            // Legend
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(HONTheme.chartSage)
                        .frame(width: 16, height: 2)
                    Text("PRs")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(HONTheme.chartSage.opacity(0.5))
                        .frame(width: 16, height: 1.5)
                    Text("Trend")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct VelocityRow: View {
    let analytics: ExerciseAnalytics

    private var phase: LiftPhase { LiftPhase.classify(analytics) }

    private var slopeLabel: String {
        let sign = analytics.slopePerWeek >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", analytics.slopePerWeek)) kg/wk"
    }

    private var hasBaseline: Bool { analytics.sessions.count >= 3 }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(analytics.exercise.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                if hasBaseline {
                    Text(phase.rawValue)
                        .font(.appFootnote)
                        .foregroundStyle(phase.color)
                } else if let e1rm = analytics.sessions.last?.estimated1RM {
                    Text("\(Int(e1rm.rounded())) kg e1RM")
                        .font(.appFootnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)

            // Sparkline from session history
            if analytics.sessions.count >= 2 {
                MiniSparkline(points: analytics.sessions.suffix(8).map(\.estimated1RM),
                              color: phase.color)
                    .frame(width: 56, height: 24)
            } else if analytics.sessions.count == 1 {
                Circle()
                    .fill(phase.color.opacity(0.35))
                    .frame(width: 7, height: 7)
                    .frame(width: 56, height: 24)
            }

            if hasBaseline {
                Text(slopeLabel)
                    .font(.monoValue(12))
                    .foregroundStyle(analytics.slopePerWeek > 0 ? HONTheme.positive
                                     : analytics.slopePerWeek < -0.2 ? HONTheme.negative : HONTheme.warning)
                    .frame(width: 80, alignment: .trailing)
            } else {
                Spacer().frame(width: 80)
            }
        }
        .padding(.vertical, 6)
    }
}

struct MiniSparkline: View {
    let points: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let mn = points.min() ?? 0, mx = points.max() ?? 1
            let range = max(mx - mn, 1)
            let pts = points.enumerated().map { i, v -> CGPoint in
                CGPoint(
                    x: w * CGFloat(i) / CGFloat(max(points.count - 1, 1)),
                    y: h - h * CGFloat((v - mn) / range)
                )
            }
            Path { p in
                guard let first = pts.first else { return }
                p.move(to: first)
                pts.dropFirst().forEach { p.addLine(to: $0) }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - HOW I TRAIN Section

struct HowSectionContent: View {
    let log: [WorkoutLogEntry]
    let analytics: AnalyticsResult

    struct PatternVolume: Identifiable {
        let id = UUID()
        let name: String
        let volume: Double
        let color: Color
    }

    private var patternVolumes: [PatternVolume] {
        var totals: [MovementPattern: Double] = [:]
        for entry in log.prefix(30) {
            for we in entry.exercises {
                totals[we.exercise.movementPattern, default: 0] += we.totalVolume
            }
        }
        let colorMap: [MovementPattern: Color] = [
            .horizontalPush: HONTheme.accent,   .verticalPush:  HONTheme.chartLavender,
            .horizontalPull: HONTheme.chartSage,   .verticalPull:  HONTheme.chartSlate,
            .hipHinge:       HONTheme.warning, .kneeFlexion:   HONTheme.positive,
            .isolation:      HONTheme.chartRose,
        ]
        return totals
            .filter { $0.value > 0 }
            .map { PatternVolume(name: $0.key.shortName, volume: $0.value, color: colorMap[$0.key] ?? .secondary) }
            .sorted { $0.volume > $1.volume }
    }

    struct RepBucket: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
        let color: Color
    }

    private var repBuckets: [RepBucket] {
        let sets = log.prefix(20).flatMap { $0.exercises.flatMap(\.completedSets) }.filter { $0.reps > 0 }
        let buckets: [(String, ClosedRange<Int>, Color)] = [
            ("1–3", 1...3, HONTheme.chartLavender),
            ("4–6", 4...6, HONTheme.accent),
            ("7–9", 7...9, HONTheme.chartSage),
            ("10–12", 10...12, HONTheme.positive),
            ("13+", 13...99, HONTheme.warning),
        ]
        return buckets.map { label, range, color in
            RepBucket(label: label, count: sets.filter { range ~= $0.reps }.count, color: color)
        }
    }

    private var avgDensity: Double {
        let sessions = log.prefix(10).filter { $0.duration > 60 }
        guard !sessions.isEmpty else { return 0 }
        let densities = sessions.map { e -> Double in
            e.totalSets > 0 && e.duration > 0 ? Double(e.totalSets) / (e.duration / 60.0) : 0
        }.filter { $0 > 0 }
        return densities.isEmpty ? 0 : densities.reduce(0, +) / Double(densities.count)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ExpandableChartCard(title: "Volume Balance") {
                    VolumeBalanceCard(patternVolumes: patternVolumes)
                }

                ExpandableChartCard(title: "Rep Range Distribution") {
                    RepRangeCard(repBuckets: repBuckets)
                }
            }

            if avgDensity > 0 {
                ExpandableChartCard(title: "Session Density") {
                    SessionDensityCard(log: log, avgDensity: avgDensity)
                }
            }

            ExpandableChartCard(title: "Workout Duration") {
                WorkoutDurationCard(log: log)
            }

            VolumeHeatmapCard(log: log)
            INOLCalendarCard(log: log)
        }
    }
}

// MARK: - WHAT INFLUENCES ME Section

struct WhatSectionContent: View {
    let log: [WorkoutLogEntry]
    let hrv: Double?
    let sleepHours: Double?
    let restingHR: Double?
    var vo2Max: Double? = nil
    var activeCalories: Double? = nil
    var respiratoryRate: Double? = nil
    var oxygenSaturation: Double? = nil
    var hrvBaseline: Double? = nil
    var hrvHistory: [HealthDataPoint] = []
    var sleepHistory: [HealthDataPoint] = []
    var rhrHistory: [HealthDataPoint] = []

    var body: some View {
        VStack(spacing: 12) {
            ExpandableChartCard(title: "Recovery Signals") { recoveryCard }
            fitnessMetricsCard
            ExpandableChartCard(title: "Feel × Session Volume") { feelScatterCard }
            ExpandableChartCard(title: "Habits & Performance") {
                HabitsPerformanceCard(log: log)
            }
        }
    }

    // Recovery tile
    private var recoveryCard: some View {
        RecoverySignalsCard(
            log: log,
            hrv: hrv,
            sleepHours: sleepHours,
            restingHR: restingHR,
            respiratoryRate: respiratoryRate,
            oxygenSaturation: oxygenSaturation,
            hrvBaseline: hrvBaseline,
            hrvHistory: hrvHistory,
            sleepHistory: sleepHistory,
            rhrHistory: rhrHistory
        )
    }

    @ViewBuilder
    private var fitnessMetricsCard: some View {
        if vo2Max != nil || activeCalories != nil {
            ExpandableChartCard(title: "Fitness Metrics") {
                FitnessMetricsCard(vo2Max: vo2Max, activeCalories: activeCalories)
            }
        }
    }

    private var feelScatterCard: some View {
        FeelVolumeCard(log: log)
    }
}

// MARK: - Volume Balance Card

struct VolumeBalanceCard: View {
    let patternVolumes: [HowSectionContent.PatternVolume]
    @Environment(\.expandedChart) private var isExpanded

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Volume Balance")
                .font(.cardTitle)
            if patternVolumes.isEmpty {
                Text("No data yet.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                let totalVol = patternVolumes.reduce(0) { $0 + $1.volume }
                let push = patternVolumes.filter { $0.name == "H. Push" || $0.name == "V. Push" }.reduce(0) { $0 + $1.volume }
                let pull = patternVolumes.filter { $0.name == "H. Pull" || $0.name == "V. Pull" }.reduce(0) { $0 + $1.volume }
                let ratio = pull > 0 ? push / pull : 0

                Chart(patternVolumes) { pv in
                    SectorMark(angle: .value("Volume", pv.volume),
                               innerRadius: .ratio(0.55), angularInset: 2)
                    .foregroundStyle(pv.color).cornerRadius(4)
                }
                .expandingFrame(normal: 140, expanded: 260)

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(patternVolumes.prefix(isExpanded ? patternVolumes.count : 4)) { pv in
                        HStack(spacing: 6) {
                            Circle().fill(pv.color).frame(width: 7, height: 7)
                            Text(pv.name).font(.system(size: 9)).foregroundStyle(.secondary)
                            Spacer()
                            if totalVol > 0 {
                                Text("\(Int((pv.volume / totalVol * 100).rounded()))%")
                                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Inline insight (F-16) — always visible
                if ratio > 0 {
                    let imbalanced = ratio > 1.3 || ratio < 0.7
                    HStack(spacing: 5) {
                        Image(systemName: imbalanced ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(imbalanced ? HONTheme.warning : HONTheme.positive)
                        Text(ratio > 1.3 ? "Push:Pull = \(String(format: "%.1f", ratio)):1 — add pulling volume"
                             : ratio < 0.7 ? "Pull:Push = \(String(format: "%.1f", 1/ratio)):1 — add horizontal push"
                             : "Push:Pull = \(String(format: "%.1f", ratio)):1 — balanced")
                            .font(.system(size: 10))
                            .foregroundStyle(imbalanced ? HONTheme.warning : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if isExpanded {
                    Divider().padding(.vertical, 4)
                    let dominant = patternVolumes.first?.name ?? "—"
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BALANCE ANALYSIS")
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).kerning(0.5)
                        Text(ratio == 0 ? "No push/pull data yet." :
                             ratio > 1.3 ? "Push:Pull ratio is \(String(format: "%.1f", ratio)):1 — you're pushing significantly more than pulling. Add rowing or pulling movements to prevent shoulder imbalance." :
                             ratio < 0.7 ? "Pull:Push ratio is \(String(format: "%.1f", 1/ratio)):1 — more pulling than pushing. Add horizontal push if you want more chest development." :
                             "Push:Pull ratio is \(String(format: "%.1f", ratio)):1 — well balanced.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Dominant pattern: \(dominant) (\(totalVol > 0 ? Int((patternVolumes[0].volume / totalVol * 100).rounded()) : 0)% of volume). Volume imbalances over months create joint and posture issues. Aim for roughly equal push and pull volume.")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                            .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Rep Range Card

struct RepRangeCard: View {
    let repBuckets: [HowSectionContent.RepBucket]
    @Environment(\.expandedChart) private var isExpanded

    private let goalMap: [String: String] = [
        "1–3": "max strength",
        "4–6": "strength-hypertrophy",
        "7–9": "hypertrophy / strength blend",
        "10–12": "hypertrophy",
        "13+": "muscular endurance"
    ]

    var body: some View {
        let totalSets = repBuckets.reduce(0) { $0 + $1.count }
        let dominant  = repBuckets.max(by: { $0.count < $1.count })
        VStack(alignment: .leading, spacing: 8) {
            Text("Rep Range Distribution")
                .font(.cardTitle)
            Chart(repBuckets) { bucket in
                BarMark(x: .value("Count", bucket.count), y: .value("Range", bucket.label))
                    .foregroundStyle(bucket.color).cornerRadius(4)
                    .annotation(position: .trailing) {
                        let pct = totalSets > 0 ? Int(Double(bucket.count) / Double(totalSets) * 100) : 0
                        Text(pct > 0 ? "\(pct)%" : "").font(.system(size: 8)).foregroundStyle(.secondary)
                    }
            }
            .chartXAxis(.hidden)
            .expandingFrame(normal: 140, expanded: 260)

            Text("Last 20 sessions").font(.appFootnote).foregroundStyle(.secondary)

            // Inline insight (F-17) — always visible
            if let dom = dominant, totalSets > 0 {
                let pct = Int(Double(dom.count) / Double(totalSets) * 100)
                let goal = goalMap[dom.label] ?? "general"
                Text("\(pct)% in \(dom.label) reps — \(goal).")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isExpanded {
                Divider().padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 6) {
                    Text("ZONE BREAKDOWN")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).kerning(0.5)
                    let singleZone = repBuckets.filter { $0.count > 0 }.count <= 1
                    if singleZone {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9)).foregroundStyle(HONTheme.warning)
                            Text("Training almost exclusively in one rep range. Vary across 4–12 reps to develop both strength and hypertrophy and prevent adaptation stalls.")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Text("Different rep ranges stress different fiber types. Strength peaks at 1–5 reps; hypertrophy at 6–20 reps with sufficient effort. Mix zones for complete development.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                        .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Session Density Card

struct SessionDensityCard: View {
    let log: [WorkoutLogEntry]
    let avgDensity: Double
    @Environment(\.expandedChart) private var isExpanded

    private var color: Color { avgDensity >= 0.6 && avgDensity <= 1.3 ? HONTheme.positive : HONTheme.warning }

    private var context: String {
        if avgDensity < 0.5 { return "Below typical — consider shorter rest periods" }
        if avgDensity <= 0.8 { return "Optimal for strength (longer rests, heavier loads)" }
        if avgDensity <= 1.2 { return "Optimal for hypertrophy (60–90 s rest)" }
        return "High density — confirm you're not rushing sets"
    }

    private var sessionDensities: [(Double, Date)] {
        log.prefix(10).compactMap { e -> (Double, Date)? in
            guard e.duration > 60, e.totalSets > 0 else { return nil }
            let d = Double(e.totalSets) / (e.duration / 60.0)
            return d > 0 ? (d, e.startedAt) : nil
        }.reversed()
    }

    private var densityTrend: String {
        let vals = sessionDensities.map { $0.0 }
        guard vals.count >= 4 else { return "" }
        let firstHalf = vals.prefix(vals.count / 2).reduce(0, +) / Double(vals.count / 2)
        let secondHalf = vals.suffix(vals.count / 2).reduce(0, +) / Double(vals.count / 2)
        let delta = secondHalf - firstHalf
        if abs(delta) < 0.05 { return "Stable across recent sessions." }
        return delta > 0
            ? String(format: "Trending up +%.1f sets/min over last 10 sessions — you're getting more efficient.", delta)
            : String(format: "Trending down %.1f sets/min — sessions are getting longer. Check rest times.", delta)
    }

    // F-18 additional metrics
    private var timeOfDayPattern: String {
        let cal = Calendar.current
        let hours = log.prefix(20).map { cal.component(.hour, from: $0.startedAt) }
        guard !hours.isEmpty else { return "" }
        let avg = Double(hours.reduce(0, +)) / Double(hours.count)
        let amCount = hours.filter { $0 < 12 }.count
        let pmCount = hours.count - amCount
        let dominantLabel = amCount > pmCount ? "AM" : "PM"
        let avgHour = Int(avg)
        let suffix = avgHour < 12 ? "AM" : "PM"
        let displayH = avgHour % 12 == 0 ? 12 : avgHour % 12
        return "\(dominantLabel) trainer (\(amCount)AM / \(pmCount)PM). Avg start: \(displayH)\(suffix)."
    }

    private var sessionGapText: String {
        let dates = log.prefix(15).map(\.startedAt).sorted()
        guard dates.count >= 2 else { return "" }
        let gaps = zip(dates, dates.dropFirst()).map { Calendar.current.dateComponents([.day], from: $0, to: $1).day ?? 0 }
        let avg = Double(gaps.reduce(0, +)) / Double(gaps.count)
        return String(format: "Avg gap between sessions: %.1f days", avg)
    }

    private var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var day = cal.startOfDay(for: Date())
        let loggedDays = Set(log.map { cal.startOfDay(for: $0.startedAt) })
        while loggedDays.contains(day) {
            streak += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Image(systemName: "timer").font(.system(size: 14)).foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session Density").font(.system(size: 12, weight: .semibold))
                    Text("Avg across last 10 sessions").font(.appFootnote).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.1f", avgDensity))
                        .font(.monoValue(20)).foregroundStyle(color)
                    Text("sets/min").font(.system(size: 8)).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(context).font(.system(size: 10)).foregroundStyle(.secondary)
            }

            if isExpanded {
                Divider().padding(.vertical, 4)

                if sessionDensities.count >= 2 {
                    let vals = sessionDensities.map { $0.0 }
                    let lo = (vals.min() ?? 0) * 0.85
                    let hi = (vals.max() ?? 2) * 1.15
                    Chart {
                        ForEach(Array(sessionDensities.enumerated()), id: \.offset) { idx, pair in
                            LineMark(x: .value("Session", idx), y: .value("Density", pair.0))
                                .foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                            PointMark(x: .value("Session", idx), y: .value("Density", pair.0))
                                .foregroundStyle(idx == sessionDensities.count - 1 ? color : color.opacity(0.4))
                                .symbolSize(idx == sessionDensities.count - 1 ? 48 : 20)
                        }
                        RuleMark(y: .value("Optimal Low", 0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(HONTheme.positive.opacity(0.4))
                        RuleMark(y: .value("Optimal High", 1.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(HONTheme.positive.opacity(0.4))
                    }
                    .chartYScale(domain: lo...hi)
                    .chartXAxis(.hidden)
                    .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) {
                        AxisValueLabel().font(.system(size: 8))
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                    }}
                    .frame(height: 100)
                }

                if !densityTrend.isEmpty {
                    Text(densityTrend).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // F-18 additional metrics
                VStack(alignment: .leading, spacing: 6) {
                    if !timeOfDayPattern.isEmpty {
                        additionalMetricRow("clock.fill", timeOfDayPattern)
                    }
                    if !sessionGapText.isEmpty {
                        additionalMetricRow("calendar", sessionGapText)
                    }
                    let streak = currentStreak
                    if streak > 0 {
                        additionalMetricRow("flame.fill", "\(streak)-day training streak")
                    }
                }

                Text("Sets/min reflects rest period length and session efficiency. Strength: 0.5–0.8 (long rests). Hypertrophy: 0.8–1.3 (short rests). Very high density may indicate insufficient inter-set recovery.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }

    private func additionalMetricRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Workout Duration Card

struct WorkoutDurationCard: View {
    let log: [WorkoutLogEntry]
    @Environment(\.expandedChart) private var isExpanded

    private struct DurationPoint: Identifiable {
        let id = UUID()
        let date: Date
        let minutes: Double
    }

    private var points: [DurationPoint] {
        log.prefix(15).filter { $0.duration > 60 }
            .map { DurationPoint(date: $0.startedAt, minutes: $0.duration / 60.0) }
            .reversed()
    }

    private var avgMinutes: Double {
        guard !points.isEmpty else { return 0 }
        return points.map(\.minutes).reduce(0, +) / Double(points.count)
    }

    private var trendNote: String {
        guard points.count >= 4 else { return "" }
        let vals = points.map(\.minutes)
        let half = vals.count / 2
        let early = vals.prefix(half).reduce(0, +) / Double(half)
        let recent = vals.suffix(half).reduce(0, +) / Double(half)
        let delta = recent - early
        if abs(delta) < 3 { return "Session length is consistent." }
        return delta > 0
            ? String(format: "Sessions trending +%.0f min longer recently. Check rest times.", delta)
            : String(format: "Sessions trending %.0f min shorter — good efficiency.", abs(delta))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Image(systemName: "clock.fill").font(.system(size: 14)).foregroundStyle(HONTheme.chartLavender)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout Duration").font(.system(size: 12, weight: .semibold))
                    Text("Avg across last 15 sessions").font(.appFootnote).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.0f", avgMinutes))
                        .font(.monoValue(20)).foregroundStyle(HONTheme.chartLavender)
                    Text("min avg").font(.system(size: 8)).foregroundStyle(.secondary)
                }
            }

            if isExpanded, points.count >= 2 {
                Divider().padding(.vertical, 4)

                let lo = (points.map(\.minutes).min() ?? 0) * 0.85
                let hi = (points.map(\.minutes).max() ?? 60) * 1.15
                Chart {
                    ForEach(Array(points.enumerated()), id: \.element.id) { idx, pt in
                        BarMark(x: .value("Session", idx), y: .value("Minutes", pt.minutes))
                            .foregroundStyle(HONTheme.chartLavender.opacity(idx == points.count - 1 ? 0.85 : 0.45))
                            .cornerRadius(3)
                        if avgMinutes > 0 {
                            RuleMark(y: .value("Avg", avgMinutes))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .foregroundStyle(HONTheme.chartLavender.opacity(0.5))
                                .annotation(position: .trailing) {
                                    Text("avg").font(.system(size: 8)).foregroundStyle(.secondary)
                                }
                        }
                    }
                }
                .chartYScale(domain: lo...hi)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { val in
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                        if let v = val.as(Double.self) {
                            AxisValueLabel { Text("\(Int(v))m").font(.system(size: 8)) }
                        }
                    }
                }
                .frame(height: 100)

                if !trendNote.isEmpty {
                    Text(trendNote).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("WHY IT MATTERS: Session length tracks your overall training commitment and recovery needs. Consistently short sessions may mean insufficient stimulus; very long sessions may push recovery costs up. A consistent duration window is a sign of good programme design.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Recovery Signals Card

struct RecoverySignalsCard: View {
    let log: [WorkoutLogEntry]
    let hrv: Double?
    let sleepHours: Double?
    let restingHR: Double?
    let respiratoryRate: Double?
    let oxygenSaturation: Double?
    var hrvBaseline: Double? = nil
    var hrvHistory: [HealthDataPoint] = []
    var sleepHistory: [HealthDataPoint] = []
    var rhrHistory: [HealthDataPoint] = []
    @Environment(\.expandedChart) private var isExpanded

    private func hrvNote(_ v: Double) -> String {
        if let base = hrvBaseline {
            if v >= base * 1.05 { return "Above your baseline — ready for intensity" }
            if v >= base * 0.90 { return "Near your baseline — train as planned" }
            return "Below baseline — prioritise recovery today"
        }
        if v >= 70 { return "High — ready for intensity" }
        if v >= 45 { return "Normal — train as planned" }
        return "Low — prioritise recovery today"
    }

    private var overallReadiness: String {
        var score = 0
        var total = 0
        if let h = hrv {
            if let base = hrvBaseline {
                score += h >= base * 1.05 ? 2 : h >= base * 0.90 ? 1 : 0
            } else {
                score += h >= 70 ? 2 : h >= 45 ? 1 : 0
            }
            total += 2
        }
        if let s = sleepHours { score += s >= 7 ? 2 : s >= 6 ? 1 : 0; total += 2 }
        if let r = restingHR { score += r < 55 ? 2 : r < 65 ? 1 : 0; total += 2 }
        guard total > 0 else { return "" }
        let pct = Double(score) / Double(total)
        if pct >= 0.75 { return "Recovery looks good — push for quality today." }
        if pct >= 0.5 { return "Mixed signals — train as planned but listen to your body." }
        return "Recovery signals are below optimal — consider a lighter session or active recovery."
    }

    private var hasAnyData: Bool {
        hrv != nil || sleepHours != nil || restingHR != nil
            || respiratoryRate != nil || oxygenSaturation != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery Signals").font(.cardTitle)

            if hasAnyData {
                recoveryRow("HRV", value: hrv.map { String(format: "%.0f ms", $0) },
                            fraction: hrv.map { min(1, $0 / 100) }, color: HONTheme.positive,
                            icon: "waveform.path.ecg", note: hrv.map { hrvNote($0) })

                recoveryRow("Sleep", value: sleepHours.map { String(format: "%.1f h", $0) },
                            fraction: sleepHours.map { min(1, $0 / 9) }, color: HONTheme.accent,
                            icon: "moon.zzz.fill",
                            note: sleepHours.map { $0 >= 7 ? "Optimal for recovery" : $0 >= 6 ? "Borderline — aim for 7–9 h" : "Under-recovered — muscle protein synthesis is reduced" })

                recoveryRow("Resting HR", value: restingHR.map { String(format: "%.0f bpm", $0) },
                            fraction: restingHR.map { 1 - min(1, max(0, ($0 - 40) / 50)) },
                            color: HONTheme.chartRose, icon: "heart.fill",
                            note: restingHR.map { $0 < 55 ? "Athletic baseline — excellent" : $0 < 65 ? "Good" : "Elevated — may indicate accumulated fatigue" })

                if let rr = respiratoryRate {
                    recoveryRow("Respiratory Rate", value: String(format: "%.0f br/min", rr),
                                fraction: 1 - min(1, max(0, (rr - 10) / 10)), color: HONTheme.chartSage,
                                icon: "lungs.fill",
                                note: rr < 14 ? "Low — excellent recovery state" : rr < 18 ? "Normal" : "Elevated — may signal stress or illness")
                }

                if let spo2 = oxygenSaturation {
                    recoveryRow("SpO₂", value: String(format: "%.0f%%", spo2),
                                fraction: min(1, (spo2 - 90) / 10), color: HONTheme.chartSlate,
                                icon: "drop.fill",
                                note: spo2 >= 97 ? "Optimal" : spo2 >= 95 ? "Normal" : "Low — check for recovery issues or altitude")
                }

                if let feel = log.first?.feelRating {
                    HStack(spacing: 8) {
                        Image(systemName: "face.smiling.fill").font(.system(size: 12))
                            .foregroundStyle(HONTheme.chartLavender).frame(width: 18)
                        Text("Latest Feel").font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(feel.icon) \(feel.rawValue)").font(.system(size: 11, weight: .semibold))
                    }
                }

                if isExpanded {
                    Divider().padding(.vertical, 2)

                    // Historical trend sparklines (F-22)
                    if !hrvHistory.isEmpty || !sleepHistory.isEmpty || !rhrHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("14-DAY TRENDS")
                                .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).kerning(0.5)
                            if !hrvHistory.isEmpty {
                                recoverySparkline("HRV", points: hrvHistory.suffix(14).map { (date: $0.date, value: $0.value) }, color: HONTheme.positive, unit: "ms")
                            }
                            if !sleepHistory.isEmpty {
                                recoverySparkline("Sleep", points: sleepHistory.suffix(14).map { (date: $0.date, value: $0.value) }, color: HONTheme.accent, unit: "h")
                            }
                            if !rhrHistory.isEmpty {
                                recoverySparkline("Resting HR", points: rhrHistory.suffix(14).map { (date: $0.date, value: $0.value) }, color: HONTheme.chartRose, unit: "bpm")
                            }
                        }
                        Divider().padding(.vertical, 2)
                    }

                    if !overallReadiness.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill").font(.system(size: 11)).foregroundStyle(HONTheme.chartAmber)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(overallReadiness).font(.system(size: 12)).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("HRV is the most reliable readiness signal. Sleep below 7 h reduces muscle protein synthesis by up to 20%. RHR elevated >5 bpm above baseline suggests incomplete recovery.")
                                    .font(.system(size: 10)).foregroundStyle(.secondary)
                                    .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connect Apple Watch")
                            .font(.subheadline.bold())
                        Text("HRV, sleep, and resting HR will appear here once Apple Watch is paired and Health access is granted.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func recoverySparkline(_ label: String, points: [(date: Date, value: Double)], color: Color, unit: String) -> some View {
        if points.count >= 2 {
            let vals = points.map(\.value)
            let lo = (vals.min() ?? 0) * 0.92
            let hi = (vals.max() ?? 1) * 1.08
            let latest = vals.last ?? 0
            let prev   = vals.dropLast().last ?? latest
            let delta  = latest - prev
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color)
                    Spacer()
                    Text(String(format: unit == "h" ? "%.1f \(unit)" : "%.0f \(unit)", latest))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    let sign = delta >= 0 ? "+" : ""
                    Text("\(sign)\(String(format: unit == "h" ? "%.1f" : "%.0f", delta))")
                        .font(.system(size: 9))
                        .foregroundStyle(delta >= 0 ? HONTheme.positive : HONTheme.negative)
                }
                Chart {
                    ForEach(Array(points.enumerated()), id: \.offset) { idx, pt in
                        LineMark(x: .value("Day", idx), y: .value(label, pt.value))
                            .foregroundStyle(color.opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        AreaMark(x: .value("Day", idx), y: .value(label, pt.value))
                            .foregroundStyle(color.opacity(0.08))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: lo...hi)
                .frame(height: 36)
            }
        }
    }

    private func recoveryRow(_ label: String, value: String?, fraction: Double?, color: Color, icon: String, note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color).frame(width: 18)
                Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text(value ?? "—").font(.monoValue(11)).foregroundStyle(value != nil ? color : .secondary)
            }
            if let f = fraction {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.1))
                        Capsule().fill(color.opacity(0.7)).frame(width: geo.size.width * CGFloat(f))
                    }
                }
                .frame(height: 5).padding(.leading, 22)
            }
            if let n = note, value != nil {
                Text(n).font(.system(size: 9)).foregroundStyle(.secondary).padding(.leading, 22)
            }
        }
    }
}

// MARK: - Fitness Metrics Card

struct FitnessMetricsCard: View {
    let vo2Max: Double?
    let activeCalories: Double?
    @Environment(\.expandedChart) private var isExpanded

    private struct VO2Category { let label: String; let color: Color; let context: String }
    private func vo2MaxCategory(_ v: Double) -> VO2Category {
        if v >= 55 { return VO2Category(label: "Superior", color: HONTheme.positive, context: "Top-tier aerobic capacity") }
        if v >= 48 { return VO2Category(label: "Excellent", color: HONTheme.accent,  context: "Well above average") }
        if v >= 42 { return VO2Category(label: "Good",     color: HONTheme.chartSage, context: "Above average") }
        if v >= 35 { return VO2Category(label: "Fair",     color: HONTheme.warning,  context: "HIIT 2–3x/wk will raise this") }
        return          VO2Category(label: "Low",          color: HONTheme.negative, context: "Consistent cardio will help") }

    private func vo2TrainingTip(_ v: Double) -> String {
        if v >= 55 { return "You're in the top 5% for aerobic fitness. Your cardiovascular base supports high training volumes and fast recovery." }
        if v >= 48 { return "Excellent cardiovascular base — you recover well between sets and between sessions. Maintain with 2 cardio sessions/wk." }
        if v >= 42 { return "Good baseline. Improve with 2–3 moderate-intensity sessions of 30+ min/wk (cycling, rowing, running)." }
        if v >= 35 { return "Below-average VO₂ max limits how quickly you recover between hard sets. 3 months of consistent Zone 2 cardio typically raises this 10–15%." }
        return "Low VO₂ max reduces recovery speed. Start with 20–30 min walks or easy cycling 3×/wk and build from there."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fitness Metrics").font(.cardTitle)

            if let vo2 = vo2Max {
                let category = vo2MaxCategory(vo2)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "wind").font(.system(size: 11)).foregroundStyle(HONTheme.accent).frame(width: 18)
                        Text("VO₂ Max").font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f ml/kg/min", vo2)).font(.monoValue(11)).foregroundStyle(HONTheme.accent)
                    }
                    HStack(spacing: 6) {
                        Spacer().frame(width: 22)
                        Text(category.label)
                            .font(.system(size: 9, weight: .semibold)).foregroundStyle(category.color)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(category.color.opacity(0.12), in: Capsule())
                        Text(category.context).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.1))
                            Capsule().fill(HONTheme.accent.opacity(0.6))
                                .frame(width: geo.size.width * CGFloat(min(1, (vo2 - 20) / 45)))
                        }
                    }
                    .frame(height: 5).padding(.leading, 22)

                    if isExpanded {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill").font(.system(size: 10)).foregroundStyle(HONTheme.chartAmber)
                            Text(vo2TrainingTip(vo2)).font(.system(size: 11)).foregroundStyle(.secondary)
                                .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 4)
                    }
                }
            }

            if let kcal = activeCalories {
                HStack {
                    Image(systemName: "flame.fill").font(.system(size: 11)).foregroundStyle(HONTheme.warning).frame(width: 18)
                    Text("Active Calories").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f kcal today", kcal)).font(.monoValue(11)).foregroundStyle(HONTheme.warning)
                }
                if isExpanded {
                    Text("WHY IT MATTERS: Active calorie expenditure drives your daily energy balance. Insufficient intake vs. expenditure slows muscle protein synthesis and recovery. Strength training typically burns 4–8 kcal/min of work time.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                        .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 22)
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Feel × Volume Card

struct FeelVolumeCard: View {
    let log: [WorkoutLogEntry]
    @Environment(\.expandedChart) private var isExpanded

    private struct FPPoint: Identifiable {
        let id = UUID()
        let feel: Int; let jitter: Double; let perfPct: Double; let feelColor: Color
    }

    private var feelPoints: [FPPoint] {
        guard !log.isEmpty else { return [] }
        let vols = log.prefix(30).map(\.totalVolume)
        let avg  = vols.isEmpty ? 1 : vols.reduce(0, +) / Double(vols.count)
        return log.prefix(30).compactMap { entry -> FPPoint? in
            guard let feel = entry.feelRating, entry.totalVolume > 0, avg > 0 else { return nil }
            let fi: Int; let color: Color
            switch feel {
            case .easy:   fi = 1; color = HONTheme.positive.opacity(0.5)
            case .strong: fi = 2; color = HONTheme.positive
            case .normal: fi = 3; color = HONTheme.accent
            case .tired:  fi = 4; color = HONTheme.negative
            case .brutal: fi = 5; color = HONTheme.negative.opacity(0.7)
            }
            let seed = entry.startedAt.timeIntervalSince1970.truncatingRemainder(dividingBy: 1000)
            return FPPoint(feel: fi, jitter: (seed / 1000.0 - 0.5) * 0.28, perfPct: entry.totalVolume / avg * 100, feelColor: color)
        }
    }

    private var correlationInsight: String {
        let pts = feelPoints
        guard pts.count >= 4 else { return "" }
        let tiredAvg = pts.filter { $0.feel == 1 }.map(\.perfPct).average
        let normalAvg = pts.filter { $0.feel == 2 }.map(\.perfPct).average
        let strongAvg = pts.filter { $0.feel == 3 }.map(\.perfPct).average
        var parts: [String] = []
        if let s = strongAvg, let t = tiredAvg, s > t + 5 {
            parts.append("When you feel Strong you produce \(Int(s - (t))) % more volume than Tired days.")
        }
        if let n = normalAvg, let t = tiredAvg, n > t + 5 {
            parts.append("Even Normal sessions beat Tired sessions by \(Int(n - t))%.")
        }
        if parts.isEmpty {
            return "Your output is consistent regardless of how you feel — a sign of mental toughness or accurate self-assessment."
        }
        return parts.joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Feel × Session Volume").font(.cardTitle)
                Text("Does how you feel predict output? This chart answers it from your own data.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }

            if feelPoints.count >= 3 {
                Chart(feelPoints) { pt in
                    PointMark(x: .value("Feel", Double(pt.feel) + pt.jitter),
                              y: .value("Volume %", pt.perfPct))
                    .foregroundStyle(pt.feelColor.opacity(0.55)).symbolSize(48)
                }
                .chartXScale(domain: 0...4)
                .chartXAxis {
                    AxisMarks(values: [1, 2, 3]) { val in
                        AxisValueLabel {
                            switch val.as(Int.self) {
                            case 1: Text("Tired").font(.system(size: 8))
                            case 2: Text("Normal").font(.system(size: 8))
                            case 3: Text("Strong").font(.system(size: 8))
                            default: Text("")
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) {
                        AxisValueLabel().font(.system(size: 8)); AxisGridLine()
                    }
                }
                .expandingFrame(normal: 150, expanded: 300)
                .chartYAxisLabel("Volume %", position: .leading)

                Text("Volume relative to your average session.").font(.appFootnote).foregroundStyle(.secondary)

                // Correlation insight — always visible (F-23)
                if !correlationInsight.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "lightbulb.fill").font(.system(size: 10)).foregroundStyle(HONTheme.chartAmber)
                        Text(correlationInsight).font(.system(size: 11)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true).lineSpacing(2)
                    }
                }

                if isExpanded {
                    Divider().padding(.vertical, 4)
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "brain.filled.head.profile").font(.system(size: 11)).foregroundStyle(HONTheme.chartLavender)
                        Text("Takeaway: On Tired days, still show up — aim for 80% effort. Even reduced-volume sessions preserve more strength than skipping, and consistent attendance compounds over months.")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                            .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text("Log workouts with feel ratings to see correlation.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(height: 100, alignment: .center).frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }
}

private extension Array where Element == Double {
    var average: Double? {
        isEmpty ? nil : reduce(0, +) / Double(count)
    }
}

// MARK: - Habits & Performance Card

// MARK: - Habit & Training metric enums for configurable correlation card

enum HabitMetric: String, CaseIterable, Identifiable {
    case sleep     = "Sleep"
    case hrv       = "HRV"
    case restingHR = "Resting HR"
    case steps     = "Steps"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .sleep:     return "moon.zzz.fill"
        case .hrv:       return "waveform.path.ecg"
        case .restingHR: return "heart.fill"
        case .steps:     return "figure.walk"
        }
    }
    var unit: String {
        switch self {
        case .sleep:     return "hrs"
        case .hrv:       return "ms"
        case .restingHR: return "bpm"
        case .steps:     return "k steps"
        }
    }
    var color: Color {
        switch self {
        case .sleep:     return HONTheme.accent
        case .hrv:       return HONTheme.positive
        case .restingHR: return HONTheme.chartRose
        case .steps:     return HONTheme.chartSage
        }
    }
}

enum TrainingMetric: String, CaseIterable, Identifiable {
    case volume   = "Volume %"
    case feel     = "Feel"
    case sets     = "Sets"
    case duration = "Duration"
    case bestE1RM = "e1RM"
    var id: String { rawValue }
}

// MARK: - Habits & Performance (fully configurable)

struct HabitsPerformanceCard: View {
    let log: [WorkoutLogEntry]
    @Environment(\.expandedChart) private var isExpanded
    @Environment(HealthKitService.self) private var health

    @State private var habitMetric:    HabitMetric    = .sleep
    @State private var trainingMetric: TrainingMetric = .volume
    @State private var habitFirst:     Bool           = true

    private struct DataPair: Identifiable {
        let id = UUID()
        let x: Double
        let y: Double
    }

    // Raw health data for the selected habit
    private var activeHealthData: [HealthDataPoint] {
        switch habitMetric {
        case .sleep:     return health.sleepHistory
        case .hrv:       return health.hrvHistory
        case .restingHR: return health.restingHRHistory
        case .steps:     return health.stepsHistory
        }
    }

    private func healthDisplayVal(_ raw: Double) -> Double {
        habitMetric == .steps ? raw / 1000.0 : raw
    }

    private var avgVolume: Double {
        let vols = log.prefix(60).map(\.totalVolume)
        return vols.isEmpty ? 1 : vols.reduce(0, +) / Double(vols.count)
    }

    private func trainingVal(from entry: WorkoutLogEntry) -> Double? {
        switch trainingMetric {
        case .volume:
            return avgVolume > 0 ? entry.totalVolume / avgVolume * 100 : nil
        case .feel:
            guard let f = entry.feelRating else { return nil }
            switch f { case .easy: return 1; case .strong: return 2; case .normal: return 3; case .tired: return 4; case .brutal: return 5 }
        case .sets:
            return entry.totalSets > 0 ? Double(entry.totalSets) : nil
        case .duration:
            return entry.duration > 0 ? entry.duration / 60.0 : nil
        case .bestE1RM:
            let best = entry.exercises.flatMap(\.completedSets).map(\.estimated1RM).max()
            return (best ?? 0) > 0 ? best : nil
        }
    }

    private var pairs: [DataPair] {
        let cal = Calendar.current
        let hMap = Dictionary(
            activeHealthData.map { (cal.startOfDay(for: $0.date), healthDisplayVal($0.value)) },
            uniquingKeysWith: { a, _ in a }
        )
        return log.prefix(60).compactMap { entry -> DataPair? in
            guard entry.totalVolume > 0, let sv = trainingVal(from: entry) else { return nil }
            let workoutDay = cal.startOfDay(for: entry.startedAt)
            let prevDay    = cal.date(byAdding: .day, value: -1, to: workoutDay)!
            let nextDay    = cal.date(byAdding: .day, value:  1, to: workoutDay)!
            let hv: Double?
            if habitFirst {
                hv = hMap[prevDay] ?? hMap[workoutDay]
            } else {
                hv = hMap[nextDay] ?? hMap[workoutDay]
            }
            guard let hv else { return nil }
            return habitFirst ? DataPair(x: hv, y: sv) : DataPair(x: sv, y: hv)
        }
    }

    private func pearson(_ xs: [Double], _ ys: [Double]) -> Double {
        guard xs.count == ys.count, xs.count >= 3 else { return 0 }
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n; let my = ys.reduce(0, +) / n
        let num = zip(xs, ys).reduce(0.0) { $0 + ($1.0 - mx) * ($1.1 - my) }
        let dx = xs.reduce(0.0) { $0 + pow($1 - mx, 2) }
        let dy = ys.reduce(0.0) { $0 + pow($1 - my, 2) }
        let denom = (dx * dy).squareRoot()
        return denom == 0 ? 0 : num / denom
    }

    private var r: Double { pairs.count >= 3 ? pearson(pairs.map(\.x), pairs.map(\.y)) : 0 }

    private func correlationLabel(_ r: Double) -> (String, Color) {
        let a = Swift.abs(r); let dir = r >= 0 ? "↑" : "↓"
        if a >= 0.5 { return ("\(dir) Strong", HONTheme.positive) }
        if a >= 0.3 { return ("\(dir) Moderate", HONTheme.accent) }
        if a >= 0.1 { return ("\(dir) Weak", HONTheme.warning) }
        return ("≈ None", .secondary)
    }

    private var xLabel: String { habitFirst ? "\(habitMetric.rawValue) (\(habitMetric.unit))" : trainingMetric.rawValue }
    private var yLabel: String { habitFirst ? trainingMetric.rawValue : "\(habitMetric.rawValue) (\(habitMetric.unit))" }
    private var directionLabel: String {
        habitFirst
            ? "\(habitMetric.rawValue) → \(trainingMetric.rawValue)"
            : "\(trainingMetric.rawValue) → \(habitMetric.rawValue)"
    }

    private var insight: String {
        guard pairs.count >= 4 else {
            return "Keep logging — need at least 4 sessions with \(habitMetric.rawValue) data to see a pattern."
        }
        let absR = Swift.abs(r)
        let direction: String
        if r > 0.05 {
            direction = habitFirst
                ? "higher \(habitMetric.rawValue) links to better \(trainingMetric.rawValue)"
                : "higher \(trainingMetric.rawValue) links to better \(habitMetric.rawValue)"
        } else if r < -0.05 {
            direction = habitFirst
                ? "higher \(habitMetric.rawValue) links to lower \(trainingMetric.rawValue)"
                : "higher \(trainingMetric.rawValue) links to lower \(habitMetric.rawValue)"
        } else {
            return "No clear relationship between \(habitMetric.rawValue) and \(trainingMetric.rawValue) in your data yet."
        }
        if absR >= 0.5 {
            return "Strong signal (\(pairs.count) sessions): \(direction). This pattern is reliable enough to plan around."
        } else if absR >= 0.3 {
            return "Moderate link (\(pairs.count) sessions): \(direction). Keep logging to confirm."
        }
        return "Weak link (\(pairs.count) sessions): \(direction). More sessions will clarify this."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Habits & Performance")
                    .font(.cardTitle)
                Text("Explore how health and training metrics relate")
                    .font(.appFootnote).foregroundStyle(.secondary)
            }

            // Health metric picker
            VStack(alignment: .leading, spacing: 4) {
                Text("HEALTH METRIC")
                    .font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary).kerning(0.5)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(HabitMetric.allCases) { metric in
                            Button {
                                habitMetric = metric
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: metric.icon).font(.system(size: 10))
                                    Text(metric.rawValue).font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(
                                    habitMetric == metric
                                        ? metric.color.opacity(0.2)
                                        : AppTheme.insetBG,
                                    in: Capsule()
                                )
                                .foregroundStyle(habitMetric == metric ? metric.color : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Training metric picker
            VStack(alignment: .leading, spacing: 4) {
                Text("TRAINING METRIC")
                    .font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary).kerning(0.5)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(TrainingMetric.allCases) { metric in
                            Button {
                                trainingMetric = metric
                            } label: {
                                Text(metric.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(
                                        trainingMetric == metric
                                            ? HONTheme.chartSlate.opacity(0.25)
                                            : AppTheme.insetBG,
                                        in: Capsule()
                                    )
                                    .foregroundStyle(trainingMetric == metric ? HONTheme.chartSlate : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Direction toggle
            Button {
                habitFirst.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                    Text(habitFirst ? "Habit drives training" : "Training drives habit")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text(directionLabel)
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            // Correlation chip + chart
            if pairs.count >= 3 {
                let (label, color) = correlationLabel(r)
                HStack(spacing: 8) {
                    Image(systemName: habitMetric.icon)
                        .font(.system(size: 10)).foregroundStyle(habitMetric.color)
                    Text(directionLabel).font(.system(size: 10, weight: .semibold))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(color)
                        Text("r = \(String(format: "%.2f", r)) · n=\(pairs.count)")
                            .font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(directionLabel.uppercased())
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).kerning(0.5)
                    Chart(pairs) { pair in
                        PointMark(
                            x: .value(xLabel, pair.x),
                            y: .value(yLabel, pair.y)
                        )
                        .foregroundStyle(habitMetric.color.opacity(0.65))
                        .symbolSize(44)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisValueLabel().font(.system(size: 8)); AxisGridLine()
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisValueLabel().font(.system(size: 8)); AxisGridLine()
                        }
                    }
                    .chartXAxisLabel(xLabel, position: .bottom, alignment: .center)
                    .chartYAxisLabel(yLabel, position: .leading)
                    .expandingFrame(normal: 150, expanded: 260)

                    if trainingMetric == .feel {
                        Text("Feel: 1 = Tired · 2 = Normal · 3 = Strong")
                            .font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Not enough matched data yet — need ≥ 3 sessions with \(habitMetric.rawValue) recorded.")
                    .font(.appFootnote).foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }

            // Insight sentence
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: habitMetric.icon)
                    .font(.system(size: 10)).foregroundStyle(habitMetric.color)
                Text(insight).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).lineSpacing(2)
            }

            if isExpanded {
                Divider().padding(.vertical, 2)
                Text("WHY IT MATTERS: Tracking the relationship between lifestyle habits and training output reveals your personal recovery signature. Sleep drives muscle protein synthesis and growth hormone release. HRV reflects nervous system readiness. Resting HR and steps capture overall activity load. Reversing the direction shows how hard training affects your next night of recovery — useful for managing overreach.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - CARDIO PERFORMANCE Section

// MARK: - Exercise Rep Trend model

private struct ExerciseRepTrend: Identifiable {
    let id = UUID()
    let exerciseName: String
    let exerciseId: UUID
    let points: [(index: Int, avgReps: Double)]
    let trend: Double
    var isImproving: Bool { trend > 0.1 }
}

private struct NamedPoint: Identifiable {
    let index: Int
    let value: Double
    var id: Int { index }
}

struct CardioSectionContent: View {
    let cardioLog: [CardioLogEntry]
    var vo2Max: Double? = nil

    private var cal: Calendar { Calendar.current }

    private var thisWeekSessions: Int {
        let today = cal.startOfDay(for: Date())
        let days = (cal.component(.weekday, from: today) + 5) % 7
        let start = cal.date(byAdding: .day, value: -days, to: today)!
        return cardioLog.filter { $0.startedAt >= start }.count
    }

    private var lastWeekSessions: Int {
        let today = cal.startOfDay(for: Date())
        let days = (cal.component(.weekday, from: today) + 5) % 7
        let thisStart = cal.date(byAdding: .day, value: -days, to: today)!
        let lastStart = cal.date(byAdding: .day, value: -7, to: thisStart)!
        return cardioLog.filter { $0.startedAt >= lastStart && $0.startedAt < thisStart }.count
    }

    private var totalRounds: Int { cardioLog.reduce(0) { $0 + $1.completedRounds } }
    private var totalReps: Int   { cardioLog.reduce(0) { $0 + $1.totalReps } }

    private var avgRepsPerMin: Double {
        let valid = cardioLog.filter { $0.durationMinutes > 0 }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0.0) { $0 + Double($1.totalReps) / Double($1.durationMinutes) } / Double(valid.count)
    }

    // Last 8 sessions — rounds per session for sparkline
    private struct RoundPoint: Identifiable {
        let id = UUID()
        let index: Int
        let rounds: Int
        let format: CircuitFormat
    }

    private var recentPoints: [RoundPoint] {
        Array(cardioLog.prefix(8).reversed().enumerated().map {
            RoundPoint(index: $0.offset, rounds: $0.element.completedRounds, format: $0.element.format)
        })
    }

    var body: some View {
        VStack(spacing: 12) {
            // VO2 Max badge
            if let vo2 = vo2Max {
                vo2MaxRow(vo2)
            }

            // Stats row
            HStack(spacing: 10) {
                cardioStatCell(icon: "bolt.heart.fill", color: HONTheme.warning,
                               label: "This Week", value: "\(thisWeekSessions)",
                               delta: thisWeekSessions != lastWeekSessions
                                   ? (thisWeekSessions > lastWeekSessions ? "+\(thisWeekSessions - lastWeekSessions) vs last" : "\(thisWeekSessions - lastWeekSessions) vs last")
                                   : lastWeekSessions > 0 ? "same as last" : nil,
                               deltaUp: thisWeekSessions >= lastWeekSessions)

                cardioStatCell(icon: "arrow.clockwise.circle.fill", color: HONTheme.accent,
                               label: "Total Rounds", value: "\(totalRounds)", delta: nil, deltaUp: true)

                if avgRepsPerMin > 0 {
                    cardioStatCell(icon: "figure.run", color: HONTheme.positive,
                                   label: "Avg Reps/Min", value: String(format: "%.0f", avgRepsPerMin),
                                   delta: nil, deltaUp: true)
                }
            }

            // Estimated HR zone distribution
            if cardioLog.count >= 3 {
                hrZoneRow
            }

            // Cardio density trend (pace proxy)
            if paceTrendPoints.count >= 3 {
                paceTrendSection
            }

            // Rounds trend sparkline
            if recentPoints.count >= 2 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ROUNDS PER SESSION")
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary).kerning(0.6)
                    Chart(recentPoints) { pt in
                        BarMark(x: .value("Session", pt.index),
                                y: .value("Rounds", pt.rounds))
                            .foregroundStyle(pt.format == .amrap ? HONTheme.accent : HONTheme.warning)
                            .cornerRadius(3)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) {
                            AxisValueLabel().font(.system(size: 8))
                            AxisGridLine()
                        }
                    }
                    .frame(height: 60)

                    HStack(spacing: 10) {
                        Label("AMRAP", systemImage: "circle.fill")
                            .font(.system(size: 9)).foregroundStyle(HONTheme.accent)
                        Label("EMOM", systemImage: "circle.fill")
                            .font(.system(size: 9)).foregroundStyle(HONTheme.warning)
                    }
                }
                .padding(12)
                .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
            }

            // Per-exercise reps progression
            if !exerciseTrends.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("EXERCISE PROGRESSION")
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary).kerning(0.6)

                    ForEach(exerciseTrends) { trend in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trend.exerciseName).font(.caption.bold())
                                HStack(spacing: 4) {
                                    Image(systemName: trend.isImproving ? "arrow.up.right" : "minus")
                                        .font(.system(size: 9))
                                        .foregroundStyle(trend.isImproving ? HONTheme.positive : .secondary)
                                    Text(trend.isImproving ? "improving" : "holding")
                                        .font(.system(size: 9)).foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 90, alignment: .leading)

                            Chart(trend.points.map { NamedPoint(index: $0.index, value: $0.avgReps) }) { pt in
                                LineMark(x: .value("Session", pt.index), y: .value("Reps", pt.value))
                                    .foregroundStyle(trend.isImproving ? HONTheme.positive : HONTheme.warning)
                                AreaMark(x: .value("Session", pt.index), y: .value("Reps", pt.value))
                                    .foregroundStyle(trend.isImproving ? HONTheme.positive.opacity(0.15) : HONTheme.warning.opacity(0.1))
                            }
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                            .frame(height: 36)

                            Text(String(format: "%.0f avg", trend.points.last?.avgReps ?? 0))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(HONTheme.textPrimary)
                                .frame(width: 44, alignment: .trailing)
                        }
                        .padding(10)
                        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            // HIIT recovery note
            if cardioLog.count >= 3 {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("For HIIT, track HRV and resting HR in \"What Influences Me\" — they're the strongest indicators of readiness for high-intensity work.")
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(1.5)
                }
                .padding(10)
                .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var exerciseTrends: [ExerciseRepTrend] {
        var byExercise: [UUID: (name: String, sessions: [(index: Int, avg: Double)])] = [:]
        let sorted = cardioLog.sorted { $0.startedAt < $1.startedAt }
        for (sessionIdx, entry) in sorted.enumerated() {
            for ce in entry.exercises {
                let relevant = entry.results.filter { $0.exerciseId == ce.id }
                guard !relevant.isEmpty else { continue }
                let avg = Double(relevant.reduce(0) { $0 + $1.repsCompleted }) / Double(relevant.count)
                if byExercise[ce.id] == nil {
                    byExercise[ce.id] = (ce.exercise.name, [])
                }
                byExercise[ce.id]!.sessions.append((sessionIdx, avg))
            }
        }
        return byExercise
            .filter { $0.value.sessions.count >= 3 }
            .map { (id, data) in
                let pts = data.sessions.enumerated().map { (i, s) in (index: i, avgReps: s.avg) }
                let slope = CardioInsightEngine.linearSlope(pts.map(\.avgReps))
                return ExerciseRepTrend(exerciseName: data.name, exerciseId: id, points: pts, trend: slope)
            }
            .sorted { $0.points.count > $1.points.count }
            .prefix(3)
            .map { $0 }
    }

    // MARK: VO2 Max

    private struct VO2Band { let label: String; let color: Color; let tip: String }
    private func vo2Category(_ v: Double) -> VO2Band {
        if v >= 55 { return VO2Band(label: "Superior", color: HONTheme.positive,   tip: "Top-tier aerobic base — sustain high HIIT frequency") }
        if v >= 48 { return VO2Band(label: "Excellent", color: HONTheme.accent,    tip: "Well above average — zone 4 work will push this higher") }
        if v >= 42 { return VO2Band(label: "Good",      color: HONTheme.chartSage, tip: "Above average — add one steady-state session per week") }
        if v >= 35 { return VO2Band(label: "Fair",      color: HONTheme.warning,   tip: "HIIT 2–3×/wk will raise aerobic ceiling") }
        return        VO2Band(label: "Low",       color: HONTheme.negative,  tip: "Consistent cardio 3×/wk is the highest-ROI intervention")
    }

    @ViewBuilder private func vo2MaxRow(_ vo2: Double) -> some View {
        let band = vo2Category(vo2)
        HStack(spacing: 12) {
            Image(systemName: "lungs.fill")
                .font(.system(size: 18)).foregroundStyle(band.color)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("VO₂ Max").font(.system(size: 11, weight: .semibold))
                    Text(String(format: "%.1f ml/kg/min", vo2))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(band.color)
                    Text(band.label)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(band.color.opacity(0.15), in: Capsule())
                        .foregroundStyle(band.color)
                }
                Text(band.tip).font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: HR Zone Estimate

    private var hrZoneRow: some View {
        let amrap = cardioLog.filter { $0.format == .amrap }.count
        let emom  = cardioLog.filter { $0.format == .emom  }.count
        let total = cardioLog.count
        // AMRAP maps to Zone 4–5, EMOM maps to Zone 3–4 (HR estimate by format)
        let highPct  = total > 0 ? Double(amrap) / Double(total) : 0   // Zone 4–5
        let modPct   = total > 0 ? Double(emom)  / Double(total) : 0   // Zone 3–4
        let lowPct   = max(0, 1 - highPct - modPct)
        return VStack(alignment: .leading, spacing: 6) {
            Text("ESTIMATED HR ZONES")
                .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary).kerning(0.6)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if lowPct > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(HONTheme.chartSage.opacity(0.7))
                            .frame(width: geo.size.width * CGFloat(lowPct))
                    }
                    if modPct > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(HONTheme.warning.opacity(0.8))
                            .frame(width: geo.size.width * CGFloat(modPct))
                    }
                    if highPct > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(HONTheme.negative.opacity(0.85))
                            .frame(width: geo.size.width * CGFloat(highPct))
                    }
                }
            }
            .frame(height: 14)
            HStack(spacing: 12) {
                Label("Zone 2–3", systemImage: "circle.fill").font(.system(size: 8))
                    .foregroundStyle(HONTheme.chartSage)
                Label("Zone 3–4 (EMOM)", systemImage: "circle.fill").font(.system(size: 8))
                    .foregroundStyle(HONTheme.warning)
                Label("Zone 4–5 (AMRAP)", systemImage: "circle.fill").font(.system(size: 8))
                    .foregroundStyle(HONTheme.negative)
            }
            Text("Zone estimate based on circuit format — connect a HR monitor for exact data.")
                .font(.system(size: 8)).foregroundStyle(.tertiary).italic()
        }
        .padding(12)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Pace Trend (reps/min over sessions)

    private struct PacePoint: Identifiable {
        let id = UUID()
        let index: Int
        let repsPerMin: Double
    }

    private var paceTrendPoints: [PacePoint] {
        cardioLog
            .filter { $0.durationMinutes > 0 && $0.totalReps > 0 }
            .sorted { $0.startedAt < $1.startedAt }
            .suffix(10)
            .enumerated()
            .map { PacePoint(index: $0.offset, repsPerMin: Double($0.element.totalReps) / Double($0.element.durationMinutes)) }
    }

    private var paceTrend: Double {
        CardioInsightEngine.linearSlope(paceTrendPoints.map(\.repsPerMin))
    }

    private var paceTrendSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("PACE TREND (REPS/MIN)")
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary).kerning(0.6)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: paceTrend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9))
                        .foregroundStyle(paceTrend >= 0 ? HONTheme.positive : HONTheme.warning)
                    Text(paceTrend >= 0 ? "improving" : "declining")
                        .font(.system(size: 9))
                        .foregroundStyle(paceTrend >= 0 ? HONTheme.positive : HONTheme.warning)
                }
            }
            Chart(paceTrendPoints) { pt in
                LineMark(x: .value("Session", pt.index), y: .value("Rep/Min", pt.repsPerMin))
                    .foregroundStyle(paceTrend >= 0 ? HONTheme.positive : HONTheme.warning)
                AreaMark(x: .value("Session", pt.index), y: .value("Rep/Min", pt.repsPerMin))
                    .foregroundStyle((paceTrend >= 0 ? HONTheme.positive : HONTheme.warning).opacity(0.12))
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) {
                    AxisValueLabel().font(.system(size: 8))
                    AxisGridLine()
                }
            }
            .frame(height: 56)
        }
        .padding(12)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
    }

    private func cardioStatCell(icon: String, color: Color, label: String,
                                value: String, delta: String?, deltaUp: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded))
            if let d = delta {
                Text(d).font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(d.hasPrefix("same") ? Color.secondary : deltaUp ? HONTheme.positive : HONTheme.negative)
            }
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - EMERGENT INSIGHTS Section

struct InsightsSectionContent: View {
    let insights: [EmergentInsight]

    var body: some View {
        VStack(spacing: 10) {
            if insights.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles").font(.title2).foregroundStyle(.secondary)
                    Text("Insights unlock as you log more sessions.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text("Connect Apple Health for sleep, HRV, and cardio correlations.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            // Active alerts strip
            let alerts = insights.filter { $0.severity == .alert && $0.dataAvailable }
            if !alerts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(alerts) { a in
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(HONTheme.negative)
                                    .font(.system(size: 13))
                                Text("\(a.title): \(a.stateName)")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(HONTheme.negative.opacity(0.1), in: Capsule())
                            .overlay(Capsule().stroke(HONTheme.negative.opacity(0.3), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            // 2-column grid of insight cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(insights) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
    }
}

struct InsightCard: View {
    let insight: EmergentInsight
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(insight.title)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .kerning(0.3)
                        .lineLimit(1)
                    Text(insight.inputsLabel)
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .padding(.bottom, 8)

                if insight.dataAvailable {
                    Text(insight.stateName)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(insight.stateColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(insight.implication)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                    // Proof line — show the data backing the claim (F-24)
                    if !insight.dataPoint.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.tertiary)
                            Text(insight.dataPoint)
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 3)
                    }
                } else {
                    Text("LEARNING")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 6)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(insight.severityColor.opacity(insight.dataAvailable ? 0.4 : 0.1), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            InsightDetailSheet(insight: insight)
        }
    }
}

// MARK: - Development Tier Detail Sheet

struct DevelopmentTierDetailSheet: View {
    let analytics: AnalyticsResult
    @Environment(\.dismiss) private var dismiss

    private struct PatternRow {
        let shortName: String
        let fullName: String
        let examples: String
        let pattern: MovementPattern
    }

    private let patternRows: [PatternRow] = [
        PatternRow(shortName: "H. Push",   fullName: "Horizontal Push", examples: "Bench Press, DB Press, Push-Up",              pattern: .horizontalPush),
        PatternRow(shortName: "V. Pull",   fullName: "Vertical Pull",   examples: "Pull-Up, Lat Pulldown, Chin-Up",              pattern: .verticalPull),
        PatternRow(shortName: "V. Push",   fullName: "Vertical Push",   examples: "Overhead Press, DB Shoulder Press",           pattern: .verticalPush),
        PatternRow(shortName: "Squat",     fullName: "Knee Flexion",    examples: "Squat, Leg Press, Hack Squat",                pattern: .kneeFlexion),
        PatternRow(shortName: "Hinge",     fullName: "Hip Hinge",       examples: "Deadlift, Romanian Deadlift, Hip Thrust",     pattern: .hipHinge),
        PatternRow(shortName: "Isolation", fullName: "Isolation",       examples: "Curl, Tricep Extension, Lateral Raise",      pattern: .isolation),
    ]

    private var rateMap: [MovementPattern: Double] {
        Dictionary(analytics.categoryAnalytics.map { ($0.pattern, $0.improvementRatePerWeek) },
                   uniquingKeysWith: { a, _ in a })
    }

    private func gradeInfo(_ rate: Double?) -> (String, Color) {
        guard let r = rate else { return ("—", .secondary) }
        if r > 1.0 { return ("Fast",   HONTheme.positive) }
        if r > 0.5 { return ("Steady", HONTheme.accent) }
        if r > 0.0 { return ("Slow",   HONTheme.warning) }
        return ("Stalled", HONTheme.negative)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Concept
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What is Development Tier?")
                            .font(.system(size: 14, weight: .bold))
                        Text("Each movement pattern is rated on how fast your estimated 1-rep max (e1RM) is improving week over week. This reflects your adaptation velocity — not your absolute strength level. 'Fast' in Squat means you're progressing quickly there right now, regardless of how heavy you lift.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))

                    // Grade scale
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Progress Scale")
                            .font(.system(size: 13, weight: .bold))
                        gradeLegendRow("Fast",    color: HONTheme.positive, desc: "Progressing fast — e1RM growing more than 1% per week")
                        gradeLegendRow("Steady",  color: HONTheme.accent,   desc: "Steady progress — gaining 0.5–1% per week")
                        gradeLegendRow("Slow",    color: HONTheme.warning,  desc: "Slow progress — improving but under 0.5% per week")
                        gradeLegendRow("Stalled", color: HONTheme.negative, desc: "Stagnant or declining — no meaningful upward trend")
                        gradeLegendRow("—",       color: .secondary,        desc: "Not enough data yet — log 3+ sessions to unlock")
                    }
                    .padding(16)
                    .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))

                    // Per-pattern breakdown
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Your Patterns")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.bottom, 12)
                        ForEach(Array(patternRows.enumerated()), id: \.offset) { i, row in
                            let rate = rateMap[row.pattern]
                            let (grade, color) = gradeInfo(rate)
                            HStack(alignment: .top, spacing: 14) {
                                Text(grade)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(color)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(color.opacity(0.12), in: Capsule())
                                    .frame(width: 58, alignment: .leading)
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(row.fullName)
                                            .font(.system(size: 13, weight: .semibold))
                                        Spacer()
                                        if let r = rate {
                                            Text(String(format: "%+.2f%%/wk", r))
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(color)
                                        } else {
                                            Text("No data")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    Text(row.examples)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 10)
                            if i < patternRows.count - 1 { Divider() }
                        }
                    }
                    .padding(16)
                    .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(16)
            }
            .background(AppTheme.pageBG)
            .navigationTitle("Development Tier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func gradeLegendRow(_ grade: String, color: Color, desc: String) -> some View {
        HStack(spacing: 12) {
            Text(grade)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 52, alignment: .leading)
            Text(desc)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Archetype Top Badge

struct ArchetypeTopBadge: View {
    let log: [WorkoutLogEntry]
    @State private var showDetail = false

    var body: some View {
        let archetype = TrainingArchetype.classify(log: log)
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(archetype.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "person.fill.checkmark")
                    .font(.system(size: 15))
                    .foregroundStyle(archetype.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Training Archetype")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(archetype.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(archetype.color)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            ArchetypeDetailSheet(archetype: archetype, log: log)
        }
    }
}

// MARK: - Archetype Detail Sheet

struct ArchetypeDetailSheet: View {
    let archetype: TrainingArchetype
    let log: [WorkoutLogEntry]
    @Environment(\.dismiss) private var dismiss

    // Compute the actual rep distribution from last 10 sessions
    private struct RepZone: Identifiable {
        let id = UUID()
        let label: String
        let range: String
        let pct: Double
        let color: Color
        let isActive: Bool
    }

    private var zones: [RepZone] {
        let sets = log.prefix(10).flatMap { $0.exercises.flatMap(\.completedSets) }.filter { $0.reps > 0 }
        let total = Double(max(sets.count, 1))
        let power    = Double(sets.filter { $0.reps <= 3  }.count) / total
        let strength = Double(sets.filter { $0.reps >= 4 && $0.reps <= 6  }.count) / total
        let hyper    = Double(sets.filter { $0.reps >= 7 && $0.reps <= 12 }.count) / total
        let endurance = Double(sets.filter { $0.reps > 12 }.count) / total
        return [
            RepZone(label: "Power",      range: "1–3 reps",  pct: power,    color: HONTheme.chartLavender, isActive: archetype == .powerFocused),
            RepZone(label: "Strength",   range: "4–6 reps",  pct: strength, color: HONTheme.accent,   isActive: archetype == .strengthBiased),
            RepZone(label: "Hypertrophy",range: "7–12 reps", pct: hyper,    color: HONTheme.positive,  isActive: archetype == .hypertrophyBiased),
            RepZone(label: "Endurance",  range: "13+ reps",  pct: endurance,color: HONTheme.chartSage,   isActive: archetype == .enduranceLite),
        ]
    }

    private var archetypeDescription: String {
        switch archetype {
        case .powerFocused:
            return "You regularly train in the 1–3 rep range — the zone that builds peak force production and neural drive. This is the domain of powerlifters and Olympic lifters."
        case .strengthBiased:
            return "Most of your sets fall in the 4–6 rep range. This is the classic strength zone: high load, full motor unit recruitment, and dense neural adaptations that build raw strength over time."
        case .hypertrophyBiased:
            return "The 7–12 rep range makes up the bulk of your training. This is the primary hypertrophy zone — the balance of mechanical tension and metabolic stress that drives muscle growth."
        case .enduranceLite:
            return "You spend most of your time above 12 reps, in the muscular endurance zone. This builds work capacity and conditioning but contributes less to peak strength or mass."
        case .balanced:
            return "Your rep distribution is spread across multiple zones without one dominating. This can reflect intentional variety or a mixed programming approach."
        }
    }

    private var whyLabel: String {
        let top = zones.max(by: { $0.pct < $1.pct })
        guard let t = top, t.pct > 0 else { return "Not enough data to classify yet." }
        return "\(Int(t.pct * 100))% of your sets in the last 10 sessions were in the \(t.label) zone (\(t.range)), which is the dominant zone in your training."
    }

    private var zoneAdaptations: String {
        switch archetype {
        case .powerFocused:
            return "Heavy singles and doubles primarily train the nervous system, not the muscle. You're building inter-muscular coordination — the ability to fire every motor unit at once — which is what separates strong from explosive. Structural muscle growth is minimal here; the gains are almost entirely neural. That's why powerlifters can be remarkably strong without looking proportionally larger."
        case .strengthBiased:
            return "The 4–6 rep zone produces a dual adaptation: you get both neural efficiency (better motor unit recruitment) and myofibrillar hypertrophy — thicker, denser muscle fibers. This is the zone with the best strength-to-size ratio. The load is high enough to create significant mechanical tension per rep, which is the primary driver of actual strength gain."
        case .hypertrophyBiased:
            return "The 7–12 range triggers muscle growth through three mechanisms simultaneously: mechanical tension from the load, metabolic stress from the rep volume, and muscle damage from the stretch under load. All three contribute to muscle protein synthesis. This is why hypertrophy training works best when you're close to failure — the last few hard reps are disproportionately responsible for the adaptation signal."
        case .enduranceLite:
            return "High-rep training builds mitochondrial density and capillary networks inside the muscle — improving its ability to sustain repeated contractions and clear metabolic waste quickly. You'll get conditioning benefits and some hypertrophy at first, but the growth stimulus diminishes as the muscle adapts. Strength gain beyond a moderate level is limited because load is too low to fully challenge motor unit recruitment."
        case .balanced:
            return "Spread across zones, your training stimulates multiple adaptation pathways at once: neural efficiency from lower rep work, myofibrillar growth from mid-range, and metabolic conditioning from higher reps. The trade-off is that no single adaptation gets maximally trained. For general fitness this is a strength; for a specific goal it's a compromise."
        }
    }

    private var optimizationTips: [(icon: String, tip: String)] {
        switch archetype {
        case .powerFocused:
            return [
                ("timer",           "Rest 3–5 full minutes between sets — neural recovery takes longer than metabolic recovery."),
                ("bolt.fill",       "Move the bar as fast as possible on every rep, even at near-maximal loads. Speed intent drives more motor units."),
                ("square.stack.3d.up", "Cap total sets per session at 12–15. Volume kills power quality more than it helps."),
                ("arrow.triangle.2.circlepath", "Run a hypertrophy block every 8–10 weeks. More muscle mass gives the nervous system more to work with."),
                ("exclamationmark.triangle", "If your numbers stall for 2+ weeks, the issue is usually CNS fatigue — take a full deload week, not just a light day."),
            ]
        case .strengthBiased:
            return [
                ("scalemass",       "Add weight as soon as you consistently hit the top of your rep range (6 reps) across all sets."),
                ("timer",           "Rest 2–3 minutes between sets — enough for full phosphocreatine replenishment."),
                ("figure.strengthtraining.traditional", "Prioritise the big compound lifts: squat, deadlift, press, row. These movements have the most carry-over."),
                ("calendar",        "Every 6–8 weeks, run a planned deload (50–60% of normal volume) to let structural adaptations consolidate."),
                ("checkmark.shield","Technique matters most at these loads. Film your sets periodically — form breaks under fatigue before you notice it."),
            ]
        case .hypertrophyBiased:
            return [
                ("timer",           "Rest 60–90 seconds between sets to keep metabolic stress elevated — longer rest reduces the growth signal."),
                ("hand.thumbsup",   "Train 1–3 reps from failure on your last set per exercise. This is where the bulk of the hypertrophy signal lives."),
                ("arrow.down.circle","Slow the lowering phase to 2–3 seconds. Eccentric load under stretch drives significant additional growth."),
                ("chart.line.uptrend.xyaxis", "Track reps per set. Progressive overload — even one extra rep per session — is what turns effort into growth over months."),
                ("square.stack.3d.up", "Aim for 10–20 weekly sets per muscle group. Below 10 is under-stimulating; above 20 starts to outpace recovery."),
            ]
        case .enduranceLite:
            return [
                ("arrow.up.circle", "To add muscle or strength, progressively shift sets into the 8–12 rep range. You don't need to abandon high reps — just rebalance."),
                ("timer",           "Rest 30–60 seconds — at this rep range, short rest is appropriate and maintains the conditioning benefit."),
                ("flame.fill",      "Use 13+ rep work as a finisher for isolation moves (lateral raises, curls, calf raises) after heavier compound work."),
                ("chart.line.uptrend.xyaxis", "Still apply progressive overload: add reps before adding weight, then repeat."),
                ("person.2",        "Pair with at least one strength-focused day per week (5–8 reps on compounds) for a more complete stimulus."),
            ]
        case .balanced:
            return [
                ("arrow.left.arrow.right", "To accelerate progress, choose a primary goal (size, strength, or conditioning) and let that zone dominate 60–70% of your volume."),
                ("calendar.badge.clock",   "Periodise by zone: spend 4–6 weeks emphasising each rep range in rotation rather than mixing everything each session."),
                ("barbell",         "Keep your compound lifts (squat, press, pull) in the 5–8 range for maximum structural carryover regardless of your primary goal."),
                ("waveform.path",   "Identify your weakest zone from the bar chart and add a focused block targeting it."),
                ("checkmark.circle","Balanced training is a strong long-term base — the goal is intentional balance, not accidental balance."),
            ]
        }
    }

    private var performanceContext: String {
        switch archetype {
        case .powerFocused:
            return "Power training is effective but fatiguing. Watch for accumulated CNS fatigue — more rest between sets (3–5 min) and fewer total sets per session keeps quality high."
        case .strengthBiased:
            return "You're in a solid zone for building usable strength. Progressive overload here — even adding 2.5 kg per session — compounds quickly over weeks."
        case .hypertrophyBiased:
            return "The hypertrophy zone is where most people build the most visible progress. Keep rest at 60–90 seconds and focus on reaching or exceeding your target reps each set."
        case .enduranceLite:
            return "High-rep training has its place, but if your goal is size or strength, consider shifting some sets into the 6–10 rep range where the stimulus per set is higher."
        case .balanced:
            return "Balanced distribution works well for general fitness. If you have a specific goal — size, strength, or performance — focusing on a primary zone will drive faster progress toward it."
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Header badge
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(archetype.color.opacity(0.15))
                                .frame(width: 52, height: 52)
                            Image(systemName: "person.fill.checkmark")
                                .font(.title2)
                                .foregroundStyle(archetype.color)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Training Archetype")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(archetype.rawValue)
                                .font(.title2.bold())
                                .foregroundStyle(archetype.color)
                        }
                    }
                    .padding(.top, 4)

                    // What it means
                    VStack(alignment: .leading, spacing: 8) {
                        Label("What this means", systemImage: "text.bubble")
                            .font(.headline)
                        Text(archetypeDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Rep distribution bars
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Why you were classified this way", systemImage: "chart.bar.fill")
                            .font(.headline)
                        Text(whyLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(spacing: 8) {
                            ForEach(zones) { zone in
                                HStack(spacing: 10) {
                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text(zone.label)
                                            .font(.caption.bold())
                                            .foregroundStyle(zone.isActive ? zone.color : .secondary)
                                        Text(zone.range)
                                            .font(.system(size: 9))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .frame(width: 82, alignment: .trailing)

                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.secondary.opacity(0.15))
                                                .frame(height: 8)
                                            Capsule()
                                                .fill(zone.color.opacity(zone.isActive ? 1.0 : 0.4))
                                                .frame(width: geo.size.width * zone.pct, height: 8)
                                        }
                                    }
                                    .frame(height: 8)

                                    Text("\(Int(zone.pct * 100))%")
                                        .font(.caption.bold())
                                        .foregroundStyle(zone.isActive ? zone.color : .secondary)
                                        .frame(width: 32, alignment: .trailing)
                                }
                            }
                        }
                        Text("Based on your last 10 sessions.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }

                    // What this zone builds
                    VStack(alignment: .leading, spacing: 8) {
                        Label("What this zone builds", systemImage: "bolt.heart.fill")
                            .font(.headline)
                        Text(zoneAdaptations)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // How to optimize
                    VStack(alignment: .leading, spacing: 10) {
                        Label("How to get the most out of it", systemImage: "target")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(optimizationTips, id: \.tip) { item in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 13))
                                        .foregroundStyle(archetype.color)
                                        .frame(width: 20, alignment: .center)
                                        .padding(.top, 1)
                                    Text(item.tip)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(14)
                        .background(archetype.color.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // How you're doing
                    VStack(alignment: .leading, spacing: 8) {
                        Label("How you're doing", systemImage: "lightbulb.fill")
                            .font(.headline)
                        Text(performanceContext)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(archetype.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(20)
            }
            .navigationTitle("Archetype")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Velocity Detail Sheet

struct VelocityDetailSheet: View {
    let analytics: ExerciseAnalytics
    @Environment(\.dismiss) private var dismiss

    private var phase: LiftPhase { LiftPhase.classify(analytics) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Phase + slope banner
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CURRENT PHASE")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .kerning(0.5)
                            Text(phase.rawValue)
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(phase.color)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Divider().frame(height: 44).padding(.horizontal, 16)
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("RATE OF PROGRESS")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .kerning(0.5)
                            let sign = analytics.slopePerWeek >= 0 ? "+" : ""
                            Text("\(sign)\(String(format: "%.2f", analytics.slopePerWeek)) kg/wk")
                                .font(.system(size: 17, weight: .bold, design: .monospaced))
                                .foregroundStyle(analytics.slopePerWeek > 0 ? HONTheme.positive
                                                 : analytics.slopePerWeek < -0.2 ? HONTheme.negative : HONTheme.warning)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(16)
                    .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))

                    // Phase explanation
                    VStack(alignment: .leading, spacing: 8) {
                        Label("What \"\(phase.rawValue)\" means", systemImage: "info.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(phase.color)
                        Text(phaseExplanation)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))

                    // Full PR chart
                    if analytics.prProgression.count >= 2 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("e1RM History")
                                    .font(.system(size: 13, weight: .bold))
                                Spacer()
                                Text("estimated 1-rep max (kg)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Chart(analytics.prProgression) { pr in
                                LineMark(x: .value("Date", pr.date), y: .value("e1RM", pr.estimated1RM))
                                    .interpolationMethod(.stepStart)
                                    .foregroundStyle(phase.color)
                                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                                AreaMark(x: .value("Date", pr.date), y: .value("e1RM", pr.estimated1RM))
                                    .interpolationMethod(.stepStart)
                                    .foregroundStyle(phase.color.opacity(0.12))
                                PointMark(x: .value("Date", pr.date), y: .value("e1RM", pr.estimated1RM))
                                    .foregroundStyle(phase.color)
                                    .symbolSize(55)
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 5)) {
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                        .font(.system(size: 9))
                                    AxisGridLine()
                                }
                            }
                            .chartYAxis {
                                AxisMarks(values: .automatic(desiredCount: 5)) {
                                    AxisValueLabel().font(.system(size: 9))
                                    AxisGridLine()
                                }
                            }
                            .frame(height: 220)
                            Text("Each point is the highest e1RM recorded for \(analytics.exercise.name) in that session.")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
                    }

                    // Recent session sparkline
                    if analytics.sessions.count >= 3 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Sessions (\(min(analytics.sessions.count, 12)) most recent)")
                                .font(.system(size: 13, weight: .bold))
                            MiniSparkline(points: analytics.sessions.suffix(12).map(\.estimated1RM),
                                          color: phase.color)
                                .frame(height: 56)
                            Text("Trend across your last sessions. Upward slope = progressing.")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(16)
            }
            .background(AppTheme.pageBG)
            .navigationTitle(analytics.exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var phaseExplanation: String {
        switch phase {
        case .linearProgression:
            return "Your e1RM is climbing consistently week over week. This is the most efficient phase — keep doing what you're doing. Increase weight when you regularly hit the top of your target rep range."
        case .plateau:
            return "Progress has stalled. Your e1RM hasn't moved meaningfully in recent sessions. Consider changing the rep range, taking a deload week, or adjusting weight selection to restart the adaptation signal."
        case .peaking:
            return "You're in a rapid strength spike — e1RM climbing faster than normal. This often follows a deload, or happens when you've been undertrained and are now pushing harder. Capitalize on it."
        case .declining:
            return "e1RM is trending downward. Possible causes: accumulated fatigue, insufficient sleep or nutrition, technique breakdown under load, or programming mismatch. Consider a deload or lighter technique session."
        case .deloading:
            return "Not enough sessions logged to classify this lift yet. Track at least 3 sessions with this exercise to see velocity analysis."
        }
    }
}

// MARK: - Insight Detail Sheet

struct InsightDetailSheet: View {
    let insight: EmergentInsight
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // State banner
                    if insight.dataAvailable {
                        VStack(spacing: 6) {
                            Text(insight.stateName)
                                .font(.honDisplay(28))
                                .foregroundStyle(insight.stateColor)
                                .multilineTextAlignment(.center)
                            Text("Based on: \(insight.inputsLabel)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(insight.stateColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    }

                    // What is this metric?
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What is \"\(insight.title)\"?")
                            .font(.system(size: 14, weight: .bold))
                        Text(conceptDescription)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))

                    if insight.dataAvailable {
                        // Implication
                        VStack(alignment: .leading, spacing: 8) {
                            Label("What this means for you", systemImage: "lightbulb.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(HONTheme.warning)
                            Text(insight.implication)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))

                        // Why this label
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Why you got this label", systemImage: "chart.bar.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(HONTheme.accent)
                            Text(insight.dataPoint)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Still Learning", systemImage: "hourglass")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text("This signal needs more data. Keep logging workouts\(insight.inputsLabel.contains("HRV") || insight.inputsLabel.contains("Sleep") ? " and ensure HealthKit is syncing" : "") to unlock this insight.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(16)
            }
            .background(AppTheme.pageBG)
            .navigationTitle(insight.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var conceptDescription: String {
        switch insight.title {
        case "Mind-Body Alignment":
            return "Compares your HRV (physiological readiness) against your subjective feel rating. When these align — both high or both low — your body and mind are telling the same story. Mismatches reveal whether non-training stressors or overconfidence are driving the gap."
        case "True Adaptation":
            return "Separates real strength gains from freshness-masking effects. A high Training Stress Balance (TSB) means you're fresh — but freshness alone isn't growth. This metric cross-references your fatigue load with your e1RM trend to determine whether gains are structural adaptations or just the result of being well-rested."
        case "Program Calibration":
            return "Analyzes how close your actual performance is to your targets across recent sessions. Uses rep-hit rate and set completion to classify whether your program is optimally challenging, too easy (you're sandbagging), or overloaded (survival training)."
        case "Imbalance Trajectory":
            return "Tracks whether your push and pull movement patterns are converging or diverging over time. Small imbalances compound — a 10% push-pull velocity gap today can become a shoulder impingement risk over months of consistent training."
        case "Net Recovery Capacity":
            return "Combines sleep quality, HRV, and training load to assess your total recovery balance. The key insight is distinguishing program fatigue (which a deload fixes) from lifestyle fatigue (which the program cannot fix — only sleep and stress management can)."
        case "PR Attempt Quality":
            return "Predicts the quality of a PR attempt right now by combining three signals: your current fatigue state, subjective feel rating, and strength velocity trend. All three need to be favorable for a high-probability PR window."
        // MARK: Cardio insights
        case "HIIT Endurance Trend":
            return "Tracks how your completed round count changes across HIIT sessions over time. More rounds in the same duration = your aerobic capacity is growing. Computed via linear regression over all logged cardio sessions."
        case "Fatigue Resistance":
            return "Measures how much your rep output drops from the first third of rounds to the last third within each session. A small drop means your anaerobic threshold is well above your working intensity. A large drop means you're hitting a wall mid-session."
        case "Work Capacity Density":
            return "Tracks your reps-per-minute across HIIT sessions over time. This is your metabolic work rate — higher density in the same time window means your cardiovascular engine is becoming more efficient."
        case "Circuit Consistency":
            return "Measures how uniform your rep output is round-to-round within a session, using standard deviation of per-round rep counts. Metronomic athletes pace well and hit similar numbers every round. Erratic athletes spike and crash, usually from poor early pacing."
        // MARK: Cross-domain insights
        case "Cardio-Strength Interference":
            return "Compares your strength session feel rating on days following a HIIT session (within 48h) versus days without prior cardio. Reveals whether circuit training is priming your body for strength work or leaving it fatigued."
        case "Modality Sequencing":
            return "Analyzes the time gap between your HIIT sessions and your next strength training session. Optimal spacing (1–2 days) allows aerobic recovery while minimizing carryover fatigue into strength work."
        case "Dual-Mode Fitness Index":
            return "Combines your HIIT round-count trend and your top-lift strength velocity to classify whether you're progressing in both modalities simultaneously. Most athletes see one improve at the other's expense at high volumes — dual improvement is the benchmark."
        case "Energy System Synergy":
            return "Cross-references HIIT sessions with the feel rating you report in strength sessions within the next 24h. A tighter window than Cardio-Strength Interference — it's testing whether your aerobic priming boosts same-day or next-morning strength readiness specifically."
        default:
            return "A composite signal derived from your training history, recovery metrics, and performance patterns."
        }
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
