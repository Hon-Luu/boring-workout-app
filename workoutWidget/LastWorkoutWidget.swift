import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct LastWorkoutProvider: TimelineProvider {

    func placeholder(in context: Context) -> LastWorkoutEntry {
        LastWorkoutEntry(
            date: Date(),
            workoutDate: Date(),
            exerciseNames: ["Bench Press", "Squats", "Deadlift"],
            totalVolume: 5000
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LastWorkoutEntry) -> Void) {
        if let summary = SharedDataManager.shared.getLastWorkoutData() {
            let entry = LastWorkoutEntry(
                date: Date(),
                workoutDate: summary.date,
                exerciseNames: summary.exerciseNames,
                totalVolume: summary.totalVolume
            )
            completion(entry)
        } else {
            completion(placeholder(in: context))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastWorkoutEntry>) -> Void) {
        let entry: LastWorkoutEntry

        if let summary = SharedDataManager.shared.getLastWorkoutData() {
            entry = LastWorkoutEntry(
                date: Date(),
                workoutDate: summary.date,
                exerciseNames: summary.exerciseNames,
                totalVolume: summary.totalVolume
            )
        } else {
            entry = LastWorkoutEntry(
                date: Date(),
                workoutDate: nil,
                exerciseNames: [],
                totalVolume: 0
            )
        }

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct LastWorkoutEntry: TimelineEntry {
    let date: Date
    let workoutDate: Date?
    let exerciseNames: [String]
    let totalVolume: Double
}

// MARK: - Widget View

struct LastWorkoutWidgetEntryView: View {

    var entry: LastWorkoutProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            mediumView
        }
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left side - date and volume
            VStack(alignment: .leading, spacing: 8) {
                // Date
                if let workoutDate = entry.workoutDate {
                    Text(formatDate(workoutDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(relativeDateString(workoutDate))
                        .font(.headline)
                        .foregroundStyle(.primary)
                } else {
                    Text("No Workouts")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Volume
                if entry.totalVolume > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Volume")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(formatVolume(entry.totalVolume))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.blue)
                    }
                }
            }

            Divider()

            // Right side - exercises
            VStack(alignment: .leading, spacing: 6) {
                Text("Exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if entry.exerciseNames.isEmpty {
                    Text("Start your first workout!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entry.exerciseNames.prefix(3), id: \.self) { name in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)

                            Text(name)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func relativeDateString(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            return "\(days) days ago"
        }
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk kg", volume / 1000)
        }
        return String(format: "%.0f kg", volume)
    }
}

// MARK: - Widget Configuration

struct LastWorkoutWidget: Widget {
    let kind: String = "LastWorkoutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastWorkoutProvider()) { entry in
            LastWorkoutWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Last Workout")
        .description("See a summary of your most recent workout.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    LastWorkoutWidget()
} timeline: {
    LastWorkoutEntry(
        date: .now,
        workoutDate: Date(),
        exerciseNames: ["Incline Dumbbell Press", "Lat Pulldown", "Barbell Squat"],
        totalVolume: 4500
    )
}
