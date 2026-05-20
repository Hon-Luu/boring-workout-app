import SwiftUI
import Charts

// MARK: - Process Detail View (Layer 1C)

struct ProcessDetailView: View {
    @Environment(SeedStore.self) private var store
    @State private var drillDown: ExerciseAnalytics? = nil

    private var composite: CompositeStrengthResult { store.analyticsCache.compositeScore }
    private var strength:  StrengthScoreResult   { store.analyticsCache.strengthScore }
    private var exercises: [ExerciseAnalytics]   { store.analyticsCache.exerciseAnalytics }
    private var tier:      StrengthTier          { strength.overallTier }

    private var inolCenter: Double {
        switch tier {
        case .beginner: return 0.60; case .intermediate: return 0.90
        case .advanced:   return 1.15; case .elite:        return 1.50
        }
    }
    private var inolPenalty: Double {
        switch tier {
        case .beginner: return 100.0; case .intermediate: return 67.0
        case .advanced:   return  57.0; case .elite:        return 40.0
        }
    }
    private var inolZone: (lo: Double, hi: Double) {
        let hw = 20.0 / inolPenalty
        return (inolCenter - hw, inolCenter + hw)
    }

    // INOL per exercise from last session
    private struct INOLRow: Identifiable {
        let id: UUID
        let name: String
        let inol: Double
        let score: Double
        let inZone: Bool
    }

    private var inolRows: [INOLRow] {
        exercises.compactMap { ea -> INOLRow? in
            guard let inol = ea.latestINOL else { return nil }
            let score = max(0, 100.0 - abs(inol - inolCenter) * inolPenalty)
            let zone = inolZone
            return INOLRow(id: ea.id, name: ea.exercise.name, inol: inol,
                           score: score, inZone: inol >= zone.lo && inol <= zone.hi)
        }
        .sorted { $0.inol > $1.inol }
    }

    // INOL history (one point per session = mean INOL across all exercises that session)
    private struct INOLHistoryPoint: Identifiable {
        let id = UUID(); let index: Int; let inol: Double
    }
    private var inolHistory: [INOLHistoryPoint] {
        // Use CSS history length as proxy; rebuild from exercise rolling data
        // Approximation: mean of each exercise's INOL is just the latest — show per-exercise trend instead
        // For a true per-session view we'd need stored data; show the last session bar chart
        []  // not enough stored per-session INOL data — handled in UI with fallback text
    }

