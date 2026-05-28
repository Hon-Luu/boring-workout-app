import SwiftUI

struct TrainerTabView: View {
    @Environment(SeedStore.self) private var store

    private var readiness: ReadinessState { store.homeCache.readiness }
    // A-002: use stable plans from store (regenerated on data change, not every render)
    private var plans: [GuidedWorkoutPlan] { store.recommendedPlans }

    @State private var selectedPlan: GuidedWorkoutPlan? = nil
    @State private var showPlanPreview = false
    @State private var showLiveSession = false
    @State private var strongestDayDismissed = false
    // T-008: time budget picker
    @AppStorage("trainerTimeBudget") private var timeBudgetMinutes: Int = 50
    // V-002: deload callout dismissal (keyed by week string)
    @AppStorage("deloadCalloutDismissedWeek") private var deloadCalloutDismissedWeek: String = ""

    private var currentWeekKey: String {
        let cal = Calendar.current
        let week = cal.component(.weekOfYear, from: Date())
        let year = cal.component(.year, from: Date())
        return "\(year)-W\(week)"
    }

    private var showDeloadCallout: Bool {
        store.deloadRecommended && deloadCalloutDismissedWeek != currentWeekKey
    }

    /// Returns true when today is the user's strongest day of the week and readiness is sufficient.
    private var showStrongestDayCallout: Bool {
        guard !strongestDayDismissed, readiness.score >= 65 else { return false }
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date()) // 1=Sun…7=Sat
        let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let todayName = (dayNames[safe: weekday] ?? "").uppercased()
        // Look for an insight whose stateName starts with today's day name and ends with DOMINANT
        let insights = EmergentInsightEngine.compute(
            log: store.workoutLog,
            analyticsResult: store.analyticsCache,
            hrv: nil, sleepHours: nil
        )
        return insights.contains { $0.title == "Your Strongest Day"
            && $0.dataAvailable
            && $0.stateName.hasPrefix(todayName)
            && $0.stateName.hasSuffix("DOMINANT") }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Mini readiness card
                    MiniReadinessCard(readiness: readiness)
                        .padding(.top, 4)

                    // Strongest-day callout (T-013)
                    if showStrongestDayCallout {
                        Text("Your strongest day of the week. Go for it.")
                            .font(.subheadline.bold())
                            .foregroundStyle(HONTheme.positive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    // V-002: deload callout
                    if showDeloadCallout {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "moon.zzz.fill")
                                .foregroundStyle(HONTheme.warning)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Recovery week")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(HONTheme.warning)
                                Text("You've been training hard. This week's plans are dialled back — intentional recovery.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                deloadCalloutDismissedWeek = currentWeekKey
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(HONTheme.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Today's plan header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Today's Plans")
                                    .font(.title3.bold())
                                Text("Swipe to skip · Tap Start to begin")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        // T-008: time budget picker
                        Picker("Time", selection: $timeBudgetMinutes) {
                            Text("Quick").tag(35)
                            Text("Standard").tag(50)
                            Text("Full").tag(65)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: timeBudgetMinutes) { _, _ in
                            store.refreshRecommendedPlans()
                        }
                    }

                    // Swipeable cards
                    SwipeableWorkoutCards(
                        plans: plans,
                        onStart: { plan in
                            selectedPlan = plan
                            showPlanPreview = true
                            strongestDayDismissed = true
                            // P-001: log plan start
                            let fb = PlanFeedback(planId: plan.id, action: "started",
                                                  timestamp: Date(), focusRegions: plan.bodyRegions)
                            store.logPlanFeedback(fb)
                        },
                        onSkip: { plan in
                            // P-001: log plan skip
                            let fb = PlanFeedback(planId: plan.id, action: "skipped",
                                                  timestamp: Date(), focusRegions: plan.bodyRegions)
                            store.logPlanFeedback(fb)
                        }
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
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) { expanded.toggle() }
            } label: {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Readiness")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(readiness.confidence == .low ? "~\(readiness.score)" : "\(readiness.score)")
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

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expanded && !readiness.factors.isEmpty {
                Divider().padding(.top, 12)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(readiness.factors) { factor in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(factor.isPositive ? HONTheme.positive : HONTheme.warning)
                                .frame(width: 5, height: 5)
                            Text(factor.text)
                                .font(.caption)
                                .foregroundStyle(factor.isPositive ? HONTheme.positive : HONTheme.warning)
                        }
                    }
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
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
