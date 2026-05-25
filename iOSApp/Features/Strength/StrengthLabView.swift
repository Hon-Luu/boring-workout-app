import SwiftUI
import Charts

// MARK: - Strength Lab (Test Tab)
//
// Hierarchy:
//   Hero  → PCSA-weighted e1RM (overall) + 90d trend
//   Level 1 → Per-pattern weighted e1RM + mini trend (expandable)
//   Level 2 → Per-exercise raw e1RM + adj e1RM + fatigue gap + numbers

struct StrengthLabView: View {
    @Environment(SeedStore.self) private var store
    @State private var showAllTime    = false
    @State private var expandedGroups = Set<PPLGroup>()

    private enum ScoreUnit: String, CaseIterable {
        case kg       = "kg"
        case kgPerCm2 = "kg/cm²"
        case nPerCm2  = "N/cm²"
    }
    @AppStorage("strengthLabUnit")   private var scoreUnit:         ScoreUnit = .kg
    @AppStorage("strengthLabAllom")  private var allometricScaling: Bool      = false

    private var exercises: [ExerciseAnalytics] { store.analyticsCache.exerciseAnalytics }

    // MARK: - PPL group (3-way split; isolation redistributed by dominant muscle)

    private enum PPLGroup: String, CaseIterable {
        case push = "Push"
        case pull = "Pull"
        case legs = "Legs"

        var icon: String {
            switch self {
            case .push: return "arrow.up.circle.fill"
            case .pull: return "arrow.down.circle.fill"
            case .legs: return "figure.run"
            }
        }
    }

    // Push muscles: chest, triceps, anterior/lateral delt
    // Pull muscles: lats, traps, rhomboids, posterior delt, biceps
    // Legs muscles: quads, glutes, hamstrings, erectors, calves, abs
    private func pplGroup(for ea: ExerciseAnalytics) -> PPLGroup {
        switch ea.exercise.movementPattern {
        case .horizontalPush, .verticalPush: return .push
        case .horizontalPull, .verticalPull: return .pull
        case .hipHinge, .kneeFlexion:        return .legs
        case .isolation:
            // Find dominant muscle by activation weight (pctMVC × PCSA)
            let profile = StrengthScoreEngine.activationProfile(for: ea.exercise)
            guard let dominant = profile.max(by: { $0.pctMVC * $0.muscle.pcsa < $1.pctMVC * $1.muscle.pcsa }) else {
                return .push
            }
            switch dominant.muscle {
            case .pectoralisMajor, .tricepsBrachii,
                 .anteriorDeltoid, .lateralDeltoid:         return .push
            case .latissimus, .trapezius, .rhomboids,
                 .posteriorDeltoid, .bicepsBrachii:         return .pull
            case .quadriceps, .gluteusMaximus, .hamstrings,
                 .erectorSpinae, .gastrocnemius,
                 .rectusAbdominis:                          return .legs
            }
        }
    }

    // MARK: - Core model

    private struct EWItem: Identifiable {
        var id: UUID { analytics.id }
        let analytics: ExerciseAnalytics
        let aw:        Double
        let group:     PPLGroup
    }

    struct StrengthPoint: Identifiable {
        let id   = UUID()
        let date: Date
        let kg:   Double
    }

    // MARK: - Items (sorted by activation weight)

    private var items: [EWItem] {
        exercises.compactMap { ea -> EWItem? in
            let profile = StrengthScoreEngine.activationProfile(for: ea.exercise)
            let aw = profile.reduce(0.0) { $0 + $1.pctMVC * $1.muscle.pcsa }
            guard aw > 0, !ea.sessions.isEmpty else { return nil }
            return EWItem(analytics: ea, aw: aw, group: pplGroup(for: ea))
        }
        .sorted { $0.aw > $1.aw }
    }

    private var totalAW: Double { items.reduce(0.0) { $0 + $1.aw } }

    // MARK: - Unit conversion

    private var allomDivisor: Double {
        guard allometricScaling, let bw = store.userProfile.bodyWeightKg, bw > 0 else { return 1 }
        return pow(bw, 0.67)    // Jaric 2002: strength / BW^0.67 removes body size confound
    }

    private func convertScore(_ kg: Double, aw: Double) -> Double {
        let scaled = kg / allomDivisor
        guard aw > 0 else { return scaled }
        switch scoreUnit {
        case .kg:       return scaled
        case .kgPerCm2: return scaled / aw
        case .nPerCm2:  return scaled * 9.81 / aw
        }
    }

    private func convertPoints(_ pts: [StrengthPoint], aw: Double) -> [StrengthPoint] {
        guard scoreUnit != .kg || allometricScaling else { return pts }
        return pts.map { StrengthPoint(date: $0.date, kg: convertScore($0.kg, aw: aw)) }
    }

    private var unitLabel: String {
        let base = scoreUnit.rawValue
        return allometricScaling ? "\(base)/BW⁰·⁶⁷" : base
    }

    private func unitFormat(_ val: Double) -> String {
        switch scoreUnit {
        case .kg:       return String(format: "%.1f", val)
        case .kgPerCm2: return String(format: "%.3f", val)
        case .nPerCm2:  return String(format: "%.2f", val)
        }
    }

    // Chooses format and stride for the y-axis based on unit and the visible value range.
    private func yAxisConfig(for pts: [StrengthPoint]) -> (fmt: String, stride: Double?) {
        let vals = pts.map(\.kg)
        let range = (vals.max() ?? 1) - (vals.min() ?? 0)
        switch scoreUnit {
        case .kg:
            return ("%.0f", nil)
        case .kgPerCm2:
            // typical range 0.01–0.5; use enough decimals to show meaningful change
            let decimals = range < 0.01 ? 4 : range < 0.1 ? 3 : 2
            let strideVal = range < 0.01 ? 0.002 : range < 0.1 ? 0.02 : nil
            return ("%.\(decimals)f", strideVal)
        case .nPerCm2:
            let decimals = range < 0.1 ? 3 : 2
            let strideVal = range < 0.1 ? 0.02 : range < 1 ? 0.2 : nil
            return ("%.\(decimals)f", strideVal)
        }
    }

    // MARK: - Week identifier

    private struct WeekID: Hashable, Comparable {
        let year: Int   // yearForWeekOfYear
        let week: Int   // weekOfYear

        static func < (lhs: WeekID, rhs: WeekID) -> Bool {
            lhs.year != rhs.year ? lhs.year < rhs.year : lhs.week < rhs.week
        }
    }

    private func weekID(for date: Date) -> WeekID {
        let c = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return WeekID(year: c.yearForWeekOfYear ?? 0, week: c.weekOfYear ?? 0)
    }