    // Rep decay per exercise (last session)
    private struct DecayRow: Identifiable {
        let id: UUID; let name: String; let decay: Double; let score: Double
    }
    private var decayRows: [DecayRow] {
        exercises.compactMap { ea -> DecayRow? in
            guard let d = ea.latestRepDecay else { return nil }
            let score: Double
            switch d {
            case -1.5 ... -0.5: score = 100
            case -2.5 ... -1.5: score = 70
            case -0.5 ..< 0:    score = 65
            case 0...:          score = 40
            default:            score = 30
            }
            return DecayRow(id: ea.id, name: ea.exercise.name, decay: d, score: score)
        }
        .sorted { abs($0.decay) > abs($1.decay) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                diagnosisCard
                overviewCard
                inolCard
                efficiencyCard
                repDecayCard
            }
            .padding(16)
        }
        .background(AppTheme.pageBG)
        .sheet(item: $drillDown) { ExerciseDetailSheet(analytics: $0) }
    }

    // MARK: - Diagnosis Card

    private var diagnosisCard: some View {
        let inol   = composite.inolSubScore
        let eff    = composite.efficiencySubScore
        let decay  = composite.repDecaySubScore
        let proc   = composite.processScore
        let color  = scoreGradeColor(proc)

        // Identify weakest sub-score
        let scores: [(label: String, score: Double, action: String)] = [
            ("INOL", inol ?? 50,
             inolDiagnosisAction(inol)),
            ("Efficiency", eff ?? 50,
             "Session cost isn't translating to strength gains. Audit sleep, protein, and stress — recovery quality directly determines efficiency score."),
            ("Rep Decay", decay ?? 50,
             "Your rep drop-off within sets is outside the optimal zone (−1.5 to −0.5 reps/set). Too steep = under-recovered. Too flat = load is too easy.")
        ].sorted { $0.score < $1.score }

        let weakest = scores.first!

        return DetailCard(title: "Process Diagnosis", icon: "stethoscope", accent: color) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(String(format: "%.0f", proc))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Process Score").font(.caption2).foregroundStyle(.secondary)
                        Text("Drag: \(weakest.label) (\(String(format: "%.0f", weakest.score)))")
                            .font(.caption.bold())
                            .foregroundStyle(weakest.score < 60 ? HONTheme.warning : .primary)
                    }
                }
                Text(weakest.action)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func inolDiagnosisAction(_ score: Double?) -> String {
        guard let score = score else {
            return "Not enough session data to compute INOL. Log more sets to activate this metric."
        }
        // Back-calculate approximate INOL from score: score ≈ 100 - |INOL - centre| × penalty
        // If score is low, load is either too low or too high
        if score < 60 {
            return "INOL score \(String(format: "%.0f", score)) — your load is far from the optimal zone for your tier (\(inolCenter) centre). Adjust sets×intensity until INOL lands in the green band on the chart below."
        }
        return "INOL is near optimal. Fine-tune intensity to keep it in the green zone."
    }

    // MARK: - Overview

    private var overviewCard: some View {
        DetailCard(title: "Score Composition", icon: "gearshape.2.fill", accent: HONTheme.chartLavender) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    metricCell(String(format: "%.0f", composite.processScore), "Process", HONTheme.chartLavender)
                    Divider().frame(height: 36)
                    metricCell(composite.inolSubScore.map { String(format: "%.0f", $0) } ?? "—", "INOL (40%)", HONTheme.accent)
                    Divider().frame(height: 36)
                    metricCell(composite.efficiencySubScore.map { String(format: "%.0f", $0) } ?? "—", "Efficiency (40%)", HONTheme.positive)
                    Divider().frame(height: 36)
                    metricCell(composite.repDecaySubScore.map { String(format: "%.0f", $0) } ?? "—", "RepDecay (20%)", HONTheme.warning)
                }
                .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

                if let i = composite.inolSubScore, let e = composite.efficiencySubScore, let d = composite.repDecaySubScore {
                    let calc = 0.40 * i + 0.40 * e + 0.20 * d
                    Text(String(format: "Process = 0.40 × %.0f + 0.40 × %.0f + 0.20 × %.0f = %.0f", i, e, d, calc))
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                } else {
                    Text("Log more sessions to compute all sub-scores.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - INOL Card

    private var inolCard: some View {
        DetailCard(title: "INOL Sub-Score", icon: "bolt.horizontal.fill", accent: HONTheme.accent) {
            VStack(spacing: 12) {
                // Tier context
                HStack(spacing: 0) {
                    metricCell(String(format: "%.2f", inolCenter), "Optimal Centre", HONTheme.accent)
                    Divider().frame(height: 36)
                    metricCell(String(format: "%.2f–%.2f", inolZone.lo, inolZone.hi), "Zone", .primary)
                    Divider().frame(height: 36)
                    metricCell(tier.rawValue, "Tier", .primary)
                }
                .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

                Text(String(format: "INOL_score = max(0, 100 − |INOL − %.2f| × %.0f)", inolCenter, inolPenalty))
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)

                if !inolRows.isEmpty {
                    Divider()
                    Text("Last session — INOL by exercise")
                        .font(.caption.bold()).foregroundStyle(.secondary)

                    // Bar chart with zone band
                    let zone = inolZone
                    Chart {
                        RectangleMark(
                            xStart: .value("Zone Lo", zone.lo),
                            xEnd:   .value("Zone Hi", zone.hi),
                            yStart: nil, yEnd: nil
                        )
                        .foregroundStyle(HONTheme.positive.opacity(0.08))

                        RuleMark(x: .value("Centre", inolCenter))
                            .foregroundStyle(HONTheme.positive.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                        ForEach(inolRows) { row in
                            BarMark(
                                x: .value("INOL", row.inol),
                                y: .value("Exercise", row.name)
                            )
                            .foregroundStyle(row.inZone ? Color.green.opacity(0.75) : Color.orange.opacity(0.75))
                            .cornerRadius(4)
                            .annotation(position: .trailing, spacing: 4) {
                                Text(String(format: "%.2f", row.inol))
                                    .font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .chartXScale(domain: 0...(max(2.5, (inolRows.map(\.inol).max() ?? 2) * 1.3)))
                    .chartXAxis {
                        AxisMarks(values: [0.5, 1.0, 1.5, 2.0]) { val in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                                .foregroundStyle(Color.secondary.opacity(0.2))
                            AxisValueLabel {
                                if let v = val.as(Double.self) {
                                    Text(String(format: "%.1f", v))
                                        .font(.system(size: 9)).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { val in
                            AxisValueLabel {
                                if let s = val.as(String.self) {
                                    Text(s).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                        }
                    }
                    .frame(height: CGFloat(inolRows.count) * 28 + 20)

                    // Legend
                    HStack(spacing: 14) {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(HONTheme.positive.opacity(0.12))
                                .frame(width: 12, height: 8)
                            Text("Optimal zone").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(HONTheme.positive.opacity(0.75))
                                .frame(width: 12, height: 8)
                            Text("In zone").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(HONTheme.warning.opacity(0.75))
                                .frame(width: 12, height: 8)
                            Text("Out of zone").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }

                    Divider()
                    // Score per exercise
                    VStack(spacing: 0) {
                        ForEach(inolRows) { row in
                            Button { drillDown = exercises.first { $0.id == row.id } } label: {
                                HStack {
                                    Text(row.name).font(.caption).lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(String(format: "%.2f", row.inol))
                                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                        .frame(width: 40, alignment: .trailing)
                                    Text(row.inZone ? "✓" : "⚠")
                                        .font(.caption).frame(width: 16)
                                    Text(String(format: "%.0f", row.score))
                                        .font(.caption.bold())
                                        .foregroundStyle(row.inZone ? HONTheme.positive : HONTheme.warning)
                                        .frame(width: 32, alignment: .trailing)
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            Divider().opacity(0.5)
                        }
                    }
                } else {
                    Text("No INOL data — log a session with completed sets.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Efficiency Card

    private var efficiencyCard: some View {
        DetailCard(title: "Efficiency Sub-Score", icon: "arrow.up.right.and.arrow.down.left", accent: HONTheme.positive) {
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    metricCell(composite.efficiencySubScore.map { String(format: "%.0f", $0) } ?? "—",
                               "Eff. Score", HONTheme.positive)
                    Divider().frame(height: 36)
                    if let ea = exercises.first, let cost = ea.latestSessionCost {
                        metricCell(String(format: "%.0f", cost), "Session Cost", .primary)
                    } else {
                        metricCell("—", "Session Cost", .primary)
                    }
                    Divider().frame(height: 36)
                    metricCell(composite.efficiencySubScore.map { scoreLabel($0) } ?? "—",
                               "Quartile", .primary)
                }
                .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

                Text("efficiency = Δrolling_avg_e1RM ÷ session_cost\nScore = 90 if top quartile · 60 if mid · 25 if bottom")
                    .font(.caption).foregroundStyle(.secondary)

                // Session load trend — gives cost context without stored per-session cost history
                let psiLoads = strength.psiHistory.suffix(12)
                if psiLoads.count >= 3 {
                    let vals = psiLoads.map(\.rawFiberLoad)
                    let mn = vals.min()! * 0.9; let mx = vals.max()! * 1.1
                    // 5-session rolling average
                    let rollingAvg: [Double] = vals.indices.map { i in
                        let window = vals[max(0, i - 4)...i]
                        return window.reduce(0, +) / Double(window.count)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("Session load trend (last \(psiLoads.count) sessions)")
                                .font(.caption2).foregroundStyle(.tertiary)
                            Spacer()
                            HStack(spacing: 4) {
                                Circle().fill(HONTheme.positive.opacity(0.5)).frame(width: 6, height: 6)
                                Text("Raw").font(.system(size: 8)).foregroundStyle(.tertiary)
                                RoundedRectangle(cornerRadius: 1).fill(HONTheme.warning).frame(width: 10, height: 2)
                                Text("5-avg").font(.system(size: 8)).foregroundStyle(.tertiary)
                            }
                        }
                        Chart {
                            ForEach(Array(vals.enumerated()), id: \.offset) { i, v in
                                LineMark(x: .value("i", i), y: .value("PSI", v))
                                    .foregroundStyle(HONTheme.positive.opacity(0.45))
                                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                                    .interpolationMethod(.linear)
                                    .symbol { Circle().fill(HONTheme.positive.opacity(0.5)).frame(width: 4) }
                            }
                            ForEach(Array(rollingAvg.enumerated()), id: \.offset) { i, v in
                                LineMark(x: .value("i", i), y: .value("Avg", v))
                                    .foregroundStyle(HONTheme.warning.opacity(0.85))
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                    .interpolationMethod(.catmullRom)
                            }
                        }
                        .chartYScale(domain: mn...mx)
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: 44)
                    }
                    .padding(8)
                    .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 8))
                }

                if !exercises.filter({ $0.efficiencyScore != nil }).isEmpty {
                    Divider()
                    VStack(spacing: 0) {
                        ForEach(exercises.filter { $0.efficiencyScore != nil }.sorted {
                            ($0.efficiencyScore ?? 0) > ($1.efficiencyScore ?? 0)
                        }.prefix(8)) { ea in
                            Button { drillDown = ea } label: {
                                HStack {
                                    Text(ea.exercise.name).font(.caption).lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(ea.efficiencyLabel ?? "—")
                                        .font(.system(size: 10))
                                        .foregroundStyle(effLabelColor(ea.efficiencyLabel))
                                    if let cost = ea.latestSessionCost {
                                        Text(String(format: "cost %.0f", cost))
                                            .font(.system(size: 9)).foregroundStyle(.tertiary)
                                            .frame(width: 58, alignment: .trailing)
                                    }
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Rep Decay Card

    private var repDecayCard: some View {
        DetailCard(title: "Rep Decay Sub-Score", icon: "arrow.down.right", accent: HONTheme.warning) {
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    metricCell(composite.repDecaySubScore.map { String(format: "%.0f", $0) } ?? "—",
                               "Decay Score", HONTheme.warning)
                    Divider().frame(height: 36)
                    metricCell("−1.5 to −0.5", "Optimal", HONTheme.positive)
                    Divider().frame(height: 36)
                    metricCell("reps/set", "Unit", .primary)
                }
                .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    decayZoneRow("[−1.5, −0.5]", "Optimal — controlled fatigue", "100", HONTheme.positive)
                    decayZoneRow("[−2.5, −1.5]", "Moderately steep", "70", HONTheme.chartAmber)
                    decayZoneRow("[−0.5,  0.0]", "Too consistent — load may be easy", "65", HONTheme.accent)
                    decayZoneRow("[  0.0,  +∞]", "Ascending — warm-up effect", "40", HONTheme.warning)
                    decayZoneRow("[  −∞, −2.5]", "Severe drop-off", "30", HONTheme.negative)
                }
                .padding(8)
                .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 8))

                if !decayRows.isEmpty {
                    Divider()
                    VStack(spacing: 0) {
                        ForEach(decayRows.prefix(8)) { row in
                            Button { drillDown = exercises.first { $0.id == row.id } } label: {
                                HStack {
                                    Text(row.name).font(.caption).lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(String(format: "%.1f rep/set", row.decay))
                                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                        .frame(width: 80, alignment: .trailing)
                                    Text(String(format: "%.0f", row.score))
                                        .font(.caption.bold())
                                        .foregroundStyle(row.score >= 90 ? HONTheme.positive : row.score >= 65 ? HONTheme.accent : HONTheme.warning)
                                        .frame(width: 32, alignment: .trailing)
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func metricCell(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color == .primary ? Color.primary : color == .secondary ? Color.secondary : color)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 8)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
    }

    private func decayZoneRow(_ range: String, _ desc: String, _ score: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Text(range).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary).frame(width: 80)
            Text(desc).font(.system(size: 9)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            Text(score).font(.system(size: 9, weight: .bold)).foregroundStyle(color).frame(width: 24, alignment: .trailing)
        }
    }

    private func scoreLabel(_ score: Double) -> String {
        score >= 80 ? "Top 25%" : score >= 50 ? "Mid 50%" : "Bottom 25%"
    }

    private func effLabelColor(_ label: String?) -> Color {
        switch label {
        case "Great":       return HONTheme.positive
        case "Average":     return HONTheme.accent
        case "Below avg":   return HONTheme.warning
        default:            return .secondary
        }
    }
}
