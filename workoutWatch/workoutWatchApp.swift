import SwiftUI

@main
struct workoutWatchApp: App {
    @State private var sessionManager = WatchSessionManager.shared
    @State private var isStandaloneMode = true  // Default to standalone

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if isStandaloneMode {
                    // Standalone mode - works without iPhone
                    StandaloneMainView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                if sessionManager.isConnected {
                                    Button {
                                        isStandaloneMode = false
                                    } label: {
                                        Image(systemName: "iphone.radiowaves.left.and.right")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                } else {
                    // Paired mode - syncs with iPhone
                    ContentView(sessionManager: sessionManager)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    isStandaloneMode = true
                                } label: {
                                    Image(systemName: "applewatch")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                }
            }
            .onChange(of: sessionManager.activeSession) { _, newSession in
                // Switch to paired mode when iPhone starts a workout
                if newSession != nil {
                    isStandaloneMode = false
                }
            }
        }
    }
}
