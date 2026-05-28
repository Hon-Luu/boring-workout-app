import SwiftUI

// MARK: - In-App Message Banner

struct HONInAppBanner: View {
    let message: HONPendingMessage
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: message.icon)
                .foregroundStyle(HONTheme.accent)
                .font(.system(size: 20))
                .frame(width: 28)
            Text(message.message)
                .font(.custom("CormorantGaramond-Light", size: 16))
                .foregroundStyle(.primary)
                .lineLimit(3)
            Spacer(minLength: 4)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Material.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
}

// MARK: - Content

struct ContentView: View {
    @Environment(SeedStore.self) private var store
    @Environment(HONHabitEngine.self) private var habitEngine
    @State private var selectedTab = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("prefersDarkMode") private var prefersDarkMode = true
    @AppStorage("hasSeenAppearanceChoice") private var hasSeenAppearanceChoice = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            WorkoutTabView()
                .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
                .tag(1)

            ProgressView()
                .tabItem { Label("Advanced", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(2)

            ExerciseInsightsView(goToSettings: { selectedTab = 5 })
                .tabItem { Label("Insights", systemImage: "chart.dots.scatter") }
                .tag(3)

            TrainerTabView()
                .tabItem { Label("Trainer", systemImage: "figure.strengthtraining.traditional") }
                .tag(4)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(5)
        }
        .tint(HONTheme.accent)
        .preferredColorScheme(prefersDarkMode ? .dark : .light)
        .overlay(alignment: .top) {
            if let msg = habitEngine.inAppMessage, selectedTab != 1 {
                HONInAppBanner(message: msg) { habitEngine.dismissInAppMessage() }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: habitEngine.inAppMessage?.id)
        .onChange(of: store.cardioLog.first?.id) { _, newId in
            guard newId != nil else { return }
            habitEngine.onAnyActivityLogged(strengthLog: store.workoutLog,
                                            cardioLog: store.cardioLog,
                                            generalLog: store.generalLog)
        }
        .onChange(of: store.generalLog.first?.id) { _, newId in
            guard newId != nil else { return }
            habitEngine.onAnyActivityLogged(strengthLog: store.workoutLog,
                                            cardioLog: store.cardioLog,
                                            generalLog: store.generalLog)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )) {
            OnboardingView { hasCompletedOnboarding = true }
                .environment(store)
        }
        .sheet(isPresented: Binding(
            get: { hasCompletedOnboarding && !hasSeenAppearanceChoice },
            set: { if !$0 { hasSeenAppearanceChoice = true } }
        )) {
            AppearanceChoiceSheet(prefersDarkMode: $prefersDarkMode) {
                hasSeenAppearanceChoice = true
            }
        }
    }
}

// MARK: - Appearance Choice Sheet

private struct AppearanceChoiceSheet: View {
    @Binding var prefersDarkMode: Bool
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Choose Your Look")
                    .font(.title.bold())
                Text("You can always change this later in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            HStack(spacing: 16) {
                AppearanceOption(
                    label: "Dark",
                    icon: "moon.fill",
                    isSelected: prefersDarkMode
                ) {
                    prefersDarkMode = true
                }

                AppearanceOption(
                    label: "Light",
                    icon: "sun.max.fill",
                    isSelected: !prefersDarkMode
                ) {
                    prefersDarkMode = false
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onDone) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HONTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(HONTheme.textPrimary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .preferredColorScheme(prefersDarkMode ? .dark : .light)
    }
}

private struct AppearanceOption: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(isSelected ? HONTheme.accent : .secondary)
                Text(label)
                    .font(.headline)
                    .foregroundStyle(isSelected ? HONTheme.accent : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? HONTheme.accent.opacity(0.12) : Color.secondary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? HONTheme.accent : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
