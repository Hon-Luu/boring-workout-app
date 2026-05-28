import SwiftUI
import Charts

// MARK: - Progress View

struct ProgressView: View {
    @Environment(SeedStore.self) private var store
    @Environment(HealthKitService.self) private var health
    @State private var showHealthTrends  = false
    @State private var whereExpanded     = true
    @State private var strongerExpanded  = true
    @State private var howExpanded       = true
    @State private var cardioExpanded    = true
    @State private var whatExpanded      = true
    @State private var insightsExpanded  = true

    private var log: [WorkoutLogEntry] { store.workoutLog }

    private var allInsights: [EmergentInsight] {
        EmergentInsightEngine.compute(
            log: log,
            analyticsResult: store.analyticsCache,
            hrv: health.hrv,
            sleepHours: health.sleepHours,
            cardioLog: store.cardioLog,
            vo2Max: health.vo2Max,
            stepsToday: health.stepsToday,
            restDays: store.restDays,
            weightHistory: store.userProfile.weightHistory
        )
    }

    // Only surface insights that are live or exactly 1 session away
    private var insights: [EmergentInsight] {
        allInsights.filter { $0.dataAvailable || $0.sessionsRemaining <= 1 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if !store.isLoaded {
                        ProgressLoadingSkeleton()
                    } else {
                        DashboardHeroCard(
                            composite:         store.analyticsCache.compositeScore,
                            strengthScore:     store.analyticsCache.strengthScore.compositeScore,
                            relativeStrengths: store.analyticsCache.strengthScore.relativeStrengths,
                            log:               log,
                            cardioLog:         store.cardioLog,
                            userProfile:       store.userProfile,
                            exerciseAnalytics: store.analyticsCache.exerciseAnalytics
                        )

                        ArchetypeTopBadge(log: log)

                        // Progressive overload intelligence: hero position per review board
                        CollapsibleDashSection(
                            title: "Am I Getting Stronger",
                            icon: "chart.line.uptrend.xyaxis",
                            isExpanded: $strongerExpanded
                        ) {
                            StrongerSectionContent(exerciseAnalytics: store.analyticsCache.exerciseAnalytics)
                        }

                        CollapsibleDashSection(
                            title: "Where Am I",
                            icon: "mappin.circle.fill",
                            isExpanded: $whereExpanded
                        ) {
                            WhereSectionContent(
                                log:           log,
                                analytics:     store.analyticsCache,
                                bodyWeightKg:  store.userProfile.bodyWeightKg
                            )
                        }

                        CollapsibleDashSection(
                            title: "How Do I Train",
                            icon: "dumbbell.fill",
                            isExpanded: $howExpanded
                        ) {
                            HowSectionContent(log: log, analytics: store.analyticsCache)
                        }

                        if !store.cardioLog.isEmpty {
                            CollapsibleDashSection(
                                title: "Cardio Performance",
                                icon: "bolt.heart.fill",
                                isExpanded: $cardioExpanded
                            ) {
                                CardioSectionContent(cardioLog: store.cardioLog, vo2Max: health.vo2Max)
                            }
                        }

                        CollapsibleDashSection(
                            title: "Recovery Signals",
                            icon: "waveform.path.ecg",
                            isExpanded: $whatExpanded
                        ) {
                            WhatSectionContent(
                                log:               log,
                                hrv:               health.hrv,
                                sleepHours:        health.sleepHours,
                                restingHR:         health.restingHR,
                                vo2Max:            health.vo2Max,
                                activeCalories:    health.activeCaloriesToday,
                                respiratoryRate:   health.respiratoryRate,
                                oxygenSaturation:  health.oxygenSaturation,
                                hrvBaseline:       health.hrvBaseline,
                                hrvHistory:        health.hrvHistory,
                                sleepHistory:      health.sleepHistory,
                                rhrHistory:        health.restingHRHistory
                            )
                        }

                        if !insights.isEmpty {
                            CollapsibleDashSection(
                                title: "Emergent Insights",
                                icon: "sparkles",
                                isExpanded: $insightsExpanded
                            ) {
                                InsightsSectionContent(insights: insights)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(AppTheme.pageBG)
            .navigationTitle("Advanced")
            .sheet(isPresented: $showHealthTrends) {
                HealthTrendsView(workoutLog: log)
                    .environment(health)
            }
        }
    }
}

// MARK: - Loading Skeleton

private struct ProgressLoadingSkeleton: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.cardBG)
                    .frame(height: 90)
            }
        }
        .opacity(pulse ? 0.4 : 0.9)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}

