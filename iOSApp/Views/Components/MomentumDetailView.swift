import SwiftUI
import Charts

// MARK: - Momentum Detail View (Layer 1B)

struct MomentumDetailView: View {
    @Environment(SeedStore.self) private var store
    @State private var drillDown: ExerciseAnalytics? = nil

    private var composite: CompositeStrengthResult { store.analyticsCache.compositeScore }
    private var strength:  StrengthScoreResult   { store.analyticsCache.strengthScore }
    private var exercises: [ExerciseAnalytics]   { store.analyticsCache.exerciseAnalytics }
    private var tier:      StrengthTier          { strength.overallTier }

    private var ceiling: Double {
        switch tier {
        case .beginner: return 3.0; case .intermediate: return 2.0
        case .advanced:   return 1.0; case .elite:        return 0.5
        }
    }

    private struct ExerciseMomentumRow: Identifiable {
        let id: UUID
        let name: String
        let stdPct: Double
        let adjPct: Double
        let score: Double
        let sessions: Int
        let isPlateau: Bool
    }

    private var exerciseRows: [ExerciseMomentumRow] {
        let slope = 50.0 / ceiling
        return exercises.map { ea in
            let pct   = max(ea.pctChangePerWeek, ea.pctChangePerWeekFatigue)
            let score = min(100, max(0, 50.0 + pct * slope))
            return ExerciseMomentumRow(
                id: ea.id, name: ea.exercise.name,
                stdPct: ea.pctChangePerWeek, adjPct: ea.pctChangePerWeekFatigue,
                score: score, sessions: ea.sessions.count, isPlateau: ea.isPlateau
            )
        }
        .sorted { $0.score > $1.score }
    }

    private var stalledRows: [ExerciseMomentumRow] { exerciseRows.filter { $0.isPlateau } }

    // PSI history — grouped into weekly averages to eliminate per-session zigzag
    private var psiPoints: [(date: Date, psi: Double)] {
        let raw = strength.psiHistory.map { ($0.date, $0.rawFiberLoad) }
        guard raw.count >= 2 else { return raw }
        let cal = Calendar.current
        var grouped: [DateComponents: [(Date, Double)]] = [:]
        for (date, val) in raw {
            let key = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            grouped[key, default: []].append((date, val))
        }
        return grouped.values.map { pts in
            let mid = pts[pts.count / 2].0
            let avg = pts.map(\.1).reduce(0, +) / Double(pts.count)
            return (date: mid, psi: avg)
        }.sorted { $0.date < $1.date }
    }

    // OLS trend line over psiPoints
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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ── Diagnosis callout ─────────────────────────────────────
                diagnosisCard

                // ── Overview card ────────────────────────────────────────
                overviewCard

                // ── PSI trend chart ──────────────────────────────────────
                if psiPoints.count >= 3 {
                    psiChartCard
                }

                // ── Stalled exercises callout ────────────────────────────
                if !stalledRows.isEmpty {
                    stalledCard
                }

