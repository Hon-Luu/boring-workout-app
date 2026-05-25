import SwiftUI
import Charts

// MARK: - Level Detail View (Layer 1A)

struct LevelDetailView: View {
    @Environment(SeedStore.self) private var store

    private var composite: CompositeStrengthResult { store.analyticsCache.compositeScore }
    private var strength:  StrengthScoreResult   { store.analyticsCache.strengthScore }
    private var exercises: [ExerciseAnalytics]   { store.analyticsCache.exerciseAnalytics }

    // Recompute Component C from relative strengths
    private var relAnchor: Double? {
        let scores: [Double] = strength.relativeStrengths
            .filter { $0.exercise.isCompound }
            .map { pt in
                switch pt.tier {
                case .beginner:   return 0.0
                case .intermediate: return 33.0
                case .advanced:     return 67.0
                case .elite:        return 100.0
                }
            }
        return scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)
    }

    private var compA: Double { composite.peakRetentionPct }
    private var compB: Double? { composite.psiLevelScore }

    // Per-exercise retention breakdown
    private struct RetentionRow: Identifiable {
        let id: UUID
        let name: String
        let activationWeight: Double
        let latestE1RM: Double
        let peakE1RM: Double
        let stdRetention: Double
        let adjRetention: Double
        let blended: Double
    }

    private var retentionRows: [RetentionRow] {
        exercises.compactMap { ea -> RetentionRow? in
            guard let latestStd = ea.sessions.last?.estimated1RM,
                  let peakStd   = ea.sessions.map(\.estimated1RM).max(), peakStd > 0 else { return nil }
            let stdRet = min(1.0, latestStd / peakStd)
            let adjRet: Double
            if let latestAdj = ea.sessionsFatigue.last?.estimated1RM,
               let peakAdj   = ea.sessionsFatigue.map(\.estimated1RM).max(), peakAdj > 0 {
                adjRet = min(1.0, latestAdj / peakAdj)
            } else {
                adjRet = stdRet
            }
            let blended = 0.5 * stdRet + 0.5 * adjRet
            let profile = StrengthScoreEngine.activationProfile(for: ea.exercise)
            let aw = profile.reduce(0.0) { $0 + $1.pctMVC * $1.muscle.pcsa }
            return RetentionRow(id: ea.id, name: ea.exercise.name,
                                activationWeight: aw,
                                latestE1RM: latestStd,
                                peakE1RM: peakStd,
                                stdRetention: stdRet, adjRetention: adjRet, blended: blended)
        }
        .sorted { $0.activationWeight > $1.activationWeight }
    }

    // Retention trend — one point per session, per pattern
    private struct RetentionPoint: Identifiable {
        let id = UUID()
        let date: Date
        let retention: Double
        let group: PatternGroup
    }

    private var retentionTrend: [RetentionPoint] {
        strength.patternBreakdown.flatMap { group, psr -> [RetentionPoint] in
            let peak = psr.history.map(\.rawFiberLoad).max() ?? 1
            return psr.history.map { pt in
                RetentionPoint(date: pt.date,
                               retention: min(100, pt.rawFiberLoad / peak * 100),
                               group: group)
            }
        }
        .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ── Diagnosis callout ─────────────────────────────────────
                diagnosisCard

                // ── Blend equation ───────────────────────────────────────
                blendCard

                // ── Component A ──────────────────────────────────────────
                componentACard

                // ── Component B (PSI Level) ──────────────────────────────
                componentBCard

                // ── Component C (Relative Anchor) ────────────────────────
                if !strength.relativeStrengths.isEmpty {
                    componentCCard
                }

                // ── Body Comp Strength ───────────────────────────────────
                if let bc = strength.bodyCompStrength {
                    bodyCompCard(bc)
                }

                // ── Retention Trend Chart ────────────────────────────────
                if retentionTrend.count >= 4 {
                    retentionTrendCard
                }
            }
            .padding(16)
        }
        .background(AppTheme.pageBG)
    }

    // MARK: - Diagnosis Card

    private var diagnosisCard: some View {
        let a = compA
        let b = compB
        let c = relAnchor

        // Identify the weakest component and generate a coaching note
        var weakLabel = "Component A (PCSA Retention)"
        var weakScore = a
        var action = "Your average e1RM is below your personal best. Focus on rebuilding strength on your highest-activation-weight exercises first — they move the needle most."

        if let b2 = b, b2 < weakScore {
            weakLabel = "Component B (PSI Level)"
            weakScore = b2
            action = "Your session fiber output is below your personal best. Check whether training volume or intensity has dropped — a 10% PSI recovery moves Level significantly."
        }
        if let c2 = c, c2 < weakScore {
            weakLabel = "Component C (Relative Strength)"
            weakScore = c2
            action = "Your compound lift ratios (e1RM ÷ body weight) are in the lower end of your tier. Prioritize squat, deadlift, and bench — these drive Component C directly."
        }

        let levelColor = scoreGradeColor(composite.levelScore)
        return DetailCard(title: "Level Diagnosis", icon: "stethoscope", accent: levelColor) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(String(format: "%.0f", composite.levelScore))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(levelColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Overall Level").font(.caption2).foregroundStyle(.secondary)
                        Text("Drag: \(weakLabel)")
                            .font(.caption.bold()).foregroundStyle(HONTheme.warning)
                    }
                }
                Text(action)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Blend Card

    private var blendCard: some View {
        DetailCard(title: "Score Composition", icon: "function") {
            VStack(spacing: 10) {
                HStack {
                    scoreCircle(String(format: "%.0f", composite.levelScore), "Level", HONTheme.accent)
                    Text("=").font(.title2.bold()).foregroundStyle(.secondary)
                    Spacer()
                    if let b = compB, let c = relAnchor {
                        blendTerm("50%", "A", String(format: "%.0f", compA), HONTheme.accent)
                        Text("+").foregroundStyle(.secondary)
                        blendTerm("30%", "B", String(format: "%.0f", b), HONTheme.positive)
                        Text("+").foregroundStyle(.secondary)
                        blendTerm("20%", "C", String(format: "%.0f", c), HONTheme.warning)
                    } else if let b = compB {
                        blendTerm("65%", "A", String(format: "%.0f", compA), HONTheme.accent)
                        Text("+").foregroundStyle(.secondary)
                        blendTerm("35%", "B", String(format: "%.0f", b), HONTheme.positive)
                    } else {
                        blendTerm("100%", "A", String(format: "%.0f", compA), HONTheme.accent)
                    }
                }

                if compB == nil {
                    Label("Add body weight in Settings to unlock Components B and C", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func scoreCircle(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 56, height: 56)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private func blendTerm(_ weight: String, _ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 15, weight: .bold)).foregroundStyle(color)
            Text(label).font(.caption2.bold()).foregroundStyle(color.opacity(0.8))
            Text(weight).font(.system(size: 9)).foregroundStyle(.tertiary)
        }
        .frame(width: 40)
    }

    // MARK: - Component A

    private var componentACard: some View {
        DetailCard(title: "Component A — PCSA Retention", icon: "chart.bar.xaxis", accent: HONTheme.accent) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    componentMetric("A Score", String(format: "%.0f", compA), HONTheme.accent)
                    Divider().frame(height: 36)
                    componentMetric("Exercises", "\(retentionRows.count)", .primary)
                    Divider().frame(height: 36)
                    componentMetric("Weighting", "PCSA", .secondary)
                }
                .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

                Text("Each exercise weighted by Σ(EMG% × PCSA) — heavier muscles count more.")
                    .font(.caption).foregroundStyle(.secondary)

                if !retentionRows.isEmpty {
                    Divider()
                    // Legend: Activation Weight explained
                    Label("Activation Wt (cm²) = Σ(EMG% × PCSA muscle area) — higher = more muscle recruited", systemImage: "info.circle")
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("Exercise").font(.caption2.bold()).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                            Text("e1RM").font(.caption2.bold()).foregroundStyle(.secondary).frame(width: 46, alignment: .trailing)
                            Text("Std").font(.caption2.bold()).foregroundStyle(.secondary).frame(width: 36, alignment: .trailing)
                            Text("Adj").font(.caption2.bold()).foregroundStyle(.secondary).frame(width: 36, alignment: .trailing)
                            Text("Blend").font(.caption2.bold()).foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        Divider()
                        ForEach(retentionRows.prefix(8)) { row in
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(row.name).font(.caption).lineLimit(1)
                                    Text(String(format: "Act. Wt %.0f cm²", row.activationWeight))
                                        .font(.system(size: 8)).foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                // e1RM: current / peak
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(String(format: "%.0f kg", row.latestE1RM))
                                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(.primary)
                                    Text(String(format: "pk %.0f", row.peakE1RM))
                                        .font(.system(size: 8)).foregroundStyle(.tertiary)
                                }
                                .frame(width: 46, alignment: .trailing)
                                retPct(row.stdRetention)
                                retPct(row.adjRetention)
                                Text(String(format: "%.0f%%", row.blended * 100))
                                    .font(.caption.bold())
                                    .foregroundStyle(row.blended >= 0.9 ? HONTheme.positive : row.blended >= 0.75 ? .primary : HONTheme.warning)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .padding(.vertical, 5)
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
        }
    }

    private func retPct(_ v: Double) -> some View {
        Text(String(format: "%.0f%%", v * 100))
            .font(.caption)
            .foregroundStyle(v >= 0.90 ? HONTheme.positive : v >= 0.75 ? .secondary : HONTheme.warning)
            .frame(width: 36, alignment: .trailing)
    }

    // MARK: - Component B

    private var componentBCard: some View {
        DetailCard(title: "Component B — PSI Level", icon: "waveform.path.ecg", accent: HONTheme.positive) {
            VStack(spacing: 12) {
                if let b = compB {
                    HStack(spacing: 0) {
                        componentMetric("B Score", String(format: "%.0f", b), HONTheme.positive)
                        Divider().frame(height: 36)
                        if let raw = strength.psiHistory.last?.rawFiberLoad {
                            componentMetric("Latest PSI", formatPSI(raw), .primary)
                        }
                        Divider().frame(height: 36)
                        if let peak = strength.psiHistory.map(\.rawFiberLoad).max() {
                            componentMetric("Peak PSI", formatPSI(peak), .primary)
                        }
                    }
                    .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

                    Text("B = latest session PSI ÷ all-time peak PSI × 100")
                        .font(.caption).foregroundStyle(.secondary)

                    Divider()

                    // PSI variants
                    VStack(spacing: 6) {
                        if let last = strength.psiHistory.last {
                            psiVariantRow("Raw fiber load", formatPSI(last.rawFiberLoad), nil)
                            if let n = last.normalizedPSI { psiVariantRow("÷ BW^0.67", String(format: "%.1f", n), "requires body weight") }
                            if let n = last.leanPSI       { psiVariantRow("÷ LeanMass^0.67", String(format: "%.1f", n), "requires body fat %") }
                            if let n = last.musclePSI     { psiVariantRow("÷ MuscleMass^0.67", String(format: "%.1f", n), "requires muscle mass %") }
                        }
                        let pct = strength.psiTrendPctPerWeek
                        psiVariantRow("PSI trend", String(format: "%@%.1f%%/wk", pct >= 0 ? "+" : "", pct), "OLS last 6 wks")
                    }
                } else {
                    Label("Add body weight in Settings to compute PSI Level", systemImage: "scalemass")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    private func psiVariantRow(_ label: String, _ value: String, _ note: String?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption)
                if let n = note { Text(n).font(.system(size: 9)).foregroundStyle(.tertiary) }
            }
            Spacer()
            Text(value).font(.caption.bold().monospacedDigit())
        }
    }

    // MARK: - Component C

    private var componentCCard: some View {
        DetailCard(title: "Component C — Relative Anchor", icon: "person.and.arrow.left.and.arrow.right", accent: HONTheme.warning) {
            VStack(spacing: 12) {
                if let c = relAnchor {
                    HStack(spacing: 0) {
                        componentMetric("C Score", String(format: "%.0f", c), HONTheme.warning)
                        Divider().frame(height: 36)
                        componentMetric("Tier", strength.overallTier.rawValue, .primary)
                        Divider().frame(height: 36)
                        let compounds = strength.relativeStrengths.filter { $0.exercise.isCompound }
                        componentMetric("Lifts", "\(compounds.count)", .primary)
                    }
                    .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

                    Text("Tier scores: Developing=0 · Intermediate=33 · Advanced=67 · Elite=100. Averaged across compound lifts.")
                        .font(.caption).foregroundStyle(.secondary)

                    Divider()

                    VStack(spacing: 0) {
                        HStack {
                            Text("Exercise").font(.caption2.bold()).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                            Text("e1RM").font(.caption2.bold()).foregroundStyle(.secondary).frame(width: 52, alignment: .trailing)
                            Text("÷ BW").font(.caption2.bold()).foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                            Text("Tier").font(.caption2.bold()).foregroundStyle(.secondary).frame(width: 54, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        Divider()
                        ForEach(strength.relativeStrengths.filter { $0.exercise.isCompound }) { pt in
                            HStack {
                                Text(pt.exercise.name).font(.caption).lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(String(format: "%.0f kg", pt.e1RM))
                                    .font(.caption).foregroundStyle(.secondary).frame(width: 52, alignment: .trailing)
                                Text(String(format: "%.2f×", pt.relativeStrength))
                                    .font(.caption.bold()).frame(width: 44, alignment: .trailing)
                                Text(pt.tier.shortLabel)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(tierColor(pt.tier))
                                    .frame(width: 54, alignment: .trailing)
                            }
                            .padding(.vertical, 5)
                            Divider().opacity(0.5)
                        }
                    }
                } else {
                    Label("Add body weight in Settings to compute Relative Anchor", systemImage: "scalemass")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Body Comp

    private func bodyCompCard(_ bc: BodyCompStrength) -> some View {
        DetailCard(title: "Body Composition Strength", icon: "figure.arms.open") {
            VStack(spacing: 6) {
                if let v = bc.leanMassKg     { bcRow("Lean mass",               String(format: "%.1f kg", v)) }
                if let v = bc.muscleMassKg   { bcRow("Muscle mass",             String(format: "%.1f kg", v)) }
                if let v = bc.psiPerLeanMass { bcRow("PSI / lean mass^0.67",   String(format: "%.1f", v)) }
                if let v = bc.psiPerMuscleMass { bcRow("PSI / muscle mass^0.67", String(format: "%.1f", v)) }
                if let v = bc.strengthToFatRatio { bcRow("Strength-fat ratio",  String(format: "%.0f", v)) }
            }
        }
    }

    private func bcRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.bold().monospacedDigit())
        }
    }

    // MARK: - Retention Trend Chart

    private var retentionTrendCard: some View {
        DetailCard(title: "Pattern Retention Trend", icon: "chart.xyaxis.line") {
            VStack(spacing: 8) {
                Chart {
                    ForEach(retentionTrend) { pt in
                        LineMark(
                            x: .value("Date", pt.date),
                            y: .value("Retention %", pt.retention),
                            series: .value("Pattern", pt.group.rawValue)
                        )
                        .foregroundStyle(patternColor(pt.group))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.linear)
                        .symbol { Circle().fill(patternColor(pt.group)).frame(width: 4) }
                    }
                    RuleMark(y: .value("Peak", 100))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .chartYScale(domain: 0...110)
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
                                Text(v >= 100 ? "Peak" : "\(Int(v))%")
                                    .font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 160)

                HStack(spacing: 14) {
                    ForEach(PatternGroup.allCases, id: \.self) { g in
                        if strength.patternBreakdown[g] != nil {
                            HStack(spacing: 4) {
                                Circle().fill(patternColor(g)).frame(width: 7, height: 7)
                                Text(g.rawValue).font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    private func componentMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color == .primary ? Color.primary : color)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func formatPSI(_ v: Double) -> String {
        v >= 100_000 ? String(format: "%.0fk", v / 1000)
            : v >= 10_000 ? String(format: "%.1fk", v / 1000)
            : String(format: "%.0f", v)
    }

    private func tierColor(_ tier: RelativeStrengthTier) -> Color {
        switch tier {
        case .beginner:   return .gray
        case .intermediate: return HONTheme.accent
        case .advanced:     return HONTheme.warning
        case .elite:        return HONTheme.chartLavender
        }
    }

    private func patternColor(_ g: PatternGroup) -> Color {
        switch g {
        case .push: return HONTheme.accent; case .pull: return HONTheme.positive
        case .legs: return HONTheme.warning; case .isolation: return HONTheme.chartLavender
        }
    }
}

// MARK: - Shared Detail Card

struct DetailCard<Content: View>: View {
    let title:   String
    let icon:    String
    var accent:  Color = .primary
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(accent == .primary ? Color.primary : accent)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 16))
    }
}
