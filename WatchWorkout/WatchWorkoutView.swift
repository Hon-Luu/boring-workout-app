import SwiftUI

// MARK: - Main Watch workout view

struct WatchWorkoutView: View {
    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        if session.isSetRecording {
            ActiveSetView().environmentObject(session)
        } else {
            IdleView().environmentObject(session)
        }
    }
}

// MARK: - Idle / between-set view

private struct IdleView: View {
    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        VStack(spacing: 10) {
            Text(session.currentExerciseName)
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(session.isWorkoutActive ? .primary : .secondary)

            if session.isWorkoutActive {
                Button(action: session.startSet) {
                    Label("Start Set", systemImage: "record.circle")
                        .font(.system(size: 15, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            } else {
                Text("Start workout on iPhone first")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !session.reps.isEmpty {
                lastSetSummary
            }
        }
        .padding()
        .navigationTitle("Boring Workout")
    }

    private var lastSetSummary: some View {
        VStack(spacing: 4) {
            Text("Last Set")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text("\(session.reps.count) reps")
                .font(.system(size: 22, weight: .black))
            if let last = session.reps.last {
                Text(String(format: "%.0f%% VL", last.velocityLossFraction * 100))
                    .font(.caption.bold())
                    .foregroundStyle(velocityColor(last.velocityLossFraction * 100))
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }

    private func velocityColor(_ pct: Double) -> Color {
        pct < 10 ? .green : pct < 20 ? .yellow : pct < 30 ? .orange : .red
    }
}

// MARK: - Active set recording view

private struct ActiveSetView: View {
    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        VStack(spacing: 6) {
            // Exercise name
            Text(session.currentExerciseName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Rep counter — big number
            Text("\(session.reps.count)")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: session.reps.count)

            // Phase indicator
            phaseIndicator

            // Speed bar
            if let last = session.reps.last {
                speedBar(last)
            }

            // End set button
            Button(action: session.endSet) {
                Text("Done")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.horizontal, 8)
    }

    // Phase label
    private var phaseIndicator: some View {
        let (label, color): (String, Color) = {
            switch session.currentPhase {
            case .eccentric:  return ("↓ Eccentric", .orange)
            case .concentric: return ("↑ Concentric", .blue)
            case .idle:       return ("Ready", .secondary)
            }
        }()
        return Text(label)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
            .animation(.easeInOut(duration: 0.15), value: session.currentPhase)
    }

    // Speed + velocity loss bar
    private func speedBar(_ rep: RepEvent) -> some View {
        let lossPct = rep.velocityLossFraction * 100
        let fillColor: Color = lossPct < 10 ? .green : lossPct < 20 ? .yellow : lossPct < 30 ? .orange : .red
        let fillFraction = max(0, min(1, 1 - rep.velocityLossFraction))

        return VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(fillColor)
                        .frame(width: geo.size.width * fillFraction, height: 6)
                        .animation(.spring(duration: 0.4), value: fillFraction)
                }
            }
            .frame(height: 6)
            HStack {
                Text(String(format: "%.1f m/s²", rep.concentricSpeed))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "−%.0f%% VL", lossPct))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(fillColor)
            }
        }
    }
}