                // ── Per-exercise table ───────────────────────────────────
                exerciseTableCard
            }
            .padding(16)
        }
        .background(AppTheme.pageBG)
        .sheet(item: $drillDown) { ExerciseDetailSheet(analytics: $0) }
    }

    // MARK: - Diagnosis Card

    private var diagnosisCard: some View {
        let pct = strength.psiTrendPctPerWeek
        let stalledCount = stalledRows.count
        let momScore = composite.momentumScore
        let color = scoreGradeColor(momScore)

        let verdict: String
        let action: String
        if pct < -0.5 {
            verdict = "PSI load is declining (\(String(format: "%.1f", pct))%/wk)"
            action = "Volume or intensity has dropped. Check if deload was intentional — if not, increase working weight or add sets to your primary exercises."
        } else if stalledCount >= 2 {
            verdict = "\(stalledCount) exercises have plateaued"
            action = "Current stimulus isn't driving adaptation. Rotate rep ranges (e.g. 3×5 → 4×8), add load, or take one deload week before reintroducing progressive overload."
        } else if momScore < 50 {
            verdict = "Growth rate is below flat for your tier"
            action = "Even a small positive trend recovers this score. Aim for +1 rep or +2.5 kg on your key lifts each session."
        } else {
            verdict = "Momentum is positive — keep training as is"
            action = "Your PSI trend is above the flat line. Maintain stimulus and monitor for plateau signals over the next 3–4 weeks."
        }

        return DetailCard(title: "Momentum Diagnosis", icon: "stethoscope", accent: color) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(String(format: "%.0f", momScore))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Momentum Score").font(.caption2).foregroundStyle(.secondary)
                        Text(verdict).font(.caption.bold())
                            .foregroundStyle(momScore >= 60 ? Color.primary : HONTheme.warning)
                    }
                }
                Text(action)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        DetailCard(title: "Score Overview", icon: "arrow.up.right.circle.fill", accent: HONTheme.positive) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    metricCell(String(format: "%.0f", composite.momentumScore), "Momentum", HONTheme.positive)
                    Divider().frame(height: 36)
                    metricCell(String(format: "%@%.1f%%", strength.psiTrendPctPerWeek >= 0 ? "+" : "",
                                     strength.psiTrendPctPerWeek), "PSI Trend", .primary)
                    Divider().frame(height: 36)
                    metricCell(String(format: "%.1f%%/wk", ceiling), "Tier Ceiling", .secondary)
                    Divider().frame(height: 36)
                    metricCell(tier.rawValue, "Tier", .primary)
                }
                .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

                // Score = 50 + pct × slope explanation
                let pct = strength.psiTrendPctPerWeek
                let slope = 50.0 / ceiling
                let score = min(100, max(0, 50.0 + pct * slope))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Formula")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                    Text(String(format: "score = clamp(50 + %.1f × %.1f, 0, 100)  =  %.0f",
                                pct, slope, score))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text(String(format: "slope = 50 ÷ ceiling = 50 ÷ %.1f = %.1f", ceiling, slope))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(10)
                .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 8))

                Text("0%/wk = 50 (flat) · +ceiling = 100 (peak rate) · −ceiling = 0 (declining)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - PSI Trend Chart

    private var psiChartCard: some View {
        DetailCard(title: "PSI Trend", icon: "waveform.path.ecg.rectangle", accent: HONTheme.positive) {
            VStack(spacing: 8) {
                let yVals = psiPoints.map(\.psi) + psiTrendLine.map(\.psi)
                let yMin = (yVals.min() ?? 0) * 0.90
                let yMax = (yVals.max() ?? 1) * 1.10

                Chart {
                    // Trend line
                    ForEach(psiTrendLine.indices, id: \.self) { i in
                        LineMark(x: .value("Date", psiTrendLine[i].date),
                                 y: .value("PSI Trend", psiTrendLine[i].psi))
                            .foregroundStyle(HONTheme.positive.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    }
                    // Actual PSI
                    ForEach(psiPoints.indices, id: \.self) { i in
                        LineMark(x: .value("Date", psiPoints[i].date),
                                 y: .value("PSI", psiPoints[i].psi))
                            .foregroundStyle(HONTheme.positive)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                            .symbol { Circle().fill(HONTheme.positive).frame(width: 5)
                                .overlay(Circle().stroke(HONTheme.textPrimary, lineWidth: 1.5)) }
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
                        Circle().fill(HONTheme.positive).frame(width: 7, height: 7)
                        Text("Raw PSI").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Rectangle().fill(HONTheme.positive.opacity(0.5)).frame(width: 14, height: 2)
                        Text("OLS Trend").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(psiPoints.count) sessions").font(.system(size: 9)).foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Stalled Card

    private func stalledSuggestion(for row: ExerciseMomentumRow) -> (text: String, icon: String) {
        guard let ea = exercises.first(where: { $0.id == row.id }),
              let inol = ea.latestINOL else {
            return ("Vary rep range or add load to break the plateau.", "arrow.triangle.2.circlepath")
        }
        if inol < 0.5 {
            return ("INOL \(String(format: "%.2f", inol)) — stimulus too low. Add sets or increase working weight.", "plus.circle.fill")
        } else if inol > 1.5 {
            return ("INOL \(String(format: "%.2f", inol)) — accumulated fatigue. Try a lighter week, then reload.", "arrow.down.circle.fill")
        } else {
            return ("INOL \(String(format: "%.2f", inol)) is in range — change the stimulus. Try a different rep range or exercise variant.", "shuffle.circle.fill")
        }
    }

    private var stalledCard: some View {
        DetailCard(title: "\(stalledRows.count) Exercise\(stalledRows.count == 1 ? "" : "s") Stalled",
                   icon: "exclamationmark.triangle.fill", accent: HONTheme.warning) {
            VStack(spacing: 10) {
                Text("Slope < 0.5 kg/wk over last 4 weeks. Each exercise has a specific suggested fix based on its INOL.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(stalledRows) { row in
                    let suggestion = stalledSuggestion(for: row)
                    Button { drillDown = exercises.first { $0.id == row.id } } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(HONTheme.warning).font(.caption)
                                Text(row.name).font(.subheadline.bold())
                                Spacer()
                                Text("\(row.sessions) sessions")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                            }
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: suggestion.icon)
                                    .font(.system(size: 10)).foregroundStyle(HONTheme.warning)
                                Text(suggestion.text)
                                    .font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(HONTheme.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Exercise Table

    private var exerciseTableCard: some View {
        DetailCard(title: "Per-Exercise Momentum", icon: "list.number") {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    Text("Exercise").font(.caption2.bold()).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Std").font(.caption2.bold()).foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                    Text("Adj").font(.caption2.bold()).foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                    Text("Score").font(.caption2.bold()).foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                }
                .padding(.vertical, 4)
                Divider()

                ForEach(exerciseRows) { row in
                    Button { drillDown = exercises.first { $0.id == row.id } } label: {
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(row.name).font(.caption).lineLimit(1)
                                    if row.isPlateau {
                                        Image(systemName: "pause.fill")
                                            .font(.system(size: 8)).foregroundStyle(HONTheme.warning)
                                    }
                                }
                                // Mini score bar
                                ZStack(alignment: .leading) {
                                    Capsule().fill(HONTheme.positive.opacity(0.1)).frame(height: 3)
                                    Capsule().fill(scoreColor(row.score).opacity(0.7))
                                        .frame(width: max(2, CGFloat(row.score / 100) * 80), height: 3)
                                }
                                .frame(width: 80)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            pctCell(row.stdPct)
                            pctCell(row.adjPct)

                            Text(String(format: "%.0f", row.score))
                                .font(.caption.bold())
                                .foregroundStyle(scoreColor(row.score))
                                .frame(width: 44, alignment: .trailing)
                        }
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().opacity(0.5)
                }

                Text("Score = clamp(50 + pct × (50 ÷ ceiling), 0, 100)  ·  Std = standard OLS · Adj = fatigue-adjusted")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
                    .padding(.top, 6)
            }
        }
    }

    // MARK: - Helpers

    private func metricCell(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color == .primary ? Color.primary : color == .secondary ? Color.secondary : color)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
    }

    private func pctCell(_ pct: Double) -> some View {
        Text(String(format: "%@%.1f%%", pct >= 0 ? "+" : "", pct))
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(pct >= 0.5 ? HONTheme.positive : pct < 0 ? HONTheme.negative : .secondary)
            .frame(width: 44, alignment: .trailing)
    }

    private func scoreColor(_ score: Double) -> Color {
        score >= 70 ? HONTheme.positive : score >= 50 ? HONTheme.accent : HONTheme.warning
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
