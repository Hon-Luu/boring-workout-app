import SwiftUI
import Charts

// MARK: - Mode Enums

private enum ScoreMode: String, CaseIterable {
    case composite   = "Overall"
    case compare     = "Compare"
    case fiberIndex  = "Fiber Index"
    case relStrength = "Rel. Strength"
    case bodyComp    = "Body Comp"
}

private enum PSIDisplayMode: String, CaseIterable {
    case raw      = "Raw"
    case byWeight = "÷ Body Wt"
    case byLean   = "÷ Lean Mass"
    case byMuscle = "÷ Muscle"
}

// MARK: - Entry Point

struct StrengthScoreView: View {
    let result: StrengthScoreResult
    let composite: CompositeStrengthResult
    let userProfile: UserProfile
    var exerciseAnalytics: [ExerciseAnalytics] = []

    @State private var mode: ScoreMode = .composite

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableModes, id: \.self) { m in
                        Button { mode = m } label: {
                            Text(m.rawValue)
                                .font(.system(size: 13, weight: mode == m ? .semibold : .regular))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(mode == m ? HONTheme.accent : AppTheme.insetBG, in: Capsule())
                                .foregroundStyle(mode == m ? HONTheme.textPrimary : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }

            switch mode {
            case .composite:   SSCompositeCard(composite: composite)
            case .compare:     SSCompareCard(exerciseAnalytics: exerciseAnalytics,
                                             result: result,
                                             userProfile: userProfile)
            case .fiberIndex:  SSFiberCard(result: result, userProfile: userProfile)
            case .relStrength: SSRelStrengthCard(result: result, hasBodyWeight: userProfile.bodyWeightKg != nil)
            case .bodyComp:    SSBodyCompCard(result: result, userProfile: userProfile)
            }
        }
    }

    private var availableModes: [ScoreMode] {
        var modes: [ScoreMode] = [.composite, .compare, .fiberIndex, .relStrength]
        if userProfile.bodyWeightKg != nil || userProfile.hasBodyComposition {
            modes.append(.bodyComp)
        }
        return modes
    }
}

// MARK: - Header Card

private struct SSHeaderCard: View {
    let result: StrengthScoreResult
    let composite: CompositeStrengthResult
    let userProfile: UserProfile

