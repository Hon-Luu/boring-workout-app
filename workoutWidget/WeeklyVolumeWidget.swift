import WidgetKit
import SwiftUI
import Charts

// MARK: - Timeline Provider

struct WeeklyVolumeProvider: TimelineProvider {

    func placeholder(in context: Context) -> WeeklyVolumeEntry {
        WeeklyVolumeEntry(date: Date(), volumeData: sampleData())
    }

    func getSnapshot(in context: Context, completion: @escaping (WeeklyVolumeEntry) -> Void) {
        let volumeData = SharedDataManager.shared.getWeeklyVolumeData()
        let entry = WeeklyVolumeEntry(date: Date(), volumeData: volumeData.isEmpty ? sampleData() : volumeData)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklyVolumeEntry>) -> Void) {
        let volumeData = SharedDataManager.shared.getWeeklyVolumeData()
        let entry = WeeklyVolumeEntry(date: Date(), volumeData: volumeData)

        // Update at midnight
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())

        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }

    private func sampleData() -> [WeeklyVolumeData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset - 6, to: today) ?? today
            return WeeklyVolumeData(date: date, volume: Double.random(in: 0...5000))
        }
    }
}

// MARK: - Timeline Entry

struct WeeklyVolumeEntry: TimelineEntry {
    let date: Date
    let volumeData: [WeeklyVolumeData]
}

// MARK: - Widget View

struct WeeklyVolumeWidgetEntryView: View {

    var entry: WeeklyVolumeProvider.Entry
    @Environment(\.widgetFamily) var family

    private var totalVolume: Double {
        entry.volumeData.reduce(0) { $0 + $1.volume }
    }

    private var maxVolume: Double {
        entry.volumeData.map { $0.volume }.max() ?? 1
    }

    var body: some View {
        switch family {
        case .systemLarge:
            largeView
        default:
            largeView
        }
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Volume")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(formatVolume(totalVolume) + " total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }

            // Chart
            if entry.volumeData.isEmpty {
                emptyStateView
            } else {
                chartView
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var chartView: some View {
        Chart(entry.volumeData, id: \.date) { data in
            BarMark(
                x: .value("Day", data.date, unit: .day),
                y: .value("Volume", data.volume)
            )
            .foregroundStyle(
                data.volume > 0
                    ? Color.blue.gradient
                    : Color.gray.opacity(0.3).gradient
            )
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(dayAbbreviation(date))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let volume = value.as(Double.self) {
                        Text(shortVolume(volume))
                            .font(.caption2)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "chart.bar")
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No data yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Complete workouts to see your weekly volume")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk kg", volume / 1000)
        }
        return String(format: "%.0f kg", volume)
    }

    private func shortVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.0fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }

    private func dayAbbreviation(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
}

// MARK: - Widget Configuration

struct WeeklyVolumeWidget: Widget {
    let kind: String = "WeeklyVolumeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeeklyVolumeProvider()) { entry in
            WeeklyVolumeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Weekly Volume")
        .description("View your workout volume for the past 7 days.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemLarge) {
    WeeklyVolumeWidget()
} timeline: {
    WeeklyVolumeEntry(
        date: .now,
        volumeData: {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            return (0..<7).map { offset in
                let date = calendar.date(byAdding: .day, value: offset - 6, to: today) ?? today
                return WeeklyVolumeData(date: date, volume: Double.random(in: 0...5000))
            }
        }()
    )
}
