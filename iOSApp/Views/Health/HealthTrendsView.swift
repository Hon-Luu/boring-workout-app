import SwiftUI
import Charts

// MARK: - Metric & range enums

// MARK: - HealthMetric (data-driven, replaces old TrendMetric enum)

struct HealthMetric: Identifiable, Hashable {
    let id:             String
    let label:          String
    let icon:           String
    let color:          Color
    let unitLabel:      String
    let higherIsBetter: Bool
    let sourceHint:     String

    // MARK: Categories (for Settings grouping)
    enum Category: String, CaseIterable {
        case recovery   = "Recovery"
        case smartScale = "Smart Scale"
        case activity   = "Activity"
        case fitness    = "Fitness"
    }
    var category: Category {
        switch id {
        case "hrv", "restingHR", "walkingHR", "sleep", "respiratoryRate", "spo2": return .recovery
        case "weight", "bodyFat", "leanMass", "bmi", "waist":                     return .smartScale
        case "vo2Max":                                                              return .fitness
        default:                                                                    return .activity
        }
    }

    // MARK: Formatting
    func format(_ v: Double) -> String {
        switch id {
        case "sleep":
            let h = Int(v); let m = Int((v - Double(h)) * 60)
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        case "steps", "flights":
            return v >= 1000 ? String(format: "%.1fk", v / 1000) : String(format: "%.0f", v)
        case "bodyFat", "spo2":
            return String(format: "%.1f%%", v)
        case "bmi":
            return String(format: "%.1f", v)
        case "activeCalories", "basalCalories":
            return String(format: "%.0f kcal", v)
        case "exerciseTime", "standTime":
            return String(format: "%.0f min", v)
        default:
            return unitLabel.isEmpty
                ? String(format: "%.1f", v)
                : String(format: "%.1f \(unitLabel)", v)
        }
    }

    // MARK: Default enabled set (shown on first launch)
    static let defaultEnabledString = "hrv,restingHR,sleep,weight,bodyFat,leanMass,vo2Max,steps,activeCalories"