    private func weekStart(_ wid: WeekID) -> Date {
        var c = DateComponents()
        c.yearForWeekOfYear = wid.year
        c.weekOfYear = wid.week
        c.weekday = 2   // Monday
        return Calendar.current.date(from: c) ?? Date()
    }

    private func prevWeek(_ wid: WeekID) -> WeekID {
        weekID(for: Calendar.current.date(byAdding: .weekOfYear, value: -1, to: weekStart(wid))!)
    }

    // MARK: - Score & history builders
    //
    // Current score: Peak + Physiological Decay model (Option B)
    //
    // Anchor  = best e1RM in last 90 days (handles bad-day noise)
    // Decay   = none for first 14 days of rest (neuromuscular efficiency maintained;
    //           Mujika & Padilla 2001), then −0.7%/day up to a 50% floor
    //           (~0.5%–1%/day for trained athletes; Häkkinen 1985, Colliander 1992)
    // Result  = missing a session never drops the score; a genuine layoff (>2 wks) decays
    //           it slowly and honestly.

    private func decayAdjustedScore(_ list: [EWItem], keyPath: KeyPath<ExerciseAnalytics, [SessionPoint]>) -> Double? {
        let now        = Date()
        let cutoff90   = now.addingTimeInterval(-90 * 86_400)
        var num = 0.0, den = 0.0
        for item in list {
            let sessions = item.analytics[keyPath: keyPath]
            guard !sessions.isEmpty else { continue }
            // Peak from last 90 days; fall back to all-time if no recent data
            let recent  = sessions.filter { $0.date >= cutoff90 }
            let anchor  = recent.isEmpty ? sessions : recent
            guard let peak = anchor.map(\.estimated1RM).max(), peak > 0 else { continue }
            let daysSince = now.timeIntervalSince(sessions.last!.date) / 86_400
            let retained  = Self.strengthRetentionFactor(daysSince: daysSince)
            num += peak * retained * item.aw
            den += item.aw
        }
        return den > 0 ? num / den : nil
    }

    // Physiological strength retention curve.
    // 0–14 days: 100% (neural efficiency fully intact; no measurable force loss)
    // >14 days:  −0.7%/day, floored at 50% (you never lose everything)
    private static func strengthRetentionFactor(daysSince days: Double) -> Double {
        guard days > 14 else { return 1.0 }
        return max(0.5, 1.0 - 0.007 * (days - 14))
    }

    // Days since the most recent session across all exercises in `list`.
    // Returns nil if within the 14-day grace window (no badge needed).
    private func restDays(for list: [EWItem]) -> Double? {
        guard let last = list.compactMap({ $0.analytics.sessions.last?.date }).max() else { return nil }
        let days = Date().timeIntervalSince(last) / 86_400
        return days > 14 ? days : nil
    }

    private func buildHistory(_ list: [EWItem], keyPath: KeyPath<ExerciseAnalytics, [SessionPoint]>) -> [StrengthPoint] {
        // Per-exercise: best e1RM per ISO week
        var weeklyBest: [UUID: [WeekID: Double]] = [:]
        for item in list {
            var best: [WeekID: Double] = [:]
            for pt in item.analytics[keyPath: keyPath] {
                let wid = weekID(for: pt.date)
                best[wid] = max(best[wid] ?? 0, pt.estimated1RM)
            }
            weeklyBest[item.id] = best
        }

        // All weeks that appear in any exercise
        let allWeeks = Set(weeklyBest.values.flatMap(\.keys)).sorted()

        return allWeeks.compactMap { wid -> StrengthPoint? in
            let prior = prevWeek(wid)
            var num = 0.0, den = 0.0
            for item in list {
                guard let bmap = weeklyBest[item.id] else { continue }
                // Best from this week or previous — nil if trained neither week
                let candidates = [bmap[wid], bmap[prior]].compactMap { $0 }
                guard let best = candidates.max() else { continue }
                num += best * item.aw; den += item.aw
            }
            return den > 0 ? StrengthPoint(date: weekStart(wid), kg: num / den) : nil
        }
    }

    // Windowed histories (90 days ≈ 13 weeks)
    private var cutoff90: Date { Date().addingTimeInterval(-90 * 86_400) }

    private func windowed(_ pts: [StrengthPoint]) -> [StrengthPoint] {
        showAllTime ? pts : pts.filter { $0.date >= cutoff90 }
    }

    private func windowedSessions(_ pts: [SessionPoint]) -> [SessionPoint] {
        showAllTime ? pts : pts.filter { $0.date >= cutoff90 }
    }

    // Delta = current week vs previous week (last two points in history)
    private func deltaWeek(history: [StrengthPoint]) -> Double? {
        guard history.count >= 2 else { return nil }
        return history.last!.kg - history[history.count - 2].kg
    }

    // Exercise-level delta: best e1RM this week vs best last week
    private func deltaWeekSessions(_ sessions: [SessionPoint]) -> Double? {
        let now      = Date()
        let thisWid  = weekID(for: now)
        let priorWid = prevWeek(thisWid)
        let thisWeekBest  = sessions.filter { weekID(for: $0.date) == thisWid  }.map(\.estimated1RM).max()
        let priorWeekBest = sessions.filter { weekID(for: $0.date) == priorWid }.map(\.estimated1RM).max()
        guard let cur = thisWeekBest, let prev = priorWeekBest else { return nil }
        return cur - prev
    }

    // MARK: - Baseline % change

    // "Baseline" = average score from weeks 0–4 (neural adaptation phase).
    // Returns nil if baseline history is unavailable.
    private func baselinePct(_ list: [EWItem]) -> Double? {
        guard let firstLog = store.workoutLog.min(by: { $0.startedAt < $1.startedAt })?.startedAt else { return nil }
        let baselineEnd = firstLog.addingTimeInterval(4 * 7 * 86_400)
        let allHist = buildHistory(list, keyPath: \.sessions)
        let baselinePts = allHist.filter { $0.date <= baselineEnd }
        guard !baselinePts.isEmpty else { return nil }
        let baselineAvg = baselinePts.map(\.kg).reduce(0, +) / Double(baselinePts.count)
        guard baselineAvg > 0,
              let current = decayAdjustedScore(list, keyPath: \.sessions) else { return nil }
        return (current - baselineAvg) / baselineAvg * 100
    }

    // MARK: - Training age phase

    private var trainingPhaseLabel: (text: String, color: Color) {
        let weeks = store.trainingAgeWeeks
        switch weeks {
        case 0..<4:  return ("Neural phase (0–4 wks)",  HONTheme.accent)
        case 4..<8:  return ("Mixed phase (4–8 wks)",   HONTheme.chartLavender)
        default:     return ("Hypertrophy phase (8+ wks)", HONTheme.positive)
        }
    }

    // MARK: - MDC-gated delta (suppress noise below minimum detectable change)

