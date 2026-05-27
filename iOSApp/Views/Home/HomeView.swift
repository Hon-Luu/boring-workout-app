import SwiftUI
import Charts

struct HomeView: View {
    @Binding var selectedTab: Int
    @Environment(SeedStore.self) private var store
    @Environment(HealthKitService.self) private var health
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("progressNudgeDismissed") private var progressNudgeDismissed: Bool = false
    @AppStorage("bodyweightNudgeDismissed") private var bodyweightNudgeDismissed: Bool = false
    @AppStorage("emergentInsightLastDate") private var emergentInsightLastDate: String = ""
    @AppStorage("emergentInsightIndex") private var emergentInsightIndex: Int = 0
    @State private var activeCircuit: CardioCircuit? = nil
    @State private var circuitCelebration: CelebrationKind? = nil
    @State private var showCircuitCelebration = false
    @State private var showLogActivity = false
    @State private var weather = WeatherService()
    @State private var showMomentumDetail = false

    // MARK: - Computed helpers

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default:     return "Good evening"
        }
    }

    // MARK: - Weekly stats (Mon–Sun, matching the celebration screen)

    private var weekStart: Date {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let daysFromMon = (cal.component(.weekday, from: today) + 5) % 7
        return cal.date(byAdding: .day, value: -daysFromMon, to: today)!
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
        var seen = Set<UUID>()
        var circuits: [CardioCircuit] = []
        for c in store.cardioCircuits where c.assignedDays.contains(weekday) {
            if seen.insert(c.id).inserted { circuits.append(c) }
        }
        for (routine, _) in todayPlan {
            for id in routine.circuitIds {
                if let c = store.cardioCircuits.first(where: { $0.id == id }),
                   c.assignedDays.contains(weekday),
                   seen.insert(c.id).inserted {
                    circuits.append(c)
                }
            }
        }
        return circuits
    }

    private var todayCompletedCircuits: [CardioLogEntry] {
        store.cardioLog
            .filter { Calendar.current.isDateInToday($0.startedAt) }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private var isPM: Bool {
        Calendar.current.component(.hour, from: Date()) >= 12
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

    // MARK: - Return experience helpers

    private var daysSinceLastActivity: Int? {
        let allDates = store.workoutLog.map(\.startedAt)
            + store.cardioLog.map(\.startedAt)
            + store.generalLog.map(\.startedAt)
        guard let mostRecent = allDates.max() else { return nil }
        return Calendar.current.dateComponents([.day], from: mostRecent, to: Date()).day
    }

    private var totalSessionsAllTime: Int {
        store.workoutLog.count + store.cardioLog.count + store.generalLog.count
    }

    private var monthsTrainingCount: Int {
        guard let first = store.workoutLog.map(\.startedAt).min() else { return 1 }
        return max(1, Calendar.current.dateComponents([.month], from: first, to: Date()).month ?? 1)
    }

    private var lastSessionBriefSummary: String? {
        guard let last = store.workoutLog.sorted(by: { $0.startedAt > $1.startedAt }).first,
              let topEx = last.exercises.max(by: { $0.totalVolume < $1.totalVolume }),
              let topSet = topEx.completedSets.max(by: { $0.weight < $1.weight }),
              topSet.weight > 0 else { return nil }
        return "\(topEx.exercise.name) — \(Int(topSet.weight))kg × \(topSet.reps)"
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

                    // MARK: Health + Training Tiles — always first (F-02)
                    HomeHealthTilesGrid(
                        health: health,
                        weeklyMinutes: weeklyMinutes,
                        lastWeekMinutes: lastWeekMinutes,
                        monthMinutes: monthMinutes,
                        lastMonthMinutes: lastMonthMinutes
                    )

                    // MARK: Today's Plan — hoisted above fold when a plan exists and hasn't been done
                    if todayWorkouts.isEmpty && !todayPlan.isEmpty {
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

                    // MARK: Primary CTA — shown when no plan is scheduled today
                    if todayPlan.isEmpty || !todayWorkouts.isEmpty {
                        Button {
                            selectedTab = 1
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(HONTheme.accent.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "plus")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(HONTheme.accent)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Start Workout")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(.primary)
                                    Text(store.activeWorkout != nil ? "Resume in-progress workout" : "Log strength, cardio, or activity")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(HONTheme.accent.opacity(0.6))
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppTheme.cardBG)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(HONTheme.accent.opacity(0.3), lineWidth: 1.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start Workout")
                        .accessibilityHint("Opens the workout tab to begin logging")
                    }


                    // MARK: Zero state guidance — shown until first session
                    if store.isLoaded && store.workoutLog.isEmpty {
                        Text("Your first session starts the signal. Everything you see here — the score, the tiers, the coach — builds from what you log.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 4)
                    }

                    // MARK: Welcome Back — shown after 7+ days away (all session types)
                    if store.isLoaded, totalSessionsAllTime > 0,
                       let days = daysSinceLastActivity, days >= 4 {
                        WelcomeBackCard(
                            daysSince: days,
                            totalSessions: totalSessionsAllTime,
                            monthsTraining: monthsTrainingCount,
                            lastSessionSummary: lastSessionBriefSummary
                        ) { selectedTab = 1 }
                    }

                    // MARK: Loading skeleton
                    if !store.isLoaded {
                        HomeLoadingSkeleton()
                    }

                    // MARK: Connect Apple Health nudge — shown once, after first session, if not authorized
                    if store.isLoaded && !store.workoutLog.isEmpty && !health.isAuthorized {
                        AppleHealthConnectCard {
                            health.requestAndFetch()
                        }
                    }

                    // MARK: Building Your Baseline (sessions 1–10 only; Coach card removed per F-03)
                    if store.isLoaded && store.workoutLog.count >= 1 && store.workoutLog.count <= 10 {
                        BeginnerProgressCard(sessionCount: store.workoutLog.count)
                    }

                    // MARK: Emergent Insight Card
                    if store.isLoaded && store.workoutLog.count >= 5 {
                        EmergentInsightCard(
                            log: store.workoutLog,
                            analyticsResult: store.analyticsCache,
                            hrv: health.hrv,
                            sleepHours: store.sleepHoursForReadiness,
                            cardioLog: store.cardioLog,
                            vo2Max: health.vo2Max,
                            stepsToday: health.stepsToday,
                            restDays: store.restDays,
                            weightHistory: store.userProfile.weightHistory,
                            lastDate: $emergentInsightLastDate,
                            insightIndex: $emergentInsightIndex
                        )
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

                    // MARK: Today's Circuit Recap
                    if !todayCompletedCircuits.isEmpty {
                        sectionHeader("Today's Circuit\(todayCompletedCircuits.count > 1 ? "s" : "")")
                        ForEach(todayCompletedCircuits) { entry in
                            CircuitRecapCard(entry: entry)
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

                    // MARK: No-plan CTA (hidden when a circuit is scheduled for today)
                    if todayWorkouts.isEmpty && todayPlan.isEmpty && todayCircuits.isEmpty {
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

                    // MARK: Activity Heat Map (F-30) — show once enough data exists
                    if store.workoutLog.count + store.cardioLog.count >= 3 {
                        StreakHeatMapView(
                            workoutLog: store.workoutLog,
                            cardioLog: store.cardioLog,
                            generalLog: store.generalLog,
                            restDays: store.restDays
                        )
                    }

                    // MARK: Best Week Blueprint (F-10 — moved from Progress)
                    if store.workoutLog.count >= 8 {
                        BestWeekBlueprintCard(
                            workoutLog: store.workoutLog,
                            cardioLog: store.cardioLog,
                            generalLog: store.generalLog
                        )
                    }

                    // MARK: Progress tab nudge (after 5th workout, once)
                    if store.workoutLog.count >= 5 && !progressNudgeDismissed {
                        progressTabNudge
                    }

                    // MARK: Bodyweight prompt (after 1st workout, if bodyweight not set)
                    if store.workoutLog.count >= 1 && store.userProfile.bodyWeightKg == nil && !bodyweightNudgeDismissed {
                        bodyweightNudge
                    }

                    // MARK: Last Session(s) — most recent activity across all modalities
                    let recentStrength = store.workoutLog
                        .sorted { $0.startedAt > $1.startedAt }
                        .filter { !Calendar.current.isDateInToday($0.startedAt) }
                        .prefix(1)
                    let recentCardio = store.cardioLog
                        .sorted { $0.startedAt > $1.startedAt }
                        .filter { !Calendar.current.isDateInToday($0.startedAt) }
                        .prefix(1)

                    if !recentStrength.isEmpty || !recentCardio.isEmpty {
                        let showStrength = recentStrength.first
                        let showCardio = recentCardio.first

                        let bothRecent: Bool = {
                            guard let s = showStrength, let c = showCardio else { return false }
                            let diff = abs(s.startedAt.timeIntervalSince(c.startedAt))
                            return diff < 3 * 86400
                        }()

                        sectionHeader("Last Session")

                        let strengthFirst = (showStrength?.startedAt ?? .distantPast) >= (showCardio?.startedAt ?? .distantPast)

                        if strengthFirst {
                            if let s = showStrength {
                                WorkoutRecapCard(
                                    workout: s,
                                    history: store.workoutLog.filter { $0.startedAt < s.startedAt },
                                    subtitle: relativeDate(s.startedAt)
                                )
                            }
                            if bothRecent, let c = showCardio {
                                CircuitRecapCard(entry: c)
                            }
                        } else {
                            if let c = showCardio {
                                CircuitRecapCard(entry: c)
                            }
                            if bothRecent, let s = showStrength {
                                WorkoutRecapCard(
                                    workout: s,
                                    history: store.workoutLog.filter { $0.startedAt < s.startedAt },
                                    subtitle: relativeDate(s.startedAt)
                                )
                            }
                        }
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
            case .amrap: AMRAPSessionView(circuit: circuit, onDone: { activeCircuit = nil; scheduleCircuitCelebration() })
            case .emom:  EMOMSessionView(circuit: circuit,  onDone: { activeCircuit = nil; scheduleCircuitCelebration() })
            }
        }
        .fullScreenCover(isPresented: $showCircuitCelebration) {
            if let kind = circuitCelebration {
                CelebrationOverlay(kind: kind) { showCircuitCelebration = false }
            }
        }
        .sheet(isPresented: $showLogActivity) {
            LogGeneralActivitySheet()
                .environment(store)
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
        .onChange(of: health.stepsToday) { _, new in
            store.stepsTodayForReadiness = new
            store.refreshAnalytics()
        }
        .onChange(of: health.sleepHours) { _, new in
            store.sleepHoursForReadiness = new
            store.refreshAnalytics()
        }
        .onChange(of: health.restingHR) { _, new in
            store.restingHRForReadiness = new
            store.refreshAnalytics()
        }
        .onChange(of: health.hrv) { _, new in
            store.hrvForReadiness = new
            store.refreshAnalytics()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(userName.isEmpty ? "\(greeting) 👋" : "\(greeting), \(userName) 👋")
                    .font(.title2.bold())
                HStack(spacing: 8) {
                    Text(todayDateString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if weeklyActiveDays > 0 {
                        Button { showMomentumDetail = true } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                Text("\(weeklyActiveDays) this week")
                                    .font(.caption.bold())
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(HONTheme.positive)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(HONTheme.positive.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showMomentumDetail) {
                            MomentumDetailView()
                                .environment(store)
                        }
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

    private func scheduleCircuitCelebration() {
        guard let entry = store.cardioLog.first(where: { Calendar.current.isDateInToday($0.startedAt) }) else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let daysFromMon = (cal.component(.weekday, from: today) + 5) % 7
        let wkStart = cal.date(byAdding: .day, value: -daysFromMon, to: today)!

        // Build unique active days this week (strength + circuits)
        let strengthDays = store.workoutLog
            .filter { $0.startedAt >= wkStart }
            .map { (cal.component(.weekday, from: $0.startedAt) + 5) % 7 }
        let circuitDays = store.cardioLog
            .filter { $0.startedAt >= wkStart }
            .map { (cal.component(.weekday, from: $0.startedAt) + 5) % 7 }
        let sessionDays = Array(Set(strengthDays + circuitDays)).sorted()

        let todayIdx = (cal.component(.weekday, from: Date()) + 5) % 7
        let dur = entry.formattedDuration
        let sets = entry.completedRounds
        let vol  = entry.totalReps

        let isComeback: Bool = {
            let allPrev = (store.workoutLog.map(\.startedAt) + store.cardioLog.dropFirst().map(\.startedAt))
                .filter { !cal.isDateInToday($0) }
                .max()
            guard let prev = allPrev else { return false }
            return Date().timeIntervalSince(prev) / 86_400 >= 7
        }()

        circuitCelebration = .sessionComplete(
            duration: dur, sets: sets, volume: vol,
            sessionDays: sessionDays, isComeback: isComeback, completedDayIndex: todayIdx
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showCircuitCelebration = true
        }
    }

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
                    Text("Helps your readiness score understand your training rhythm")
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
                Label("Start \(routine.name.isEmpty ? "Workout" : routine.name)", systemImage: "play.fill")
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
    private var isMindBodyOverconfident: Bool {
        // CON-06: HRV low (< 65) but recent feel high (tired/brutal) → overconfident
        guard let hrv = health.hrv, hrv < 65 else { return false }
        let recentFeel = store.workoutLog.prefix(3).compactMap(\.feelRating)
        guard !recentFeel.isEmpty else { return false }
        let avgFeel = recentFeel.map { f -> Double in
            switch f { case .easy: return 0.0; case .strong: return 0.25; case .normal: return 0.5; case .tired: return 0.75; case .brutal: return 1.0 }
        }.reduce(0, +) / Double(recentFeel.count)
        return avgFeel >= 0.5
    }

    private var narrative: String {
        WorkoutNarrativeEngine.generate(workout: workout, history: history,
                                        isMindBodyOverconfident: isMindBodyOverconfident)
    }

    private var topLift: (name: String, weight: Double, reps: Int)? {
        workout.exercises
            .compactMap { we -> (String, Double, Int)? in
                guard let best = we.bestSet else { return nil }
                return (we.exercise.name, best.weight, best.reps)
            }
            .max(by: { $0.1 * Double($0.2) < $1.1 * Double($1.2) })
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
                        Text(feel.icon).font(.caption)
                        Text("Felt \(feel.rawValue)")
                            .font(.caption.bold()).foregroundStyle(.secondary)
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

            // Stats strip — always visible (F-06)
            HStack(spacing: 0) {
                StatPill(label: "Exercises", value: "\(workout.exercises.count)")
                Divider().frame(height: 30)
                StatPill(label: "Sets", value: "\(workout.totalSets)")
                Divider().frame(height: 30)
                StatPill(label: "Volume", value: "\(Int(workout.totalVolume)) kg")
                if let pct = volumeChangePct {
                    Divider().frame(height: 30)
                    StatPill(
                        label: "vs Prev",
                        value: "\(pct >= 0 ? "+" : "")\(Int(pct.rounded()))%",
                        valueColor: pct >= 0 ? AppTheme.positive : AppTheme.warning
                    )
                }
                if let hr = workout.averageHeartRate ?? avgHR {
                    Divider().frame(height: 30)
                    StatPill(label: "Avg HR", value: "\(Int(hr)) bpm", valueColor: HONTheme.negative)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

            // Top lift highlight (F-06)
            if let lift = topLift {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(HONTheme.accent)
                    Text("Top lift:")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(lift.name)
                        .font(.caption.bold())
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(lift.weight.weightFormatted) kg × \(lift.reps)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(HONTheme.positive)
                }
            }

            // Exercise list behind expand
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(isExpanded ? "Hide exercises" : "Show exercises")
                        .font(.caption).foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack(spacing: 0) {
                    if let cal = workout.activeCalories ?? activeCalories {
                        StatPill(label: "Cal Burned", value: "\(Int(cal)) kcal", valueColor: HONTheme.warning)
                        Divider().frame(height: 30)
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
        case "purple": return HONTheme.chartLavender
        case "green":  return HONTheme.positive
        case "blue":   return HONTheme.chartSlate
        case "yellow": return HONTheme.warning
        case "orange": return HONTheme.accent
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
                .stroke(HONTheme.chartLavender.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Home Health Tiles Grid (F-02)

private struct HomeTile: View {
    let icon: String
    let title: String
    let value: String
    var valueColor: Color = .primary
    var trend: String? = nil
    var trendPositive: Bool? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            if let t = trend {
                let tColor: Color = trendPositive == true ? HONTheme.positive : trendPositive == false ? HONTheme.negative : .secondary
                Text(t)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(tColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .frame(height: 56)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { onTap?() }
    }
}


private struct MinutesTile: View {
    let weeklyMinutes: Int
    let lastWeekMinutes: Int
    let monthMinutes: Int
    let lastMonthMinutes: Int

    private func deltaColor(_ delta: Int) -> Color {
        delta > 0 ? HONTheme.positive : delta < 0 ? HONTheme.negative : .secondary
    }
    private func deltaText(_ delta: Int, label: String) -> String {
        let sign = delta >= 0 ? "+" : ""
        return "\(label) \(sign)\(delta)m"
    }

    var body: some View {
        let wowDelta = weeklyMinutes - lastWeekMinutes
        let momDelta = monthMinutes - lastMonthMinutes
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Active Min")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(weeklyMinutes)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(weeklyMinutes > 0 ? Color.primary : Color.secondary)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                Text("WTD")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(deltaText(wowDelta, label: "WoW"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(deltaColor(wowDelta))
                    .lineLimit(1)
                Text(deltaText(momDelta, label: "MoM"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(deltaColor(momDelta))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .frame(height: 62)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct HomeHealthTilesGrid: View {
    let health: HealthKitService
    let weeklyMinutes: Int
    let lastWeekMinutes: Int
    let monthMinutes: Int
    let lastMonthMinutes: Int

    @State private var selectedHealthTile: HomeHealthTile?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private func hrvLabel(_ v: Double) -> (String, Color) {
        switch v {
        case 60...: return ("\(Int(v)) ms", HONTheme.positive)
        case 40..<60: return ("\(Int(v)) ms", HONTheme.warning)
        default: return ("\(Int(v)) ms", HONTheme.negative)
        }
    }
    private func rhrLabel(_ v: Double) -> (String, Color) {
        switch v {
        case ..<55: return ("\(Int(v)) bpm", HONTheme.positive)
        case 55..<70: return ("\(Int(v)) bpm", .primary)
        case 70..<80: return ("\(Int(v)) bpm", HONTheme.warning)
        default: return ("\(Int(v)) bpm", HONTheme.negative)
        }
    }
    private func sleepLabel(_ v: Double) -> (String, Color) {
        let h = Int(v); let m = Int((v - Double(h)) * 60)
        let label = m > 0 ? "\(h)h \(m)m" : "\(h)h"
        switch v {
        case 7...: return (label, HONTheme.positive)
        case 6..<7: return (label, HONTheme.warning)
        default: return (label, HONTheme.negative)
        }
    }
    private func stepsLabel(_ v: Int) -> (String, Color) {
        let label = v >= 1000 ? String(format: "%.1fk", Double(v) / 1000) : "\(v)"
        switch v {
        case 10000...: return (label, HONTheme.positive)
        case 7500..<10000: return (label, .primary)
        case 5000..<7500: return (label, HONTheme.warning)
        default: return (label, HONTheme.negative)
        }
    }
    private func calLabel(_ v: Double) -> (String, Color) {
        switch v {
        case 600...: return ("\(Int(v)) cal", HONTheme.positive)
        case 300..<600: return ("\(Int(v)) cal", .primary)
        default: return ("\(Int(v)) cal", HONTheme.warning)
        }
    }
    private func deltaTrend(_ delta: Int, unit: String, vsLabel: String) -> (String, Bool?) {
        if delta == 0 { return ("same as \(vsLabel)", nil) }
        let sign = delta > 0 ? "+" : ""
        return ("\(sign)\(delta) \(unit) vs \(vsLabel)", delta > 0)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            // Steps first — top-left position
            if let v = health.stepsToday {
                let (label, color) = stepsLabel(v)
                HomeTile(icon: "figure.walk", title: "Steps", value: label, valueColor: color,
                         onTap: { selectedHealthTile = .steps })
            }
            if let v = health.hrv {
                let (label, color) = hrvLabel(v)
                HomeTile(icon: "waveform.path.ecg", title: "HRV", value: label, valueColor: color,
                         onTap: { selectedHealthTile = .hrv })
            }
            if let v = health.restingHR {
                let (label, color) = rhrLabel(v)
                HomeTile(icon: "heart.fill", title: "Resting HR", value: label, valueColor: color,
                         onTap: { selectedHealthTile = .restingHR })
            }
            if let v = health.sleepHours {
                let (label, color) = sleepLabel(v)
                HomeTile(icon: "moon.zzz.fill", title: "Sleep", value: label, valueColor: color,
                         onTap: { selectedHealthTile = .sleep })
            }
            MinutesTile(
                weeklyMinutes: weeklyMinutes,
                lastWeekMinutes: lastWeekMinutes,
                monthMinutes: monthMinutes,
                lastMonthMinutes: lastMonthMinutes
            )
            if let v = health.activeCaloriesToday {
                let (label, color) = calLabel(v)
                HomeTile(icon: "bolt.fill", title: "Active Cal", value: label, valueColor: color,
                         onTap: { selectedHealthTile = .activeCalories })
            }
        }
        .sheet(item: $selectedHealthTile) { tile in
            HealthMetricDetailSheet(metric: tile, health: health)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
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
                    RangeRow(label: "Excellent", range: "42 – 49 ml/kg/min", color: HONTheme.positive.opacity(0.7)),
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

    private var wowComparison: (value: Double, unit: String, isPositive: Bool)? {
        let history: [HealthDataPoint]
        switch metric {
        case .hrv:       history = health.hrvHistory
        case .restingHR: history = health.restingHRHistory
        case .sleep:     history = health.sleepHistory
        case .steps:     history = health.stepsHistory
        case .vo2Max, .activeCalories: return nil
        }
        guard let latest = history.last else { return nil }
        let cutoff = latest.date.addingTimeInterval(-7 * 86400)
        guard let prev = history.filter({ $0.date <= cutoff }).last else { return nil }
        let delta = latest.value - prev.value
        let unit: String
        let positiveIsGood: Bool
        switch metric {
        case .hrv:       unit = " ms"; positiveIsGood = true
        case .restingHR: unit = " bpm"; positiveIsGood = false
        case .sleep:     unit = " h"; positiveIsGood = true
        case .steps:     unit = " steps"; positiveIsGood = true
        default:         unit = ""; positiveIsGood = true
        }
        return (delta, unit, positiveIsGood ? delta >= 0 : delta <= 0)
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

                // WoW comparison
                if let wow = wowComparison {
                    let sign = wow.value >= 0 ? "+" : ""
                    let formatted = metric == .sleep
                        ? String(format: "%@%.1f h WoW", sign, wow.value)
                        : String(format: "%@%.0f%@ WoW", sign, wow.value, wow.unit)
                    HStack(spacing: 8) {
                        Image(systemName: wow.isPositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12))
                            .foregroundStyle(wow.isPositive ? HONTheme.positive : HONTheme.negative)
                        Text(formatted)
                            .font(.subheadline.bold())
                            .foregroundStyle(wow.isPositive ? HONTheme.positive : HONTheme.negative)
                        Text("vs same day last week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 10))
                }

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

// MARK: - Circuit Recap Card

private struct CircuitRecapCard: View {
    let entry: CardioLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.circuitName)
                        .font(.subheadline.bold())
                    Text(entry.format.rawValue)
                        .font(.caption)
                        .foregroundStyle(entry.format.color)
                }
                Spacer()
                Text(entry.formattedDuration)
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(HONTheme.accent.opacity(0.1), in: Capsule())
                    .foregroundStyle(HONTheme.accent)
            }

            HStack(spacing: 20) {
                statPill(label: "Rounds", value: "\(entry.completedRounds)")
                statPill(label: "Reps", value: "\(entry.totalReps)")
                statPill(label: "Exercises", value: "\(entry.exercises.count)")
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded).bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Readiness Coach Card

private struct ReadinessCoachCard: View {
    let readiness: ReadinessState
    var sleepHours: Double?
    var restingHR: Double?
    var hrv: Double?

    private var recoveryScore: Int? {
        let sleepScore: Int? = sleepHours.map { h -> Int in
            if h >= 8 { return 40 }
            if h >= 7 { return 32 }
            if h >= 6 { return 20 }
            return 10
        }
        let hrScore: Int? = restingHR.map { r -> Int in
            if r < 55  { return 30 }
            if r < 65  { return 25 }
            if r < 75  { return 18 }
            return 8
        }
        let hrvScore: Int? = hrv.map { v -> Int in
            if v > 70  { return 30 }
            if v >= 50 { return 22 }
            if v >= 30 { return 14 }
            return 6
        }
        guard sleepScore != nil || hrScore != nil || hrvScore != nil else { return nil }
        return (sleepScore ?? 0) + (hrScore ?? 0) + (hrvScore ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HONTheme.accent)
                    .frame(width: 26, height: 26)
                    .background(HONTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                Text("Coach")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.4)
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 10) {
                    if let rec = recoveryScore {
                        HStack(spacing: 3) {
                            Text("Recovery")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("\(rec)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(rec >= 70 ? HONTheme.positive : rec >= 45 ? HONTheme.warning : HONTheme.negative)
                        }
                    } else {
                        Text("Recovery —")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("Readiness \(readiness.score)/99")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(readiness.confidence.color)
                }
            }
            Text(readiness.coachingNote)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
            if !readiness.hasSleepData {
                HStack(spacing: 4) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(recoveryScore == nil
                         ? "Based on training data only · Connect Apple Health for full readiness"
                         : "Connect Apple Health to include sleep in your score.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(HONTheme.accent.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Streak Heat Map (GitHub-style activity calendar, F-30)

private struct HeatMapDayKey: Identifiable {
    let id = UUID()
    let date: Date
}

private struct HeatMapDaySheet: View {
    let date: Date
    let workoutLog: [WorkoutLogEntry]
    let cardioLog: [CardioLogEntry]
    let generalLog: [GeneralActivityEntry]
    let isRestDay: Bool
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current

    private var workoutsOnDay: [WorkoutLogEntry] {
        workoutLog.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
    }
    private var cardioOnDay: [CardioLogEntry] {
        cardioLog.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
    }
    private var generalOnDay: [GeneralActivityEntry] {
        generalLog.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
    }

    private var isEmpty: Bool {
        workoutsOnDay.isEmpty && cardioOnDay.isEmpty && generalOnDay.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: isRestDay ? "moon.zzz.fill" : "circle.dashed")
                                .font(.title2)
                                .foregroundStyle(isRestDay ? HONTheme.warning : Color.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isRestDay ? "Planned rest" : "No activity logged")
                                    .font(.headline)
                                Text(isRestDay ? "Recovery day." : "A missed day or an untracked session.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        ForEach(workoutsOnDay, id: \.startedAt) { entry in
                            HStack(spacing: 12) {
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(HONTheme.accent)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.muscleGroups.isEmpty ? "Strength session" : entry.muscleGroups)
                                        .font(.subheadline.bold())
                                    HStack(spacing: 8) {
                                        Label(entry.formattedDuration, systemImage: "clock")
                                        Label("\(entry.totalSets) sets", systemImage: "list.number")
                                    }
                                    .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
                        }
                        ForEach(cardioOnDay, id: \.startedAt) { entry in
                            HStack(spacing: 12) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 15))
                                    .foregroundStyle(HONTheme.chartSage)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.circuitName)
                                        .font(.subheadline.bold())
                                    HStack(spacing: 8) {
                                        Label(entry.formattedDuration, systemImage: "clock")
                                        Label("\(entry.completedRounds) rounds", systemImage: "arrow.clockwise")
                                    }
                                    .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
                        }
                        ForEach(generalOnDay, id: \.startedAt) { entry in
                            HStack(spacing: 12) {
                                Image(systemName: entry.activityType.icon)
                                    .font(.system(size: 15))
                                    .foregroundStyle(HONTheme.chartSlate)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.activityType.rawValue)
                                        .font(.subheadline.bold())
                                    Label("\(entry.durationMinutes) min · \(entry.intensityLevel.rawValue)", systemImage: "clock")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.45), .medium])
        .presentationDragIndicator(.visible)
    }
}

private struct StreakHeatMapView: View {
    let workoutLog: [WorkoutLogEntry]
    let cardioLog: [CardioLogEntry]
    let generalLog: [GeneralActivityEntry]
    var restDays: [Date] = []

    @ScaledMetric(relativeTo: .caption2) private var cellSize: CGFloat = 9
    @State private var tappedDay: HeatMapDayKey?

    private let calendar = Calendar.current

    /// 35 days ending today, padded at the start to align the first real day to Monday.
    private var paddedDays: [Date?] {
        let today = calendar.startOfDay(for: Date())
        let last35: [Date] = (0..<35).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
        guard let first = last35.first else { return [] }
        let weekday = calendar.component(.weekday, from: first)  // 1=Sun…7=Sat
        let mondayOffset = (weekday + 5) % 7                      // Mon=0…Sun=6
        let padding: [Date?] = Array(repeating: nil, count: mondayOffset)
        return padding + last35.map { Optional($0) }
    }

    private func dateKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Dictionary keyed by "yyyy-MM-dd" mapping to total activity count across all modalities.
    private var activityCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for entry in workoutLog {
            counts[dateKey(calendar.startOfDay(for: entry.startedAt)), default: 0] += 1
        }
        for entry in cardioLog {
            counts[dateKey(calendar.startOfDay(for: entry.startedAt)), default: 0] += 1
        }
        for entry in generalLog {
            counts[dateKey(calendar.startOfDay(for: entry.startedAt)), default: 0] += 1
        }
        return counts
    }

    private var restDayKeys: Set<String> {
        Set(restDays.map { dateKey(calendar.startOfDay(for: $0)) })
    }

    private func cellColor(for count: Int, isRest: Bool) -> Color {
        if count > 0 {
            switch count {
            case 1:  return HONTheme.positive.opacity(0.55)
            case 2:  return HONTheme.positive.opacity(0.8)
            default: return HONTheme.positive
            }
        }
        if isRest { return HONTheme.warning.opacity(0.35) }
        return Color.secondary.opacity(0.12)
    }

    var body: some View {
        let padded = paddedDays
        let counts = activityCounts
        let rests = restDayKeys
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Activity Heatmap")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("Strength · cardio · general activity — past 5 weeks")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                Spacer()
                Text("Tap any day")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.4))
            }
            // Flexible columns — fill card width, fixed-height cells
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                spacing: 2
            ) {
                ForEach(Array(padded.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let key = dateKey(date)
                        let count = counts[key] ?? 0
                        let isRest = rests.contains(key)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cellColor(for: count, isRest: isRest))
                            .frame(maxWidth: .infinity)
                            .frame(height: cellSize)
                            .contentShape(Rectangle())
                            .onTapGesture { tappedDay = HeatMapDayKey(date: date) }
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: cellSize)
                    }
                }
            }
            // Day labels
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                spacing: 0
            ) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            HStack {
                Text("~10 wks ago")
                    .font(.system(size: 8)).foregroundStyle(.secondary.opacity(0.4))
                Spacer()
                if !restDays.isEmpty {
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(HONTheme.warning.opacity(0.35))
                            .frame(width: 8, height: 8)
                        Text("Rest")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    .padding(.trailing, 6)
                }
                Text("Today")
                    .font(.system(size: 8)).foregroundStyle(.secondary.opacity(0.4))
            }
            HStack(spacing: 4) {
                Text("Less")
                    .font(.system(size: 8)).foregroundStyle(.secondary.opacity(0.4))
                ForEach([0.20, 0.45, 0.65, 0.85, 1.0], id: \.self) { opacity in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(HONTheme.positive.opacity(opacity))
                        .frame(width: 8, height: 8)
                }
                Text("More")
                    .font(.system(size: 8)).foregroundStyle(.secondary.opacity(0.4))
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        .sheet(item: $tappedDay) { key in
            HeatMapDaySheet(
                date: key.date,
                workoutLog: workoutLog,
                cardioLog: cardioLog,
                generalLog: generalLog,
                isRestDay: restDayKeys.contains(dateKey(calendar.startOfDay(for: key.date)))
            )
        }
    }
}

// MARK: - Beginner Progress Card

private struct BeginnerProgressCard: View {
    let sessionCount: Int

    private let milestones: [(Int, String)] = [
        (3, "Tier unlocks"),
        (5, "Readiness activates"),
        (10, "Full analytics")
    ]

    private var isGraduated: Bool { sessionCount >= 10 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isGraduated {
                // Graduation state
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(HONTheme.positive.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(HONTheme.positive)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Foundation Built")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("10 sessions in. Full analytics are now unlocked.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
            } else {
                HStack {
                    Text("Building Your Baseline")
                        .font(.caption.bold())
                        .foregroundStyle(HONTheme.positive)
                    Spacer()
                    Text("\(sessionCount)/10")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.12))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(HONTheme.positive)
                            .frame(width: geo.size.width * min(Double(sessionCount) / 10.0, 1.0))
                    }
                }
                .frame(height: 4)

                // Milestone markers
                VStack(spacing: 4) {
                    ForEach(milestones, id: \.0) { count, label in
                        HStack(spacing: 6) {
                            Image(systemName: sessionCount >= count ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 11))
                                .foregroundStyle(sessionCount >= count ? HONTheme.positive : .secondary)
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(sessionCount >= count ? .primary : .secondary)
                            Spacer()
                            Text("Session \(count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isGraduated ? HONTheme.positive.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .animation(.spring(duration: 0.4), value: isGraduated)
    }
}

// MARK: - Welcome Back Card

private struct WelcomeBackCard: View {
    let daysSince: Int
    let totalSessions: Int
    let monthsTraining: Int
    let lastSessionSummary: String?
    let onStart: () -> Void

    private var gapLabel: String {
        switch daysSince {
        case 4...6:   return "Ready to pick up where you left off?"
        case 7...13:  return "Back after \(daysSince) days."
        case 14...29: return "Away for \(daysSince) days."
        case 30...89: return "Away for \(daysSince / 7) weeks."
        default:      return "Away for \(daysSince / 30)+ months."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(HONTheme.accent.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HONTheme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(gapLabel)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("The habit continues.")
                        .font(.caption)
                        .foregroundStyle(HONTheme.accent)
                }
                Spacer()
            }

            // Foundation stats
            HStack(spacing: 0) {
                foundationStat(value: "\(totalSessions)",
                               label: totalSessions == 1 ? "session logged" : "sessions logged")
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 1, height: 28)
                    .padding(.horizontal, 16)
                foundationStat(value: "\(monthsTraining)",
                               label: monthsTraining == 1 ? "month building" : "months building")
            }
            .padding(14)
            .background(HONTheme.surface, in: RoundedRectangle(cornerRadius: 12))

            // Last session context
            if let summary = lastSessionSummary {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("Last logged: \(summary)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // CTA
            Button(action: onStart) {
                Text("Start a session")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HONTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(HONTheme.accent, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(HONTheme.accent.opacity(0.35), lineWidth: 1)
        )
    }

    private func foundationStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(HONTheme.accent)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Apple Health Connect Card

private struct AppleHealthConnectCard: View {
    let onConnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(HONTheme.chartRose.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(HONTheme.chartRose)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Apple Health")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Unlock readiness scoring with sleep & HRV data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }

            Button(action: onConnect) {
                Text("Connect")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HONTheme.chartRose)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(HONTheme.chartRose.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(HONTheme.chartRose.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(HONTheme.chartRose.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Emergent Insight Card (S3)

private struct EmergentInsightCard: View {
    let log: [WorkoutLogEntry]
    let analyticsResult: AnalyticsResult
    var hrv: Double?
    var sleepHours: Double?
    let cardioLog: [CardioLogEntry]
    var vo2Max: Double?
    var stepsToday: Int?
    var restDays: [Date]
    var weightHistory: [WeightEntry]
    @Binding var lastDate: String
    @Binding var insightIndex: Int

    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var availableInsights: [EmergentInsight] {
        let all = EmergentInsightEngine.compute(
            log: log,
            analyticsResult: analyticsResult,
            hrv: hrv,
            sleepHours: sleepHours,
            cardioLog: cardioLog,
            vo2Max: vo2Max,
            stepsToday: stepsToday,
            restDays: restDays,
            weightHistory: weightHistory
        ).filter { $0.dataAvailable }
        return all.count >= 2 ? all : []
    }

    private var currentInsight: EmergentInsight? {
        guard !availableInsights.isEmpty else { return nil }
        let idx = insightIndex % availableInsights.count
        return availableInsights[idx]
    }

    var body: some View {
        Group {
            if let insight = currentInsight {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(HONTheme.accent)
                            .frame(width: 24, height: 24)
                            .background(HONTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        Text(insight.title)
                            .font(.system(size: 11, weight: .bold))
                            .kerning(0.3)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(insight.stateName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(insight.stateColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(insight.stateColor.opacity(0.12), in: Capsule())
                    }

                    Text(insight.dataPoint)
                        .font(.custom("CormorantGaramond-Light", size: 18))
                        .foregroundStyle(HONTheme.accent)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(insight.implication)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)

                    Text("Powered by \(insight.inputsLabel)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(insight.stateColor.opacity(0.2), lineWidth: 1))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Keep logging to unlock cross-domain insights.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .onAppear {
            let today = todayKey
            guard !availableInsights.isEmpty else { return }
            if lastDate != today {
                insightIndex = (insightIndex + 1) % availableInsights.count
                lastDate = today
            }
        }
    }
}

// MARK: - Best Week Blueprint Card (S4)

struct BestWeekBlueprintCard: View {
    let workoutLog: [WorkoutLogEntry]
    let cardioLog: [CardioLogEntry]
    let generalLog: [GeneralActivityEntry]

    private struct WeekData {
        let weekStart: Date
        let sessions: Int
        let volume: Double
        let avgFeel: Double
    }

    private func feelScore(_ r: FeelRating) -> Double {
        switch r {
        case .easy:   return 5
        case .strong: return 5
        case .normal: return 3
        case .tired:  return 2
        case .brutal: return 1
        }
    }

    private func feelEmoji(_ r: FeelRating) -> String {
        switch r {
        case .easy:   return "😊"
        case .strong: return "💪"
        case .normal: return "😐"
        case .tired:  return "😴"
        case .brutal: return "🔥"
        }
    }

    private var weeklyData: [WeekData] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let cutoff = cal.date(byAdding: .weekOfYear, value: -12, to: today) else { return [] }

        func weekStart(for date: Date) -> Date {
            let d = cal.startOfDay(for: date)
            let dayOfWeek = (cal.component(.weekday, from: d) + 5) % 7
            return cal.date(byAdding: .day, value: -dayOfWeek, to: d) ?? d
        }

        var sessionCounts: [Date: Int]      = [:]
        var volumeTotals:  [Date: Double]   = [:]
        var feelLists:     [Date: [Double]] = [:]

        for entry in workoutLog where entry.startedAt >= cutoff {
            let ws = weekStart(for: entry.startedAt)
            sessionCounts[ws, default: 0] += 1
            volumeTotals[ws, default: 0]  += entry.totalVolume
            if let feel = entry.feelRating {
                feelLists[ws, default: []].append(feelScore(feel))
            }
        }
        for entry in cardioLog where entry.startedAt >= cutoff {
            sessionCounts[weekStart(for: entry.startedAt), default: 0] += 1
        }
        for entry in generalLog where entry.startedAt >= cutoff {
            sessionCounts[weekStart(for: entry.startedAt), default: 0] += 1
        }

        return sessionCounts.keys.map { ws in
            let f = feelLists[ws] ?? []
            let avgFeel = f.isEmpty ? 3.0 : f.reduce(0, +) / Double(f.count)
            return WeekData(weekStart: ws, sessions: sessionCounts[ws]!, volume: volumeTotals[ws] ?? 0, avgFeel: avgFeel)
        }.filter { $0.sessions > 0 }
    }

    private var bestWeek: WeekData? {
        let weeks = weeklyData
        guard weeks.count >= 4 else { return nil }
        let maxSessions = Double(weeks.map(\.sessions).max() ?? 1)
        let maxVolume   = weeks.map(\.volume).max() ?? 1
        func composite(_ w: WeekData) -> Double {
            let normVol  = maxVolume  > 0 ? w.volume  / maxVolume  : 0
            let normSess = maxSessions > 0 ? Double(w.sessions) / maxSessions : 0
            let normFeel = w.avgFeel / 5.0
            return 0.5 * normVol + 0.3 * normSess + 0.2 * normFeel
        }
        return weeks.max(by: { composite($0) < composite($1) })
    }

    private func dateRange(_ weekStart: Date) -> String {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: weekStart)) – \(f.string(from: end))"
    }

    private func formattedVolume(_ v: Double) -> String {
        v >= 1000 ? String(format: "%.1fk kg", v / 1000) : "\(Int(v)) kg"
    }

    private func avgFeelEmoji(_ score: Double) -> String {
        switch score {
        case 4.5...: return "💪"
        case 3.5..<4.5: return "😊"
        case 2.5..<3.5: return "😐"
        case 1.5..<2.5: return "😴"
        default: return "🔥"
        }
    }

    var body: some View {
        if let week = bestWeek {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HONTheme.accent)
                        .frame(width: 24, height: 24)
                        .background(HONTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your Best Week")
                            .font(.system(size: 11, weight: .bold))
                            .kerning(0.3)
                            .foregroundStyle(.primary)
                        Text("Ranked by volume · sessions · feel")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(dateRange(week.weekStart))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("\(week.sessions) session\(week.sessions == 1 ? "" : "s") · \(formattedVolume(week.volume)) total · Avg feel: \(avgFeelEmoji(week.avgFeel))")
                    .font(.custom("CormorantGaramond-Light", size: 18))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Blueprint: replicate this week's pattern for peak results.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(HONTheme.accent.opacity(0.2), lineWidth: 1))
        }
    }
}