    // MARK: All available metrics
    static let all: [HealthMetric] = [
        // ── Recovery ─────────────────────────────────────────────────────────
        .init(id: "hrv",             label: "HRV",           icon: "waveform.path.ecg",
              color: HONTheme.chartSlate,
              unitLabel: "ms",       higherIsBetter: true,
              sourceHint: "Apple Watch records overnight."),
        .init(id: "restingHR",       label: "Resting HR",    icon: "heart.fill",
              color: HONTheme.chartRose,
              unitLabel: "bpm",      higherIsBetter: false,
              sourceHint: "Apple Watch."),
        .init(id: "walkingHR",       label: "Walking HR",    icon: "heart.circle.fill",
              color: HONTheme.chartRose.opacity(0.75),
              unitLabel: "bpm",      higherIsBetter: false,
              sourceHint: "Apple Watch — avg HR during walks."),
        .init(id: "sleep",           label: "Sleep",         icon: "moon.zzz.fill",
              color: HONTheme.chartLavender,
              unitLabel: "hrs",      higherIsBetter: true,
              sourceHint: "Apple Watch sleep tracking."),
        .init(id: "respiratoryRate", label: "Resp. Rate",    icon: "wind",
              color: HONTheme.chartSlate.opacity(0.75),
              unitLabel: "br/min",   higherIsBetter: false,
              sourceHint: "Apple Watch records overnight."),
        .init(id: "spo2",            label: "Blood Oxygen",  icon: "drop.circle.fill",
              color: HONTheme.chartLavender.opacity(0.75),
              unitLabel: "%",        higherIsBetter: true,
              sourceHint: "Apple Watch Series 6+."),
        // ── Body Composition ─────────────────────────────────────────────────
        .init(id: "weight",          label: "Weight",        icon: "scalemass.fill",
              color: HONTheme.chartAmber,
              unitLabel: "kg",       higherIsBetter: false,
              sourceHint: "Smart scale or manual entry."),
        .init(id: "bodyFat",         label: "Body Fat",      icon: "drop.fill",
              color: HONTheme.chartClay,
              unitLabel: "%",        higherIsBetter: false,
              sourceHint: "Smart scale → Apple Health (Body Fat %)."),
        .init(id: "leanMass",        label: "Lean Mass",     icon: "figure.arms.open",
              color: HONTheme.chartSage,
              unitLabel: "kg",       higherIsBetter: true,
              sourceHint: "Smart scale → Apple Health (Lean Body Mass)."),
        .init(id: "bmi",             label: "BMI",           icon: "chart.bar.fill",
              color: HONTheme.chartLavender,
              unitLabel: "",         higherIsBetter: false,
              sourceHint: "Derived from weight + height in Apple Health."),
        .init(id: "waist",           label: "Waist",         icon: "circle.dashed",
              color: HONTheme.chartAmber.opacity(0.75),
              unitLabel: "cm",       higherIsBetter: false,
              sourceHint: "Smart scale or manual entry in Apple Health."),
        // ── Activity ─────────────────────────────────────────────────────────
        .init(id: "steps",           label: "Steps",         icon: "figure.walk",
              color: HONTheme.chartSage,
              unitLabel: "steps",    higherIsBetter: true,
              sourceHint: "iPhone + Apple Watch."),
        .init(id: "distance",        label: "Distance",      icon: "figure.run",
              color: HONTheme.chartSage.opacity(0.75),
              unitLabel: "km",       higherIsBetter: true,
              sourceHint: "iPhone + Apple Watch."),
        .init(id: "flights",         label: "Flights",       icon: "stairs",
              color: HONTheme.chartSlate,
              unitLabel: "flights",  higherIsBetter: true,
              sourceHint: "iPhone barometric pressure sensor."),
        .init(id: "activeCalories",  label: "Active Cal",    icon: "flame.fill",
              color: HONTheme.chartClay,
              unitLabel: "kcal",     higherIsBetter: true,
              sourceHint: "Apple Watch."),
        .init(id: "basalCalories",   label: "Basal Cal",     icon: "bolt.fill",
              color: HONTheme.chartAmber.opacity(0.85),
              unitLabel: "kcal",     higherIsBetter: true,
              sourceHint: "Estimated from weight, age, and activity."),
        .init(id: "exerciseTime",    label: "Exercise Min",  icon: "timer",
              color: HONTheme.chartSage,
              unitLabel: "min",      higherIsBetter: true,
              sourceHint: "Apple Watch exercise ring."),
        .init(id: "standTime",       label: "Stand Time",    icon: "figure.stand",
              color: HONTheme.chartSlate.opacity(0.85),
              unitLabel: "min",      higherIsBetter: true,
              sourceHint: "Apple Watch stand ring."),
        // ── Fitness ───────────────────────────────────────────────────────────
        .init(id: "vo2Max",          label: "VO2 Max",       icon: "lungs.fill",
              color: HONTheme.chartSage,
              unitLabel: "ml/kg·min", higherIsBetter: true,
              sourceHint: "Apple Watch Series 3+ — requires an outdoor run."),
    ]
}

enum TrendRange: Int, CaseIterable {
    case days30 = 30, days60 = 60, days90 = 90

    var label: String {
        switch self { case .days30: return "30d"; case .days60: return "60d"; case .days90: return "90d" }
    }
}

// MARK: - Main view

struct HealthTrendsView: View {
    @Environment(HealthKitService.self) private var health
    let workoutLog: [WorkoutLogEntry]

    @AppStorage("selectedTrendMetricId")  private var selectedMetricId: String = "hrv"
    @AppStorage("enabledHealthMetricIds") private var enabledIdsRaw:    String = HealthMetric.defaultEnabledString
    @State private var selectedRange: TrendRange   = .days30
    @State private var dataPoints: [HealthDataPoint] = []
    @State private var isLoading = false

    private var enabledMetrics: [HealthMetric] {
        let ids = Set(enabledIdsRaw.split(separator: ",").map(String.init))
        return HealthMetric.all.filter { ids.contains($0.id) }
    }
    private var selectedMetric: HealthMetric {
        enabledMetrics.first { $0.id == selectedMetricId }
            ?? enabledMetrics.first
            ?? HealthMetric.all[0]
    }

