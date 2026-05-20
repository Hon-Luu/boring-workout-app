import SwiftUI

struct TrainerTabView: View {
    @Environment(SeedStore.self) private var store

    private var readiness: ReadinessState { store.homeCache.readiness }
    private var plans: [GuidedWorkoutPlan] {
        WorkoutPlanEngine.generatePlans(store: store, readiness: readiness)
    }

    @State private var selectedPlan: GuidedWorkoutPlan? = nil
    @State private var showPlanPreview = false
    @State private var showLiveSession = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Mini readiness card
                    MiniReadinessCard(readiness: readiness)
                        .padding(.top, 4)

                    // Today's plan header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Plans")
                            .font(.title3.bold())
                        Text("Swipe to skip · Tap Start to begin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Swipeable cards
                    SwipeableWorkoutCards(
                        plans: plans,
                        onStart: { plan in
                            selectedPlan = plan
                            showPlanPreview = true
                        },
                        onSkip: {}
                    )

                    // Coach notes
                    CoachNotesCard(note: readiness.coachingNote)

                    // Or start custom
                    Divider()

                    Button {
                        store.startWorkout()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Start a Custom Workout")
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(HONTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(HONTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(AppTheme.pageBG)
            .navigationTitle("Trainer")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showPlanPreview) {
            if let plan = selectedPlan {
                GuidedWorkoutPlanView(plan: plan) {
                    showPlanPreview = false
                    showLiveSession = true
                }
            }
        }
        .fullScreenCover(isPresented: $showLiveSession) {
            if let plan = selectedPlan {
                GuidedWorkoutSessionView(plan: plan)
                    .environment(store)
            }
        }
    }
}

// MARK: - Mini Readiness Card

private struct MiniReadinessCard: View {
    let readiness: ReadinessState

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Readiness")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(readiness.score)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("/ 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider().frame(height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Confidence:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(readiness.confidence.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(readiness.confidence.color)
                }
                HStack(spacing: 4) {
                    Image(systemName: readiness.deltaFromBaseline >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2.bold())
                    Text("\(abs(readiness.deltaFromBaseline)) vs 30-day avg")
                        .font(.caption)
                }
                .foregroundStyle(readiness.deltaFromBaseline >= 0 ? HONTheme.positive : HONTheme.warning)
            }

            Spacer()
        }
        .padding(16)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Coach Notes Card

private struct CoachNotesCard: View {
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Coach's Note", systemImage: "quote.bubble.fill")
                .font(.subheadline.bold())
                .foregroundStyle(HONTheme.accent)
            Text(note)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}
