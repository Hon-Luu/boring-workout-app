import SwiftUI

struct WorkoutTabView: View {
    @Environment(SeedStore.self) private var store
    @Environment(HealthKitService.self) private var health
    @Environment(HONHabitEngine.self) private var habitEngine
    @State private var showPicker = false
    @State private var showDiscardAlert = false
    @State private var showRoutines = false
    @State private var showStartOptions = false
    @State private var showRoutineSelector = false
    @State private var showEmptyWorkoutAlert = false

    // Celebration queue
    @State private var celebrationQueue: [CelebrationKind] = []
    @State private var showCelebration = false
    @State private var showShareSheet = false
    @State private var shareText = ""
    @AppStorage("lastShownStreakMilestone") private var lastShownStreakMilestone: Int = 0

    // First-workout celebration — pending flag survives crash between save and display
    @AppStorage("pendingFirstWorkoutCelebration") private var pendingFirstWorkoutCelebration = false
    @State private var showFirstWorkoutCelebration = false

    var body: some View {
        NavigationStack {
            Group {
                if store.activeWorkout != nil {
                    ActiveWorkoutView(showExercisePicker: $showPicker, onFinish: handleFinish)
                } else {
                    EmptyWorkoutView(
                        onStartCustom: { showStartOptions = true },
                        onManageRoutines: { showRoutines = true }
                    )
                }
            }
            .navigationTitle(store.activeWorkout == nil ? "Workout" : (store.activeWorkout?.name.isEmpty == false ? store.activeWorkout!.name : "Active Workout"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if store.activeWorkout != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Discard", role: .destructive) { showDiscardAlert = true }
                            .foregroundStyle(HONTheme.negative)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Routines") { showRoutines = true }
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { exercise, _ in store.addExercise(exercise) }
                    .environment(store)
            }
            .sheet(isPresented: $showRoutines) {
                TemplatesView()
                    .environment(store)
            }
            .sheet(isPresented: $showRoutineSelector) {
                RoutineSelectorView { routine, weekday in
                    store.startWorkout(fromRoutine: routine, weekday: weekday)
                }
                .environment(store)
            }
            .confirmationDialog("Start Workout", isPresented: $showStartOptions, titleVisibility: .visible) {
                Button("Pick Exercises") {
                    store.startWorkout()
                    showPicker = true
                }
                if !store.routines.isEmpty {
                    Button("Load a Routine") {
                        showRoutineSelector = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Start empty and pick exercises, or load all exercises from a saved routine.")
            }
            .sheet(isPresented: $showFirstWorkoutCelebration, onDismiss: {
                pendingFirstWorkoutCelebration = false
            }) {
                FirstWorkoutCelebrationSheet()
                    .environment(store)
            }
            .onAppear {
                // Recover pending celebration after crash/force-quit
                if pendingFirstWorkoutCelebration && !showFirstWorkoutCelebration {
                    showFirstWorkoutCelebration = true
                }
            }
            .alert("Discard Workout?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) { store.discardWorkout() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All logged sets will be lost.")
            }
            .alert("No Sets Logged", isPresented: $showEmptyWorkoutAlert) {
                Button("Discard", role: .destructive) { store.discardWorkout() }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("You haven't logged any sets yet. Discard this workout or keep going?")
            }
            // Celebration full-screen overlay
            .fullScreenCover(isPresented: $showCelebration) {
                if let kind = celebrationQueue.first {
                    CelebrationOverlay(kind: kind) {
                        celebrationQueue.removeFirst()
                        if celebrationQueue.isEmpty {
                            showCelebration = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                buildShareText()
                                showShareSheet = true
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                WorkoutShareSheet(text: shareText)
            }
            // Trigger celebrations and habit intelligence when a new workout is saved
            .onChange(of: store.workoutLog.first?.id) { _, newId in
                guard newId != nil, let entry = store.workoutLog.first else { return }
                guard Calendar.current.isDateInToday(entry.startedAt) else { return }
                buildCelebrationQueue(entry: entry)
                habitEngine.onSessionLogged(entry: entry, fullLog: store.workoutLog,
                                            cardioLog: store.cardioLog, generalLog: store.generalLog)
            }
        }
    }

    private func handleFinish(_ feel: FeelRating?) {
        let completedSets = store.activeWorkout?.exercises.flatMap(\.completedSets).count ?? 0
        guard completedSets > 0 else { showEmptyWorkoutAlert = true; return }
        store.finishWorkout(feel: feel)
        if let entry = store.workoutLog.first {
            let bw = store.userProfile.bodyWeightKg
            if let bw, entry.activeCalories == nil {
                store.updateWorkoutCalories(id: entry.id, calories: 5.0 * bw * (entry.duration / 3600.0))
            }
            health.saveWorkout(entry, bodyWeightKg: bw)
        }
        NotificationScheduler.scheduleReEngagement()
        if store.workoutLog.count == 1 {
            pendingFirstWorkoutCelebration = true
            showFirstWorkoutCelebration = true
        }
    }

    private func buildShareText() {
        guard let entry = store.workoutLog.first else { return }
        let sets    = entry.totalSets
        let vol     = Int(entry.totalVolume)
        let dur     = entry.formattedDuration
        let prs     = store.newPRs.prefix(2).map(\.exerciseName).joined(separator: ", ")
        var text    = "Logged \(sets) sets · \(vol) kg total volume · \(dur) — tracked with H.O.N."
        if !prs.isEmpty { text = "🏆 PR on \(prs) — " + text }
        shareText = text
    }

    private func buildCelebrationQueue(entry: WorkoutLogEntry) {
        guard entry.totalSets > 0 else { return }
        var queue: [CelebrationKind] = []

        let cal = Calendar.current

        // Detect comeback: previous session was 7+ days ago
        let isComeback: Bool = {
            guard store.workoutLog.count > 1 else { return false }
            let prev = store.workoutLog[1].startedAt
            return entry.startedAt.timeIntervalSince(prev) / 86_400 >= 7
        }()

        // 1. Streak milestone first — rarest, most HON; shown once per milestone
        let streak = store.currentStreak
        if [7, 30, 100].contains(streak) && streak != lastShownStreakMilestone {
            queue.append(.streakMilestone(days: streak))
            lastShownStreakMilestone = streak
        }

        // 2. Session complete — always shown
        // Monday-based week: find most recent Monday at midnight
        let todayStart    = cal.startOfDay(for: Date())
        let daysFromMon   = (cal.component(.weekday, from: todayStart) + 5) % 7
        let weekStart     = cal.date(byAdding: .day, value: -daysFromMon, to: todayStart)!

        let sessionDays: [Int] = Array(Set(
            store.workoutLog
                .filter { $0.startedAt >= weekStart }
                .map { e -> Int in
                    let wd = cal.component(.weekday, from: e.startedAt)
                    return (wd + 5) % 7  // Calendar Sun=1..Sat=7 → Mon=0..Sun=6
                }
        ))

        // Sparking dot = the actual weekday the workout was completed
        let completedWD       = cal.component(.weekday, from: entry.startedAt)
        let completedDayIndex = (completedWD + 5) % 7

        // B-008b: count exercises with 0 completed sets when ≥1 was planned
        let skippedCount = entry.exercises.filter { we in
            we.completedSets.isEmpty && !we.sets.isEmpty
        }.count

        let hasPR = !store.newPRs.isEmpty

        queue.append(.sessionComplete(
            duration: entry.formattedDuration,
            sets: entry.totalSets,
            volume: Int(entry.totalVolume),
            sessionDays: sessionDays,
            isComeback: isComeback,
            completedDayIndex: completedDayIndex,
            skippedCount: skippedCount,
            hasPR: hasPR
        ))

        // 3. PRs last — individual achievements (up to 3)
        for pr in store.newPRs.prefix(3) {
            queue.append(.personalRecord(
                exerciseName: pr.exerciseName,
                weight: pr.weight,
                reps: pr.reps
            ))
        }

        guard !queue.isEmpty else { return }
        celebrationQueue = queue
        // Slight delay so feel sheet can finish dismissing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            showCelebration = true
        }
    }
}

// MARK: - Empty State

private struct EmptyWorkoutView: View {
    @Environment(SeedStore.self) private var store
    @Environment(HealthKitService.self) private var health
    let onStartCustom: () -> Void
    let onManageRoutines: () -> Void
    @State private var showCircuits = false
    @State private var showRestOrInjury = false

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f
    }()

    var todayRoutines: [WorkoutTemplate] { store.todayRoutines() }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Today's routine cards (one per matching routine)
                if !todayRoutines.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today · \(Self.dayFormatter.string(from: Date()))")
                            .font(.caption.bold())
                            .foregroundStyle(HONTheme.accent)
                            .padding(.horizontal, 4)
                        ForEach(todayRoutines) { routine in
                            TodayRoutineCard(
                                routine: routine,
                                exercises: store.todayExercises(for: routine),
                                onStart: { store.startWorkout(fromRoutine: routine) }
                            )
                        }
                    }
                }

                // Empty workout button — secondary when routines exist
                Button(action: onStartCustom) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(store.routines.isEmpty ? "Start Workout" : "Start Empty Workout")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(store.routines.isEmpty ? HONTheme.accent : HONTheme.accent.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(store.routines.isEmpty ? HONTheme.textPrimary : HONTheme.accent)
                }

                // Rest / injury button
                Button(action: { showRestOrInjury = true }) {
                    HStack {
                        Image(systemName: "bandage.fill")
                        Text("Log Rest or Injury")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HONTheme.negative.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(HONTheme.negative)
                }
                .sheet(isPresented: $showRestOrInjury) {
                    RestOrInjurySheet()
                        .environment(store)
                }

                // Circuits button
                Button(action: { showCircuits = true }) {
                    HStack {
                        Image(systemName: "bolt.heart.fill")
                        Text("Start a Circuit")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HONTheme.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(HONTheme.warning)
                }
                .sheet(isPresented: $showCircuits) {
                    CardioCircuitsView()
                        .environment(store)
                        .environment(health)
                }

                // All routines
                if !store.routines.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("My Routines")
                                .font(.headline)
                            Spacer()
                            Button("Manage", action: onManageRoutines)
                                .font(.subheadline)
                                .foregroundStyle(HONTheme.accent)
                        }
                        ForEach(store.routines) { routine in
                            RoutinePreviewRow(
                                routine: routine,
                                onStart: { store.startWorkout(fromRoutine: routine) }
                            )
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No routines yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Create Routine", action: onManageRoutines)
                            .buttonStyle(.bordered)
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
        }
    }
}

// MARK: - Today card (for routines scheduled today)

private struct TodayRoutineCard: View {
    @Environment(SeedStore.self) private var store
    @Environment(HealthKitService.self) private var health
    let routine: WorkoutTemplate
    let exercises: [TemplateExercise]
    let onStart: () -> Void

