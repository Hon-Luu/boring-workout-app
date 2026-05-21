import SwiftUI
import Charts

struct HomeView: View {
    @Binding var selectedTab: Int
    @Environment(SeedStore.self) private var store
    @Environment(HealthKitService.self) private var health
    @AppStorage("userName") private var userName: String = "Alex"
    @AppStorage("progressNudgeDismissed") private var progressNudgeDismissed: Bool = false
    @AppStorage("bodyweightNudgeDismissed") private var bodyweightNudgeDismissed: Bool = false
    @State private var activeCircuit: CardioCircuit? = nil
    @State private var weather = WeatherService()

    // MARK: - Computed helpers

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default:     return "Good evening"
        }
    }

    // Exclude workouts from today so the card doesn't show "Today"
    private var pastWorkouts: [WorkoutLogEntry] {
        store.workoutLog.filter { !Calendar.current.isDateInToday($0.startedAt) }
    }

    private var lastWorkout: WorkoutLogEntry? { pastWorkouts.first }

    private var lastWorkoutHistory: [WorkoutLogEntry] {
        pastWorkouts.count > 1 ? Array(pastWorkouts.dropFirst()) : []
    }

    // MARK: - Weekly stats (Sun–Sat current calendar week)

    private var weekStart: Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
    }

    private var weeklyWorkouts: [WorkoutLogEntry] {
        store.workoutLog.filter { $0.startedAt >= weekStart }
    }

    // Last week: same Sunday through the same weekday as today
    private var lastWeekWorkouts: [WorkoutLogEntry] {
        let cal = Calendar.current
        let lastWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: weekStart)!
        let lastWeekSameMoment = cal.date(byAdding: .weekOfYear, value: -1, to: Date())!
        return store.workoutLog.filter { $0.startedAt >= lastWeekStart && $0.startedAt < lastWeekSameMoment }
    }

    private var lastWeekMinutes: Int {
        Int(lastWeekWorkouts.map(\.duration).reduce(0, +) / 60)
    }

    // Month-to-date vs same period last month
    private var monthStart: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    }

    private var lastMonthWorkouts: [WorkoutLogEntry] {
        let cal = Calendar.current
        let lastMonthStart = cal.date(byAdding: .month, value: -1, to: monthStart)!
        let lastMonthSameMoment = cal.date(byAdding: .month, value: -1, to: Date())!
        return store.workoutLog.filter { $0.startedAt >= lastMonthStart && $0.startedAt < lastMonthSameMoment }
    }

    private var lastMonthMinutes: Int {
        Int(lastMonthWorkouts.map(\.duration).reduce(0, +) / 60)
    }

    private var monthMinutes: Int {
        let monthWorkouts = store.workoutLog.filter { $0.startedAt >= monthStart }
        return Int(monthWorkouts.map(\.duration).reduce(0, +) / 60)
    }

    private var weeklyMinutes: Int {
        Int(weeklyWorkouts.map(\.duration).reduce(0, +) / 60)
    }

    private var weeklySets: Int {
        weeklyWorkouts.flatMap(\.exercises).flatMap(\.completedSets).count
    }

    private var weeklyVolume: Int {
        Int(weeklyWorkouts.map(\.totalVolume).reduce(0, +))
    }

    private var weeklyActiveDays: Int {
        Set(weeklyWorkouts.map { Calendar.current.startOfDay(for: $0.startedAt) }).count
    }

    private var todayPlan: [(WorkoutTemplate, [TemplateExercise])] {
        store.routines.compactMap { routine in
            let ex = store.todayExercises(for: routine)
            return ex.isEmpty ? nil : (routine, ex)
        }
    }

    private var todayCircuits: [CardioCircuit] {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return store.cardioCircuits.filter { $0.assignedDays.contains(weekday) }
    }

    private var isPM: Bool {
        #if DEBUG
        return true
        #else
        return Calendar.current.component(.hour, from: Date()) >= 12
        #endif
    }

    private var todayWorkouts: [WorkoutLogEntry] {
        store.workoutLog
            .filter { Calendar.current.isDateInToday($0.startedAt) }
            .sorted { $0.startedAt < $1.startedAt }   // chronological — oldest first
    }

    private var todayHints: [UUID: ExerciseTodayHint] { store.homeCache.todayHints }
    private var exerciseNotes: [UUID: String]          { store.homeCache.exerciseNotes }
    private var progressTrend: [ExerciseProgress]      { store.homeCache.progressTrend }

    // All weekdays (1=Sun…7=Sat) that have at least one exercise scheduled
    private var allScheduledWeekdays: Set<Int> {
        Set(store.routines.flatMap { $0.exercises.flatMap(\.assignedDays) })
    }

    // Next scheduled workout day after today, with how many days away it is
    private var upcomingPlan: (weekday: Int, daysAway: Int, plans: [(WorkoutTemplate, [TemplateExercise])])? {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let scheduled = allScheduledWeekdays
        guard !scheduled.isEmpty else { return nil }

        for offset in 1...7 {
            let candidate = (todayWeekday - 1 + offset) % 7 + 1
            if scheduled.contains(candidate) {
                let plans: [(WorkoutTemplate, [TemplateExercise])] = store.routines.compactMap { routine in
                    let ex = routine.exercises.filter { $0.assignedDays.contains(candidate) }
                    return ex.isEmpty ? nil : (routine, ex)
                }
                return plans.isEmpty ? nil : (candidate, offset, plans)
            }
        }
        return nil
    }

    // Show "Next Up" only when the next workout is tomorrow (1 day away) and it's 8 PM+
    private var shouldShowUpcoming: Bool {
        guard let upcoming = upcomingPlan else { return false }
        #if DEBUG
        return upcoming.daysAway == 1
        #else
        let hour = Calendar.current.component(.hour, from: Date())
        return upcoming.daysAway == 1 && hour >= 20
        #endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Header + Weather
                    headerSection

                    // MARK: Loading skeleton
                    if !store.isLoaded {
                        HomeLoadingSkeleton()
                    }

                    // MARK: Weekly Stats Strip
                    if !weeklyWorkouts.isEmpty {
                        WeeklyStatsStrip(
                            minutes: weeklyMinutes,
                            workouts: weeklyWorkouts.count,
                            sets: weeklySets,
                            volume: weeklyVolume,
                            activeDays: weeklyActiveDays,
                            wowDelta: weeklyMinutes - lastWeekMinutes,
                            momDelta: monthMinutes - lastMonthMinutes
                        )
                    }

                    // MARK: Health Snapshots
                    if health.hrv != nil || health.restingHR != nil || health.sleepHours != nil
                        || health.stepsToday != nil || health.activeCaloriesToday != nil || health.vo2Max != nil {
                        HealthSnapshotRow(health: health)
                    }

                    // MARK: Today's Workout Recap (all sessions completed today)
                    if !todayWorkouts.isEmpty {
                        let multiSession = todayWorkouts.count > 1
                        sectionHeader(multiSession ? "Today's Workouts" : "Today's Workout")
                        ForEach(Array(todayWorkouts.enumerated()), id: \.element.id) { index, session in
                            WorkoutRecapCard(
                                workout: session,
                                history: store.workoutLog.filter { $0.startedAt < session.startedAt },
                                subtitle: multiSession ? "Session \(index + 1)" : "Today"
                            )
                        }
                    }

                    // MARK: Today's Plan (shown when no workout done yet and plan exists)
                    if todayWorkouts.isEmpty && !todayPlan.isEmpty {
                        sectionHeader("Today's Plan")
                        let hints = todayHints
                        let notes = exerciseNotes
                        ForEach(todayPlan, id: \.0.id) { routine, exercises in
                            TodayPlanCard(routine: routine, exercises: exercises, hints: hints, notes: notes) {
                                if store.activeWorkout == nil {
                                    store.startWorkout(fromRoutine: routine)
                                }
                                selectedTab = 1
                            }
                        }
                    }

                    // MARK: Today's Circuits
                    if !todayCircuits.isEmpty {
                        sectionHeader("Today's Circuit\(todayCircuits.count > 1 ? "s" : "")")
                        ForEach(todayCircuits) { circuit in
                            TodayCircuitCard(circuit: circuit) {
                                activeCircuit = circuit
                            }
                        }
                    }

                    // MARK: No-plan CTA
                    if todayWorkouts.isEmpty && todayPlan.isEmpty {
                        startFreeWorkoutBanner
                        if !store.isTodayRestDay {
                            restDayBanner
                        } else {
                            restDayConfirmation
                        }
                    }

                    // MARK: Upcoming Workout
                    if shouldShowUpcoming, let upcoming = upcomingPlan {
                        sectionHeader("Next Up")
                        UpcomingWorkoutCard(weekday: upcoming.weekday, plans: upcoming.plans, log: store.workoutLog)
                    }

                    // MARK: Progress tab nudge (after 5th workout, once)
                    if store.workoutLog.count >= 5 && !progressNudgeDismissed {
                        progressTabNudge
                    }

                    // MARK: Bodyweight prompt (after 1st workout, if bodyweight not set)
                    if store.workoutLog.count >= 1 && store.userProfile.bodyWeightKg == nil && !bodyweightNudgeDismissed {
                        bodyweightNudge
                    }

                    // MARK: Last Workout Recap
                    if let last = lastWorkout {
                        sectionHeader("Last Workout")
                        WorkoutRecapCard(
                            workout: last,
                            history: lastWorkoutHistory,
                            subtitle: relativeDate(last.startedAt)
                        )
                    }

                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
            .background(AppTheme.pageBG)
            .navigationBarHidden(true)
        }
        .fullScreenCover(item: $activeCircuit) { circuit in
            switch circuit.format {
            case .amrap: AMRAPSessionView(circuit: circuit, onDone: { activeCircuit = nil })
            case .emom:  EMOMSessionView(circuit: circuit,  onDone: { activeCircuit = nil })
            }
        }
        .onAppear {
            weather.request()
            health.requestAndFetch()
        }
        .onChange(of: health.bodyweight) { _, new in
            guard let bw = new, bw > 0 else { return }
            store.userProfile.bodyWeightKg = bw
        }
        .onChange(of: health.bodyFatPercentage) { _, new in
            guard let fat = new, fat > 0 else { return }
            store.userProfile.bodyFatPercent = fat
        }
        .onChange(of: health.leanBodyMass) { _, new in
            guard let lean = new, lean > 0,
                  let bw = store.userProfile.bodyWeightKg, bw > 0 else { return }
            store.userProfile.muscleMassPercent = (lean / bw) * 100
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting), \(userName) 👋")
                    .font(.title2.bold())
                HStack(spacing: 8) {
                    Text(todayDateString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if weeklyActiveDays > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                            Text("\(weeklyActiveDays) this week")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(HONTheme.positive)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(HONTheme.positive.opacity(0.12), in: Capsule())
                    } else if store.currentStreak > 1 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                            Text("\(store.currentStreak)d streak")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(HONTheme.warning)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(HONTheme.warning.opacity(0.12), in: Capsule())
                    }
                }
            }
            Spacer()
            weatherBadge
        }
    }

    private var todayDateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    @ViewBuilder
    private var weatherBadge: some View {
        if weather.isLoading {
            ProgressView().frame(width: 64)
        } else if let temp = weather.temperature {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: weather.icon)
                        .symbolRenderingMode(.multicolor)
                        .font(.title3)
                    Text(weather.formatted(temp))
                        .font(.title3.bold())
                }
                if let hi = weather.highTemp, let lo = weather.lowTemp {
                    Text("H:\(weather.formatted(hi))  L:\(weather.formatted(lo))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(weather.condition)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else if weather.denied {
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "location.slash").foregroundStyle(.secondary)
                Text("No location").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.bottom, -8)
    }

    private func analyticsInsightRow(text: String) -> some View {
        Button { selectedTab = 2 } label: {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.bold())
                    .foregroundStyle(HONTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(HONTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var bodyweightNudge: some View {
        HStack(spacing: 14) {
            Image(systemName: "scalemass")
                .font(.title2)
                .foregroundStyle(HONTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Add your bodyweight")
                    .font(.subheadline.bold())
                Text("Required for BEG / INT / ADV / ELITE strength tier tracking in Insights")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                bodyweightNudgeDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
        }
        .padding(14)
        .background(HONTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var progressTabNudge: some View {
        HStack(spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundStyle(HONTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your trends are ready")
                    .font(.subheadline.bold())
                Text("Check the Progress tab to see how you're improving")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                progressNudgeDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
        }
        .padding(14)
        .background(HONTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            progressNudgeDismissed = true
            selectedTab = 2
        }
    }

    private var restDayBanner: some View {
        Button { store.logRestDay() } label: {
            HStack(spacing: 14) {
                Image(systemName: "moon.zzz.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Taking a rest day?")
                        .font(.subheadline.bold())
                    Text("Log it to keep your streak context")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var restDayConfirmation: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(HONTheme.positive)
            Text("Rest day logged")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Undo") { store.removeRestDay(for: Date()) }
                .font(.caption)
                .foregroundStyle(HONTheme.accent)
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private var startFreeWorkoutBanner: some View {
        Button { selectedTab = 1 } label: {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(HONTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("No plan today")
                        .font(.subheadline.bold())
                    Text("Tap to start a free workout")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 7 { return "\(days) days ago" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

// MARK: - Today Plan Card

private struct TodayPlanCard: View {
    let routine: WorkoutTemplate
    let exercises: [TemplateExercise]
    let hints: [UUID: ExerciseTodayHint]
    let notes: [UUID: String]
    let onStart: () -> Void

    @State private var isExpanded = false
    @State private var showWhyTooltip = false

    private var brief: String {
        WorkoutFeedbackEngine.preworkoutBrief(exercises: exercises, hints: hints)
            ?? "Same weights as last session."
    }

    private var whyExplanation: String {
        let hasIncrease = hints.values.contains { if case .increase = $0.kind { return true }; return false }
        let hasDeload = hints.values.contains { if case .deload = $0.kind { return true }; return false }
        if hasDeload {
            return "One or more exercises haven't progressed in 3+ sessions. The app suggests backing off to reset momentum before your next push."
        }
        if hasIncrease {
            return "You completed all sets with good reps last session. Progressive overload principle: add weight when you can complete the target sets × reps."
        }
        return "Based on your last session's performance, this weight keeps your training consistent while your body adapts."
    }

    private var supersetGroups: [[TemplateExercise]] {
        var groups: [[TemplateExercise]] = []
        var seen: Set<String> = []
        for ex in exercises {
            if let g = ex.supersetGroup {
                if seen.contains(g) { continue }
                seen.insert(g)
                groups.append(exercises.filter { $0.supersetGroup == g })
            } else {
                groups.append([ex])
            }
        }
        return groups
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header
            HStack {
                Label(routine.name.isEmpty ? "My Routine" : routine.name,
                      systemImage: "calendar.badge.checkmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(HONTheme.accent)
                Spacer()
                Text("\(exercises.count) exercise\(exercises.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Coaching brief — always visible
            HStack(alignment: .top, spacing: 6) {
                Text(brief)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
                Button {
                    showWhyTooltip = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showWhyTooltip, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Why this recommendation?", systemImage: "lightbulb")
                            .font(.caption.bold())
                            .foregroundStyle(HONTheme.accent)
                        Text(whyExplanation)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: 280)
                    .presentationCompactAdaptation(.popover)
                }
            }

            // Expand/collapse exercise list
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(isExpanded ? "Hide exercises" : "Show exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(supersetGroups.enumerated()), id: \.offset) { _, group in
                        if group.count == 1, let ex = group.first {
                            SingleExerciseRow(te: ex, hint: hints[ex.exercise.id], note: notes[ex.exercise.id])
                        } else {
                            SupersetGroupRow(exercises: group)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button(action: onStart) {
                Label("Start Workout", systemImage: "play.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(HONTheme.accent, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(HONTheme.textPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppTheme.cardBG,
                    in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct SingleExerciseRow: View {
    let te: TemplateExercise
    var hint: ExerciseTodayHint? = nil
    var note: String? = nil

    private var noteColor: Color {
        guard let h = hint else { return .secondary }
        if h.isUrgent { return HONTheme.warning }
        if case .increase = h.kind { return HONTheme.positive }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Circle()
                    .fill(HONTheme.accent.opacity(0.12))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: te.exercise.equipment == .barbell ? "figure.strengthtraining.traditional"
                              : te.exercise.equipment == .dumbbell ? "dumbbell.fill"
                              : "figure.core.training")
                            .font(.caption2)
                            .foregroundStyle(HONTheme.accent)
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(te.exercise.name)
                        .font(.subheadline)
                    Text("\(te.targetSets) × \(te.targetReps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let n = note {
                Text(n)
                    .font(.caption)
                    .foregroundStyle(noteColor)
                    .padding(.leading, 42)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SupersetGroupRow: View {
    let exercises: [TemplateExercise]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(HONTheme.warning.opacity(0.7))
                    .frame(width: 3)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("Superset \(exercises.first?.supersetGroup ?? "")")
                    .font(.caption.bold())
                    .foregroundStyle(HONTheme.warning)
                ForEach(exercises) { te in
                    HStack(spacing: 8) {
                        Text(te.exercise.name)
                            .font(.subheadline)
                        Spacer()
                        Text("\(te.targetSets)×\(te.targetReps)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.leading, 4)
    }
}

// MARK: - Workout Recap Card

private struct WorkoutRecapCard: View {
    let workout: WorkoutLogEntry
    let history: [WorkoutLogEntry]
    let subtitle: String

    @Environment(SeedStore.self) private var store
    @Environment(HealthKitService.self) private var health
    @State private var isExpanded = false
    @State private var avgHR: Double? = nil
    @State private var activeCalories: Double? = nil

    private var previousVolume: Double? { history.first.map(\.totalVolume) }
    private var volumeChangePct: Double? {
        guard let prev = previousVolume, prev > 0 else { return nil }
        return (workout.totalVolume - prev) / prev * 100
    }
    private var narrative: String {
        WorkoutNarrativeEngine.generate(workout: workout, history: history)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name.isEmpty ? "Workout" : workout.name)
                        .font(.subheadline.bold())
                    Text(subtitle)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let feel = workout.feelRating {
                    HStack(spacing: 4) {
                        Text(feel.icon)
                            .font(.caption)
                        Text("Felt \(feel.rawValue)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.08), in: Capsule())
                }
                Text(workout.formattedDuration)
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(HONTheme.accent.opacity(0.1), in: Capsule())
                    .foregroundStyle(HONTheme.accent)
            }

            Text(narrative)
                .font(.subheadline).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true).lineSpacing(3)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(isExpanded ? "Hide details" : "Show details")
                        .font(.caption).foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack(spacing: 0) {
                    StatPill(label: "Exercises", value: "\(workout.exercises.count)")
                    Divider().frame(height: 30)
                    StatPill(label: "Sets", value: "\(workout.totalSets)")
                    Divider().frame(height: 30)
                    StatPill(label: "Volume", value: "\(Int(workout.totalVolume)) kg")
                    if let hr = workout.averageHeartRate ?? avgHR {
                        Divider().frame(height: 30)
                        StatPill(label: "Avg HR", value: "\(Int(hr)) bpm", valueColor: HONTheme.negative)
                    }
                    if let cal = workout.activeCalories ?? activeCalories {
                        Divider().frame(height: 30)
                        StatPill(label: "Cal Burned", value: "\(Int(cal)) kcal", valueColor: HONTheme.warning)
                    }
                    if let pct = volumeChangePct {
                        Divider().frame(height: 30)
                        StatPill(
                            label: "vs Prev",
                            value: "\(pct >= 0 ? "+" : "")\(Int(pct.rounded()))%",
                            valueColor: pct >= 0 ? AppTheme.positive : AppTheme.warning
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))
                .transition(.opacity.combined(with: .move(edge: .top)))

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(workout.exercises) { we in
                        HStack {
                            Text(we.exercise.name).font(.caption)
                            Spacer()
                            if let best = we.bestSet {
                                Text("\(best.weight.weightFormatted) kg × \(best.reps)")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        .task(id: workout.id) {
            guard let end = workout.finishedAt, health.isAuthorized else { return }
            async let bpmTask = workout.averageHeartRate == nil
                ? health.fetchAverageHeartRate(from: workout.startedAt, to: end) : nil
            async let calTask = workout.activeCalories == nil
                ? health.fetchActiveCalories(from: workout.startedAt, to: end) : nil
            let (bpm, cal) = await (bpmTask, calTask)
            if let bpm { avgHR = bpm; store.updateWorkoutHeartRate(id: workout.id, bpm: bpm) }
            if let cal { activeCalories = cal; store.updateWorkoutCalories(id: workout.id, calories: cal) }
        }
    }
}

// MARK: - Strength Retention Card

private struct StrengthRetentionCard: View {
    let composite: CompositeStrengthResult

    private func gradeColor(hex: String) -> Color {
        switch hex {
        case "purple": return .purple
        case "green":  return HONTheme.positive
        case "blue":   return .blue
        case "yellow": return HONTheme.warning
        case "orange": return .orange
        default:       return HONTheme.negative
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Retention ring
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(1, composite.peakRetentionPct))
                    .stroke(
                        gradeColor(hex: composite.gradeColor),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: composite.peakRetentionPct)
                VStack(spacing: 1) {
                    Text("\(Int(composite.peakRetentionPct * 100))%")
                        .font(.system(.callout, design: .rounded).bold())
                    Text("Peak")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)

            // Grade + scores
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(composite.grade)
                        .font(.system(.title2, design: .rounded).bold())
                        .foregroundStyle(gradeColor(hex: composite.gradeColor))
                    Text("Composite")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                Text(composite.insight)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    miniScore("Level", value: composite.levelScore)
                    miniScore("Momentum", value: composite.momentumScore)
                    miniScore("Process", value: composite.processScore)
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private func miniScore(_ label: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value))")
                .font(.system(.caption, design: .rounded).bold())
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Progress Trend Card

private struct ProgressTrendCard: View {
    let trend: [ExerciseProgress]

    private var gainers: [ExerciseProgress] {
        trend.filter { ($0.gain ?? 0) > 0.5 }.prefix(3).map { $0 }
    }
    private var stalled: [ExerciseProgress] {
        trend.filter { $0.isStalled }.prefix(2).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !gainers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Moving in the right direction")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(gainers, id: \.exerciseId) { ex in
                        HStack {
                            Text(ex.exerciseName)
                                .font(.subheadline)
                            Spacer()
                            if let gain = ex.gain {
                                Text("+\(gain.weightFormatted) kg over 6 weeks")
                                    .font(.caption.bold())
                                    .foregroundStyle(HONTheme.positive)
                            }
                        }
                    }
                }
            }

            if !stalled.isEmpty {
                if !gainers.isEmpty { Divider() }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Worth a closer look")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(stalled, id: \.exerciseId) { ex in
                        HStack {
                            Text(ex.exerciseName)
                                .font(.subheadline)
                            Spacer()
                            Text("Stuck for \(ex.sessionCount) sessions")
                                .font(.caption)
                                .foregroundStyle(HONTheme.warning)
                        }
                    }
                }
            }

            if gainers.isEmpty && stalled.isEmpty {
                Text("Keep showing up — your trends build over time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(AppTheme.cardBG,
                    in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Upcoming Workout Card

private struct UpcomingWorkoutCard: View {
    let weekday: Int
    let plans: [(WorkoutTemplate, [TemplateExercise])]
    let log: [WorkoutLogEntry]

    @State private var isExpanded = false

    private var weekdayName: String {
        let names = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard weekday >= 0 && weekday < names.count else { return "" }
        return names[weekday]
    }

    private var allExercises: [TemplateExercise] {
        plans.flatMap(\.1)
    }

    private var brief: String {
        WorkoutFeedbackEngine.upcomingSessionBrief(exercises: allExercises, log: log)
    }

    private var exerciseCount: Int { allExercises.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(weekdayName, systemImage: "calendar")
                    .font(.subheadline.bold())
                    .foregroundStyle(HONTheme.chartLavender)
                Spacer()
                Text("Tomorrow · \(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(brief)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(isExpanded ? "Hide exercises" : "Show exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(allExercises) { te in
                        HStack {
                            Text(te.exercise.name)
                                .font(.subheadline)
                            Spacer()
                            Text("\(te.targetSets) × \(te.targetReps)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(AppTheme.cardBG,
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Loading Skeleton

private struct HomeLoadingSkeleton: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.cardBG)
                .frame(height: 66)
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.cardBG)
                .frame(height: 120)
        }
        .opacity(pulse ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}

// MARK: - Weekly Stats Strip

private struct WeeklyStatsStrip: View {
    let minutes: Int
    let workouts: Int
    let sets: Int
    let volume: Int
    let activeDays: Int
    let wowDelta: Int   // this-week minutes minus same-period last week
    let momDelta: Int   // month-to-date minutes minus same-period last month

    private var formattedVolume: String {
        volume >= 1000 ? String(format: "%.1fk", Double(volume) / 1000) : "\(volume)"
    }

    var body: some View {
        HStack(spacing: 0) {
            activeCell
            divider
            statCell(value: "\(workouts)", unit: "session\(workouts == 1 ? "" : "s")", label: "This Week")
            divider
            statCell(value: "\(sets)", unit: "sets", label: "Total")
            divider
            statCell(value: formattedVolume, unit: "kg", label: "Volume")
        }
        .padding(.vertical, 14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    // Active cell with WoW and MoM sub-metrics
    private var activeCell: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(minutes)")
                    .font(.system(.headline, design: .rounded).bold())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("min")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            Text("Active")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                deltaLabel(delta: wowDelta, prefix: "WoW")
                deltaLabel(delta: momDelta, prefix: "MoM")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func deltaLabel(delta: Int, prefix: String) -> some View {
        let sign = delta >= 0 ? "+" : ""
        let color: Color = delta > 0 ? HONTheme.positive : delta < 0 ? HONTheme.negative : .secondary
        return Text("\(prefix) \(sign)\(delta)m")
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(color)
    }

    private func statCell(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(.headline, design: .rounded).bold())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(unit)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 1, height: 32)
    }
}

// MARK: - Health Snapshot Row

private enum HomeHealthTile: Identifiable {
    case hrv, restingHR, sleep, vo2Max, steps, activeCalories
    var id: Self { self }
}

private struct HealthSnapshotRow: View {
    let health: HealthKitService
    @State private var detail: HomeHealthTile?

    private func hrvInfo() -> (label: String, color: Color) {
        guard let v = health.hrv else { return ("—", .secondary) }
        switch v {
        case 60...: return ("\(Int(v)) ms", HONTheme.positive)
        case 40..<60: return ("\(Int(v)) ms", HONTheme.warning)
        default: return ("\(Int(v)) ms", HONTheme.negative)
        }
    }

    private func hrInfo() -> (label: String, color: Color) {
        guard let v = health.restingHR else { return ("—", .secondary) }
        switch v {
        case ..<55: return ("\(Int(v)) bpm", HONTheme.positive)
        case 55..<70: return ("\(Int(v)) bpm", .primary)
        case 70..<80: return ("\(Int(v)) bpm", HONTheme.warning)
        default: return ("\(Int(v)) bpm", HONTheme.negative)
        }
    }

    private func sleepInfo() -> (label: String, color: Color) {
        guard let v = health.sleepHours else { return ("—", .secondary) }
        let h = Int(v); let m = Int((v - Double(h)) * 60)
        let label = m > 0 ? "\(h)h \(m)m" : "\(h)h"
        switch v {
        case 7...: return (label, HONTheme.positive)
        case 6..<7: return (label, HONTheme.warning)
        default: return (label, HONTheme.negative)
        }
    }

    private func vo2Info() -> (label: String, color: Color) {
        guard let v = health.vo2Max else { return ("—", .secondary) }
        let label = String(format: "%.0f ml/kg", v)
        switch v {
        case 50...: return (label, HONTheme.positive)
        case 40..<50: return (label, .primary)
        case 30..<40: return (label, HONTheme.warning)
        default: return (label, HONTheme.negative)
        }
    }

    private func stepsInfo() -> (label: String, color: Color) {
        guard let v = health.stepsToday else { return ("—", .secondary) }
        let label = v >= 1000 ? String(format: "%.1fk", Double(v) / 1000) : "\(v)"
        switch v {
        case 10000...: return (label, HONTheme.positive)
        case 7500..<10000: return (label, .primary)
        case 5000..<7500: return (label, HONTheme.warning)
        default: return (label, HONTheme.negative)
        }
    }

    private func calInfo() -> (label: String, color: Color) {
        guard let v = health.activeCaloriesToday else { return ("—", .secondary) }
        let label = "\(Int(v)) cal"
        switch v {
        case 600...: return (label, HONTheme.positive)
        case 300..<600: return (label, .primary)
        default: return (label, HONTheme.warning)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    let hrv = hrvInfo()
                    HealthPill(icon: "waveform.path.ecg", title: "HRV",
                               value: hrv.label, valueColor: hrv.color,
                               history: health.hrvHistory) { detail = .hrv }

                    let hr = hrInfo()
                    HealthPill(icon: "heart.fill", title: "Resting HR",
                               value: hr.label, valueColor: hr.color,
                               history: health.restingHRHistory) { detail = .restingHR }

                    let sl = sleepInfo()
                    HealthPill(icon: "moon.zzz.fill", title: "Sleep",
                               value: sl.label, valueColor: sl.color,
                               history: health.sleepHistory) { detail = .sleep }

                    if health.vo2Max != nil {
                        let v = vo2Info()
                        HealthPill(icon: "lungs.fill", title: "VO2 Max",
                                   value: v.label, valueColor: v.color) { detail = .vo2Max }
                    }

                    if health.stepsToday != nil {
                        let s = stepsInfo()
                        HealthPill(icon: "figure.walk", title: "Steps",
                                   value: s.label, valueColor: s.color,
                                   history: health.stepsHistory) { detail = .steps }
                    }

                    if health.activeCaloriesToday != nil {
                        let c = calInfo()
                        HealthPill(icon: "flame.fill", title: "Active Cal",
                                   value: c.label, valueColor: c.color) { detail = .activeCalories }
                    }
                }
                .padding(.horizontal, 2)
            }

            if let ts = health.lastFetched {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refreshed ") + Text(ts, style: .relative) + Text(" ago")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.leading, 2)
            }
        }
        .sheet(item: $detail) { metric in
            HealthMetricDetailSheet(metric: metric, health: health)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct HealthPill: View {
    let icon: String
    let title: String
    let value: String
    let valueColor: Color
    var history: [HealthDataPoint] = []
    let onTap: () -> Void

    private var last7: [HealthDataPoint] { Array(history.suffix(7)) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(valueColor)
                if last7.count >= 3 {
                    let vals = last7.map(\.value)
                    let minV = vals.min() ?? 0
                    let maxV = vals.max() ?? 1
                    let range = maxV - minV
                    let trend: String = {
                        guard let first = vals.first, let last = vals.last else { return "stable" }
                        let delta = last - first
                        if abs(delta) < range * 0.1 { return "stable" }
                        return delta > 0 ? "trending up" : "trending down"
                    }()
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(last7) { pt in
                            let norm = range > 0 ? (pt.value - minV) / range : 0.5
                            RoundedRectangle(cornerRadius: 1)
                                .fill(valueColor.opacity(0.25 + norm * 0.75))
                                .frame(width: 4, height: max(4, norm * 16 + 4))
                        }
                    }
                    .frame(height: 20, alignment: .bottom)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(title) 7-day sparkline, \(trend)")
                    .accessibilityHint("Shows trend over the past 7 days")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Health Metric Detail Sheet

private struct HealthMetricDetailSheet: View {
    let metric: HomeHealthTile
    let health: HealthKitService

    private struct RangeRow {
        let label: String
        let range: String
        let color: Color
    }

    private var config: (icon: String, title: String, subtitle: String, value: String, explanation: String, ranges: [RangeRow]) { // swiftlint:disable:this large_tuple
        switch metric {
        case .vo2Max:
            let v = health.vo2Max
            let val = v.map { String(format: "%.0f ml/kg/min", $0) } ?? "No data"
            return (
                icon: "lungs.fill",
                title: "VO2 Max",
                subtitle: "Cardiorespiratory fitness",
                value: val,
                explanation: "VO2 Max measures how efficiently your body uses oxygen during exercise. A higher number means better cardiovascular fitness. It's one of the strongest predictors of longevity and overall health — and it responds well to consistent training over time.",
                ranges: [
                    RangeRow(label: "Superior", range: "≥ 50 ml/kg/min", color: HONTheme.positive),
                    RangeRow(label: "Excellent", range: "42 – 49 ml/kg/min", color: .green.opacity(0.7)),
                    RangeRow(label: "Good", range: "35 – 41 ml/kg/min", color: .primary),
                    RangeRow(label: "Fair", range: "28 – 34 ml/kg/min", color: HONTheme.warning),
                    RangeRow(label: "Low", range: "< 28 ml/kg/min", color: HONTheme.negative),
                ]
            )
        case .steps:
            let v = health.stepsToday
            let val = v.map { $0 >= 1000 ? String(format: "%.1fk steps", Double($0) / 1000) : "\($0) steps" } ?? "No data"
            return (
                icon: "figure.walk",
                title: "Steps Today",
                subtitle: "Daily movement",
                value: val,
                explanation: "Daily step count reflects how much you're moving outside the gym. Low step counts (under 5,000) are independently associated with worse cardiovascular outcomes, even in people who exercise regularly. Think of steps as your baseline activity on top of your structured training.",
                ranges: [
                    RangeRow(label: "Very active", range: "≥ 10,000 steps", color: HONTheme.positive),
                    RangeRow(label: "Active", range: "7,500 – 9,999", color: .primary),
                    RangeRow(label: "Lightly active", range: "5,000 – 7,499", color: HONTheme.warning),
                    RangeRow(label: "Sedentary", range: "< 5,000 steps", color: HONTheme.negative),
                ]
            )
        case .activeCalories:
            let v = health.activeCaloriesToday
            let val = v.map { "\(Int($0)) kcal" } ?? "No data"
            return (
                icon: "flame.fill",
                title: "Active Calories",
                subtitle: "Today's burn beyond resting",
                value: val,
                explanation: "Active calories are the energy you burn through movement — everything above what your body burns at rest. This includes your workouts, steps, and any other activity tracked by your Apple Watch. It's a real-time picture of your total daily energy expenditure.",
                ranges: [
                    RangeRow(label: "High output", range: "≥ 600 kcal", color: HONTheme.positive),
                    RangeRow(label: "Moderate", range: "300 – 599 kcal", color: .primary),
                    RangeRow(label: "Low", range: "< 300 kcal", color: HONTheme.warning),
                ]
            )
        case .hrv:
            let v = health.hrv
            let val = v.map { "\(Int($0)) ms" } ?? "No data"
            return (
                icon: "waveform.path.ecg",
                title: "Heart Rate Variability",
                subtitle: "Last night · SDNN",
                value: val,
                explanation: "HRV measures the variation in time between heartbeats. A higher number means your nervous system is recovering well — your body is ready to handle stress. A low number typically means you're under-recovered, even if you feel fine.",
                ranges: [
                    RangeRow(label: "Well recovered", range: "≥ 60 ms", color: HONTheme.positive),
                    RangeRow(label: "Moderate fatigue", range: "40 – 59 ms", color: HONTheme.warning),
                    RangeRow(label: "Under-recovered", range: "< 40 ms", color: HONTheme.negative),
                ]
            )
        case .restingHR:
            let v = health.restingHR
            let val = v.map { "\(Int($0)) bpm" } ?? "No data"
            return (
                icon: "heart.fill",
                title: "Resting Heart Rate",
                subtitle: "Most recent reading",
                value: val,
                explanation: "Your resting heart rate is how fast your heart beats when you're completely at rest. An elevated RHR — especially compared to your baseline — is one of the earliest signs of fatigue, illness, or stress. A lower resting HR generally reflects better cardiovascular fitness.",
                ranges: [
                    RangeRow(label: "Excellent", range: "< 55 bpm", color: HONTheme.positive),
                    RangeRow(label: "Normal", range: "55 – 69 bpm", color: .primary),
                    RangeRow(label: "Slightly elevated", range: "70 – 79 bpm", color: HONTheme.warning),
                    RangeRow(label: "Elevated — rest or deload", range: "≥ 80 bpm", color: HONTheme.negative),
                ]
            )
        case .sleep:
            let v = health.sleepHours
            let val: String
            if let v {
                let h = Int(v); let m = Int((v - Double(h)) * 60)
                val = m > 0 ? "\(h)h \(m)m" : "\(h)h"
            } else { val = "No data" }
            return (
                icon: "moon.zzz.fill",
                title: "Sleep Duration",
                subtitle: "Last night · time asleep",
                value: val,
                explanation: "Sleep is when your body actually rebuilds muscle. Protein synthesis, hormone release, and neural consolidation all happen during sleep — not during the workout. Consistently sleeping under 7 hours measurably reduces strength output and slows recovery between sessions.",
                ranges: [
                    RangeRow(label: "Optimal for recovery", range: "≥ 7h", color: HONTheme.positive),
                    RangeRow(label: "Moderate — manageable", range: "6 – 6h 59m", color: HONTheme.warning),
                    RangeRow(label: "Insufficient — expect slower recovery", range: "< 6h", color: HONTheme.negative),
                ]
            )
        }
    }

    private var thirtyDayHistory: [HealthDataPoint] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let history: [HealthDataPoint]
        switch metric {
        case .hrv:          history = health.hrvHistory
        case .restingHR:    history = health.restingHRHistory
        case .sleep:        history = health.sleepHistory
        case .steps:        history = health.stepsHistory
        case .vo2Max, .activeCalories: history = []
        }
        return history.filter { $0.date >= cutoff }
    }

    var body: some View {
        let c = config
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header
                HStack(spacing: 12) {
                    Image(systemName: c.icon)
                        .font(.title2)
                        .foregroundStyle(HONTheme.accent)
                        .frame(width: 44, height: 44)
                        .background(HONTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.title)
                            .font(.headline)
                        Text(c.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(c.value)
                        .font(.title3.bold())
                }

                Divider()

                // Explanation
                Text(c.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                // 30-day chart
                if !thirtyDayHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("30-Day Trend")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ThirtyDayMiniChart(dataPoints: thirtyDayHistory, color: HONTheme.accent)
                    }
                    .padding(14)
                    .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
                }

                // Ranges
                VStack(alignment: .leading, spacing: 0) {
                    Text("Ranges")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 10)

                    ForEach(Array(c.ranges.enumerated()), id: \.offset) { i, row in
                        HStack {
                            Circle()
                                .fill(row.color)
                                .frame(width: 8, height: 8)
                            Text(row.label)
                                .font(.subheadline)
                            Spacer()
                            Text(row.range)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                        if i < c.ranges.count - 1 { Divider() }
                    }
                }
                .padding(14)
                .background(AppTheme.cardBG,
                            in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(20)
        }
        .background(AppTheme.pageBG)
    }
}

private struct ThirtyDayMiniChart: View {
    let dataPoints: [HealthDataPoint]
    let color: Color

    var body: some View {
        let vals = dataPoints.map(\.value)
        let minV = vals.min() ?? 0
        let maxV = vals.max() ?? 1
        let range = maxV - minV

        HStack(alignment: .bottom, spacing: 3) {
            ForEach(dataPoints) { pt in
                let norm = range > 0 ? (pt.value - minV) / range : 0.5
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.3 + norm * 0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(4, norm * 56 + 4))
                }
            }
        }
        .frame(height: 60, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("30-day chart with \(dataPoints.count) data points")
    }
}

// MARK: - Today Circuit Card

private struct TodayCircuitCard: View {
    let circuit: CardioCircuit
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 14) {
                Image(systemName: circuit.format.icon)
                    .font(.title2)
                    .foregroundStyle(HONTheme.accent)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(circuit.displayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("\(circuit.format.rawValue) · \(circuit.durationMinutes) min · \(circuit.exercises.count) exercise\(circuit.exercises.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.caption.bold())
                    .foregroundStyle(HONTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(HONTheme.accent.opacity(0.12), in: Circle())
            }
            .padding(14)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

