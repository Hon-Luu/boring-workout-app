import SwiftUI

struct FirstWorkoutCelebrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SeedStore.self) private var store
    @State private var showHONSheet = false

    private let milestones: [(String, String)] = [
        ("Come back tomorrow to start seeing your estimated 1-rep max (e1RM) trend", "chart.line.uptrend.xyaxis"),
        ("After 3 sessions, your strength tier unlocks", "shield.lefthalf.filled"),
        ("After 10 sessions, readiness confidence rises to High", "brain.head.profile")
    ]

    var body: some View {
        ZStack {
            HONTheme.background.ignoresSafeArea()

            // Decorative background shapes
            decorativeBackground

            ScrollView {
                VStack(spacing: 32) {

                    // Trophy icon
                    ZStack {
                        Circle()
                            .fill(HONTheme.accent.opacity(0.12))
                            .frame(width: 110, height: 110)
                        Circle()
                            .fill(HONTheme.accent.opacity(0.07))
                            .frame(width: 140, height: 140)
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(HONTheme.accent)
                    }
                    .padding(.top, 40)

                    // Headline
                    VStack(spacing: 8) {
                        Text("Your First Workout")
                            .font(.honDisplay(34))
                            .foregroundStyle(HONTheme.textPrimary)
                        Text("is Logged!")
                            .font(.honDisplay(34))
                            .foregroundStyle(HONTheme.accent)
                    }
                    .multilineTextAlignment(.center)

                    // Subheadline
                    Text("You've taken the first step.\nEvery session from here compounds.")
                        .font(.honBody(15))
                        .foregroundStyle(HONTheme.textPrimary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    // Milestone bullets
                    VStack(spacing: 14) {
                        ForEach(Array(milestones.enumerated()), id: \.offset) { _, milestone in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(HONTheme.positive)
                                    .frame(width: 22)
                                Text(milestone.0)
                                    .font(.honBody(15))
                                    .foregroundStyle(HONTheme.textPrimary.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(3)
                                Spacer()
                            }
                        }
                    }
                    .padding(20)
                    .background(HONTheme.surface, in: RoundedRectangle(cornerRadius: 16))

                    // CTA button
                    Button {
                        dismiss()
                    } label: {
                        Text("Start My Journey")
                            .font(.honBody(17, weight: .bold))
                            .foregroundStyle(HONTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(HONTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    // What's H.O.N.?
                    Button {
                        showHONSheet = true
                    } label: {
                        Text("What's H.O.N.?")
                            .font(.honBody(13))
                            .foregroundStyle(HONTheme.accent.opacity(0.7))
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 28)
            }
        }
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showHONSheet) {
            HONExplanationSheet()
        }
    }

    // MARK: - Decorative background

    private var decorativeBackground: some View {
        ZStack {
            // Top-right amber diamond
            Diamond()
                .fill(HONTheme.accent.opacity(0.06))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(15))
                .offset(x: 140, y: -60)

            // Bottom-left circle
            Circle()
                .fill(HONTheme.accent.opacity(0.05))
                .frame(width: 160, height: 160)
                .offset(x: -120, y: 300)

            // Mid-right small circle
            Circle()
                .fill(HONTheme.positive.opacity(0.07))
                .frame(width: 80, height: 80)
                .offset(x: 150, y: 200)

            // Small top-left diamond
            Diamond()
                .fill(HONTheme.positive.opacity(0.05))
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(-10))
                .offset(x: -140, y: 80)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - H.O.N. Explanation Sheet

struct HONExplanationSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let bullets: [(String, String)] = [
        ("arrow.counterclockwise.circle.fill", "Returning after a gap is part of the habit — not a failure of it"),
        ("archivebox.fill", "Every session you've ever logged is here, waiting for you"),
        ("chart.line.uptrend.xyaxis", "Numbers track your training. The habit is the goal.")
    ]

    var body: some View {
        ZStack {
            HONTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag indicator spacer
                Capsule()
                    .fill(HONTheme.textPrimary.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 28)

                ScrollView {
                    VStack(spacing: 24) {
                        // Title block
                        VStack(spacing: 6) {
                            Text("What is H.O.N.?")
                                .font(.honDisplay(28))
                                .foregroundStyle(HONTheme.textPrimary)
                            Text("Habit Over Numbers")
                                .font(.honBody(15, weight: .semibold))
                                .foregroundStyle(HONTheme.accent)
                        }
                        .multilineTextAlignment(.center)

                        // Body text
                        Text("This app exists to help you keep the habit. Not to reward your best weeks or punish your gaps — to be here, ready, every time you decide to come back. With an honest record of everything you've built, and nothing that makes showing up feel harder than it already is.")
                            .font(.honBody(15))
                            .foregroundStyle(HONTheme.textPrimary.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        // Bullet points
                        VStack(spacing: 14) {
                            ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: bullet.0)
                                        .font(.system(size: 18))
                                        .foregroundStyle(HONTheme.accent)
                                        .frame(width: 22)
                                    Text(bullet.1)
                                        .font(.honBody(15))
                                        .foregroundStyle(HONTheme.textPrimary.opacity(0.85))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineSpacing(3)
                                    Spacer()
                                }
                            }
                        }
                        .padding(20)
                        .background(HONTheme.surface, in: RoundedRectangle(cornerRadius: 16))

                        // Got it button
                        Button {
                            dismiss()
                        } label: {
                            Text("Got it")
                                .font(.honBody(17, weight: .bold))
                                .foregroundStyle(HONTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(HONTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 28)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Diamond Shape

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