    @State private var activeCircuit: CardioCircuit? = nil

    var preview: String {
        let names = exercises.prefix(3).map(\.exercise.name).joined(separator: " · ")
        return exercises.count > 3 ? names + " +\(exercises.count - 3) more" : names
    }

    private var attachedCircuits: [CardioCircuit] {
        routine.circuitIds.compactMap { id in store.cardioCircuits.first { $0.id == id } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(routine.name.isEmpty ? "Unnamed Routine" : routine.name)
                    .font(.title3.bold())
                Spacer()
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(HONTheme.accent)
            }
            if !preview.isEmpty {
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text("\(exercises.count) exercise\(exercises.count == 1 ? "" : "s") today")
                .font(.caption2.bold())
                .foregroundStyle(HONTheme.accent)


            Button(action: onStart) {
                Text("Start Workout")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(HONTheme.accent, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(HONTheme.textPrimary)
            }
        }
        .padding()
        .background(HONTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .fullScreenCover(item: $activeCircuit) { circuit in
            if circuit.format == .amrap {
                AMRAPSessionView(circuit: circuit, onDone: { activeCircuit = nil })
                    .environment(store)
                    .environment(health)
            } else {
                EMOMSessionView(circuit: circuit, onDone: { activeCircuit = nil })
                    .environment(store)
                    .environment(health)
            }
        }
    }
}

// MARK: - All-routines row with play button

private struct RoutinePreviewRow: View {
    let routine: WorkoutTemplate
    let onStart: () -> Void

    private static let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var scheduledDays: String {
        let days = Set(routine.exercises.flatMap(\.assignedDays)).sorted()
        return days.compactMap { Self.dayNames[safe: $0] }.joined(separator: " · ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(routine.name.isEmpty ? "Unnamed Routine" : routine.name)
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    if !scheduledDays.isEmpty {
                        Text(scheduledDays)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !routine.circuitIds.isEmpty {
                        Label("\(routine.circuitIds.count) circuit\(routine.circuitIds.count == 1 ? "" : "s")", systemImage: "bolt.heart.fill")
                            .font(.caption)
                            .foregroundStyle(HONTheme.warning)
                    }
                }
            }
            Spacer()
            Button(action: onStart) {
                Image(systemName: "play.fill")
                    .font(.subheadline)
                    .padding(8)
                    .background(HONTheme.accent.opacity(0.1), in: Circle())
                    .foregroundStyle(HONTheme.accent)
            }
        }
        .padding()
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Routine Selector (pick a routine + specific day)

struct RoutineSelectorView: View {
    @Environment(SeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onSelect: (WorkoutTemplate, Int?) -> Void  // routine, weekday (nil = all)

    private static let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.routines) { routine in
                    let days = scheduledDays(for: routine)
                    Section(routine.name.isEmpty ? "Unnamed Routine" : routine.name) {
                        ForEach(days, id: \.self) { weekday in
                            let exercises = routine.exercises.filter { $0.assignedDays.contains(weekday) }
                            Button {
                                onSelect(routine, weekday)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(Self.dayNames[safe: weekday] ?? "Day \(weekday)")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text(exercises.map(\.exercise.name).joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        if days.count > 1 {
                            Button {
                                onSelect(routine, nil)
                                dismiss()
                            } label: {
                                Label("Load All Days (\(routine.exercises.count) exercises)", systemImage: "list.bullet")
                                    .font(.subheadline)
                                    .foregroundStyle(HONTheme.accent)
                            }
                        }
                    }
                }
            }
            .listStyle(.grouped)
            .overlay {
                if store.routines.isEmpty {
                    ContentUnavailableView("No Routines", systemImage: "calendar.badge.plus")
                }
            }
            .navigationTitle("Load a Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func scheduledDays(for routine: WorkoutTemplate) -> [Int] {
        Array(Set(routine.exercises.flatMap(\.assignedDays))).sorted()
    }
}

// MARK: - Session Review Sheet

struct SessionReviewSheet: View {
    @Environment(SeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onDone: () -> Void

    private var workout: WorkoutLogEntry? { store.activeWorkout }

    private var totalCompletedSets: Int {
        guard let ex = workout?.exercises else { return 0 }
        return ex.flatMap(\.completedSets).count
    }

    private var totalVolume: Double {
        guard let ex = workout?.exercises else { return 0 }
        return ex.flatMap(\.completedSets).reduce(0.0) { acc, s in acc + s.weight * Double(s.reps) }
    }

    private var elapsed: String {
        guard let start = workout?.startedAt else { return "—" }
        let mins = Int(Date().timeIntervalSince(start) / 60)
        if mins < 60 { return "\(mins) min" }
        return "\(mins / 60)h \(mins % 60)m"
    }

    var body: some View {
        NavigationStack {
            List {
                statsSection
                exercisesSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss(); onDone() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var isVolumePR: Bool {
        guard totalVolume > 0 else { return false }
        let prevBest = store.workoutLog.prefix(50)
            .map(\.totalVolume)
            .max() ?? 0
        return totalVolume > prevBest
    }

    private var statsSection: some View {
        Section {
            HStack(spacing: 0) {
                statPill(value: elapsed, label: "Duration")
                Divider().frame(height: 36)
                statPill(value: "\(totalCompletedSets)", label: "Sets")
                Divider().frame(height: 36)
                VStack(spacing: 2) {
                    statPill(value: "\(Int(totalVolume)) kg", label: "Volume")
                    if isVolumePR {
                        VolumePRBadge()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var exercisesSection: some View {
        if let exercises = workout?.exercises, !exercises.isEmpty {
            Section("Exercises") {
                ForEach(exercises) { we in
                    SessionExerciseRow(we: we)
                }
            }
        }
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SessionExerciseRow: View {
    let we: WorkoutExercise

    private var completed: [SetRecord] { we.completedSets }

    private var bestLine: String? {
        let best = completed.max { ($0.weight * Double($0.reps)) < ($1.weight * Double($1.reps)) }
        guard let b = best else { return nil }
        return "\(b.weight.weightFormatted) kg × \(b.reps)"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(we.exercise.name)
                    .font(.subheadline)
                if let line = bestLine {
                    Text(line)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            let count = completed.count
            Text("\(count) set\(count == 1 ? "" : "s")")
                .font(.caption.bold())
                .foregroundStyle(count == 0 ? Color.secondary : HONTheme.accent)
        }
    }
}

// MARK: - Feel Selector Sheet

struct FeelSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onFinish: (FeelRating?) -> Void
    @State private var hasFinished = false

    var body: some View {
        VStack(spacing: 20) {
            Text("How did that feel?")
                .font(.title3.bold())
                .padding(.top, 28)

            HStack(spacing: 8) {
                ForEach(FeelRating.allCases, id: \.self) { feel in
                    Button {
                        hasFinished = true
                        onFinish(feel)
                        dismiss()
                    } label: {
                        VStack(spacing: 6) {
                            Text(feel.icon)
                                .font(.system(size: 28))
                            Text(feel.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            Button("Skip") {
                hasFinished = true
                onFinish(nil)
                dismiss()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
        .onDisappear {
            if !hasFinished { onFinish(nil) }
        }
    }
}

// MARK: - Rest or Injury Sheet

struct RestOrInjurySheet: View {
    @Environment(SeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: RestOrInjuryMode? = nil
    @State private var note: String = ""
    @State private var logged = false

    enum RestOrInjuryMode: String, CaseIterable {
        case rest    = "Rest Day"
        case injury  = "Injury / Pain"
        case illness = "Illness"
        case travel  = "Travel / Life"

        var icon: String {
            switch self {
            case .rest:    return "moon.zzz.fill"
            case .injury:  return "bandage.fill"
            case .illness: return "cross.case.fill"
            case .travel:  return "airplane.departure"
            }
        }
        var color: Color {
            switch self {
            case .rest:    return .blue
            case .injury:  return HONTheme.negative
            case .illness: return HONTheme.warning
            case .travel:  return HONTheme.accent
            }
        }
        var note: String {
            switch self {
            case .rest:    return "Planned rest day logged. The readiness score won't count this as a training gap."
            case .injury:  return "Injury logged. Rest — connective tissue adapts slower than muscle. Return gradually."
            case .illness: return "Illness logged. Your immune system is doing the work right now. This is rest, not a gap."
            case .travel:  return "Life happens. No penalty. Come back when you can."
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if logged {
                    VStack(spacing: 16) {
                        Image(systemName: selectedMode?.icon ?? "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(selectedMode?.color ?? HONTheme.positive)
                        Text("Logged")
                            .font(.title2.bold())
                        Text(selectedMode?.note ?? "Logged.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 32)
                    Spacer()
                    Button("Done") { dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HONTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(HONTheme.textPrimary)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                } else {
                    Text("What's keeping you out today?")
                        .font(.headline)
                        .padding(.top, 8)

                    VStack(spacing: 10) {
                        ForEach(RestOrInjuryMode.allCases, id: \.self) { mode in
                            Button {
                                selectedMode = mode
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 18))
                                        .foregroundStyle(mode.color)
                                        .frame(width: 28)
                                    Text(mode.rawValue)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    if selectedMode == mode {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(mode.color)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    selectedMode == mode ? mode.color.opacity(0.12) : Color.secondary.opacity(0.07),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(selectedMode == mode ? mode.color : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    Button {
                        guard let mode = selectedMode else { return }
                        if mode == .injury || mode == .illness {
                            store.logInjuryDay()
                        } else {
                            store.logRestDay()
                        }
                        withAnimation { logged = true }
                    } label: {
                        Text(selectedMode == nil ? "Select a reason above" : "Log \(selectedMode!.rawValue)")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedMode == nil ? Color.secondary.opacity(0.12) : HONTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(selectedMode == nil ? Color.secondary : HONTheme.textPrimary)
                            .fontWeight(.semibold)
                    }
                    .disabled(selectedMode == nil)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Log Absence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Workout Share Sheet

struct WorkoutShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let text: String

    var body: some View {
        VStack(spacing: 24) {
            Text("Share Your Workout")
                .font(.title3.bold())
                .padding(.top, 28)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 16) {
                ShareLink(item: text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(HONTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(HONTheme.textPrimary)
                        .fontWeight(.semibold)
                }

                Button("Skip") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
    }
}