// MARK: - Standard Lifts Benchmark Card

// A LiftDef matches exercises in the log by name keywords.
struct LiftDef {
    let name: String
    let icon: String
    let thresholds: StrengthThresholds  // BW ratios: dev/int/adv (elite = above adv)
    let matchTerms: [String]
    let rejectTerms: [String]
}

// A LiftPair groups a barbell lift with its optional dumbbell equivalent.
// The id is used as the UserDefaults key for the picker selection.
struct LiftPair: Identifiable {
    let id: String
    let barbell: LiftDef
    let dumbbell: LiftDef?   // nil = no dumbbell equivalent; picker hidden
}

struct LiftSection {
    let title: String
    let note: String?
    let pairs: [LiftPair]
}

// Thresholds sourced from Symmetric Strength population data and Greg Nuckols research benchmarks.
// All values are BW-relative e1RM CEILINGS — crossing above promotes to the next tier.
// Dumbbell values are per-hand (how the app logs dumbbell sets).
let standardLiftSections: [LiftSection] = [
    LiftSection(title: "Core Lifts", note: nil, pairs: [
        LiftPair(id: "bench",
            barbell: LiftDef(name: "Bench Press", icon: "rectangle.portrait.fill",
                thresholds: StrengthThresholds(beginner: 0.80, intermediate: 1.15, advanced: 1.60),
                matchTerms: ["bench press"],
                rejectTerms: ["dumbbell", "machine", "incline", "decline", "smith", "close"]),
            dumbbell: LiftDef(name: "DB Bench Press", icon: "rectangle.portrait.fill",
                thresholds: StrengthThresholds(beginner: 0.28, intermediate: 0.40, advanced: 0.56),
                matchTerms: ["dumbbell bench press", "dumbbell flat press", "db bench"],
                rejectTerms: ["incline", "decline", "machine"])),
        LiftPair(id: "squat",
            barbell: LiftDef(name: "Barbell Squat", icon: "figure.strengthtraining.traditional",
                thresholds: StrengthThresholds(beginner: 1.00, intermediate: 1.40, advanced: 1.90),
                matchTerms: ["squat"],
                rejectTerms: ["goblet", "machine", "hack", "bulgarian", "split", "leg press", "smith", "front", "overhead", "jump"]),
            dumbbell: nil),
        LiftPair(id: "deadlift",
            barbell: LiftDef(name: "Deadlift", icon: "arrow.up.to.line",
                thresholds: StrengthThresholds(beginner: 1.25, intermediate: 1.75, advanced: 2.25),
                matchTerms: ["deadlift"],
                rejectTerms: ["romanian", "rdl", "single", "stiff", "machine", "smith", "sumo"]),
            dumbbell: nil),
        LiftPair(id: "ohp",
            barbell: LiftDef(name: "Overhead Press", icon: "arrow.up.circle",
                thresholds: StrengthThresholds(beginner: 0.45, intermediate: 0.65, advanced: 0.90),
                matchTerms: ["overhead press", "military press"],
                rejectTerms: ["dumbbell", "machine", "arnold", "cable", "smith", "seated"]),
            dumbbell: LiftDef(name: "DB Shoulder Press", icon: "arrow.up.circle",
                thresholds: StrengthThresholds(beginner: 0.16, intermediate: 0.23, advanced: 0.32),
                matchTerms: ["dumbbell shoulder press", "dumbbell overhead press", "dumbbell military press", "dumbbell press"],
                rejectTerms: ["bench", "incline", "machine", "arnold"])),
    ]),
    LiftSection(title: "Barbell", note: nil, pairs: [
        LiftPair(id: "row",
            barbell: LiftDef(name: "Barbell Row", icon: "arrow.down.to.line",
                thresholds: StrengthThresholds(beginner: 0.75, intermediate: 1.00, advanced: 1.35),
                matchTerms: ["barbell row", "bent over row", "bent-over row", "pendlay row"],
                rejectTerms: ["dumbbell", "machine", "cable", "single", "one arm"]),
            dumbbell: LiftDef(name: "DB Row (1 arm)", icon: "arrow.down.to.line",
                thresholds: StrengthThresholds(beginner: 0.35, intermediate: 0.50, advanced: 0.68),
                matchTerms: ["dumbbell row", "db row", "one arm row", "single arm row", "single-arm row"],
                rejectTerms: ["machine", "cable"])),
        LiftPair(id: "incline",
            barbell: LiftDef(name: "Incline Bench", icon: "rectangle.portrait.topthird.inset.filled",
                thresholds: StrengthThresholds(beginner: 0.65, intermediate: 0.90, advanced: 1.25),
                matchTerms: ["incline bench press", "incline press", "incline barbell"],
                rejectTerms: ["dumbbell", "machine", "cable", "smith"]),
            dumbbell: LiftDef(name: "Incline DB Press", icon: "rectangle.portrait.topthird.inset.filled",
                thresholds: StrengthThresholds(beginner: 0.22, intermediate: 0.32, advanced: 0.44),
                matchTerms: ["incline dumbbell press", "incline db press", "dumbbell incline"],
                rejectTerms: ["machine", "cable", "smith"])),
    ]),
    LiftSection(title: "Machine & Cable", note: "Varies by machine — use as a guide", pairs: [
        LiftPair(id: "legpress",
            barbell: LiftDef(name: "Leg Press", icon: "figure.strengthtraining.traditional",
                thresholds: StrengthThresholds(beginner: 1.50, intermediate: 2.25, advanced: 3.00),
                matchTerms: ["leg press"],
                rejectTerms: ["single", "one leg", "one-leg"]),
            dumbbell: nil),
        LiftPair(id: "latpulldown",
            barbell: LiftDef(name: "Lat Pulldown", icon: "arrow.down.circle",
                thresholds: StrengthThresholds(beginner: 0.55, intermediate: 0.85, advanced: 1.20),
                matchTerms: ["lat pulldown", "cable pulldown"],
                rejectTerms: ["reverse", "behind neck", "behind the neck"]),
            dumbbell: nil),
        LiftPair(id: "cablerow",
            barbell: LiftDef(name: "Seated Cable Row", icon: "arrow.backward.to.line",
                thresholds: StrengthThresholds(beginner: 0.55, intermediate: 0.85, advanced: 1.20),
                matchTerms: ["cable row", "seated row", "chest supported row", "chest-supported row"],
                rejectTerms: ["dumbbell", "barbell", "machine row"]),
            dumbbell: nil),
    ]),
]

