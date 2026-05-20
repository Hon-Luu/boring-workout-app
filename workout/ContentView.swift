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

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            WorkoutTabView()
                .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
                .tag(1)

            ProgressView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(2)

            ExerciseInsightsView()
                .tabItem { Label("Insights", systemImage: "chart.dots.scatter") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
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
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )) {
            OnboardingView { hasCompletedOnboarding = true }
                .environment(store)
        }
    }
}