    // For pattern-level scores we take the strictest (highest) MDC among constituent exercises.
    private func mdcForGroup(_ g: PPLGroup) -> Double {
        pItems(g).map(\.analytics.exercise.movementPattern.mdc).max() ?? 5.0
    }

    private func mdcForAll() -> Double {
        items.map(\.analytics.exercise.movementPattern.mdc).max() ?? 5.0
    }

    // MARK: - Per-group helpers

    private func pItems(_ g: PPLGroup)   -> [EWItem]        { items.filter { $0.group == g } }
    private func pAW(_ g: PPLGroup)      -> Double          { pItems(g).reduce(0) { $0 + $1.aw } }
    private func pHistory(_ g: PPLGroup) -> [StrengthPoint] { buildHistory(pItems(g), keyPath: \.sessions) }

    // MARK: - Composite score data

    private var composite:        CompositeStrengthResult { store.analyticsCache.compositeScore }
    private var strength:         StrengthScoreResult     { store.analyticsCache.strengthScore }
    private var exerciseAnalytics: [ExerciseAnalytics]    { store.analyticsCache.exerciseAnalytics }

    private var fourWeekDeltas: (css: Double?, level: Double?, momentum: Double?) {
        let history = composite.history
        guard history.count >= 2 else { return (nil, nil, nil) }
        let cutoff = Date().addingTimeInterval(-28 * 86400)
        guard let ref = history.dropLast().min(by: {
            abs($0.date.timeIntervalSince(cutoff)) < abs($1.date.timeIntervalSince(cutoff))
        }), ref.date < Date().addingTimeInterval(-7 * 86400) else { return (nil, nil, nil) }
        let last = history.last!
        return (last.score - ref.score, last.level - ref.level, last.momentum - ref.momentum)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // ── Tier scoring system ──────────────────────────────
                    LabOverallTierCard(
                        tier: strength.overallTier,
                        trendPct: strength.psiTrendPctPerWeek,
                        compoundCount: strength.relativeStrengths.filter { $0.exercise.isCompound }.count
                    )
                    LabRelativeStrengthCard(
                        relativeStrengths: strength.relativeStrengths,
                        bodyWeightKg: store.userProfile.bodyWeightKg
                    )

                    // ── Strength constellation (e1RM vs BW ratio trails) ─
                    StrengthConstellationCard(
                        log: store.workoutLog,
                        bodyWeightKg: store.userProfile.bodyWeightKg
                    )

                    Divider().padding(.vertical, 2)

                    // ── Composite Score section ──────────────────────────
                    compositeSection

                    Divider()
                        .padding(.vertical, 4)

                    // Global controls
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Picker("", selection: $scoreUnit) {
                                ForEach(ScoreUnit.allCases, id: \.self) { u in
                                    Text(u.rawValue).tag(u)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 210)

                            Spacer()

                            Picker("", selection: $showAllTime) {
                                Text("90d").tag(false)
                                Text("All").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 90)
                        }
                        if scoreUnit == .kgPerCm2 || scoreUnit == .nPerCm2 {
                            Text(scoreUnit == .kgPerCm2
                                 ? "Force per cm² of muscle — removes size advantage between athletes"
                                 : "Newtons per cm² — physiological force density (research standard)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 2)
                        }

                        HStack(spacing: 12) {
                            // Allometric scaling toggle — only useful if body weight is set
                            let hasBW = store.userProfile.bodyWeightKg != nil
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle(isOn: $allometricScaling) {
                                    HStack(spacing: 4) {
                                        Text("Allometric (÷ BW⁰·⁶⁷)")
                                            .font(.system(size: 11, weight: .medium))
                                        if !hasBW {
                                            Image(systemName: "exclamationmark.circle")
                                                .font(.system(size: 10))
                                                .foregroundStyle(HONTheme.warning)
                                        }
                                    }
                                }
                                .toggleStyle(.button)
                                .buttonStyle(.bordered)
                                .tint(allometricScaling ? HONTheme.accent : .secondary)
                                .font(.system(size: 11))
                                .disabled(!hasBW)
                                if !hasBW {
                                    Text("Add body weight in Settings → Profile to enable allometric scaling")
                                        .font(.system(size: 9))
                                        .foregroundStyle(HONTheme.accent)
                                        .padding(.horizontal, 2)
                                }
                            }

                            Spacer()

                            // Training age phase badge
                            let phase = trainingPhaseLabel
                            Text(phase.text)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(phase.color)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(phase.color.opacity(0.1), in: Capsule())
                        }
                    }

                    heroCard

