import Foundation
import WidgetKit

// MARK: - Widget Models (shared with main app)

struct WorkoutStreak: Codable {
    let currentStreak: Int
    let lastWorkoutDate: Date?
}

struct LastWorkoutSummary: Codable {
    let date: Date
    let exerciseNames: [String]
    let totalVolume: Double
}

struct WeeklyVolumeData: Codable {
    let date: Date
    let volume: Double
}

// MARK: - Shared Data Manager

class SharedDataManager {

    static let shared = SharedDataManager()
    private let appGroupId = "group.workout.shared"

    private init() {}

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    // MARK: - Streak Data

    func getStreakData() -> WorkoutStreak {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: "streakData"),
              let streak = try? JSONDecoder().decode(WorkoutStreak.self, from: data) else {
            return WorkoutStreak(currentStreak: 0, lastWorkoutDate: nil)
        }
        return streak
    }

    // MARK: - Last Workout Data

    func getLastWorkoutData() -> LastWorkoutSummary? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: "lastWorkoutData"),
              let summary = try? JSONDecoder().decode(LastWorkoutSummary.self, from: data) else {
            return nil
        }
        return summary
    }

    // MARK: - Weekly Volume Data

    func getWeeklyVolumeData() -> [WeeklyVolumeData] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: "weeklyVolumeData"),
              let volumes = try? JSONDecoder().decode([WeeklyVolumeData].self, from: data) else {
            return []
        }
        return volumes
    }
}

// MARK: - Widget Reload Helper

extension WidgetCenter {
    static func reloadWorkoutWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: "StreakWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "LastWorkoutWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "WeeklyVolumeWidget")
    }
}