    private var workoutDatesInRange: [Date] {
        let cal = Calendar.current
        let cutoff = Date().addingTimeInterval(-Double(selectedRange.rawValue) * 86400)
        return Array(
            Set(workoutLog
                .filter { $0.startedAt >= cutoff }
                .map { cal.startOfDay(for: $0.startedAt) })
        ).sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Metric chips
                    MetricPickerRow(metrics: enabledMetrics, selectedId: $selectedMetricId)

                    // Range + authorization state
                    if health.isAuthorized {
                        // Range picker
                        Picker("Range", selection: $selectedRange) {
                            ForEach(TrendRange.allCases, id: \.rawValue) {
                                Text($0.label).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)

                        if isLoading {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .frame(height: 220)
                        } else if dataPoints.isEmpty {
                            noDataPlaceholder
                        } else {
                            TrendChart(
                                points: dataPoints,
                                metric: selectedMetric,
                                workoutDates: workoutDatesInRange,
                                range: selectedRange
                            )

                            TrendInsightCard(
                                points: dataPoints,
                                metric: selectedMetric,
                                workoutDates: workoutDatesInRange
                            )
                        }
                    } else {
                        healthPermissionBanner
                    }
                }
                .padding(16)
            }
            .background(AppTheme.pageBG)
            .navigationTitle("Health Trends")
            .navigationBarTitleDisplayMode(.large)
        }
        .task(id: "\(selectedMetricId)-\(selectedRange.rawValue)") {
            guard health.isAuthorized else { return }
            isLoading = true
            dataPoints = await health.fetchHistoricalData(metric: selectedMetric, days: selectedRange.rawValue)
            isLoading = false
        }
        .onChange(of: enabledIdsRaw) {
            // If the selected metric was just disabled, fall back to first enabled
            let ids = Set(enabledIdsRaw.split(separator: ",").map(String.init))
            if !ids.contains(selectedMetricId) {
                selectedMetricId = enabledMetrics.first?.id ?? "hrv"
            }
        }
    }

    private var noDataPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: selectedMetric.icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No \(selectedMetric.label) data in this window.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(selectedMetric.sourceHint)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private var healthPermissionBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.clipboard")
                .font(.largeTitle)
                .foregroundStyle(HONTheme.negative)
            Text("Apple Health access needed")
                .font(.headline)
            Text("Go to Settings → Health → Data Access & Devices to enable access, then return to the Home tab to authorize.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Metric picker

private struct MetricPickerRow: View {
    let metrics: [HealthMetric]
    @Binding var selectedId: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(metrics) { metric in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedId = metric.id }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: metric.icon)
                                .font(.caption2)
                            Text(metric.label)
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selectedId == metric.id ? metric.color : AppTheme.insetBG,
                                    in: Capsule())
                        .foregroundStyle(selectedId == metric.id ? HONTheme.textPrimary : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Trend chart

private struct TrendChart: View {
    let points: [HealthDataPoint]
    let metric: HealthMetric
    let workoutDates: [Date]
    let range: TrendRange

    private var movingAvg: [HealthDataPoint] {
        let window = 7
        return points.indices.map { i in
            let slice = points[max(0, i - window + 1)...i]
            let avg = slice.map(\.value).reduce(0, +) / Double(slice.count)
            return HealthDataPoint(date: points[i].date, value: avg)
        }
    }

    private var yDomain: ClosedRange<Double> {
        guard let lo = points.map(\.value).min(),
              let hi = points.map(\.value).max() else { return 0...100 }
        let pad = max((hi - lo) * 0.15, 1)
        return (lo - pad)...(hi + pad)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("\(metric.label) · \(range.label)", systemImage: metric.icon)
                    .font(.caption.bold())
                    .foregroundStyle(metric.color)
                Spacer()
                HStack(spacing: 12) {
                    LegendDot(color: metric.color.opacity(0.5), label: "Daily")
                    LegendDot(color: metric.color, label: "7d avg")
                    LegendDot(color: HONTheme.accent.opacity(0.3), label: "Workout")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Chart {
                // Workout day markers
                ForEach(workoutDates, id: \.self) { d in
                    RuleMark(x: .value("Workout", d))
                        .foregroundStyle(HONTheme.accent.opacity(0.18))
                        .lineStyle(StrokeStyle(lineWidth: 6))
                }

                // Raw daily values (faint area + dots)
                ForEach(points) { pt in
                    AreaMark(
                        x: .value("Date", pt.date),
                        yStart: .value("Base", yDomain.lowerBound),
                        yEnd:   .value(metric.unitLabel, pt.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [metric.color.opacity(0.12), metric.color.opacity(0.0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", pt.date),
                        y: .value(metric.unitLabel, pt.value)
                    )
                    .symbolSize(18)
                    .foregroundStyle(metric.color.opacity(0.4))
                }

                // 7-day moving average line
                ForEach(movingAvg) { pt in
                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value(metric.unitLabel, pt.value)
                    )
                    .foregroundStyle(metric.color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range.rawValue / 5)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 9))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            Text(metric.format(v)).font(.system(size: 9))
                        }
                    }
                }
            }
            .frame(height: 220)
        }
        .padding(16)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
        }
    }
}