                    ForEach(PPLGroup.allCases.filter { !pItems($0).isEmpty }, id: \.self) { group in
                        patternCard(group)
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .background(AppTheme.pageBG)
            .navigationTitle("Strength Lab")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: PillarDestination.self) { dest in
                PillarDetailContainerView(initial: dest)
            }
            .navigationDestination(for: PatternGroup.self) { group in
                PatternDetailView(group: group)
            }
        }
    }

    // MARK: - Composite Score Section

    private var compositeSection: some View {
        let deltas = fourWeekDeltas
        return VStack(spacing: 12) {
            Text("COMPOSITE STRENGTH SCORE")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .kerning(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Hero: grade + score + insight
            LabCSSHeroCard(composite: composite, tier: strength.overallTier, cssΔ: deltas.css)

            // Pillar cards
            HStack(spacing: 10) {
                NavigationLink(value: PillarDestination.level) {
                    LabPillarCard(title: "Level",    value: composite.levelScore,    color: HONTheme.accent,
                                  icon: "chart.bar.fill",         subtitle: String(format: "%.0f%% of peak", composite.peakRetentionPct),
                                  delta: deltas.level,            description: "Strength vs your peak")
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(8)
                    }
                }
                NavigationLink(value: PillarDestination.momentum) {
                    LabPillarCard(title: "Momentum", value: composite.momentumScore, color: HONTheme.positive,
                                  icon: "arrow.up.right.circle.fill", subtitle: trendLabel,
                                  delta: deltas.momentum,         description: "Rate of progress")
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(8)
                    }
                }
                NavigationLink(value: PillarDestination.process) {
                    LabPillarCard(title: "Process",  value: composite.processScore,  color: HONTheme.chartLavender,
                                  icon: "gearshape.2.fill",       subtitle: processLabel,
                                  delta: nil,                     description: "Training quality")
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(8)
                    }
                }
            }
            .buttonStyle(.plain)

            // CSS history sparkline
            if composite.history.count >= 3 {
                LabCSSHistoryCard(history: composite.history)
            } else if composite.history.count == 2 {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("1 more session to see your score history")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
            }

            // Pattern breakdown
            if !strength.patternBreakdown.isEmpty {
                LabPatternBreakdownCard(breakdown: strength.patternBreakdown, exerciseAnalytics: exerciseAnalytics)
            }
        }
    }

    private var trendLabel: String {
        let pct = strength.psiTrendPctPerWeek
        return String(format: "%@%.1f%%/wk", pct >= 0 ? "+" : "", pct)
    }

    private var processLabel: String {
        guard let inol = composite.inolSubScore else { return "—" }
        return String(format: "INOL %.0f", inol)
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        let allHist   = buildHistory(items, keyPath: \.sessions)
        let dispHist  = windowed(allHist)
        let score     = decayAdjustedScore(items, keyPath: \.sessions)
        let adjScore  = decayAdjustedScore(items, keyPath: \.sessionsFatigue)
        let rawDelta  = deltaWeek(history: allHist)
        let mdc       = mdcForAll()
        let delta: Double? = rawDelta.flatMap { abs($0) >= mdc ? $0 : nil }
        let pctBaseline = baselinePct(items)
        let aw        = totalAW
        let restD     = restDays(for: items)

        return VStack(alignment: .leading, spacing: 14) {

            Text("PCSA-WEIGHTED e1RM")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .kerning(0.8)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    if let s = score {
                        let cv = convertScore(s, aw: aw)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(unitFormat(cv))
                                .font(.system(size: 52, weight: .black, design: .rounded))
                            Text(unitLabel)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 8)
                        }
                        if let a = adjScore {
                            let ca = convertScore(a, aw: aw)
                            HStack(spacing: 6) {
                                Text("Fresh capacity:")
                                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                                Text("\(unitFormat(ca)) \(unitLabel)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(HONTheme.accent)
                                if let gap = score.map({ a - $0 }), gap > 0.5 {
                                    let cg = convertScore(gap, aw: aw)
                                    Text("+\(unitFormat(cg)) \(unitLabel) fatigue")
                                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                                }
                            }
                        }
                        if let pct = pctBaseline {
                            HStack(spacing: 6) {
                                Text("vs baseline:")
                                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                                Text(String(format: "%@%.1f%%", pct >= 0 ? "+" : "", pct))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(pct >= 0 ? HONTheme.positive : HONTheme.negative)
                            }
                        }
                        if let d = restD {
                            let ret = Self.strengthRetentionFactor(daysSince: d)
                            HStack(spacing: 4) {
                                Image(systemName: "moon.zzz")
                                    .font(.system(size: 9))
                                Text(String(format: "%.0fd rest · %.0f%% retained", d, ret * 100))
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(HONTheme.warning)
                        }
                    } else {
                        Text("—")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let d = delta {
                    let cd = convertScore(d, aw: aw)
                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: d >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption.bold())
                            Text("\(d >= 0 ? "+" : "")\(unitFormat(abs(cd) * (d >= 0 ? 1 : -1))) \(unitLabel)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(d >= 0 ? HONTheme.positive : HONTheme.negative)
                        Text("vs last week")
                            .font(.system(size: 9)).foregroundStyle(.tertiary)
                    }
                    .padding(.bottom, 6)
                }
            }

            Divider()

            let heroConverted = convertPoints(dispHist, aw: aw)
            let heroCfg = yAxisConfig(for: heroConverted)
            trendChart(heroConverted, color: HONTheme.accent, height: 200, yFmt: heroCfg.fmt, yStride: heroCfg.stride)
        }
        .padding(16)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Pattern Card (same layout as hero)

    @ViewBuilder
    private func patternCard(_ group: PPLGroup) -> some View {
        let pitems     = pItems(group)
        let allPhist   = pHistory(group)
        let dispPhist  = windowed(allPhist)
        let pscore     = decayAdjustedScore(pitems, keyPath: \.sessions)
        let padjScore  = decayAdjustedScore(pitems, keyPath: \.sessionsFatigue)
        let rawPdelta  = deltaWeek(history: allPhist)
        let pmdc       = mdcForGroup(group)
        let pdelta: Double? = rawPdelta.flatMap { abs($0) >= pmdc ? $0 : nil }
        let contribPct = totalAW > 0 ? pAW(group) / totalAW * 100 : 0
        let isExpanded = expandedGroups.contains(group)
        let col        = groupColor(group)
        let paw        = pAW(group)
        let pRestD     = restDays(for: pitems)

        VStack(alignment: .leading, spacing: 14) {

            // Eyebrow
            HStack {
                Text("\(group.rawValue.uppercased())  ·  PCSA-WEIGHTED e1RM")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .kerning(0.8)
                Spacer()
                Text(String(format: "%.0f%% of score  ·  %d exercises", contribPct, pitems.count))
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            }

            // Numbers
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    if let s = pscore {
                        let cv = convertScore(s, aw: paw)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(unitFormat(cv))
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(col)
                            Text(unitLabel)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 6)
                        }
                        if let a = padjScore {
                            let ca = convertScore(a, aw: paw)
                            HStack(spacing: 6) {
                                Text("Fresh capacity:")
                                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                                Text("\(unitFormat(ca)) \(unitLabel)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(col.opacity(0.8))
                            }
                        }
                        if let d = pRestD {
                            let ret = Self.strengthRetentionFactor(daysSince: d)
                            HStack(spacing: 4) {
                                Image(systemName: "moon.zzz")
                                    .font(.system(size: 9))
                                Text(String(format: "%.0fd rest · %.0f%% retained", d, ret * 100))
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(HONTheme.warning)
                        }
                    } else {
                        Text("No data")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let d = pdelta {
                    let cd = convertScore(d, aw: paw)
                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: d >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption.bold())
                            Text("\(d >= 0 ? "+" : "")\(unitFormat(abs(cd) * (d >= 0 ? 1 : -1))) \(unitLabel)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(d >= 0 ? HONTheme.positive : HONTheme.negative)
                        Text("vs last week")
                            .font(.system(size: 9)).foregroundStyle(.tertiary)
                    }
                    .padding(.bottom, 6)
                }
            }

            Divider()

            // Trend chart
            let patConverted = convertPoints(dispPhist, aw: paw)
            let patCfg = yAxisConfig(for: patConverted)
            trendChart(patConverted, color: col, height: 160, yFmt: patCfg.fmt, yStride: patCfg.stride)

            // Expand button
            Button {
                withAnimation(.spring(duration: 0.28)) {
                    if isExpanded { expandedGroups.remove(group) }
                    else          { expandedGroups.insert(group) }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(isExpanded ? "Hide exercises" : "Show \(pitems.count) exercises")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(col)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(col.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            // Exercises
            if isExpanded {
                Divider()
                ForEach(pitems) { item in
                    exerciseRow(item)
                    if item.id != pitems.last?.id {
                        Divider().padding(.leading, 0).opacity(0.4)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Exercise Row

    @ViewBuilder
    private func exerciseRow(_ item: EWItem) -> some View {
        let ea         = item.analytics
        let rawSess    = windowedSessions(ea.sessions)
        let adjSess    = windowedSessions(ea.sessionsFatigue)
        let curRaw     = ea.sessions.last?.estimated1RM
        let curAdj     = ea.sessionsFatigue.last?.estimated1RM
        let peakRaw    = ea.sessions.map(\.estimated1RM).max()
        let wPct       = totalAW > 0 ? item.aw / totalAW * 100 : 0
        let rawDelta   = deltaWeekSessions(ea.sessions)
        let fatigueGap: Double? = {
            guard let r = curRaw, let a = curAdj else { return nil }
            return a - r    // positive = capacity hidden by fatigue
        }()

        VStack(alignment: .leading, spacing: 10) {

            // Name + delta
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ea.exercise.name)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Text(String(format: "Activation wt %.0f cm²  ·  %.0f%% of score", item.aw, wPct))
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                Spacer()
                if let d = rawDelta {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(spacing: 3) {
                            Image(systemName: d >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 8, weight: .bold))
                            Text(String(format: "%@%.1f kg", d >= 0 ? "+" : "", d))
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(d >= 0 ? HONTheme.positive : HONTheme.negative)
                        Text("vs last week").font(.system(size: 8)).foregroundStyle(.tertiary)
                    }
                }
            }

            // Metric pills
            HStack(spacing: 8) {
                if let r = curRaw  { metricPill("e1RM",  String(format: "%.0f kg", r), .primary)  }
                if let a = curAdj  { metricPill("Fresh", String(format: "%.0f kg", a), HONTheme.accent)     }
                if let g = fatigueGap, g > 0.5 {
                    metricPill("Gap", String(format: "+%.0f kg", g), g > 8 ? HONTheme.warning : .secondary)
                }
                if let p = peakRaw { metricPill("Peak",  String(format: "%.0f kg", p), HONTheme.chartLavender)  }
                let trend = ea.pctChangePerWeek
                metricPill("Δ/wk",
                           String(format: "%@%.1f%%", trend >= 0 ? "+" : "", trend),
                           trend >= 0.3 ? HONTheme.positive : trend < 0 ? HONTheme.negative : .secondary)
            }

            // Chart: raw dots + 3-session rolling avg + adj rolling avg
            // Rolling avg computed on data side (not via interpolation method)
            // so .linear is accurate rather than artificially smooth.
            let rollSess = windowedSessions(ea.rollingAvg)
            let adjRoll  = windowedSessions(ea.rollingAvgFatigue)

            // Need ≥3 raw sessions to draw any trend line
            let canShowTrend = rawSess.count >= 3

            if rawSess.count >= 2 {
                let allVals = (rawSess + rollSess + adjRoll).map(\.estimated1RM)
                let mnRaw   = allVals.min() ?? 0
                let mxRaw   = allVals.max() ?? 100
                let pad     = max((mxRaw - mnRaw) * 0.12, 2.0)

                Chart {
                    // Raw sessions: faint dots — show actual session variance
                    ForEach(rawSess) { pt in
                        PointMark(x: .value("Date", pt.date),
                                  y: .value("Session", pt.estimated1RM))
                            .foregroundStyle(Color.primary.opacity(0.22))
                            .symbolSize(16)
                    }
                    // 5-session rolling avg trend line — only if enough data
                    if canShowTrend && rollSess.count >= 3 {
                        ForEach(rollSess) { pt in
                            LineMark(x: .value("Date", pt.date),
                                     y: .value("Trend", pt.estimated1RM))
                                .foregroundStyle(Color.primary.opacity(0.85))
                                .lineStyle(StrokeStyle(lineWidth: 2.5))
                                .interpolationMethod(.linear)
                        }
                    }
                    // Adj rolling avg — dashed blue, only if enough data
                    if canShowTrend && adjRoll.count >= 3 {
                        ForEach(adjRoll) { pt in
                            LineMark(x: .value("Date", pt.date),
                                     y: .value("FreshTrend", pt.estimated1RM))
                                .foregroundStyle(HONTheme.accent.opacity(0.60))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                .interpolationMethod(.linear)
                        }
                    }
                }
                .chartYScale(domain: (mnRaw - pad)...(mxRaw + pad))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .font(.system(size: 8)).foregroundStyle(Color.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [3]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                Text(String(format: "%.0f", v))
                                    .font(.system(size: 8)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 100)

                if canShowTrend {
                    HStack(spacing: 12) {
                        legendItem(Color.primary.opacity(0.3), solid: true,  "Sessions")
                        legendItem(Color.primary.opacity(0.85), solid: false, "Rolling avg")
                        if adjRoll.count >= 3 {
                            legendItem(HONTheme.accent.opacity(0.60), solid: false, "Fresh (adj)")
                        }
                    }
                } else {
                    Text("Log \(3 - rawSess.count) more session\(3 - rawSess.count == 1 ? "" : "s") to show trend line")
                        .font(.system(size: 8)).foregroundStyle(.tertiary)
                }
            } else {
                Text("Log more sessions to see trend")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    // MARK: - Shared trend chart
    // Raw weekly dots shown as context; a 3-week rolling average is the actual line.
    // This decouples visual smoothness from chart interpolation method —
    // the data itself is smoothed, so .linear interpolation is accurate.

    private func rollingAvg3(_ pts: [StrengthPoint]) -> [StrengthPoint] {
        pts.indices.map { i in
            let window = pts[max(0, i - 2)...i]
            let avg    = window.reduce(0.0) { $0 + $1.kg } / Double(window.count)
            return StrengthPoint(date: pts[i].date, kg: avg)
        }
    }

    @ViewBuilder
    private func trendChart(_ points: [StrengthPoint], color: Color, height: CGFloat,
                            yFmt: String = "%.0f", yStride: Double? = nil) -> some View {
        if points.count >= 2 {
            let smoothed = rollingAvg3(points)
            let allVals  = (points + smoothed).map(\.kg)
            let mnRaw    = allVals.min()!
            let mxRaw    = allVals.max()!
            // Expand domain to include N/cm² reference band when relevant
            let refLo: Double = 15.0, refHi: Double = 22.5
            let showRef = scoreUnit == .nPerCm2 && !allometricScaling
            let pad      = max((mxRaw - mnRaw) * 0.15, showRef ? 1.0 : 2.0)
            let mn       = showRef ? min(mnRaw - pad, refLo - 1) : mnRaw - pad
            let mx       = showRef ? max(mxRaw + pad, refHi + 1) : mxRaw + pad
            let xMin     = points.map(\.date).min()!
            let xMax     = points.map(\.date).max()!

            Chart {
                // Area fill under smoothed line
                ForEach(smoothed) { pt in
                    AreaMark(x: .value("Date", pt.date),
                             yStart: .value("Base", mn),
                             yEnd:   .value("Smooth", pt.kg))
                        .foregroundStyle(
                            LinearGradient(colors: [color.opacity(0.20), color.opacity(0.03)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.linear)
                }
                // Raw weekly dots — context, shows actual variance
                ForEach(points) { pt in
                    PointMark(x: .value("Date", pt.date),
                              y: .value("Raw",  pt.kg))
                        .foregroundStyle(color.opacity(0.30))
                        .symbolSize(20)
                }
                // 3-week rolling average — the trend line
                ForEach(smoothed) { pt in
                    LineMark(x: .value("Date", pt.date),
                             y: .value("Smooth", pt.kg))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.linear)
                }
            }
            .chartBackground { proxy in
                // N/cm² reference band drawn as a background so it adds no chart data points
                // (RectangleMark would add xMin/xMax as discrete tick positions → vertical grid lines)
                if showRef {
                    GeometryReader { geo in
                        if let yTop = proxy.position(forY: refHi),
                           let yBot = proxy.position(forY: refLo) {
                            let bandH = max(0, yBot - yTop)
                            HONTheme.positive.opacity(0.10)
                                .frame(width: geo.size.width, height: bandH)
                                .position(x: geo.size.width / 2, y: yTop + bandH / 2)
                        }
                    }
                }
            }
            .chartYScale(domain: mn...mx)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0))   // suppress white vertical lines
                    AxisTick(stroke: StrokeStyle(lineWidth: 0))
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .font(.system(size: 9)).foregroundStyle(Color.secondary)
                }
            }
            .chartYAxis {
                let marks: AxisMarkValues = yStride.map { .stride(by: $0) } ?? .automatic(desiredCount: 3)
                AxisMarks(position: .leading, values: marks) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            Text(String(format: yFmt, v))
                                .font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: height)
        } else {
            Text("Not enough data yet")
                .font(.caption).foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: height)
        }
    }

    // MARK: - UI helpers

    private func metricPill(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(color == .primary ? Color.primary : color)
            Text(label)
                .font(.system(size: 8)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 7))
    }

    private func legendItem(_ color: Color, solid: Bool, _ label: String) -> some View {
        HStack(spacing: 4) {
            if solid {
                Circle().fill(color).frame(width: 6, height: 6)
            } else {
                RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 10, height: 2)
            }
            Text(label).font(.system(size: 8)).foregroundStyle(.secondary)
        }
    }

    private func groupColor(_ g: PPLGroup) -> Color {
        switch g {
        case .push: return AppTheme.primary    // HONTheme.accent
        case .pull: return HONTheme.chartSage               // matches AppTheme.pattern(.pull)
        case .legs: return AppTheme.warning    // HONTheme.warning
        }
    }
}

// MARK: - Pillar Navigation (moved from ProgressView)

enum PillarDestination: Hashable {
    case level, momentum, process
    var title: String {
        switch self { case .level: "Level"; case .momentum: "Momentum"; case .process: "Process" }
    }
}

struct PillarDetailContainerView: View {
    @State private var selected: PillarDestination

    init(initial: PillarDestination) {
        _selected = State(initialValue: initial)
    }

    var body: some View {
        Group {
            switch selected {
            case .level:    LevelDetailView()
            case .momentum: MomentumDetailView()
            case .process:  ProcessDetailView()
            }
        }
        .id(selected)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $selected) {
                    Text("Level").tag(PillarDestination.level)
                    Text("Momentum").tag(PillarDestination.momentum)
                    Text("Process").tag(PillarDestination.process)
                }
                .pickerStyle(.segmented)
                .frame(width: 270)
            }
        }
    }
}