struct StandardLiftsCard: View {
    let log: [WorkoutLogEntry]
    let bodyWeightKg: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strength Standards")
                        .font(.system(size: 13, weight: .bold))
                    Text("e1RM ÷ bodyweight vs community benchmarks")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(HONTheme.accent.opacity(0.7))
            }
            Text("Thresholds are bodyweight-relative, so the comparison is meaningful regardless of your size. They're based on general population data and are not gender-adjusted — relative strength ratios already account for most of that difference.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineSpacing(2)

            if bodyWeightKg == nil {
                HStack(spacing: 8) {
                    Image(systemName: "scalemass").foregroundStyle(.secondary)
                    Text("Add your body weight in Settings → Strength Profile to unlock tier classification and relative strength benchmarks.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
            } else if log.isEmpty {
                Text("Log your first workout to see strength benchmarks and e1RM trends here.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            } else {
                ForEach(standardLiftSections, id: \.title) { section in
                    sectionView(section)
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func sectionView(_ section: LiftSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(section.title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .kerning(0.5)
                if let note = section.note {
                    Text("· \(note)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            VStack(spacing: 16) {
                ForEach(section.pairs) { pair in
                    LiftPairRow(pair: pair, log: log, bodyWeightKg: bodyWeightKg)
                }
            }
        }
    }
}

// MARK: - Composite Score Card

private struct CompositeScoreCard: View {
    let composite: CompositeStrengthScore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Composite Strength")
                        .font(.system(size: 13, weight: .bold))
                    Text("Push · Pull · Legs coverage score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.tier(composite.tier).opacity(0.85))
            }

            // Big score + tier
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(Int(composite.score.rounded()))")
                    .font(.heroRounded(48))
                    .foregroundStyle(AppTheme.tier(composite.tier))
                VStack(alignment: .leading, spacing: 2) {
                    Text(composite.tier.rawValue.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.tier(composite.tier))
                    Text("out of 100")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if composite.isCoverageGated {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(HONTheme.warning)
                }
            }

            Divider()

            // PPL breakdown
            VStack(spacing: 10) {
                ForEach(PPLCategory.allCases, id: \.self) { cat in
                    PPLRow(category: cat, score: composite.pplScores[cat])
                }
            }

            // Coverage warning
            if !composite.missingCategories.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(HONTheme.warning)
                    Text("Log \(composite.missingCategories.map(\.rawValue).joined(separator: " & ")) compounds to unlock full ranking")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(HONTheme.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct PPLRow: View {
    let category: PPLCategory
    let score: Double?

    private var tier: StrengthTier {
        guard let s = score else { return .beginner }
        return tierFromScore(s)
    }

    private func tierFromScore(_ s: Double) -> StrengthTier {
        if s < 20 { return .beginner }
        if s < 50 { return .intermediate }
        if s < 80 { return .advanced }
        return .elite
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.system(size: 12))
                .frame(width: 18)
                .foregroundStyle(score != nil ? AppTheme.tier(tier) : Color.secondary.opacity(0.4))

            Text(category.rawValue)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 36, alignment: .leading)

            if let s = score {
                // Mini score bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                        Capsule()
                            .fill(AppTheme.tier(tier).opacity(0.7))
                            .frame(width: geo.size.width * CGFloat(s / 100))
                    }
                }
                .frame(height: 6)

                Text("\(Int(s.rounded()))")
                    .font(.monoValue(12))
                    .foregroundStyle(AppTheme.tier(tier))
                    .frame(width: 28, alignment: .trailing)

                Text(tier.rawValue)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.tier(tier))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppTheme.tier(tier).opacity(0.12), in: Capsule())
                    .frame(width: 62, alignment: .leading)
            } else {
                GeometryReader { _ in
                    Capsule().fill(Color.secondary.opacity(0.08))
                }
                .frame(height: 6)
                Text("–")
                    .font(.monoValue(12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, alignment: .trailing)
                Text("No data")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .frame(width: 62, alignment: .leading)
            }
        }
        .frame(height: 20)
    }
}

// Per-pair row with persistent barbell/dumbbell picker
private struct LiftPairRow: View {
    let pair: LiftPair
    let log: [WorkoutLogEntry]
    let bodyWeightKg: Double?

    @State private var useDumbbell: Bool

    init(pair: LiftPair, log: [WorkoutLogEntry], bodyWeightKg: Double?) {
        self.pair = pair
        self.log = log
        self.bodyWeightKg = bodyWeightKg
        // Restore last selection from UserDefaults; default false (barbell)
        let saved = pair.dumbbell != nil && UserDefaults.standard.bool(forKey: "liftVariant_\(pair.id)")
        _useDumbbell = State(initialValue: saved)
    }

    private var activeLift: LiftDef { useDumbbell ? pair.dumbbell! : pair.barbell }

    private func bestE1RM(for lift: LiftDef) -> Double? {
        var best = 0.0
        for entry in log {
            for we in entry.exercises {
                let n = we.exercise.name.lowercased()
                guard lift.matchTerms.contains(where: { n.contains($0) }),
                      !lift.rejectTerms.contains(where: { n.contains($0) }) else { continue }
                let e = we.completedSets.map(\.estimated1RM).max() ?? 0
                best = max(best, e)
            }
        }
        return best > 0 ? best : nil
    }

    private func liftTier(rel: Double, t: StrengthThresholds) -> RelativeStrengthTier {
        if rel < t.beginner   { return .beginner }
        if rel < t.intermediate { return .intermediate }
        if rel < t.advanced     { return .advanced }
        return .elite
    }

    var body: some View {
        let bw    = bodyWeightKg ?? 1
        let e1rm  = bestE1RM(for: activeLift)
        let rel   = e1rm.map { $0 / bw } ?? 0.0
        let tier  = e1rm != nil ? liftTier(rel: rel, t: activeLift.thresholds) : RelativeStrengthTier.beginner
        let color = e1rm != nil ? AppTheme.tier(tier) : Color.secondary

        VStack(alignment: .leading, spacing: 5) {
            // Row 1: icon + name + pill picker
            HStack(spacing: 6) {
                Image(systemName: activeLift.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(activeLift.name)
                    .font(.system(size: 12, weight: .semibold))
                    .animation(nil, value: useDumbbell)

                if pair.dumbbell != nil {
                    Spacer(minLength: 4)
                    // Pill picker
                    HStack(spacing: 1) {
                        pillTab("Barbell", selected: !useDumbbell) {
                            useDumbbell = false
                            UserDefaults.standard.set(false, forKey: "liftVariant_\(pair.id)")
                        }
                        pillTab("DB", selected: useDumbbell) {
                            useDumbbell = true
                            UserDefaults.standard.set(true, forKey: "liftVariant_\(pair.id)")
                        }
                    }
                    .padding(2)
                    .background(AppTheme.insetBG, in: Capsule())
                } else {
                    Spacer()
                }
            }

            // Row 2: stats (ratio × BW and e1RM)
            HStack(spacing: 0) {
                Spacer().frame(width: 22)   // indent to align under name
                if let e1rm {
                    HStack(spacing: 3) {
                        Text(String(format: "%.2f×", rel))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(color)
                        Text("BW")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 10))
                        Text("Est. 1RM")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text(String(format: "%.0f kg", e1rm))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Not logged yet")
                        .font(.caption2).foregroundStyle(.tertiary).italic()
                }
            }

            // Row 3: tier bar with kg targets + percentiles
            if e1rm != nil {
                TierProgressBar(
                    relStrength:     rel,
                    thresholds:      activeLift.thresholds,
                    tier:            tier,
                    bodyWeightKg:    bodyWeightKg,
                    showPercentiles: true
                )
                .padding(.top, 2)
            }
        }
    }

    private func pillTab(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, weight: selected ? .bold : .regular))
                .foregroundStyle(selected ? .primary : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(selected ? AppTheme.cardBG : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tier Progress Bar

struct TierProgressBar: View {
    let relStrength: Double
    let thresholds: StrengthThresholds
    let tier: RelativeStrengthTier
    var bodyWeightKg: Double? = nil
    var showPercentiles: Bool = false

    // Bar right edge: 25% past the advanced ceiling so Elite users see movement
    private var maxVal: Double { thresholds.advanced * 1.25 }

    private func frac(_ v: Double) -> CGFloat {
        CGFloat(max(0, min(v / maxVal, 1.0)))
    }

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let w = geo.size.width
                let devX  = frac(thresholds.beginner)   * w
                let intX  = frac(thresholds.intermediate) * w
                let advX  = frac(thresholds.advanced)     * w
                let dotX  = frac(relStrength)             * w

                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.gray.opacity(0.50))
                            .frame(width: devX)
                        Rectangle().fill(HONTheme.accent.opacity(0.50))
                            .frame(width: max(0, intX - devX))
                        Rectangle().fill(HONTheme.chartLavender.opacity(0.50))
                            .frame(width: max(0, advX - intX))
                        Rectangle().fill(HONTheme.chartLavender.opacity(0.45))
                            .frame(maxWidth: .infinity)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(height: 8)

                    ForEach([devX, intX, advX], id: \.self) { x in
                        Rectangle()
                            .fill(Color(.systemBackground).opacity(0.9))
                            .frame(width: 1.5, height: 8)
                            .offset(x: x)
                    }

                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        .shadow(color: indicatorColor.opacity(0.4), radius: 3, x: 0, y: 1)
                        .offset(x: max(0, min(dotX - 7, w - 14)))
                }
            }
            .frame(height: 14)

            // Zone labels: tier name / kg target / percentile
            GeometryReader { geo in
                let w  = geo.size.width
                let bw = bodyWeightKg
                ZStack(alignment: .leading) {
                    label("Beg",   kg: nil,
                          pct: showPercentiles ? "bottom 50%" : nil,
                          at: 0,                             w: w, align: .leading)
                    label("Int",   kg: bw.map { Int($0 * thresholds.beginner)   },
                          pct: showPercentiles ? "top 50%" : nil,
                          at: frac(thresholds.beginner),   w: w, align: .center)
                    label("Adv",   kg: bw.map { Int($0 * thresholds.intermediate) },
                          pct: showPercentiles ? "top 25%" : nil,
                          at: frac(thresholds.intermediate), w: w, align: .center)
                    label("Elite", kg: bw.map { Int($0 * thresholds.advanced)     },
                          pct: showPercentiles ? "top 10%" : nil,
                          at: frac(thresholds.advanced),     w: w, align: .trailing)
                }
            }
            .frame(height: labelHeight)
        }
    }

    private var labelHeight: CGFloat {
        let hasKg  = bodyWeightKg != nil
        let hasPct = showPercentiles
        if hasKg && hasPct { return 48 }
        if hasKg || hasPct { return 34 }
        return 18
    }

    private func label(_ text: String, kg: Int?, pct: String?, at frac: CGFloat, w: CGFloat, align: HorizontalAlignment) -> some View {
        VStack(spacing: 1) {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.80))
            if let kg {
                Text("\(kg)kg")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary.opacity(0.75))
            }
            if let pct {
                Text(pct)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary.opacity(0.65))
            }
        }
        .offset(x: offsetForLabel(frac: frac, w: w, align: align))
    }

    private func offsetForLabel(frac: CGFloat, w: CGFloat, align: HorizontalAlignment) -> CGFloat {
        switch align {
        case .leading:   return 0
        case .trailing:  return w - 32
        default:         return max(0, frac * w - 8)
        }
    }

    private var indicatorColor: Color { AppTheme.tier(tier) }
}

