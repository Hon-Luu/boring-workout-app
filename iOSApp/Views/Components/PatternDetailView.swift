import SwiftUI
import Charts

// MARK: - Pattern Detail View (Layer 1D)

struct PatternDetailView: View {
    let group: PatternGroup

    @Environment(SeedStore.self) private var store
    @State private var drillDown: ExerciseAnalytics? = nil
    @State private var showPSIExplainer = false

    private var strength: StrengthScoreResult { store.analyticsCache.strengthScore }
    private var allExercises: [ExerciseAnalytics] { store.analyticsCache.exerciseAnalytics }

    private var psr: PatternStrengthResult? { strength.patternBreakdown[group] }

    private var groupExercises: [ExerciseAnalytics] {
        allExercises.filter { ea in
            PatternGroup.allCases.first(where: { $0.patterns.contains(ea.exercise.movementPattern) }) == group
        }
    }

    private var accent: Color {
        switch group {
        case .push:      return HONTheme.accent
        case .pull:      return HONTheme.positive
        case .legs:      return HONTheme.warning
        case .isolation: return HONTheme.chartLavender
        }
    }

    // MARK: - Retention rows

    private struct RetentionRow: Identifiable {
        let id: UUID
        let name: String
        let activationWeight: Double
        let retention: Double        // blended std/adj, 0–1
        let weightedContrib: Double  // aw × retention (unnormalized)
        let sessions: [Double]       // sparkline e1RM values
        let isPlateau: Bool
    }

    private var retentionRows: [RetentionRow] {
        let rows: [RetentionRow] = groupExercises.compactMap { ea in
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
            let spark = ea.sessions.suffix(8).map(\.estimated1RM)
            return RetentionRow(id: ea.id, name: ea.exercise.name,
                                activationWeight: aw,
                                retention: blended,
                                weightedContrib: aw * blended,
                                sessions: spark,
                                isPlateau: ea.isPlateau)
        }
        .sorted { $0.activationWeight > $1.activationWeight }

        let totalContrib = rows.reduce(0.0) { $0 + $1.weightedContrib }
        guard totalContrib > 0 else { return rows }
        return rows
    }

    private var totalWeight: Double { retentionRows.reduce(0.0) { $0 + $1.activationWeight } }

    // MARK: - PSI chart data

    private var psiPoints: [(date: Date, psi: Double)] {
        (psr?.history ?? []).map { ($0.date, $0.rawFiberLoad) }
    }

    private var psiTrendLine: [(date: Date, psi: Double)] {
        guard psiPoints.count >= 2 else { return [] }
        let pts = psiPoints.map { (x: $0.date.timeIntervalSince1970, y: $0.psi) }
        let (slope, intercept) = linearFit(pts)
        let t0 = pts.first!.x; let t1 = pts.last!.x
        return [
            (date: Date(timeIntervalSince1970: t0), psi: slope * t0 + intercept),
            (date: Date(timeIntervalSince1970: t1), psi: slope * t1 + intercept)
        ]
    }