// MARK: - Lab Composite Cards

func scoreGradeColor(_ v: Double) -> Color {
    v >= 80 ? HONTheme.positive : v >= 70 ? HONTheme.accent : v >= 60 ? HONTheme.warning : HONTheme.negative
}

private struct LabCSSHeroCard: View {
    let composite: CompositeStrengthResult
    let tier: StrengthTier
    let cssΔ: Double?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 2) {
                Text(String(format: "%.0f", composite.overallScore))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(gradeColor)
                Text(composite.grade)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(gradeColor.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let d = cssΔ {
                    Text(String(format: "%@%.1f", d >= 0 ? "+" : "", d))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(d >= 0 ? HONTheme.positive : HONTheme.negative)
                }
            }
            .frame(width: 64)
            .padding(.vertical, 8)
            .background(gradeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 8) {
                Text("Composite Strength Score")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .kerning(0.5)
                Text(composite.insight)
                    .font(.system(size: 13, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                TierBadge(tier: tier)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 16))
    }

    private var gradeColor: Color {
        switch composite.gradeColor {
        case "purple": return HONTheme.chartLavender
        case "green":  return HONTheme.positive
        case "blue":   return HONTheme.accent
        case "yellow": return HONTheme.chartAmber
        case "orange": return HONTheme.warning
        default:       return HONTheme.negative
        }
    }
}

