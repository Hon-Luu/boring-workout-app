import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct StreakProvider: TimelineProvider {

    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), streak: 7)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let streakData = SharedDataManager.shared.getStreakData()
        let entry = StreakEntry(date: Date(), streak: streakData.currentStreak)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let streakData = SharedDataManager.shared.getStreakData()
        let entry = StreakEntry(date: Date(), streak: streakData.currentStreak)

        // Update at midnight
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())

        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
}

// MARK: - Widget View

struct StreakWidgetEntryView: View {

    var entry: StreakProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            // Flame icon
            Image(systemName: entry.streak > 0 ? "flame.fill" : "flame")
                .font(.system(size: 32))
                .foregroundStyle(entry.streak > 0 ? .orange : .gray)

            // Streak number
            Text("\(entry.streak)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            // Label
            Text(entry.streak == 1 ? "day streak" : "day streak")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Configuration

struct StreakWidget: Widget {
    let kind: String = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Workout Streak")
        .description("Track your consecutive workout days.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    StreakWidget()
} timeline: {
    StreakEntry(date: .now, streak: 7)
    StreakEntry(date: .now, streak: 0)
}
