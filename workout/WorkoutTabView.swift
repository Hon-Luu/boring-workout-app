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
    @State private var showFeelSelector = false
    @State private var showEmptyWorkoutAlert = false

    // Celebration queue
    @State private var celebrationQueue: [CelebrationKind] = []
    @State private var showCelebration = false
    @AppStorage("lastShownStreakMilestone") private var lastShownStreakMilestone: Int = 0

    var body: some View {
        NavigationStack {
            Group {
                if store.activeWorkout != nil {
                    ActiveWorkoutView(showExercisePicker: $showPicker)
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
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Finish") {
                            let completedSets = store.activeWorkout?.exercises.flatMap(\.completedSets).count ?? 0
                            if completedSets == 0 {
                                showEmptyWorkoutAlert = true
                            } else {
                                showFeelSelector = true
                            }
                        }
                        .fontWeight(.semibold)
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
            .sheet(isPresented: $showFeelSelector) {
                FeelSelectorSheet { feel in
                    store.finishWorkout(feel: feel)
                    if let entry = store.workoutLog.first {
                        let bw = store.userProfile.bodyWeightKg
                        if let bw, entry.activeCalories == nil {
                            store.updateWorkoutCalories(id: entry.id, calories: 5.0 * bw * (entry.duration / 3600.0))
                        }
                        health.saveWorkout(entry, bodyWeightKg: bw)
                    }
                    NotificationScheduler.scheduleReEngagement()
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
                        if celebrationQueue.isEmpty { showCelebration = false }
                    }
                }
            }
            // Trigger celebrations and habit intelligence when a new workout is saved
            .onChange(of: store.workoutLog.first?.id) { _, newId in
                guard newId != nil, let entry = store.workoutLog.first else { return }
                guard Calendar.current.isDateInToday(entry.startedAt) else { return }
                buildCelebrationQueue(entry: entry)
                habitEngine.onSessionLogged(entry: entry, fullLog: store.workoutLog)
            }
        }
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

        queue.append(.sessionComplete(
            duration: entry.formattedDuration,
            sets: entry.totalSets,
            volume: Int(entry.totalVolume),
            sessionDays: sessionDays,
            isComeback: isComeback,
            completedDayIndex: completedDayIndex
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

                // Empty workout button
                Button(action: onStartCustom) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(todayRoutines.isEmpty ? "Start Workout" : "Start Empty Workout")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(todayRoutines.isEmpty ? HONTheme.accent : HONTheme.accent.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(todayRoutines.isEmpty ? HONTheme.textPrimary : HONTheme.accent)
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

            // Attached circuits
            if !attachedCircuits.isEmpty {
                Divider().opacity(0.4)
                VStack(spacing: 6) {
                    ForEach(attachedCircuits) { circuit in
                        Button {
                            activeCircuit = circuit
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: circuit.format.icon)
                                    .font(.caption.bold())
                                Text(circuit.displayName)
                                    .font(.caption.bold())
                                Text("·")
                                    .foregroundStyle(.tertiary)
                                Text("\(circuit.durationMinutes) min")
                                    .font(.caption)
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                            }
                            .foregroundStyle(circuit.format.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(circuit.format.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

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

    var body: some View {
        VStack(spacing: 20) {
            Text("How did that feel?")
                .font(.title3.bold())
                .padding(.top, 28)

            HStack(spacing: 12) {
                ForEach(FeelRating.allCases, id: \.self) { feel in
                    Button {
                        onFinish(feel)
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            Text(feel.icon)
                                .font(.system(size: 34))
                            Text(feel.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Button("Skip") {
                onFinish(nil)
                dismiss()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(230)])
        .presentationDragIndicator(.visible)
    }
}
