import SwiftUI

// MARK: - Workout Plan Preview

struct GuidedWorkoutPlanView: View {
    let plan: GuidedWorkoutPlan
    let onStart: () -> Void
    @Environment(SeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var exercises: [GuidedExercise]
    @State private var showSwapper: (Bool, Int) = (false, 0)

    init(plan: GuidedWorkoutPlan, onStart: @escaping () -> Void) {
        self.plan = plan
        self.onStart = onStart
        _exercises = State(initialValue: plan.exercises)
    }

    var body: some View {
        NavigationStack {
            List {
                // Coach note
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "figure.mind.and.body")
                            .font(.title2)
                            .foregroundStyle(HONTheme.accent)
                        Text(plan.coachNote)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }

                // Exercises
                Section("Exercises") {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { i, ge in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(ge.exercise.name)
                                    .font(.body)
                                HStack(spacing: 6) {
                                    Text(ge.exercise.equipment.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("·")
                                        .foregroundStyle(.secondary)
                                    Text("\(ge.targetSets) sets × \(ge.targetReps) reps")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if ge.targetWeight > 0 {
                                        Text("· \(ge.targetWeight.weightFormatted) kg")
                                            .font(.caption)
                                            .foregroundStyle(HONTheme.accent)
                                    }
                                }
                            }
                            Spacer()
                            Button {
                                showSwapper = (true, i)
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Stats
                Section {
                    HStack(spacing: 0) {
                        StatPill(label: "Duration", value: "~\(plan.estimatedMinutes) min")
                            .frame(maxWidth: .infinity)
                        Divider().frame(height: 32)
                        StatPill(label: "Exercises", value: "\(exercises.count)")
                            .frame(maxWidth: .infinity)
                        Divider().frame(height: 32)
                        IntensityBadge(intensity: plan.intensity)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(plan.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start") {
                        dismiss()
                        onStart()
                    }
                    .fontWeight(.bold)
                }
            }
            .sheet(isPresented: Binding(
                get: { showSwapper.0 },
                set: { showSwapper.0 = $0 }
            )) {
                ExerciseSwapperView(
                    current: exercises[showSwapper.1].exercise,
                    onSelect: { replacement, _ in
                        let updated = exercises[showSwapper.1]
                        exercises[showSwapper.1] = GuidedExercise(
                            exercise: replacement,
                            targetSets: updated.targetSets,
                            targetReps: updated.targetReps,
                            targetWeight: store.lastPerformance(for: replacement).first?.weight ?? 0
                        )
                    }
                )
            }
        }
    }
}

// MARK: - Live Guided Session

struct GuidedWorkoutSessionView: View {
    @Environment(SeedStore.self) private var store
    @Environment(HealthKitService.self) private var health
    @Environment(\.dismiss) private var dismiss

    let plan: GuidedWorkoutPlan

    @State private var exercises: [GuidedExercise]
    @State private var currentExerciseIndex = 0
    @State private var currentSetIndex = 0
    @State private var weight: Double = 0
    @State private var reps: Int = 0
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var restSecondsLeft = 0
    @State private var restTimer: Timer? = nil
    @State private var showFinishAlert = false
    @AppStorage("restTimerSeconds") private var restTimerSeconds: Int = 90

    init(plan: GuidedWorkoutPlan) {
        self.plan = plan
        _exercises = State(initialValue: plan.exercises)
    }

    private var currentExercise: GuidedExercise? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }

    private var allComplete: Bool {
        exercises.allSatisfy(\.isComplete)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                ProgressBar(current: currentExerciseIndex, total: exercises.count)

                ScrollView {
                    VStack(spacing: 20) {
                        if let ex = currentExercise {
                            CurrentExerciseCard(
                                guidedExercise: ex,
                                currentSet: currentSetIndex + 1,
                                weight: $weight,
                                weightText: $weightText,
                                reps: $reps,
                                repsText: $repsText,
                                lastSets: store.lastPerformance(for: ex.exercise)
                            )

                            LogSetButton(action: logCurrentSet)

                            if restSecondsLeft > 0 {
                                RestCountdown(seconds: restSecondsLeft, onSkip: stopRest)
                            }
                        }

                        // Upcoming exercises
                        if currentExerciseIndex + 1 < exercises.count {
                            UpcomingList(
                                exercises: Array(exercises[(currentExerciseIndex + 1)...])
                            )
                        }
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(plan.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { showFinishAlert = true }
                        .fontWeight(.semibold)
                }
            }
            .alert("Finish Workout?", isPresented: $showFinishAlert) {
                Button("Finish & Save") { saveAndDismiss() }
                Button("Cancel", role: .cancel) {}
            }
        }
        .onAppear { loadTargetValues() }
        .onDisappear { stopRest() }
    }

    // MARK: - Actions

    private func loadTargetValues() {
        guard let ex = currentExercise else { return }
        let lastSets = store.lastPerformance(for: ex.exercise)
        let w = lastSets.isEmpty ? ex.targetWeight : (lastSets.first?.weight ?? ex.targetWeight)
        weight = w
        reps   = ex.targetReps
        weightText = w.weightFormatted
        repsText   = "\(ex.targetReps)"
    }

    private func logCurrentSet() {
        guard currentExerciseIndex < exercises.count else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let ge = exercises[currentExerciseIndex]
        var set = SetRecord(weight: weight, reps: reps,
                            targetWeight: ge.targetWeight > 0 ? ge.targetWeight : weight,
                            targetReps: ge.targetReps)
        set.isCompleted  = true
        set.completedAt  = Date()
        exercises[currentExerciseIndex].completedSets.append(set)

        let ex = exercises[currentExerciseIndex]

        if ex.completedSets.filter(\.isCompleted).count >= ex.targetSets {
            // Move to next exercise
            if currentExerciseIndex + 1 < exercises.count {
                currentExerciseIndex += 1
                currentSetIndex = 0
                loadTargetValues()
            }
        } else {
            currentSetIndex += 1
            if restTimerSeconds > 0 { startRest(seconds: restTimerSeconds) }
        }
    }

    private func startRest(seconds: Int) {
        restSecondsLeft = seconds
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if restSecondsLeft > 0 {
                restSecondsLeft -= 1
            } else {
                stopRest()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func stopRest() {
        restTimer?.invalidate()
        restTimer = nil
        restSecondsLeft = 0
    }

    private func saveAndDismiss() {
        store.startWorkout()
        for ge in exercises {
            store.addExercise(ge.exercise)
            if let wi = store.activeWorkout?.exercises.indices.last {
                store.activeWorkout!.exercises[wi].sets = ge.completedSets
            }
        }
        store.finishWorkout()
        if let entry = store.workoutLog.first { health.saveWorkout(entry) }
        dismiss()
    }
}

// MARK: - Sub-views

private struct ProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.secondary.opacity(0.15))
                Rectangle()
                    .fill(HONTheme.accent)
                    .frame(width: total > 0 ? geo.size.width * CGFloat(current) / CGFloat(total) : 0)
                    .animation(.spring(), value: current)
            }
        }
        .frame(height: 3)
    }
}

