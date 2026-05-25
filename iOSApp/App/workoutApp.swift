import SwiftUI
import AVFoundation

@main
struct workoutApp: App {
    private let store = SeedStore.shared
    private let health = HealthKitService()
    private let habitEngine = HONHabitEngine()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Allow Spotify / Apple Music to keep playing during workouts.
        // .mixWithOthers means our app never interrupts background audio.
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .default, options: [.mixWithOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            HONAppRoot()
                .environment(store)
                .environment(health)
                .environment(habitEngine)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                NotificationScheduler.scheduleReEngagement()
                habitEngine.checkForDriftOrDeload()
            }
        }
    }
}
