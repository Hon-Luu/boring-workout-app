import SwiftUI

struct SwipeableWorkoutCards: View {
    let plans: [GuidedWorkoutPlan]
    let onStart: (GuidedWorkoutPlan) -> Void
    let onSkip: (GuidedWorkoutPlan) -> Void

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var exitOffset: CGFloat = 0
    @State private var isExiting = false

    private var visiblePlans: [GuidedWorkoutPlan] {
        Array(plans.dropFirst(currentIndex).prefix(3))
    }

    var body: some View {
        ZStack {
            if visiblePlans.isEmpty {
                allDoneCard
            } else {
                ForEach(Array(visiblePlans.enumerated().reversed()), id: \.element.id) { position, plan in
                    WorkoutCard(
                        plan: plan,
                        dragOffset: position == 0 ? dragOffset : .zero,
                        onStart: { startPlan(plan) },
                        onSkip: { skipCard() }
                    )
                    .scaleEffect(cardScale(position: position))
                    .offset(y: cardYOffset(position: position))
                    .zIndex(Double(3 - position))
                    .allowsHitTesting(position == 0)
                    .gesture(position == 0 ? dragGesture : nil)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentIndex)
                }
            }
        }
        .frame(height: 280)
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let threshold: CGFloat = 90
                if value.translation.width < -threshold {
                    skipCard()
                } else if value.translation.width > threshold {
                    if let plan = visiblePlans.first { startPlan(plan) }
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    // MARK: - Actions

    private func skipCard() {
        guard let plan = visiblePlans.first else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            dragOffset = CGSize(width: -600, height: 80)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            currentIndex = min(currentIndex + 1, plans.count)
            dragOffset = .zero
            onSkip(plan)
        }
    }

    private func startPlan(_ plan: GuidedWorkoutPlan) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            dragOffset = CGSize(width: 600, height: -40)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dragOffset = .zero
            onStart(plan)
        }
    }

    // MARK: - Card Scaling

    private func cardScale(position: Int) -> Double {
        let base = 1.0 - Double(position) * 0.06
        let dragProgress = min(abs(dragOffset.width) / 100.0, 1.0)
        return base + Double(position) * 0.06 * dragProgress
    }

    private func cardYOffset(position: Int) -> Double {
        let base = Double(position) * 14.0
        let dragProgress = min(abs(dragOffset.width) / 100.0, 1.0)
        return base * (1.0 - dragProgress)
    }

    // MARK: - All Done

    private var allDoneCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(HONTheme.positive)
            Text("You've seen all plans")
                .font(.headline)
            Button("Refresh") { currentIndex = 0 }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .background(AppTheme.cardBG,
                    in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Individual Card

private struct WorkoutCard: View {
    let plan: GuidedWorkoutPlan
    let dragOffset: CGSize
    let onStart: () -> Void
    let onSkip: () -> Void

    private var rotation: Double { Double(dragOffset.width) / 22 }
    private var swipeProgress: Double { dragOffset.width / 120 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    IntensityBadge(intensity: plan.intensity)
                    Spacer()
                    Text("~\(plan.estimatedMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(plan.title)
                    .font(.system(size: 26, weight: .bold))

                Text(plan.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider().padding(.horizontal, 20)

            // Exercise list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.exercises.prefix(4)) { ge in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(HONTheme.accent.opacity(0.15))
                            .frame(width: 7, height: 7)
                        Text(ge.exercise.name)
                            .font(.subheadline)
                        if let tag = ge.performanceTag {
                            Text(tag)
                                .font(.caption2)
                                .foregroundStyle(tag.hasPrefix("↑") ? HONTheme.positive : tag.hasPrefix("⟳") ? HONTheme.warning : .secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background((tag.hasPrefix("↑") ? HONTheme.positive : tag.hasPrefix("⟳") ? HONTheme.warning : Color.secondary).opacity(0.12), in: Capsule())
                        }
                        Spacer()
                        Text("\(ge.targetSets)×\(ge.targetReps)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                if plan.exercises.count > 4 {
                    Text("+\(plan.exercises.count - 4) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 17)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Spacer(minLength: 0)

            Divider().padding(.horizontal, 20)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onSkip) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.caption.bold())
                        Text("Skip")
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.secondary)
                }

                Button(action: onStart) {
                    HStack(spacing: 6) {
                        Text("Start")
                            .font(.subheadline.bold())
                        Image(systemName: "arrow.right")
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(HONTheme.accent, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(HONTheme.textPrimary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background(AppTheme.cardBG,
                    in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    dragOffset.width > 20 ? HONTheme.positive.opacity(min(dragOffset.width / 200.0, 0.18)) :
                    dragOffset.width < -20 ? Color.secondary.opacity(min(-dragOffset.width / 200.0, 0.12)) :
                    Color.clear
                )
                .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .offset(dragOffset)
        .rotationEffect(.degrees(rotation))
        // Skip/Start overlays
        .overlay(alignment: .topLeading) {
            Text("SKIP")
                .font(.title3.bold())
                .foregroundStyle(HONTheme.negative)
                .padding(16)
                .opacity(max(0, -swipeProgress))
        }
        .overlay(alignment: .topTrailing) {
            Text("START")
                .font(.title3.bold())
                .foregroundStyle(HONTheme.positive)
                .padding(16)
                .opacity(max(0, swipeProgress))
        }
    }
}

// MARK: - Intensity Badge

struct IntensityBadge: View {
    let intensity: GuidedWorkoutPlan.Intensity

    private var color: Color {
        switch intensity {
        case .light:    return HONTheme.positive
        case .moderate: return HONTheme.warning
        case .heavy:    return HONTheme.negative
        }
    }

    var body: some View {
        Text(intensity.rawValue)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
