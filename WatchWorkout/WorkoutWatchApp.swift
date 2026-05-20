// ─────────────────────────────────────────────────────────────────
// WorkoutWatchApp.swift
// Boring Workout — Apple Watch Target
//
// HOW TO ADD THIS TARGET IN XCODE:
//   1. File > New > Target > watchOS > App
//   2. Name: "WatchWorkout", Bundle: com.yourname.workout.watchkitapp
//   3. Add all files in this WatchWorkout/ folder to the new target
//   4. Add WatchConnectivity.framework to BOTH targets
//   5. In the Watch target, also add the shared RepDetectionModels.swift
// ─────────────────────────────────────────────────────────────────

import SwiftUI

@main
struct WorkoutWatchApp: App {
    @StateObject private var session = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            WatchWorkoutView()
                .environmentObject(session)
        }
    }
}