private struct CurrentExerciseCard: View {
    let guidedExercise: GuidedExercise
    let currentSet: Int
    @Binding var weight: Double
    @Binding var weightText: String
    @Binding var reps: Int
    @Binding var repsText: String
    let lastSets: [SetRecord]

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Exercise \(currentSet) of \(guidedExercise.targetSets)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(guidedExercise.exercise.name)
                    .font(.title2.bold())
                Text("\(guidedExercise.exercise.bodyRegion.rawValue) · \(guidedExercise.exercise.equipment.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Previous performance
            if let prev = lastSets.first {
                Text("Last time: \(prev.weight.weightFormatted) kg × \(prev.reps) reps")
                    .font(.caption)
                    .foregroundStyle(HONTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(HONTheme.accent.opacity(0.1), in: Capsule())
            }

            // Input row
            HStack(spacing: 24) {
                NumberStepper(
                    label: "Weight (kg)",
                    text: $weightText,
                    value: $weight,
                    step: 2.5,
                    minimum: 0
                )
                Text("×")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                NumberStepper(
                    label: "Reps",
                    text: $repsText,
                    value: Binding(get: { Double(reps) }, set: { reps = Int($0) }),
                    step: 1,
                    minimum: 1,
                    isInteger: true
                )
            }

            // V-003: cold-start weight placeholder when no history weight is available
            if guidedExercise.targetWeight == 0 && lastSets.isEmpty {
                Text("Start light")
                    .font(.caption)
                    .foregroundStyle(HONTheme.accent.opacity(0.8))
            }

            // Completed sets mini display
            if !guidedExercise.completedSets.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(guidedExercise.completedSets.enumerated()), id: \.offset) { i, s in
                        Text("\(s.weight.weightFormatted)×\(s.reps)")
                            .font(.caption.monospacedDigit())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(HONTheme.positive.opacity(0.12), in: Capsule())
                            .foregroundStyle(HONTheme.positive)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct NumberStepper: View {
    let label: String
    @Binding var text: String
    @Binding var value: Double
    let step: Double
    let minimum: Double
    var isInteger: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button {
                    value = max(minimum, value - step)
                    text = isInteger ? "\(Int(value))" : value.weightFormatted
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                TextField("0", text: $text)
                    .keyboardType(isInteger ? .numberPad : .decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.title.bold().monospacedDigit())
                    .frame(width: 64)
                    .onChange(of: text) { _, v in
                        if isInteger, let i = Int(v)    { value = Double(i) }
                        else if let d = Double(v)       { value = d }
                    }
                Button {
                    value += step
                    text = isInteger ? "\(Int(value))" : value.weightFormatted
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(HONTheme.accent)
                }
            }
        }
    }
}

private struct LogSetButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label("Log Set", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(HONTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(HONTheme.textPrimary)
        }
    }
}

