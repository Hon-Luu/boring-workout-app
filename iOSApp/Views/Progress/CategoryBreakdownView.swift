import SwiftUI
import Charts

struct CategoryBreakdownView: View {
    let categories: [CategoryAnalytics]   // sorted best improvement first
    let insights: [String]

    @State private var explainerTopic: ProgressExplainerTopic? = nil

    var body: some View {
        VStack(spacing: 12) {
            improvementChart
            if categories.count >= 2 { efficiencyGrid }
            if !insights.isEmpty { insightsCard }
        }
        .sheet(item: $explainerTopic) { topic in
            ProgressExplainerSheet(topic: topic)
        }
    }

    // MARK: - Improvement rate bar chart

    private var improvementChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Strength Gain by Pattern")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                Button { explainerTopic = .strengthGainByPattern } label: {
                    Image(systemName: "info.circle").font(.caption).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }

            Chart {
                RuleMark(x: .value("Zero", 0.0))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))

                ForEach(categories) { cat in
                    BarMark(
                        x: .value("Rate", cat.improvementRatePerWeek),
                        y: .value("Pattern", cat.pattern.shortName)
                    )
                    .foregroundStyle(effColor(cat.efficiency).opacity(0.85))
                    .cornerRadius(3)
                    .annotation(
                        position: cat.improvementRatePerWeek >= 0 ? .trailing : .leading,
                        spacing: 4
                    ) {
                        Text(signedPct(cat.improvementRatePerWeek))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .chartXScale(domain: xDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            Text(String(format: "%.1f%%", v))
                                .font(.system(size: 8))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { val in
                    AxisValueLabel {
                        if let s = val.as(String.self) {
                            Text(s)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.primary)
                        }
                    }
                }
            }
            .frame(height: max(100, CGFloat(categories.count) * 38))
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private var xDomain: ClosedRange<Double> {
        let vals = categories.map(\.improvementRatePerWeek)
        let lo   = min((vals.min() ?? 0) * 1.5, -0.3)
        let hi   = max((vals.max() ?? 1) * 1.5,  0.3)
        return lo...hi
    }

    // MARK: - 2×2 Efficiency grid

    private var efficiencyGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Efficiency Matrix")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                Text("volume × gain")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Button { explainerTopic = .efficiencyMatrix } label: {
                    Image(systemName: "info.circle").font(.caption).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                quadCell(.efficient)
                quadCell(.opportunity)
                quadCell(.inefficient)
                quadCell(.lowPriority)
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private func quadCell(_ quad: EfficiencyClass) -> some View {
        let matched = categories.filter { $0.efficiency == quad }
        let color   = effColor(quad)

        return VStack(alignment: .leading, spacing: 6) {
            // Quadrant label
            HStack(spacing: 4) {
                Image(systemName: quad.icon).font(.caption2).foregroundStyle(color)
                Text(quad.rawValue).font(.caption2.bold()).foregroundStyle(color)
            }

            // Patterns in this quadrant
            if matched.isEmpty {
                Text("—")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(matched.prefix(4)) { cat in
                    HStack(spacing: 4) {
                        Image(systemName: cat.pattern.icon)
                            .font(.system(size: 8))
                            .foregroundStyle(Color.secondary)
                        Text(cat.pattern.shortName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }
                }
                if matched.count > 4 {
                    Text("+\(matched.count - 4) more")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Insights card

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Key Insights", systemImage: "lightbulb.fill")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                Button { explainerTopic = .keyInsights } label: {
                    Image(systemName: "info.circle").font(.caption).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(insights.enumerated()), id: \.offset) { _, text in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(HONTheme.accent)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(text)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func effColor(_ e: EfficiencyClass) -> Color {
        switch e {
        case .efficient:   return HONTheme.positive
        case .inefficient: return HONTheme.warning
        case .opportunity: return HONTheme.accent
        case .lowPriority: return .gray
        }
    }

    private func signedPct(_ v: Double) -> String {
        String(format: v >= 0 ? "+%.1f%%" : "%.1f%%", v)
    }
}