// MARK: - Tier Badge

struct TierBadge: View {
    let tier: StrengthTier

    var body: some View {
        Text(tier.rawValue)
            .font(.caption2.bold())
            .foregroundStyle(tierColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tierColor.opacity(0.15), in: Capsule())
    }

    var tierColor: Color { AppTheme.tier(tier) }
}

// MARK: - Weekly Progress Card

private struct WeeklyProgressCard: View {
    let log: [WorkoutLogEntry]

    private var cal: Calendar { Calendar.current }

    private struct WeekStats {
        let sessions: Int
        let minutes:  Int
        let volumeKg: Double
        let sets:     Int
    }

    private struct WeekBar: Identifiable {
        let id:        Int
        let label:     String
        let volume:    Double
        let isCurrent: Bool
    }

    private func weekBounds(offset: Int) -> (start: Date, end: Date) {
        let base  = cal.date(byAdding: .weekOfYear, value: offset, to: Date())!
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: base)
        comps.weekday = 2
        let start = cal.date(from: comps) ?? Date()
        let end   = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? Date()
        return (start, end)
    }

    private func stats(offset: Int) -> WeekStats {
        let (start, end) = weekBounds(offset: offset)
        let entries = log.filter { $0.startedAt >= start && $0.startedAt < end }
        return WeekStats(
            sessions: entries.count,
            minutes:  Int(entries.reduce(0) { $0 + $1.duration } / 60),
            volumeKg: entries.reduce(0) { $0 + $1.totalVolume },
            sets:     entries.reduce(0) { $0 + $1.totalSets }
        )
    }

    private var activeDays: Set<Int> {
        let (start, end) = weekBounds(offset: 0)
        return Set(log.filter { $0.startedAt >= start && $0.startedAt < end }.map { entry in
            (cal.component(.weekday, from: entry.startedAt) + 5) % 7
        })
    }

    private var weekRangeLabel: String {
        let (start, end) = weekBounds(offset: 0)
        let last = cal.date(byAdding: .day, value: -1, to: end)!
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return "\(f.string(from: start)) – \(f.string(from: last))"
    }

    private var bars: [WeekBar] {
        let f = DateFormatter(); f.dateFormat = "M/d"
        return (-7...0).map { offset in
            let (s, e) = weekBounds(offset: offset)
            let vol = log.filter { $0.startedAt >= s && $0.startedAt < e }
                        .reduce(0.0) { $0 + $1.totalVolume }
            return WeekBar(id: offset, label: f.string(from: s), volume: vol, isCurrent: offset == 0)
        }
    }

    private func fmtVolume(_ v: Double) -> String {
        if v >= 10_000 { return String(format: "%.0fk", v / 1_000) }
        if v >= 1_000  { return String(format: "%.1fk", v / 1_000) }
        return String(format: "%.0f", v)
    }

    private func fmtDuration(_ m: Int) -> String {
        m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }

    private func fmtVolDelta(_ d: Double) -> String {
        let sign = d >= 0 ? "+" : ""
        if abs(d) >= 1_000 { return String(format: "%@%.1fk", sign, d / 1_000) }
        return String(format: "%@%.0f", sign, d)
    }

    var body: some View {
        let tw = stats(offset: 0)
        let lw = stats(offset: -1)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("THIS WEEK")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .kerning(0.8)
                Spacer()
                Text(weekRangeLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 0) {
                ForEach(Array(zip(0..<7, ["M","T","W","T","F","S","S"])), id: \.0) { idx, name in
                    let active = activeDays.contains(idx)
                    VStack(spacing: 3) {
                        Circle()
                            .fill(active ? HONTheme.accent : Color.secondary.opacity(0.15))
                            .frame(width: 9, height: 9)
                        Text(name)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(active ? HONTheme.accent : Color.secondary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                statCell(icon: "figure.strengthtraining.traditional", color: HONTheme.accent,
                         label: "Workouts",
                         value: "\(tw.sessions)",
                         deltaText: tw.sessions != lw.sessions
                             ? String(format: "%+d vs last wk", tw.sessions - lw.sessions)
                             : lw.sessions > 0 ? "same as last wk" : nil,
                         deltaUp: tw.sessions >= lw.sessions)

                statCell(icon: "clock.fill", color: HONTheme.chartLavender,
                         label: "Duration",
                         value: fmtDuration(tw.minutes),
                         deltaText: tw.minutes != lw.minutes && (tw.minutes > 0 || lw.minutes > 0)
                             ? String(format: "%+dm vs last wk", tw.minutes - lw.minutes)
                             : lw.minutes > 0 ? "same as last wk" : nil,
                         deltaUp: tw.minutes >= lw.minutes)

                statCell(icon: "scalemass.fill", color: HONTheme.positive,
                         label: "Volume (kg)",
                         value: "\(fmtVolume(tw.volumeKg))",
                         deltaText: abs(tw.volumeKg - lw.volumeKg) >= 1 && (tw.volumeKg > 0 || lw.volumeKg > 0)
                             ? "\(fmtVolDelta(tw.volumeKg - lw.volumeKg)) vs last wk"
                             : lw.volumeKg > 0 ? "same as last wk" : nil,
                         deltaUp: tw.volumeKg >= lw.volumeKg)

                statCell(icon: "list.number", color: HONTheme.warning,
                         label: "Sets",
                         value: "\(tw.sets)",
                         deltaText: tw.sets != lw.sets && (tw.sets > 0 || lw.sets > 0)
                             ? String(format: "%+d vs last wk", tw.sets - lw.sets)
                             : lw.sets > 0 ? "same as last wk" : nil,
                         deltaUp: tw.sets >= lw.sets)
            }

            let hasHistory = bars.dropLast().contains { $0.volume > 0 }
            if hasHistory || tw.volumeKg > 0 {
                Divider()
                Text("8-WEEK VOLUME TREND")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .kerning(0.6)

                ExpandableChartCard(title: "8-Week Volume Trend") {
                    Chart(bars) { bar in
                        BarMark(x: .value("Week", bar.label),
                                y: .value("Volume", bar.volume))
                            .foregroundStyle(bar.isCurrent ? HONTheme.accent : HONTheme.chartSlate.opacity(0.35))
                            .cornerRadius(3)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisValueLabel()
                                .font(.system(size: 9))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(v >= 1000 ? String(format: "%.1fk", v / 1000) : String(format: "%.0f", v))
                                        .font(.system(size: 8))
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                        }
                    }
                    .expandingFrame(normal: 80, expanded: 200)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private func statCell(icon: String, color: Color, label: String,
                          value: String, deltaText: String?, deltaUp: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let dt = deltaText {
                    let isNeutral = dt.hasPrefix("same")
                    HStack(spacing: 2) {
                        if !isNeutral {
                            Image(systemName: deltaUp ? "arrow.up" : "arrow.down")
                                .font(.system(size: 7, weight: .bold))
                        }
                        Text(dt)
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundStyle(isNeutral ? Color.secondary : deltaUp ? HONTheme.positive : HONTheme.negative)
                }
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Activity Strip

private struct ActivityStripCard: View {
    let activityDays: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 30 Days")
                .font(.caption.bold()).foregroundStyle(.secondary)
            HStack(spacing: 3) {
                ForEach(0..<30, id: \.self) { daysAgo in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(activityDays.contains(daysAgo) ? HONTheme.accent : Color.secondary.opacity(0.12))
                        .frame(maxWidth: .infinity).frame(height: 20)
                }
            }
            HStack {
                Text("30 days ago"); Spacer(); Text("Today")
            }
            .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Quick Stats Row

private struct QuickStatsRow: View {
    let sessions: Int
    let prs:      Int
    let avgPerWeek: Double
    let volume:   Double

    private var volumeLabel: String {
        volume >= 1_000_000 ? String(format: "%.1fM", volume / 1_000_000)
            : volume >= 1000 ? "\(Int(volume / 1000))k"
            : "\(Int(volume))"
    }

    var body: some View {
        HStack(spacing: 10) {
            stat("\(sessions)",                         "Sessions",  "figure.strengthtraining.traditional", HONTheme.accent)
            stat("\(prs)",                              "PRs",       "trophy.fill",                          HONTheme.chartAmber)
            stat(volumeLabel,                           "kg Lifted", "scalemass.fill",                       HONTheme.positive)
            stat(String(format: "%.1f", avgPerWeek),   "Avg/wk",    "calendar",                             HONTheme.chartLavender)
        }
    }

    private func stat(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            Text(value).font(.subheadline.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Collapsible PR Section

private struct CollapsiblePRSection: View {
    let prsByRegion: [(BodyRegion, [PersonalRecord])]
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("Personal Records")
                        .font(.headline).foregroundStyle(.primary)
                    Spacer()
                    Text("\(prsByRegion.flatMap(\.1).count) total")
                        .font(.caption).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, 14)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(prsByRegion, id: \.0) { region, prs in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(region.rawValue, systemImage: region.icon)
                                .font(.caption.bold()).foregroundStyle(regionColor(region))
                            ForEach(prs) { pr in PRCard(pr: pr, accent: regionColor(region)) }
                        }
                    }
                }
                .padding(14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
    }

    private func regionColor(_ region: BodyRegion) -> Color {
        switch region {
        case .chest: return HONTheme.negative;  case .back: return HONTheme.accent
        case .shoulders: return HONTheme.warning; case .arms: return HONTheme.chartLavender
        case .legs: return HONTheme.positive; case .core: return HONTheme.chartSage
        }
    }
}

// MARK: - PR Card

struct PRCard: View {
    let pr: PersonalRecord
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3).fill(accent).frame(width: 3).padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(pr.exerciseName).font(.subheadline.bold())
                Text(pr.date, style: .date).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "trophy.fill").font(.caption2).foregroundStyle(HONTheme.chartAmber)
                    Text("\(pr.weight.weightFormatted) kg × \(pr.reps)").font(.subheadline.bold())
                }
                Text("≈ \(Int(pr.estimated1RM)) kg 1RM").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Health Trends Entry Card

private struct HealthTrendsEntryCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(HONTheme.accent.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(HONTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Health Trends")
                        .font(.subheadline.bold())
                    Text("HRV, sleep, HR, VO2 Max overlaid with your workouts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