    var body: some View {
        HStack(spacing: 14) {
            // Composite score badge
            VStack(spacing: 2) {
                Text(String(format: "%.0f", composite.overallScore))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(gradeColor)
                Text(composite.grade)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(gradeColor.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 64, height: 52)
            .background(gradeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(result.overallTier.rawValue)
                    .font(.headline)
                Text(composite.insight)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }

            Spacer()

            if let bw = userProfile.bodyWeightKg {
                VStack(spacing: 2) {
                    Text("\(Int(bw)) kg")
                        .font(.caption.bold())
                    Text("body wt")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(HONTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private var gradeColor: Color {
        switch composite.gradeColor {
        case "purple": return HONTheme.chartLavender
        case "green":  return HONTheme.positive
        case "blue":   return HONTheme.accent
        case "yellow": return HONTheme.chartAmber
        case "orange": return HONTheme.warning
        default:       return .secondary
        }
    }
}

// MARK: - Fiber Index Card

private struct SSFiberCard: View {
    let result: StrengthScoreResult
    let userProfile: UserProfile

    @State private var displayMode: PSIDisplayMode = .raw

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Muscle Fiber Load Index")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
            }

            // Sub-mode picker — only show options that have data
            if availableDisplayModes.count > 1 {
                Picker("", selection: $displayMode) {
                    ForEach(availableDisplayModes, id: \.self) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)
                .onChange(of: availableDisplayModes) { _, modes in
                    if !modes.contains(displayMode) { displayMode = modes.first ?? .raw }
                }
            }

            if result.psiHistory.isEmpty {
                emptyState
            } else {
                psiChart
                formulaNote
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        .onAppear {
            if userProfile.bodyWeightKg != nil { displayMode = .byWeight }
        }
    }

    private var availableDisplayModes: [PSIDisplayMode] {
        var modes: [PSIDisplayMode] = [.raw]
        if userProfile.bodyWeightKg != nil          { modes.append(.byWeight) }
        if userProfile.leanMassKg != nil            { modes.append(.byLean) }
        if userProfile.muscleMassKg != nil          { modes.append(.byMuscle) }
        return modes
    }

    private func yValue(for pt: PSIPoint) -> Double {
        switch displayMode {
        case .raw:      return pt.rawFiberLoad
        case .byWeight: return pt.normalizedPSI ?? pt.rawFiberLoad
        case .byLean:   return pt.leanPSI ?? pt.normalizedPSI ?? pt.rawFiberLoad
        case .byMuscle: return pt.musclePSI ?? pt.normalizedPSI ?? pt.rawFiberLoad
        }
    }

    private var yAxisLabel: String {
        switch displayMode {
        case .raw:      return "Muscle Load"
        case .byWeight: return "Muscle Load (÷ body wt)"
        case .byLean:   return "Muscle Load (÷ lean mass)"
        case .byMuscle: return "Muscle Load (÷ muscle mass)"
        }
    }

    private var psiChart: some View {
        let pts = result.psiHistory
        let values = pts.map { yValue(for: $0) }
        let yMin = (values.min() ?? 0) * 0.85
        let yMax = (values.max() ?? 1) * 1.15

        return Chart {
            ForEach(pts) { pt in
                AreaMark(
                    x: .value("Date", pt.date),
                    y: .value(yAxisLabel, yValue(for: pt))
                )
                .foregroundStyle(LinearGradient(
                    colors: [HONTheme.chartLavender.opacity(0.25), HONTheme.chartLavender.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                ))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", pt.date),
                    y: .value(yAxisLabel, yValue(for: pt))
                )
                .foregroundStyle(HONTheme.chartLavender)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
                .symbol {
                    Circle().fill(HONTheme.chartLavender).frame(width: 5, height: 5)
                }
            }
        }
        .chartYScale(domain: yMin...yMax)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel {
                    if let v = val.as(Double.self) {
                        Text(v >= 1000 ? String(format: "%.0fk", v / 1000) : String(format: "%.0f", v))
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 160)
    }

    private var formulaNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How it's calculated")
                .font(.caption2.bold()).foregroundStyle(.secondary)
            Text("Each set is scored by how heavy it was relative to your best, how many reps you did, and which muscles it works the hardest.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Exercises that recruit large, powerful muscle groups (e.g. squats, deadlifts) score higher than isolation moves.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if displayMode != .raw {
                Text("Dividing by \(normDenominator) removes the size advantage — a lighter person with the same score is proportionally just as strong.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(HONTheme.chartLavender.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private var normDenominator: String {
        switch displayMode {
        case .raw:      return ""
        case .byWeight: return "body weight"
        case .byLean:   return "lean mass"
        case .byMuscle: return "muscle mass"
        }
    }

    private var emptyState: some View {
        Text("Log workouts to build your Fiber Load history.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }
}

// MARK: - Relative Strength Card

private struct SSRelStrengthCard: View {
    let result: StrengthScoreResult
    let hasBodyWeight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Relative Strength")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                Text("e1RM ÷ body weight")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            }

            if !hasBodyWeight {
                noBodyWeightPrompt
            } else if result.relativeStrengths.isEmpty {
                Text("Log workouts to see your relative strength rankings.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                relStrengthList
                tierLegend
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private var relStrengthList: some View {
        VStack(spacing: 6) {
            ForEach(result.relativeStrengths.prefix(12)) { pt in
                HStack(spacing: 10) {
                    tierBadge(pt.tier)
                        .frame(width: 34)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(pt.exercise.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Text(pt.exercise.movementPattern.shortName)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.2f×", pt.relativeStrength))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        Text("\(Int(pt.e1RM)) kg")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .background(tierColor(pt.tier).opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func tierBadge(_ tier: RelativeStrengthTier) -> some View {
        Text(tier.shortLabel)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(tierColor(tier))
            .padding(.horizontal, 5).padding(.vertical, 3)
            .background(tierColor(tier).opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .frame(maxWidth: .infinity)
    }

    private var tierLegend: some View {
        HStack(spacing: 14) {
            ForEach(RelativeStrengthTier.allCases, id: \.self) { tier in
                HStack(spacing: 4) {
                    Circle().fill(tierColor(tier)).frame(width: 6, height: 6)
                    Text(tier.rawValue).font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }

    private var noBodyWeightPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "scalemass")
                .font(.title2).foregroundStyle(.secondary)
            Text("Add your body weight in Settings to see relative strength rankings.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func tierColor(_ tier: RelativeStrengthTier) -> Color {
        switch tier {
        case .beginner:   return .gray
        case .intermediate: return HONTheme.accent
        case .advanced:     return HONTheme.positive
        case .elite:        return HONTheme.chartLavender
        }
    }
}

// MARK: - Body Comp Strength Card

private struct SSBodyCompCard: View {
    let result: StrengthScoreResult
    let userProfile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Strength vs Body Composition")
                .font(.caption.bold()).foregroundStyle(.secondary)

            if !hasAnyData {
                noDataPrompt
            } else {
                bodyCompGrid
                if let bc = result.bodyCompStrength {
                    compositionSummary(bc)
                }
                bodyCompNote
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private var hasAnyData: Bool {
        userProfile.bodyWeightKg != nil || userProfile.hasBodyComposition
    }

    private var bodyCompGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            if let bw = userProfile.bodyWeightKg {
                bcMetricCell(
                    icon: "scalemass.fill", color: HONTheme.accent,
                    title: "Body Weight",
                    value: String(format: "%.1f kg", bw),
                    sub: nil
                )
            }
            if let bf = userProfile.bodyFatPercent {
                bcMetricCell(
                    icon: "drop.fill", color: HONTheme.warning,
                    title: "Body Fat",
                    value: String(format: "%.1f%%", bf),
                    sub: userProfile.bodyWeightKg.map { String(format: "%.1f kg fat", $0 * bf / 100) }
                )
            }
            if let lm = userProfile.leanMassKg {
                bcMetricCell(
                    icon: "figure.strengthtraining.traditional", color: HONTheme.positive,
                    title: "Lean Mass",
                    value: String(format: "%.1f kg", lm),
                    sub: nil
                )
            }
            if let mm = userProfile.muscleMassKg {
                bcMetricCell(
                    icon: "bolt.fill", color: HONTheme.chartLavender,
                    title: "Muscle Mass",
                    value: String(format: "%.1f kg", mm),
                    sub: nil
                )
            }
            if let wp = userProfile.waterPercent {
                bcMetricCell(
                    icon: "humidity.fill", color: HONTheme.chartSlate,
                    title: "Body Water",
                    value: String(format: "%.1f%%", wp),
                    sub: nil
                )
            }
            if let bk = userProfile.boneMassKg {
                bcMetricCell(
                    icon: "cross.fill", color: HONTheme.chartSage,
                    title: "Bone Mass",
                    value: String(format: "%.2f kg", bk),
                    sub: nil
                )
            }
        }
    }

    private func bcMetricCell(icon: String, color: Color, title: String, value: String, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption2).foregroundStyle(color)
                Text(title).font(.caption2.bold()).foregroundStyle(color)
            }
            Text(value).font(.subheadline.bold())
            if let s = sub {
                Text(s).font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func compositionSummary(_ bc: BodyCompStrength) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Strength Normalized to Body Composition")
                .font(.caption2.bold()).foregroundStyle(.secondary)

            if let psiLean = bc.psiPerLeanMass {
                strengthRatioRow(
                    label: "Strength per Lean Mass",
                    value: String(format: "%.2f", psiLean),
                    note: "How strong you are relative to your non-fat weight. Higher = more muscle strength per kg of body"
                )
            }
            if let psiMuscle = bc.psiPerMuscleMass {
                strengthRatioRow(
                    label: "Strength per Muscle Mass",
                    value: String(format: "%.2f", psiMuscle),
                    note: "How efficiently your muscle is being used. A high score means your muscle works hard"
                )
            }
            if let sfr = bc.strengthToFatRatio {
                strengthRatioRow(
                    label: "Strength vs Body Fat",
                    value: String(format: "%.0f", sfr),
                    note: "Higher = more strength output compared to fat mass you're carrying"
                )
            }
        }
        .padding(10)
        .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))
    }

    private func strengthRatioRow(label: String, value: String, note: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption.bold())
                Text(note).font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(HONTheme.chartLavender)
        }
    }

    private var bodyCompNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Muscle Load = how hard your muscles worked this session, weighted by the size of each muscle group recruited.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("All ratios are size-scaled so the numbers are fair to compare regardless of your body weight.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var noDataPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.title2).foregroundStyle(.secondary)
            Text("Enter your body weight and body composition data in Settings to unlock this view.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Compare Card — single multi-curve chart per exercise

private struct SSCompareCard: View {
    let exerciseAnalytics: [ExerciseAnalytics]
    let result: StrengthScoreResult
    let userProfile: UserProfile

    @State private var selectedID: UUID? = nil

    private var selected: ExerciseAnalytics? {
        if let id = selectedID { return exerciseAnalytics.first { $0.id == id } }
        return exerciseAnalytics.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if exerciseAnalytics.isEmpty {
                Text("Log workouts to see the comparison.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                exercisePills
                if let ea = selected {
                    SSCurveCompareChart(analytics: ea)
                }
                patternSummarySection
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private var exercisePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(exerciseAnalytics) { ea in
                    let isSelected = (selectedID ?? exerciseAnalytics.first?.id) == ea.id
                    Button {
                        selectedID = ea.id
                    } label: {
                        Text(ea.exercise.name)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? HONTheme.textPrimary : .primary)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(isSelected ? HONTheme.accent : AppTheme.insetBG,
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // ── Pattern-level summary ─────────────────────────────────────────────

    private func groupFor(_ p: MovementPattern) -> PatternGroup {
        PatternGroup.allCases.first { $0.patterns.contains(p) } ?? .isolation
    }

    private func patternColor(_ g: PatternGroup) -> Color {
        switch g {
        case .push:      return HONTheme.accent
        case .pull:      return HONTheme.positive
        case .legs:      return HONTheme.warning
        case .isolation: return HONTheme.chartLavender
        }
    }

    // PCSA-weighted level + OLS momentum from the pattern breakdown engine.
    // Plateaued count still comes from per-exercise analytics for accuracy.
    private var patternRows: [(group: PatternGroup, level: Double, trend: Double, inol: Double?, count: Int, plateaued: Int)] {
        var grouped: [PatternGroup: [ExerciseAnalytics]] = [:]
        for ea in exerciseAnalytics { grouped[groupFor(ea.exercise.movementPattern), default: []].append(ea) }
        return PatternGroup.allCases.compactMap { g in
            guard let psr = result.patternBreakdown[g] else { return nil }
            let eas = grouped[g] ?? []
            let inolVals = eas.compactMap(\.latestINOL)
            let avgInol: Double? = inolVals.isEmpty ? nil : inolVals.reduce(0, +) / Double(inolVals.count)
            return (g, psr.levelScore, psr.pctChangePerWeek, avgInol, eas.count, eas.filter { $0.isPlateau }.count)
        }
    }

    private var patternSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By Movement Pattern")
                .font(.caption.bold()).foregroundStyle(.secondary)

            ForEach(patternRows, id: \.group) { row in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(patternColor(row.group).opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: row.group.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(patternColor(row.group))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(row.group.rawValue).font(.system(size: 12, weight: .semibold))
                            if row.plateaued > 0 {
                                Text("\(row.plateaued) stalled")
                                    .font(.system(size: 9)).foregroundStyle(HONTheme.warning)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(HONTheme.warning.opacity(0.1), in: Capsule())
                            }
                        }
                        Text("\(row.count) exercise\(row.count == 1 ? "" : "s")")
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(String(format: "%.0f%% of peak", row.level))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(row.level >= 90 ? HONTheme.positive : row.level >= 75 ? HONTheme.accent : HONTheme.warning)
                        HStack(spacing: 6) {
                            Text(String(format: "%@%.1f%%/wk", row.trend >= 0 ? "+" : "", row.trend))
                                .font(.system(size: 9))
                                .foregroundStyle(row.trend >= 0.3 ? HONTheme.positive : row.trend >= 0 ? .secondary : HONTheme.negative)
                            if let inol = row.inol {
                                Text(String(format: "Vol %.2f", inol))
                                    .font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(8)
                .background(patternColor(row.group).opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Single-exercise multi-curve chart

private struct SSCurveCompareChart: View {
    let analytics: ExerciseAnalytics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            statsRow
            chart
            legendRow
        }
        .padding(12)
        .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 12))
    }

    // ── Stats comparison row ───────────────────────────────────────────────

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(
                label: "Est. Max",
                value: analytics.sessions.last.map { String(format: "%.0f kg", $0.estimated1RM) } ?? "—",
                sub: slopeLabel(analytics.slopePerWeek, analytics.pctChangePerWeek),
                color: HONTheme.accent
            )
            Divider().frame(height: 36)
            statCell(
                label: "Rested Max",
                value: analytics.sessionsFatigue.last.map { String(format: "%.0f kg", $0.estimated1RM) } ?? "—",
                sub: slopeLabel(analytics.slopePerWeekFatigue, analytics.pctChangePerWeekFatigue),
                color: HONTheme.warning
            )
            Divider().frame(height: 36)
            statCell(
                label: "All-Time PR",
                value: analytics.prProgression.last.map { String(format: "%.0f kg", $0.estimated1RM) } ?? "—",
                sub: "personal best",
                color: HONTheme.chartAmber
            )
            Divider().frame(height: 36)
            statCell(
                label: "Sessions",
                value: "\(analytics.sessions.count)",
                sub: analytics.isPlateau ? "⚠ Stalled" : "logged",
                color: analytics.isPlateau ? HONTheme.warning : .secondary
            )
        }
        .padding(.vertical, 6)
        .background(AppTheme.cardBG.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }

    private func slopeLabel(_ slope: Double, _ pct: Double) -> String {
        String(format: "%@%.1f%%/wk", pct >= 0 ? "+" : "", pct)
    }

    private func statCell(label: String, value: String, sub: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
            Text(sub).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // ── Chart ──────────────────────────────────────────────────────────────

    private var chart: some View {
        let std   = analytics.sessions
        let avg   = analytics.rollingAvg
        let fadj  = analytics.sessionsFatigue
        let favg  = analytics.rollingAvgFatigue
        let today = Date()

        // Historical trend lines (actual data span)
        let stdTrend   = olsTrendPoints(sessions: std)
        let fadjTrend  = olsTrendPoints(sessions: fadj)
        // Forecast lines (dashed, beyond last session)
        let stdFuture  = olsPredictionPoints(sessions: std)
        let fadjFuture = olsPredictionPoints(sessions: fadj)

        let allPts = (avg + favg + stdTrend + stdFuture + fadjTrend + fadjFuture).map { $0.estimated1RM }
        let yMin   = (allPts.min() ?? 0) * 0.92
        let yMax   = (allPts.max() ?? 1) * 1.08

        return Chart {
            // ── "Now" vertical divider between actual and forecast ──
            RuleMark(x: .value("Now", today))
                .foregroundStyle(Color.secondary.opacity(0.25))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .annotation(position: .top, spacing: 2) {
                    Text("Now").font(.system(size: 8)).foregroundStyle(.secondary)
                }

            // ── Rested max OLS — historical (orange dashed) ──
            if fadjTrend.count == 2 {
                ForEach(fadjTrend) { pt in
                    LineMark(x: .value("Date", pt.date), y: .value("Rested Trend", pt.estimated1RM))
                        .foregroundStyle(HONTheme.warning.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .interpolationMethod(.linear)
                }
            }
            // ── Rested max forecast (lighter orange, longer dashes) ──
            if fadjFuture.count == 2 {
                ForEach(fadjFuture) { pt in
                    LineMark(x: .value("Date", pt.date), y: .value("Rested Forecast", pt.estimated1RM))
                        .foregroundStyle(HONTheme.warning.opacity(0.28))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                        .interpolationMethod(.linear)
                }
            }

            // ── Standard OLS — historical (green solid) ──
            if stdTrend.count == 2 {
                ForEach(stdTrend) { pt in
                    LineMark(x: .value("Date", pt.date), y: .value("Trend", pt.estimated1RM))
                        .foregroundStyle(HONTheme.positive.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.linear)
                }
            }
            // ── Standard forecast (dashed green) ──
            if stdFuture.count == 2 {
                ForEach(stdFuture) { pt in
                    LineMark(x: .value("Date", pt.date), y: .value("Forecast", pt.estimated1RM))
                        .foregroundStyle(HONTheme.positive.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                        .interpolationMethod(.linear)
                }
            }

            // ── Rested max rolling avg (orange solid) ──
            ForEach(favg) { pt in
                LineMark(x: .value("Date", pt.date), y: .value("Rested Avg", pt.estimated1RM))
                    .foregroundStyle(HONTheme.warning)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
            }

            // ── Actual rolling avg (blue solid) ──
            ForEach(avg) { pt in
                LineMark(x: .value("Date", pt.date), y: .value("Avg", pt.estimated1RM))
                    .foregroundStyle(HONTheme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)
                    .symbol { Circle().fill(HONTheme.accent).frame(width: 5, height: 5) }
            }

            // ── PR markers ──
            ForEach(analytics.prProgression) { pt in
                PointMark(x: .value("Date", pt.date), y: .value("PR", pt.estimated1RM))
                    .symbol { Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(HONTheme.chartAmber) }
                    .annotation(position: .top, spacing: 2) {
                        Text(String(format: "%.0f", pt.estimated1RM))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(HONTheme.chartAmber)
                    }
            }
        }
        .chartYScale(domain: yMin...yMax)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                    .foregroundStyle(Color.secondary.opacity(0.2))
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                    .foregroundStyle(Color.secondary.opacity(0.15))
                AxisValueLabel {
                    if let v = val.as(Double.self) {
                        Text(String(format: "%.0f kg", v))
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 220)
    }

    // ── Legend ─────────────────────────────────────────────────────────────

    private var legendRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                legendItem(solid: true,  color: HONTheme.accent,   label: "Actual avg")
                legendItem(solid: true,  color: HONTheme.warning, label: "Rested avg")
                legendItem(solid: true,  color: HONTheme.positive,  label: "Trend (actual)")
            }
            HStack(spacing: 12) {
                legendItem(solid: false, color: HONTheme.positive,  label: "Trend (forecast)")
                legendItem(solid: false, color: HONTheme.warning, label: "Rested forecast")
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(HONTheme.chartAmber)
                    Text("PR").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func legendItem(solid: Bool, color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            if solid {
                Rectangle().fill(color).frame(width: 14, height: 2.5)
            } else {
                // dashed line indicator
                HStack(spacing: 2) {
                    Rectangle().fill(color.opacity(0.5)).frame(width: 6, height: 2.5)
                    Rectangle().fill(color.opacity(0.5)).frame(width: 4, height: 2.5)
                }
            }
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    // ── OLS helpers ───────────────────────────────────────────────────────

    private func olsSlope(sessions: [SessionPoint]) -> (slope: Double, xMean: Double, yMean: Double)? {
        guard sessions.count >= 2 else { return nil }
        let dates  = sessions.map { $0.date.timeIntervalSince1970 }
        let values = sessions.map { $0.estimated1RM }
        let n      = Double(sessions.count)
        let xMean  = dates.reduce(0, +) / n
        let yMean  = values.reduce(0, +) / n
        let num    = zip(dates, values).reduce(0) { $0 + ($1.0 - xMean) * ($1.1 - yMean) }
        let den    = dates.reduce(0) { $0 + ($1 - xMean) * ($1 - xMean) }
        guard den != 0 else { return nil }
        return (num / den, xMean, yMean)
    }

    private func olsTrendPoints(sessions: [SessionPoint]) -> [SessionPoint] {
        guard let (slope, xMean, yMean) = olsSlope(sessions: sessions) else { return [] }
        func y(_ t: TimeInterval) -> Double { yMean + slope * (t - xMean) }
        let t0 = sessions.first!.date.timeIntervalSince1970
        let t1 = sessions.last!.date.timeIntervalSince1970
        return [
            SessionPoint(date: Date(timeIntervalSince1970: t0), estimated1RM: y(t0), bestWeight: 0, bestReps: 0, feel: nil),
            SessionPoint(date: Date(timeIntervalSince1970: t1), estimated1RM: y(t1), bestWeight: 0, bestReps: 0, feel: nil)
        ]
    }

    private func olsPredictionPoints(sessions: [SessionPoint]) -> [SessionPoint] {
        guard sessions.count >= 3,
              let (slope, xMean, yMean) = olsSlope(sessions: sessions) else { return [] }
        func y(_ t: TimeInterval) -> Double { max(0, yMean + slope * (t - xMean)) }
        let t0 = sessions.last!.date.timeIntervalSince1970
        let historySpan = t0 - sessions.first!.date.timeIntervalSince1970
        let forward = min(historySpan, 6 * 7 * 86400)   // cap at 6 weeks
        let t1 = t0 + forward
        return [
            SessionPoint(date: Date(timeIntervalSince1970: t0), estimated1RM: y(t0), bestWeight: 0, bestReps: 0, feel: nil),
            SessionPoint(date: Date(timeIntervalSince1970: t1), estimated1RM: y(t1), bestWeight: 0, bestReps: 0, feel: nil)
        ]
    }
}

private struct SSExerciseScoreRow: View {
    let analytics: ExerciseAnalytics
    let relPoint: RelativeStrengthPoint?
    let hasBodyWeight: Bool

    private var latestE1RM: Double? { analytics.sessions.last?.estimated1RM }
    private var latestFadjE1RM: Double? { analytics.sessionsFatigue.last?.estimated1RM }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(analytics.exercise.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(analytics.exercise.movementPattern.shortName)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if analytics.isPlateau {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                        Text("Plateau")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(HONTheme.warning)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(HONTheme.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                }
                Text("\(analytics.sessions.count) sessions")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            // Metric grid: 3 columns × 2 rows
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                metricCell(
                    icon: "scalemass.fill", color: HONTheme.accent,
                    label: "Est. Max",
                    value: latestE1RM.map { String(format: "%.0f kg", $0) } ?? "—",
                    sub: analytics.sessions.last.map { String(format: "%.0f kg × %d reps", $0.bestWeight, $0.bestReps) }
                )
                metricCell(
                    icon: "bolt.fill", color: HONTheme.chartSlate,
                    label: "Rested Max",
                    value: latestFadjE1RM.map { String(format: "%.0f kg", $0) } ?? "—",
                    sub: fadjDelta
                )
                trendCell
                inolCell
                efficiencyCell
                relStrengthCell
            }

            // Sparkline — e1RM trend
            if analytics.sessions.count >= 2 {
                sparkline
            }
        }
        .padding(12)
        .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 12))
    }

    private var sparkline: some View {
        let pts = analytics.sessions
        let fapts = analytics.sessionsFatigue
        let values = pts.map { $0.estimated1RM }
        let faValues = fapts.map { $0.estimated1RM }
        let allVals = values + faValues
        let yMin = (allVals.min() ?? 0) * 0.94
        let yMax = (allVals.max() ?? 1) * 1.06
        let trendColor: Color = analytics.isPlateau ? HONTheme.warning
            : max(analytics.pctChangePerWeek, analytics.pctChangePerWeekFatigue) >= 0.5 ? HONTheme.positive
            : max(analytics.pctChangePerWeek, analytics.pctChangePerWeekFatigue) >= 0 ? HONTheme.accent : HONTheme.negative

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Estimated Max History")
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Circle().fill(trendColor).frame(width: 5, height: 5)
                        Text("Actual").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 3) {
                        Circle().fill(HONTheme.warning.opacity(0.7)).frame(width: 5, height: 5)
                        Text("Rested est.").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
            }

            Chart {
                // Fatigue-adjusted line (orange, dashed)
                ForEach(Array(fapts.enumerated()), id: \.offset) { idx, pt in
                    LineMark(
                        x: .value("Session", idx),
                        y: .value("Fadj e1RM", pt.estimated1RM)
                    )
                    .foregroundStyle(HONTheme.warning.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .interpolationMethod(.catmullRom)
                }
                // Standard e1RM line
                ForEach(Array(pts.enumerated()), id: \.offset) { idx, pt in
                    LineMark(
                        x: .value("Session", idx),
                        y: .value("e1RM", pt.estimated1RM)
                    )
                    .foregroundStyle(trendColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                    .symbol { Circle().fill(trendColor).frame(width: 4, height: 4) }
                }
                // PR annotations
                ForEach(Array(analytics.prProgression.enumerated()), id: \.offset) { _, pr in
                    let sessionIdx = pts.firstIndex(where: {
                        Calendar.current.isDate($0.date, inSameDayAs: pr.date)
                    }).map { Double($0) }
                    if let x = sessionIdx {
                        PointMark(
                            x: .value("Session", x),
                            y: .value("PR", pr.estimated1RM)
                        )
                        .symbol { Image(systemName: "star.fill").font(.system(size: 7)).foregroundStyle(HONTheme.chartAmber) }
                    }
                }
            }
            .chartYScale(domain: yMin...yMax)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                        .foregroundStyle(Color.secondary.opacity(0.15))
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            Text(String(format: "%.0f", v))
                                .font(.system(size: 8)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 72)
        }
        .padding(8)
        .background(AppTheme.cardBG.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }

    private var fadjDelta: String? {
        guard let e = latestE1RM, let fa = latestFadjE1RM, e > 0 else { return nil }
        let diff = (fa - e) / e * 100
        return String(format: "+%.0f%% if fully rested", diff)
    }

    private var trendCell: some View {
        let pct = analytics.pctChangePerWeek
        let pctFadj = analytics.pctChangePerWeekFatigue
        let best = max(pct, pctFadj)
        let color: Color = best > 0.5 ? HONTheme.positive : best > 0 ? HONTheme.accent : HONTheme.negative
        let sign = best >= 0 ? "+" : ""
        return metricCell(
            icon: "arrow.up.right", color: color,
            label: "Trend",
            value: String(format: "%@%.1f%%/wk", sign, best),
            sub: String(format: "%.2f kg/wk", analytics.slopePerWeek)
        )
    }

    private var inolCell: some View {
        let inol = analytics.latestINOL
        let zone = inol.map { INOLZone(inol: $0).rawValue } ?? "—"
        let color: Color = {
            guard let i = inol else { return .secondary }
            switch i {
            case ..<0.4:  return .secondary
            case ..<0.8:  return HONTheme.accent
            case ..<1.5:  return HONTheme.positive
            case ..<2.0:  return HONTheme.warning
            default:      return HONTheme.negative
            }
        }()
        return metricCell(
            icon: "gauge.with.needle", color: color,
            label: "Volume Load",
            value: inol.map { String(format: "%.2f", $0) } ?? "—",
            sub: zone
        )
    }

    private var efficiencyCell: some View {
        let label = analytics.efficiencyLabel ?? "—"
        let color: Color = {
            switch label {
            case "Great":      return HONTheme.positive
            case "Average":    return HONTheme.accent
            case "Below avg":  return HONTheme.warning
            default:           return .secondary
            }
        }()
        return metricCell(
            icon: "arrow.up.forward.circle", color: color,
            label: "Efficiency",
            value: label,
            sub: "gains vs effort"
        )
    }

    private var relStrengthCell: some View {
        if !hasBodyWeight {
            return AnyView(metricCell(
                icon: "scalemass", color: .secondary,
                label: "Rel. Str.",
                value: "No BW",
                sub: "Set in Settings"
            ))
        }
        guard let rp = relPoint else {
            return AnyView(metricCell(
                icon: "scalemass", color: .secondary,
                label: "Rel. Str.",
                value: "—",
                sub: nil
            ))
        }
        let tierColor: Color = {
            switch rp.tier {
            case .beginner:   return .secondary
            case .intermediate: return HONTheme.accent
            case .advanced:     return HONTheme.positive
            case .elite:        return HONTheme.chartLavender
            }
        }()
        return AnyView(metricCell(
            icon: "trophy.fill", color: tierColor,
            label: "Rel. Str.",
            value: String(format: "%.2f×", rp.relativeStrength),
            sub: rp.tier.rawValue
        ))
    }

    private func metricCell(icon: String, color: Color, label: String, value: String, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let s = sub {
                Text(s)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Score Info Sheet

private struct SSScoreInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    formulaCard
                    levelCard
                    momentumCard
                    processCard
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .background(AppTheme.pageBG)
            .navigationTitle("How the Score Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var formulaCard: some View {
        infoCard(icon: "function", color: HONTheme.chartLavender, title: "The Formula") {
            VStack(alignment: .leading, spacing: 10) {
                Text("CSS combines three pillars into a single 0–100 score:")
                    .font(.subheadline).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                formulaBlock("CSS  =  0.35 × Level\n     +  0.40 × Momentum\n     +  0.25 × Process")
                HStack(spacing: 0) {
                    pillarChip("35%", "Level",    HONTheme.accent)
                    Spacer()
                    pillarChip("40%", "Momentum", HONTheme.positive)
                    Spacer()
                    pillarChip("25%", "Process",  HONTheme.chartLavender)
                }
                Text("Momentum has the highest weight because rate of improvement is more predictive of long-term progress than current absolute level.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var levelCard: some View {
        infoCard(icon: "chart.bar.fill", color: HONTheme.accent, title: "Level  (35%)") {
            VStack(alignment: .leading, spacing: 10) {
                Text("How close your current strength is to your personal best, across all exercises.")
                    .font(.subheadline).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                formulaBlock("Level  =  mean( current_e1RM ÷ best_e1RM )\n         × 100   per exercise")
                exampleRow("🔵", "At peak (PR week)",        "current ≈ best → Level ≈ 100")
                exampleRow("🟡", "After deload",             "current ≈ 90% of best → Level ≈ 90")
                exampleRow("🔴", "Returning from injury",    "current ≈ 70% of best → Level ≈ 70")
                Text("A Level below 80 is normal after a planned recovery phase — it's not a failure.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if true { // PSI note always shown
                    Text("If body weight is set in Settings, Level also blends in PSI (fiber load) at 50/50, giving a fuller picture of your strength level across all muscle groups.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var momentumCard: some View {
        infoCard(icon: "arrow.up.right", color: HONTheme.positive, title: "Momentum  (40%)") {
            VStack(alignment: .leading, spacing: 10) {
                Text("How fast you are improving right now, from OLS linear regression across recent sessions.")
                    .font(.subheadline).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                formulaBlock("Momentum  =  clamp( 50 + %/wk × 25,  0, 100 )\n\n0 %/wk  →  50 pts  (flat, no progress)\n+2%/wk  →  100 pts  (strong gains)\n−2%/wk  →  0 pts   (declining)")
                Text("The app uses the best of two trends — standard e1RM and fatigue-adjusted e1RM — so you get credit for improvement even if raw numbers are suppressed by fatigue.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 0) {
                    momentumTick("0",    "0%/wk",  HONTheme.negative)
                    Spacer()
                    momentumTick("50",   "flat",   HONTheme.warning)
                    Spacer()
                    momentumTick("75",   "+1%/wk", HONTheme.accent)
                    Spacer()
                    momentumTick("100",  "+2%/wk", HONTheme.positive)
                }
                .padding(.top, 4)
            }
        }
    }

    private var processCard: some View {
        infoCard(icon: "gearshape.2.fill", color: HONTheme.chartLavender, title: "Process  (25%)") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Training quality from your most recent session. Three sub-scores combined:")
                    .font(.subheadline).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                formulaBlock("Process  =  0.40 × INOL_score\n         +  0.40 × Efficiency_score\n         +  0.20 × RepDecay_score")

                subScoreSection("INOL", "40% of Process",
                    "Measures how close your session volume/intensity was to the optimal zone (INOL 0.8–1.5).",
                    "INOL_score  =  max(0,  100 − |INOL − 1.15| × 55)\nPeak at INOL=1.15 → 100 pts\nEvery 1.0 unit away from optimal → −55 pts")

                subScoreSection("Efficiency", "40% of Process",
                    "Are you gaining strength proportional to the fatigue you're producing? Ranked against your own history.",
                    "≥ Q3 (top 25% of your sessions)  →  90 pts\nQ1–Q3 (middle 50%)               →  60 pts\n< Q1 (bottom 25%)                →  25 pts")

                subScoreSection("Rep Decay", "20% of Process",
                    "Is your intra-session fatigue rate in a healthy range? −1.5 to −0.5 reps/set is optimal.",
                    "−1.5 to −0.5 reps/set  →  100 pts  (optimal)\n−3.0 to −1.5            →   70 pts\n  0  to −0.5 (flat)     →   65 pts\n> 0  (ascending)        →   40 pts\n< −3.0 (steep drop)     →   30 pts")
            }
        }
    }

    private func infoCard<Content: View>(icon: String, color: Color, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.bold()).foregroundStyle(color)
                Text(title).font(.headline)
            }
            content()
        }
        .padding(16)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private func formulaBlock(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 8))
    }

    private func pillarChip(_ pct: String, _ name: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(pct).font(.system(size: 16, weight: .black)).foregroundStyle(color)
            Text(name).font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func momentumTick(_ pts: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(pts).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func exampleRow(_ emoji: String, _ context: String, _ result: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(emoji)
            VStack(alignment: .leading, spacing: 2) {
                Text(context).font(.caption.bold()).foregroundStyle(.primary)
                Text(result).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func subScoreSection(_ name: String, _ weight: String, _ desc: String, _ formula: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(name).font(.caption.bold()).foregroundStyle(HONTheme.chartLavender)
                Text("·").foregroundStyle(.tertiary)
                Text(weight).font(.caption).foregroundStyle(.secondary)
            }
            Text(desc).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(formula)
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.primary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(10)
        .background(HONTheme.chartLavender.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Composite Score Card

private struct SSCompositeCard: View {
    let composite: CompositeStrengthResult

    @State private var showScoreInfo = false

    var body: some View {
        VStack(spacing: 14) {
            pillarsSection
                .sheet(isPresented: $showScoreInfo) { SSScoreInfoSheet() }
            if composite.history.count >= 3 { historyChart }
            processBreakdown
            formulaNote
        }
    }

    // ── Three pillars ─────────────────────────────────────────────────────

    private var pillarsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Score Breakdown")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                Text("Strength Level · Progress Rate · Training Quality")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
                Button { showScoreInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            pillarRow(label: "Strength Level",    value: composite.levelScore,    color: HONTheme.accent,
                      detail: String(format: "You're at %.0f%% of your personal best", composite.peakRetentionPct))
            pillarRow(label: "Progress Rate", value: composite.momentumScore, color: HONTheme.positive,
                      detail: momentumDetail)
            pillarRow(label: "Training Quality",  value: composite.processScore,  color: HONTheme.chartLavender,
                      detail: processDetail)
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private var momentumDetail: String {
        let mapped = (composite.momentumScore - 50.0) / 25.0
        if abs(mapped) < 0.1 { return "Progress is flat — no clear gains or losses" }
        let dir = mapped > 0 ? "gaining" : "losing"
        return String(format: "Strength is %@ at %.1f%%/week on average", dir, abs(mapped))
    }

    private var processDetail: String {
        var parts: [String] = []
        if let i = composite.inolSubScore        { parts.append(String(format: "Volume %.0f", i)) }
        if let e = composite.efficiencySubScore  { parts.append(String(format: "Efficiency %.0f", e)) }
        if let d = composite.repDecaySubScore    { parts.append(String(format: "Endurance %.0f", d)) }
        return parts.isEmpty ? "Needs more data" : parts.joined(separator: " · ")
    }

    private func pillarRow(label: String, value: Double, color: Color, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label).font(.caption.bold()).foregroundStyle(color)
                Spacer()
                Text(String(format: "%.0f / 100", value))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.12))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.75))
                        .frame(width: geo.size.width * CGFloat(value / 100), height: 8)
                }
            }
            .frame(height: 8)
            Text(detail)
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    // ── Historical trend chart ────────────────────────────────────────────

    private var historyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Score History")
                .font(.caption.bold()).foregroundStyle(.secondary)

            Chart {
                // Reference lines at score thresholds
                ForEach([90.0, 80.0, 70.0, 60.0], id: \.self) { threshold in
                    RuleMark(y: .value("Threshold", threshold))
                        .foregroundStyle(Color.secondary.opacity(0.20))
                        .lineStyle(StrokeStyle(lineWidth: 0.6, dash: [4, 3]))
                }

                ForEach(composite.history) { pt in
                    AreaMark(x: .value("Date", pt.date), y: .value("Score", pt.score))
                        .foregroundStyle(LinearGradient(
                            colors: [scoreColor(pt.score).opacity(0.30), scoreColor(pt.score).opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .interpolationMethod(.catmullRom)

                    LineMark(x: .value("Date", pt.date), y: .value("Score", pt.score))
                        .foregroundStyle(scoreColor(pt.score))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                        .symbol { Circle().fill(scoreColor(pt.score)).frame(width: 5, height: 5) }
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 60, 70, 80, 90, 100]) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                        .foregroundStyle(Color.secondary.opacity(0.15))
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            Text("\(Int(v))")
                                .font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                        .foregroundStyle(Color.secondary.opacity(0.15))
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            .frame(height: 160)

            // Score legend
            HStack(spacing: 10) {
                ForEach([("Peak","purple"),("Strong","green"),("Solid","blue"),("Building","yellow"),("Steady","orange")], id: \.0) { label, c in
                    HStack(spacing: 3) {
                        Circle().fill(namedColor(c)).frame(width: 6, height: 6)
                        Text(label).font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 90...: return HONTheme.chartLavender
        case 80..<90: return HONTheme.positive
        case 70..<80: return HONTheme.accent
        case 60..<70: return HONTheme.chartAmber
        case 50..<60: return HONTheme.warning
        default:      return HONTheme.negative
        }
    }

    // ── Process sub-score breakdown ───────────────────────────────────────

    private var processBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Training Quality  (last session)")
                .font(.caption.bold()).foregroundStyle(.secondary)

            HStack(spacing: 10) {
                processCell(label: "Volume",     value: composite.inolSubScore,       note: "sets & intensity",  icon: "waveform")
                processCell(label: "Efficiency", value: composite.efficiencySubScore, note: "gains per effort",  icon: "bolt.fill")
                processCell(label: "Endurance",  value: composite.repDecaySubScore,   note: "strength across sets", icon: "arrow.down.right")
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private func processCell(label: String, value: Double?, note: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption).foregroundStyle(HONTheme.chartLavender)
            if let v = value {
                Text(String(format: "%.0f", v))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                Text(note).font(.system(size: 8)).foregroundStyle(.tertiary)
            } else {
                Text("—").font(.title3).foregroundStyle(.tertiary)
                Text(label).font(.system(size: 9)).foregroundStyle(.tertiary)
                Text("needs data").font(.system(size: 8)).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(HONTheme.chartLavender.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    // ── Formula note ──────────────────────────────────────────────────────

    private var formulaNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("How this score is calculated")
                .font(.caption2.bold()).foregroundStyle(.secondary)
            Text("Strength Level: how close your current max is to your all-time best across all exercises.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            Text("Progress Rate: how fast your strength is improving week-over-week.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            Text("Training Quality: whether your volume, efficiency, and intra-set endurance are in a healthy range.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            Text("Tap ⓘ for the full breakdown.")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(HONTheme.chartLavender.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func namedColor(_ name: String) -> Color {
        switch name {
        case "purple": return HONTheme.chartLavender
        case "green":  return HONTheme.positive
        case "blue":   return HONTheme.accent
        case "yellow": return HONTheme.chartAmber
        case "orange": return HONTheme.warning
        case "red":    return HONTheme.negative
        default:       return .gray
        }
    }
}