private struct LabPillarCard: View {
    let title:       String
    let value:       Double
    let color:       Color
    let icon:        String
    let subtitle:    String
    let delta:       Double?
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.caption).foregroundStyle(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(String(format: "%.0f", value))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(scoreGradeColor(value))
                if let d = delta {
                    Text(String(format: "%@%.0f", d >= 0 ? "+" : "", d))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(d >= 0 ? HONTheme.positive : HONTheme.negative)
                }
            }
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.12)).frame(height: 5)
                Capsule().fill(scoreGradeColor(value).opacity(0.75))
                    .frame(width: max(4, CGFloat(value / 100) * (UIScreen.main.bounds.width / 3 - 40)), height: 5)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Text(description).font(.system(size: 9, weight: .medium)).foregroundStyle(color.opacity(0.7))
                Text(subtitle).font(.system(size: 9)).foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct LabCSSHistoryCard: View {
    let history: [CSSHistoryPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Score History").font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                Text("\(history.count) sessions").font(.caption2).foregroundStyle(.tertiary)
            }
            Chart {
                ForEach([(0.0, 60.0, HONTheme.negative), (60.0, 70.0, HONTheme.warning),
                         (70.0, 80.0, HONTheme.accent), (80.0, 90.0, HONTheme.positive),
                         (90.0, 100.0, HONTheme.chartLavender)], id: \.0) { lo, hi, col in
                    RectangleMark(yStart: .value("lo", lo), yEnd: .value("hi", hi))
                        .foregroundStyle(col.opacity(0.06))
                }
                ForEach([(60.0, "C", HONTheme.warning), (70.0, "B", HONTheme.accent),
                         (80.0, "A", HONTheme.positive),  (90.0, "S", HONTheme.chartLavender)], id: \.0) { threshold, label, col in
                    RuleMark(y: .value(label, threshold))
                        .foregroundStyle(col.opacity(0.25))
                        .lineStyle(StrokeStyle(lineWidth: 0.75, dash: [4, 3]))
                        .annotation(position: .trailing, alignment: .center) {
                            Text(label).font(.system(size: 8, weight: .bold)).foregroundStyle(col.opacity(0.7))
                        }
                }
                ForEach(history) { pt in
                    LineMark(x: .value("Date", pt.date), y: .value("CSS", pt.score))
                        .foregroundStyle(Color.primary.opacity(0.85))
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                        .symbol { Circle().fill(scoreGradeColor(pt.score)).frame(width: 5) }
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .font(.system(size: 9)).foregroundStyle(Color.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            Text("\(Int(v))").font(.system(size: 9)).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .frame(height: 100)
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct LabPatternBreakdownCard: View {
    let breakdown: [PatternGroup: PatternStrengthResult]
    let exerciseAnalytics: [ExerciseAnalytics]

    private func groupFor(_ p: MovementPattern) -> PatternGroup {
        PatternGroup.allCases.first { $0.patterns.contains(p) } ?? .isolation
    }

    private var rows: [(group: PatternGroup, psr: PatternStrengthResult, plateaued: Int)] {
        PatternGroup.allCases.compactMap { g in
            guard let psr = breakdown[g] else { return nil }
            let stalled = exerciseAnalytics.filter { groupFor($0.exercise.movementPattern) == g && $0.isPlateau }.count
            return (g, psr, stalled)
        }
    }

    private var totalWeight: Double { rows.reduce(0) { $0 + $1.psr.activationWeightTotal } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pattern Breakdown").font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                Text("tap to drill down").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            ForEach(rows, id: \.group) { row in
                let wPct = totalWeight > 0 ? row.psr.activationWeightTotal / totalWeight * 100 : 0
                NavigationLink(value: row.group) {
                    LabPatternRow(group: row.group, psr: row.psr, plateaued: row.plateaued, weightPct: wPct)
                }
                .buttonStyle(.plain)
                if row.group != rows.last?.group { Divider().padding(.leading, 14) }
            }
            .padding(.bottom, 4)
        }
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct LabPatternRow: View {
    let group: PatternGroup
    let psr: PatternStrengthResult
    let plateaued: Int
    let weightPct: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: group.icon)
                .font(.system(size: 13))
                .foregroundStyle(patternColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(group.rawValue).font(.subheadline.bold())
                    if plateaued > 0 {
                        Text("\(plateaued) stalled")
                            .font(.system(size: 9)).foregroundStyle(HONTheme.warning)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(HONTheme.warning.opacity(0.12), in: Capsule())
                    }
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(patternColor.opacity(0.12)).frame(height: 4)
                    Capsule().fill(patternColor.opacity(0.7))
                        .frame(width: max(2, CGFloat(psr.levelScore / 100) * 100), height: 4)
                }
                .frame(width: 100)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f", psr.levelScore))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreGradeColor(psr.levelScore))
                let sign = psr.pctChangePerWeek >= 0 ? "+" : ""
                Text(String(format: "%@%.1f%%/wk", sign, psr.pctChangePerWeek))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(psr.pctChangePerWeek >= 0.3 ? HONTheme.positive : psr.pctChangePerWeek < 0 ? HONTheme.negative : .secondary)
                if weightPct > 0 {
                    Text(String(format: "%.0f%% of Level", weightPct))
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private var patternColor: Color {
        switch group {
        case .push:      return HONTheme.accent
        case .pull:      return HONTheme.positive
        case .legs:      return HONTheme.warning
        case .isolation: return HONTheme.chartLavender
        }
    }
}

// MARK: - Lab Tier Scoring Cards (moved from Progress)

private struct LabOverallTierCard: View {
    let tier: StrengthTier
    let trendPct: Double
    let compoundCount: Int

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(tierColor.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: tier.systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(tierColor)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Overall Strength Tier")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .kerning(0.5)
                Text(tier.rawValue)
                    .font(.heroRounded(26))
                    .foregroundStyle(tierColor)
                Text(compoundSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(compoundCount == 0 ? HONTheme.warning : .secondary)
            }
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                let sign = trendPct >= 0 ? "+" : ""
                Text(String(format: "%@%.1f%%", sign, trendPct))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(trendPct >= 0.5 ? HONTheme.positive : trendPct < 0 ? HONTheme.negative : .secondary)
                Text("/ week")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 16))
    }

    private var compoundSubtitle: String {
        switch compoundCount {
        case 0:    return "Log bench, squat, deadlift, or row to activate"
        case 1, 2: return "Based on \(compoundCount) compound lift\(compoundCount == 1 ? "" : "s") — add more for accuracy"
        default:   return tier.description
        }
    }

    private var tierColor: Color { AppTheme.tier(tier) }
}

private struct LabPatternSummary {
    let group: PatternGroup
    let best: RelativeStrengthPoint
    let score: Double
    let exercises: [RelativeStrengthPoint]
}

private struct LabRelativeStrengthCard: View {
    let relativeStrengths: [RelativeStrengthPoint]
    let bodyWeightKg: Double?

    private var summaries: [LabPatternSummary] {
        PatternGroup.allCases.compactMap { group in
            let pts = relativeStrengths
                .filter { group.patterns.contains($0.exercise.movementPattern) }
                .sorted { $0.relativeStrength > $1.relativeStrength }
            guard let best = pts.first else { return nil }
            let score = StrengthScoreEngine.tierScore(relStrength: best.relativeStrength, thresholds: best.thresholds)
            return LabPatternSummary(group: group, best: best, score: score, exercises: pts)
        }
    }

    private var compositeScore: Double {
        let functional = summaries.filter { $0.group != .isolation }
        guard !functional.isEmpty else { return 0 }
        return functional.map(\.score).reduce(0, +) / Double(functional.count)
    }

    private var strengthRatio: Double { compositeScore / 50.0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if bodyWeightKg == nil {
                HStack(spacing: 8) {
                    Image(systemName: "scalemass").foregroundStyle(.secondary)
                    Text("Add body weight in Settings to see relative strength rankings.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
            } else if relativeStrengths.isEmpty {
                Text("Log workouts to see your relative strength rankings.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 16)
            } else {
                compositeHero
                Divider()
                VStack(spacing: 10) {
                    ForEach(summaries, id: \.group) { summary in
                        LabPatternStrengthRow(summary: summary, bodyWeightKg: bodyWeightKg)
                    }
                }
                if relativeStrengths.count > 8 {
                    Text("You have \(relativeStrengths.count) exercises tracked · each pattern shows top 5 by relative strength")
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
                Text("Index: Push · Pull · Legs averaged (1.0 = Intermediate). Ratios = e1RM ÷ bodyweight.")
                    .font(.appFootnote).foregroundStyle(.tertiary).padding(.top, 2)
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private var compositeHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Relative Strength Index")
                .font(.microLabel).foregroundStyle(.tertiary).textCase(.uppercase).kerning(0.5)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.2f", strengthRatio))
                    .font(.heroRounded(44)).foregroundStyle(ratioColor)
                Text("×")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ratioColor.opacity(0.7)).padding(.bottom, 4)
                Spacer()
                Text(ratioLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary).padding(.bottom, 6)
            }
            LabCompositeRatioBar(ratio: strengthRatio)
        }
    }

    private var ratioColor: Color {
        if strengthRatio >= 1.5 { return HONTheme.chartLavender }
        if strengthRatio >= 1.0 { return HONTheme.chartLavender }
        if strengthRatio >= 0.5 { return HONTheme.accent }
        return .gray
    }

    private var ratioLabel: String {
        switch strengthRatio {
        case 2.0...:    return "Elite level"
        case 1.5..<2.0: return "Advanced"
        case 1.0..<1.5: return "Above standard"
        case 0.5..<1.0: return "Building toward standard"
        default:         return "Getting started"
        }
    }
}

private struct LabPatternStrengthRow: View {
    let summary: LabPatternSummary
    let bodyWeightKg: Double?
    @State private var editExercise: Exercise?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: summary.group.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(groupColor).frame(width: 20)
                Text(summary.group.rawValue)
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text(String(format: "%.2f×", summary.score / 50.0))
                    .font(.monoValue())
                    .foregroundStyle(AppTheme.tier(summary.best.tier))
            }
            TierProgressBar(
                relStrength:  summary.best.relativeStrength,
                thresholds:   summary.best.thresholds,
                tier:         summary.best.tier,
                bodyWeightKg: bodyWeightKg
            )
            VStack(spacing: 6) {
                ForEach(Array(summary.exercises.prefix(5))) { pt in
                    Button { editExercise = pt.exercise } label: {
                        HStack(alignment: .top, spacing: 6) {
                            Text(pt.exercise.name)
                                .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(String(format: "%.2f×", pt.relativeStrength))
                                        .font(.monoValue(11, weight: .semibold))
                                        .foregroundStyle(AppTheme.tier(pt.tier))
                                    Text(String(format: "%.0f kg", pt.recentE1RM))
                                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                                }
                                if let bw = bodyWeightKg {
                                    let t = pt.thresholds
                                    let rel = pt.relativeStrength
                                    if rel < t.beginner {
                                        Text("→ \(Int(t.beginner * bw))kg for Int")
                                            .font(.system(size: 8)).foregroundStyle(.tertiary)
                                    } else if rel < t.intermediate {
                                        Text("→ \(Int(t.intermediate * bw))kg for Adv")
                                            .font(.system(size: 8)).foregroundStyle(.tertiary)
                                    } else if rel < t.advanced {
                                        Text("→ \(Int(t.advanced * bw))kg for Elite")
                                            .font(.system(size: 8)).foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            Image(systemName: "pencil")
                                .font(.system(size: 9)).foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 28)
                }
                if summary.exercises.count > 5 {
                    Text("+\(summary.exercises.count - 5) more · showing top 5 by relative strength")
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                        .padding(.leading, 28).padding(.top, 2)
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .background(groupColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        .sheet(item: $editExercise) { exercise in
            ExerciseLogEditSheet(exercise: exercise)
        }
    }

    private var groupColor: Color { AppTheme.pattern(summary.group) }
}

private struct LabCompositeRatioBar: View {
    let ratio: Double
    private let maxVal = 2.0
    private func frac(_ v: Double) -> CGFloat { CGFloat(max(0, min(v / maxVal, 1.0))) }
    private var dotColor: Color {
        if ratio >= 1.5 { return HONTheme.chartLavender }
        if ratio >= 1.0 { return HONTheme.positive }
        if ratio >= 0.5 { return HONTheme.accent }
        return .gray
    }
    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let w = geo.size.width
                let x1 = frac(0.5) * w; let x2 = frac(1.0) * w
                let x3 = frac(1.5) * w; let dotX = frac(ratio) * w
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.gray.opacity(0.50)).frame(width: x1)
                        Rectangle().fill(HONTheme.accent.opacity(0.50)).frame(width: x2 - x1)
                        Rectangle().fill(HONTheme.positive.opacity(0.50)).frame(width: x3 - x2)
                        Rectangle().fill(HONTheme.chartLavender.opacity(0.45)).frame(maxWidth: .infinity)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4)).frame(height: 8)
                    ForEach([x1, x2, x3], id: \.self) { x in
                        Rectangle().fill(Color(.systemBackground).opacity(0.9))
                            .frame(width: 1.5, height: 8).offset(x: x)
                    }
                    Circle().fill(dotColor).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        .shadow(color: dotColor.opacity(0.4), radius: 3)
                        .offset(x: max(0, min(dotX - 7, w - 14)))
                }
            }
            .frame(height: 14)
            HStack(spacing: 0) {
                Text("Dev").frame(maxWidth: .infinity, alignment: .leading)
                Text("Building").frame(maxWidth: .infinity, alignment: .center)
                Text("Standard").frame(maxWidth: .infinity, alignment: .center)
                Text("Elite").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 8, weight: .semibold)).foregroundStyle(.tertiary)
        }
    }
}