// MARK: - Insights card

private struct TrendInsightCard: View {
    let points: [HealthDataPoint]
    let metric: HealthMetric
    let workoutDates: [Date]

    // Workout days vs rest days
    private var splitAvgs: (workoutAvg: Double?, restAvg: Double?) {
        guard !points.isEmpty else { return (nil, nil) }
        let cal = Calendar.current
        let wdSet = Set(workoutDates.map { cal.startOfDay(for: $0) })
        let wdPoints = points.filter { wdSet.contains(cal.startOfDay(for: $0.date)) }
        let rdPoints = points.filter { !wdSet.contains(cal.startOfDay(for: $0.date)) }
        let avg: ([HealthDataPoint]) -> Double? = { pts in
            pts.isEmpty ? nil : pts.map(\.value).reduce(0, +) / Double(pts.count)
        }
        return (avg(wdPoints), avg(rdPoints))
    }

    // Overall linear trend: slope in units-per-week
    private var weeklySlope: Double? {
        guard points.count >= 4 else { return nil }
        let sorted = points.sorted { $0.date < $1.date }
        let n = Double(sorted.count)
        let xs = sorted.indices.map { Double($0) }
        let ys = sorted.map(\.value)
        let xMean = xs.reduce(0, +) / n
        let yMean = ys.reduce(0, +) / n
        let num = zip(xs, ys).reduce(0.0) { $0 + ($1.0 - xMean) * ($1.1 - yMean) }
        let den = xs.reduce(0.0) { $0 + ($1 - xMean) * ($1 - xMean) }
        guard den > 0 else { return nil }
        return (num / den) * 7   // convert per-sample to per-week
    }

    private var periodStats: (min: Double, avg: Double, max: Double)? {
        guard !points.isEmpty else { return nil }
        let vals = points.map(\.value)
        return (vals.min()!, vals.reduce(0, +) / Double(vals.count), vals.max()!)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Trend direction
            if let slope = weeklySlope {
                let improving = metric.higherIsBetter ? slope > 0 : slope < 0
                let stable = abs(slope) < 0.5
                HStack(spacing: 8) {
                    Image(systemName: stable ? "minus.circle.fill" : (improving ? "arrow.up.circle.fill" : "arrow.down.circle.fill"))
                        .foregroundStyle(stable ? Color.secondary : (improving ? HONTheme.positive : HONTheme.warning))
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(stable
                             ? "Holding steady over this window"
                             : (improving
                                ? "\(metric.label) is tracking in the right direction"
                                : "\(metric.label) has been declining lately"))
                            .font(.subheadline.bold())
                        Text(stable
                             ? "Less than 0.5 \(metric.unitLabel) change per week"
                             : String(format: "%+.1f \(metric.unitLabel)/week", slope))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))
            }

            // Workout vs rest split
            let split = splitAvgs
            if let wd = split.workoutAvg, let rd = split.restAvg {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workout days vs rest days")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 0) {
                        SplitStatPill(label: "Workout days", value: metric.format(wd), color: HONTheme.accent)
                        Spacer()
                        let diff = wd - rd
                        let diffStr = String(format: "%+.1f \(metric.unitLabel)", diff)
                        let better = metric.higherIsBetter ? diff > 0 : diff < 0
                        Text(diffStr)
                            .font(.caption.bold())
                            .foregroundStyle(abs(diff) < 0.5 ? Color.secondary : (better ? HONTheme.positive : HONTheme.warning))
                        Spacer()
                        SplitStatPill(label: "Rest days", value: metric.format(rd), color: .secondary)
                    }
                    .padding(.horizontal, 4)
                }
            }

            // Period stats
            if let stats = periodStats {
                Divider()
                HStack(spacing: 0) {
                    MiniStat(label: "Low", value: metric.format(stats.min))
                    Divider().frame(height: 32)
                    MiniStat(label: "Avg", value: metric.format(stats.avg))
                    Divider().frame(height: 32)
                    MiniStat(label: "High", value: metric.format(stats.max))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct SplitStatPill: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value).font(.subheadline.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct MiniStat: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.caption.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