private struct RestCountdown: View {
    let seconds: Int
    let onSkip: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rest")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(timeString)
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(seconds > 30 ? HONTheme.positive : seconds > 10 ? HONTheme.warning : HONTheme.negative)
            }
            Spacer()
            Button("Skip Rest", action: onSkip)
                .font(.subheadline)
                .foregroundStyle(HONTheme.accent)
        }
        .padding()
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
    }

    private var timeString: String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct UpcomingList: View {
    let exercises: [GuidedExercise]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Up Next")
                .font(.headline)
                .foregroundStyle(.secondary)
            ForEach(exercises) { ge in
                HStack {
                    Text(ge.exercise.name)
                        .font(.subheadline)
                    Spacer()
                    Text("\(ge.targetSets)×\(ge.targetReps)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Exercise Swapper

struct ExerciseSwapperView: View {
    let current: Exercise
    let showTemplateToggle: Bool
    let onSelect: (Exercise, Bool) -> Void

    @Environment(SeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEquipment: Equipment? = nil
    @State private var selectedRegion: BodyRegion? = nil
    @State private var swapForTemplate = false

    init(current: Exercise,
         showTemplateToggle: Bool = false,
         onSelect: @escaping (Exercise, Bool) -> Void) {
        self.current = current
        self.showTemplateToggle = showTemplateToggle
        self.onSelect = onSelect
    }

    private var alternatives: [Exercise] {
        store.exercises
            .filter { $0.id != current.id }
            .filter { selectedRegion  == nil || $0.bodyRegion  == selectedRegion }
            .filter { selectedEquipment == nil || $0.equipment == selectedEquipment }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Body region filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Any", isSelected: selectedRegion == nil) {
                            selectedRegion = nil
                        }
                        ForEach(BodyRegion.allCases, id: \.self) { region in
                            FilterChip(title: region.rawValue, isSelected: selectedRegion == region) {
                                selectedRegion = selectedRegion == region ? nil : region
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                Divider()
                // Equipment filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Any", isSelected: selectedEquipment == nil) {
                            selectedEquipment = nil
                        }
                        ForEach(Equipment.allCases, id: \.self) { eq in
                            FilterChip(title: eq.rawValue, isSelected: selectedEquipment == eq) {
                                selectedEquipment = selectedEquipment == eq ? nil : eq
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                Divider()
                if showTemplateToggle {
                    Toggle("Also update routine", isOn: $swapForTemplate)
                        .font(.subheadline)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                }
                Divider()
                List(alternatives) { exercise in
                    Button {
                        onSelect(exercise, swapForTemplate)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise.name)
                                    .foregroundStyle(.primary)
                                Text("\(exercise.bodyRegion.rawValue) · \(exercise.equipment.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if exercise.isCompound {
                                Text("Compound")
                                    .font(.caption)
                                    .foregroundStyle(HONTheme.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Swap Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - FilterChip (reused across pickers)

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? HONTheme.accent : Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(isSelected ? HONTheme.textPrimary : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
