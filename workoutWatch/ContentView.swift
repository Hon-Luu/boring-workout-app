import SwiftUI
import WatchKit

struct ContentView: View {
    @Bindable var sessionManager: WatchSessionManager
    @State private var repEngine = RepCountingEngine()

    var body: some View {
        Group {
            if let session = sessionManager.activeSession {
                WorkoutActiveView(
                    session: session,
                    repEngine: repEngine,
                    sessionManager: sessionManager
                )
            } else {
                WaitingView(isConnected: sessionManager.isConnected)
            }
        }
    }
}

// MARK: - Waiting View

struct WaitingView: View {
    let isConnected: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 44))
                .foregroundColor(.blue)

            Text("Waiting for workout...")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Start a workout on your iPhone")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(isConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)

                Text(isConnected ? "Connected" : "Connecting...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
    }
}

// MARK: - Workout Active View

struct WorkoutActiveView: View {
    let session: WatchWorkoutSession
    @Bindable var repEngine: RepCountingEngine
    @Bindable var sessionManager: WatchSessionManager

    @State private var showingRestTimer = false
    @State private var restTimeRemaining: Int = 0

    private var currentSetIndex: Int {
        min(session.completedSets, session.setRecords.count - 1)
    }

    private var currentSet: WatchSetRecord? {
        guard currentSetIndex < session.setRecords.count else { return nil }
        return session.setRecords[currentSetIndex]
    }

    var body: some View {
        VStack(spacing: 6) {
            // Exercise name
            Text(session.exerciseName)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            // Set indicator
            Text("Set \(session.completedSets + 1) of \(session.plannedSets)")
                .font(.caption2)
                .foregroundColor(.blue)

            // Weight display
            if let set = currentSet {
                Text(formatWeight(set.weight))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if showingRestTimer {
                RestTimerWatchView(
                    timeRemaining: $restTimeRemaining,
                    onComplete: {
                        showingRestTimer = false
                        repEngine.reset()
                    },
                    onSkip: {
                        showingRestTimer = false
                        repEngine.reset()
                        sessionManager.skipRestTimer()
                    }
                )
            } else {
                RepCounterView(repEngine: repEngine)
            }

            Spacer()

            // Action buttons
            if !showingRestTimer {
                HStack(spacing: 16) {
                    // Decrease reps
                    Button {
                        repEngine.adjustReps(-1)
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Image(systemName: "minus")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    // Complete set
                    Button {
                        completeSet()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.title2)
                            .frame(width: 50, height: 50)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)

                    // Increase reps
                    Button {
                        repEngine.adjustReps(1)
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            repEngine.startTracking(exerciseName: session.exerciseName)
        }
        .onDisappear {
            repEngine.stopTracking()
        }
    }

    private func completeSet() {
        // Haptic for set complete
        WKInterfaceDevice.current().play(.success)

        // Send update to iPhone
        sessionManager.completeSet(
            reps: repEngine.currentReps,
            confidence: repEngine.confidence
        )

        // Check if workout complete
        if session.completedSets + 1 >= session.plannedSets {
            // Workout complete celebration
            WKInterfaceDevice.current().play(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                WKInterfaceDevice.current().play(.success)
            }
        } else {
            // Start rest timer
            restTimeRemaining = session.restTimerDuration
            showingRestTimer = true
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == 0 {
            return "Bodyweight"
        } else if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight)) kg"
        } else {
            return String(format: "%.1f kg", weight)
        }
    }
}

// MARK: - Rep Counter View

struct RepCounterView: View {
    @Bindable var repEngine: RepCountingEngine

    var body: some View {
        VStack(spacing: 4) {
            // Large rep counter
            Text("\(repEngine.currentReps)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(.green)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: repEngine.currentReps)

            Text("REPS")
                .font(.caption)
                .foregroundColor(.secondary)

            // Tracking indicator
            if repEngine.isTracking {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Tracking")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                .padding(.top, 2)
            }
        }
    }
}

// MARK: - Rest Timer Watch View

struct RestTimerWatchView: View {
    @Binding var timeRemaining: Int
    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            Text("REST")
                .font(.caption)
                .foregroundColor(.orange)

            Text(timeString)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
                .monospacedDigit()

            Button("Skip") {
                WKInterfaceDevice.current().play(.click)
                timer?.invalidate()
                onSkip()
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var timeString: String {
        let mins = timeRemaining / 60
        let secs = timeRemaining % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1

                // Haptic feedback for countdown
                if timeRemaining == 0 {
                    WKInterfaceDevice.current().play(.notification)
                    timer?.invalidate()
                    onComplete()
                } else if timeRemaining <= 3 {
                    WKInterfaceDevice.current().play(.click)
                }
            }
        }
    }
}

#Preview {
    ContentView(sessionManager: WatchSessionManager.shared)
}