    private var psiRollingAvg: [(date: Date, psi: Double)] {
        guard psiPoints.count >= 3 else { return psiPoints }
        let window = 5
        return psiPoints.indices.compactMap { i -> (date: Date, psi: Double)? in
            let lo = max(0, i - window / 2)
            let hi = min(psiPoints.count - 1, i + window / 2)
            let slice = psiPoints[lo...hi]
            let avg = slice.map(\.psi).reduce(0, +) / Double(slice.count)
            return (date: psiPoints[i].date, psi: avg)
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ── Coaching insight ──────────────────────────────────────
                coachingInsightCard

                // ── Overview ─────────────────────────────────────────────
                overviewCard

                // ── PSI trend chart ───────────────────────────────────────
                if psiPoints.count >= 3 {
                    psiChartCard
                }

                // ── PCSA-weighted level breakdown ─────────────────────────
                if !retentionRows.isEmpty {
                    levelBreakdownCard
                }

                // ── Exercise list with sparklines ─────────────────────────
                if !groupExercises.isEmpty {
                    exerciseListCard
                }
            }
            .padding(16)
        }
        .background(AppTheme.pageBG)
        .navigationTitle(group.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $drillDown) { ExerciseDetailSheet(analytics: $0) }
    }

    // MARK: - Coaching Insight Card

    private var coachingInsightCard: some View {
        let overallLevel = store.analyticsCache.compositeScore.levelScore
        let patLevel     = psr?.levelScore ?? 0
        let pct          = psr?.pctChangePerWeek ?? 0
        let stalled      = retentionRows.filter { $0.isPlateau }.count
        let topDriver    = retentionRows.first?.name

        // Pattern level vs overall
        let levelCtx: String
        if patLevel >= overallLevel + 5 {
            levelCtx = "\(group.rawValue) is your strongest pattern (Level \(Int(patLevel)), above your overall \(Int(overallLevel)))"
        } else if patLevel <= overallLevel - 8 {
            levelCtx = "\(group.rawValue) is dragging your overall Level (\(Int(patLevel)) vs overall \(Int(overallLevel))) — this pattern has the most to gain"
        } else {
            levelCtx = "\(group.rawValue) is tracking your overall score (Level \(Int(patLevel)))"
        }

        // Momentum context
        let momCtx: String
        if pct >= 0.5 {
            momCtx = "Momentum is positive (+\(String(format: "%.1f", pct))%/wk) — keep the program."
        } else if pct < -0.3 {
            momCtx = "Momentum is declining (\(String(format: "%.1f", pct))%/wk) — review volume and intensity."
        } else {
            momCtx = "Momentum is flat (\(String(format: "%+.1f", pct))%/wk) — a rep range change may re-spark adaptation."
        }

        // Stall context
        let stallCtx: String
        if stalled == 0 {
            stallCtx = "No exercises stalled."
        } else {
            stallCtx = "\(stalled) exercise\(stalled == 1 ? "" : "s") stalled — see the exercise list below for specific fixes."
        }

        // Driver note
        let driverCtx = topDriver.map { "Primary driver by muscle mass: \($0)." } ?? ""

        let body = "\(levelCtx). \(momCtx) \(stallCtx) \(driverCtx)"
        let color = scoreGradeColor(patLevel)

        return DetailCard(title: "\(group.rawValue) Verdict", icon: "text.badge.checkmark", accent: color) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(String(format: "%.0f", patLevel))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pattern Level").font(.caption2).foregroundStyle(.secondary)
                        TierBadge(tier: store.analyticsCache.strengthScore.overallTier)
                    }
                }
                Text(body)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        DetailCard(title: "\(group.rawValue) Overview", icon: iconFor(group), accent: accent) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    metricCell(String(format: "%.0f", psr?.levelScore ?? 0),
                               "Level", accent)
                    Divider().frame(height: 36)
                    metricCell(String(format: "%.0f", psr?.momentumScore ?? 0),
                               "Momentum", HONTheme.positive)
                    Divider().frame(height: 36)
                    let pct = psr?.pctChangePerWeek ?? 0
                    metricCell(String(format: "%@%.1f%%/wk", pct >= 0 ? "+" : "", pct),
                               "Trend", pct >= 0.5 ? HONTheme.positive : pct < 0 ? HONTheme.negative : .secondary)
                    Divider().frame(height: 36)
                    metricCell("\(groupExercises.count)", "Exercises", .secondary)
                }
                .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

                if retentionRows.contains(where: { $0.isPlateau }) {
                    let stalledCount = retentionRows.filter { $0.isPlateau }.count
                    Label("\(stalledCount) exercise\(stalledCount == 1 ? "" : "s") stalled in \(group.rawValue)",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(HONTheme.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - PSI Trend Chart

    private var psiChartCard: some View {
        DetailCard(title: "Fiber Load Trend (PSI)", icon: "waveform.path.ecg.rectangle", accent: accent) {
            VStack(spacing: 8) {
                let yVals = psiPoints.map(\.psi) + psiRollingAvg.map(\.psi) + psiTrendLine.map(\.psi)
                let yMin = (yVals.min() ?? 0) * 0.90
                let yMax = (yVals.max() ?? 1) * 1.10

                Chart {
                    // Raw per-session values — context dots only
                    ForEach(psiPoints.indices, id: \.self) { i in
                        PointMark(x: .value("Date", psiPoints[i].date),
                                  y: .value("PSI", psiPoints[i].psi))
                            .foregroundStyle(accent.opacity(0.25))
                            .symbolSize(20)
                    }
                    // 3-session rolling average — primary signal line
                    ForEach(psiRollingAvg.indices, id: \.self) { i in
                        LineMark(x: .value("Date", psiRollingAvg[i].date),
                                 y: .value("Avg", psiRollingAvg[i].psi))
                            .foregroundStyle(accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.linear)
                    }
                    // OLS direction — dashed backdrop
                    ForEach(psiTrendLine.indices, id: \.self) { i in
                        LineMark(x: .value("Date", psiTrendLine[i].date),
                                 y: .value("Trend", psiTrendLine[i].psi))
                            .foregroundStyle(accent.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    }
                }
                .chartYScale(domain: yMin...yMax)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .font(.system(size: 9)).foregroundStyle(Color.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                Text(v >= 1000 ? String(format: "%.0fk", v / 1000) : "\(Int(v))")
                                    .font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 160)

                HStack(spacing: 14) {
                    HStack(spacing: 4) {
                        Circle().fill(accent.opacity(0.35)).frame(width: 7, height: 7)
                        Text("Per session").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Rectangle().fill(accent).frame(width: 14, height: 2.5)
                        Text("3-session avg").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Rectangle().fill(accent.opacity(0.4)).frame(width: 14, height: 1)
                        Text("Direction").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(psiPoints.count) sessions").font(.system(size: 9)).foregroundStyle(.tertiary)
                    Button {
                        showPSIExplainer = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showPSIExplainer) {
                        AnalyticsExplainerSheet()
                    }
                }
            }
        }
    }

    // MARK: - Level Breakdown Card

    private var levelBreakdownCard: some View {
        DetailCard(title: "PCSA-Weighted Level", icon: "chart.bar.xaxis", accent: accent) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Exercise").font(.caption2.bold()).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("AW").font(.caption2.bold()).foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                    Text("Ret%").font(.caption2.bold()).foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                    Text("Wt%").font(.caption2.bold()).foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                }
                .padding(.vertical, 4)
                Divider()

                let totalContrib = retentionRows.reduce(0.0) { $0 + $1.weightedContrib }
                ForEach(retentionRows) { row in
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(row.name).font(.caption).lineLimit(1)
                                if row.isPlateau {
                                    Image(systemName: "pause.fill")
                                        .font(.system(size: 8)).foregroundStyle(HONTheme.warning)
                                }
                            }
                            ZStack(alignment: .leading) {
                                Capsule().fill(accent.opacity(0.10)).frame(height: 3)
                                Capsule().fill(accent.opacity(0.7))
                                    .frame(width: max(2, CGFloat(row.retention) * 80), height: 3)
                            }
                            .frame(width: 80)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(String(format: "%.0f", row.activationWeight))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)

                        Text(String(format: "%.0f%%", row.retention * 100))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(row.retention >= 0.90 ? HONTheme.positive :
                                             row.retention >= 0.75 ? .primary : HONTheme.warning)
                            .frame(width: 44, alignment: .trailing)

                        let wPct = totalContrib > 0 ? row.weightedContrib / totalContrib * 100 : 0
                        Text(String(format: "%.0f%%", wPct))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .padding(.vertical, 7)
                    Divider().opacity(0.5)
                }

                Text("AW = Σ(pctMVC × PCSA cm²)  ·  Ret% = latestE1RM ÷ peakE1RM  ·  Wt% = AW-weighted contribution")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
                    .padding(.top, 6)
            }
        }
    }

    // MARK: - Exercise List Card

    private var exerciseListCard: some View {
        DetailCard(title: "Exercises", icon: "list.bullet", accent: accent) {
            VStack(spacing: 0) {
                ForEach(retentionRows) { row in
                    if let ea = allExercises.first(where: { $0.id == row.id }) {
                        Button { drillDown = ea } label: {
                            exerciseRow(row: row, ea: ea)
                        }
                        .buttonStyle(.plain)
                        Divider().opacity(0.5)
                    }
                }
                // Exercises with no retention data (no sessions yet)
                let knownIds = Set(retentionRows.map(\.id))
                ForEach(groupExercises.filter { !knownIds.contains($0.id) }) { ea in
                    Button { drillDown = ea } label: {
                        HStack {
                            Text(ea.exercise.name).font(.subheadline)
                            Spacer()
                            Text("No data").font(.caption).foregroundStyle(.tertiary)
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().opacity(0.5)
                }
            }
        }
    }

    @ViewBuilder
    private func exerciseRow(row: RetentionRow, ea: ExerciseAnalytics) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(ea.exercise.name).font(.subheadline).lineLimit(1)
                    if row.isPlateau {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 9)).foregroundStyle(HONTheme.warning)
                    }
                }
                HStack(spacing: 6) {
                    let pct = ea.pctChangePerWeek
                    Text(String(format: "%@%.1f%%/wk", pct >= 0 ? "+" : "", pct))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(pct >= 0.5 ? HONTheme.positive : pct < 0 ? HONTheme.negative : .secondary)
                    if let inol = ea.latestINOL {
                        Text(String(format: "INOL %.2f", inol))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Sparkline (last ≤8 sessions)
            if row.sessions.count >= 2 {
                SparklineView(values: row.sessions, color: accent)
                    .frame(width: 60, height: 28)
            }

            if let latest = ea.sessions.last?.estimated1RM {
                VStack(spacing: 1) {
                    Text(String(format: "%.0f", latest))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text("kg").font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                .frame(width: 38, alignment: .trailing)
            }

            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func metricCell(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color == .secondary ? Color.secondary : color)
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
    }

    private func iconFor(_ g: PatternGroup) -> String {
        switch g {
        case .push:      return "arrow.up.forward.circle.fill"
        case .pull:      return "arrow.down.backward.circle.fill"
        case .legs:      return "figure.run.circle.fill"
        case .isolation: return "scope"
        }
    }

    private func linearFit(_ pts: [(x: Double, y: Double)]) -> (slope: Double, intercept: Double) {
        let n = Double(pts.count)
        let xMean = pts.map(\.x).reduce(0, +) / n
        let yMean = pts.map(\.y).reduce(0, +) / n
        let num = pts.reduce(0.0) { $0 + ($1.x - xMean) * ($1.y - yMean) }
        let den = pts.reduce(0.0) { $0 + ($1.x - xMean) * ($1.x - xMean) }
        let slope = den != 0 ? num / den : 0
        return (slope, yMean - slope * xMean)
    }
}

// MARK: - Sparkline

private struct SparklineView: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let mn = values.min() ?? 0
            let mx = values.max() ?? 1
            let range = mx - mn
            let w = geo.size.width
            let h = geo.size.height
            let step = range > 0 ? h / range : 1

            Path { path in
                for (i, v) in values.enumerated() {
                    let x = w * CGFloat(i) / CGFloat(max(values.count - 1, 1))
                    let y = h - (CGFloat(v - mn) * step)
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else       { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}