private struct ExerciseLogEditSheet: View {
    let exercise: Exercise
    @Environment(SeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private struct SessionRow: Identifiable {
        let id: UUID; let date: Date; let bestSet: SetRecord?; let e1RM: Double; let setCount: Int
    }

    private var sessions: [SessionRow] {
        store.workoutLog.compactMap { entry -> SessionRow? in
            guard let we = entry.exercises.first(where: { $0.exercise.id == exercise.id }) else { return nil }
            let completed = we.completedSets
            let best = completed.max(by: { $0.estimated1RM < $1.estimated1RM })
            return SessionRow(id: entry.id, date: entry.startedAt, bestSet: best,
                              e1RM: best?.estimated1RM ?? 0, setCount: completed.count)
        }.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    ContentUnavailableView("No logged sessions", systemImage: "tray",
                        description: Text("Log a workout with \(exercise.name) to see history here."))
                } else {
                    ForEach(sessions) { row in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.date, style: .date)
                                    .font(.system(size: 13, weight: .semibold))
                                Text("\(row.setCount) set\(row.setCount == 1 ? "" : "s")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let best = row.bestSet {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "%.0f kg × %d", best.weight, best.reps))
                                        .font(.system(size: 13, weight: .medium))
                                    if row.e1RM > 0 {
                                        Text(String(format: "e1RM %.0f kg", row.e1RM))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            store.deleteExerciseFromWorkout(workoutId: sessions[i].id, exerciseId: exercise.id)
                        }
                    }
                }
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
