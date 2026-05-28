import SwiftUI

struct SwapTarget: Identifiable {
    let id = UUID()
    let exerciseIndex: Int
    let exercise: Exercise
    let originalExerciseId: UUID
    let hasTemplate: Bool
}

struct ActiveWorkoutView: View {
    @Environment(SeedStore.self) private var store
    @Binding var showExercisePicker: Bool
    var onFinish: ((FeelRating?) -> Void)? = nil

    @State private var restSecondsRemaining: Int = 0
    @State private var restTimerExpired = false
    @State private var restTimer: Timer? = nil
    @AppStorage("restTimerSeconds") private var restDuration: Int = 90
    @State private var showPRBanner = false
    @State private var prExerciseName = ""
    @State private var showEmptyWorkoutAlert = false
    @State private var swapTarget: SwapTarget? = nil
    @State private var showWeightSuggestions = false
    @State private var acceptedSuggestionIds: Set<UUID> = []

    // Tracks which set index is "active" (next to do) per exercise
    @State private var activeSetMap: [Int: Int] = [:]
    // ID of exercise card to scroll to after superset auto-advance
    @State private var scrollToId: UUID? = nil
    @State private var showReadinessSheet = false

    private var hasAnyCompletedSets: Bool {
        store.activeWorkout?.exercises.contains { !$0.completedSets.isEmpty } ?? false
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Pre-session readiness — shown before first set is logged
                        if store.activeWorkout?.readinessBefore == nil && !hasAnyCompletedSets {
                            ReadinessPromptCard { rating in
                                store.setReadinessBefore(rating)
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                        }

                        let exercises = store.activeWorkout?.exercises ?? []
                        ForEach(Array(exercises.enumerated()), id: \.element.id) { exerciseIndex, we in
                            let prevGroup = exerciseIndex > 0 ? exercises[exerciseIndex - 1].supersetGroup : nil
                            let isContinuation = we.supersetGroup != nil && we.supersetGroup == prevGroup
                            let isLastInGroup: Bool = {
                                guard let g = we.supersetGroup else { return true }
                                return exercises.indices.filter { exercises[$0].supersetGroup == g }.last == exerciseIndex
                            }()
                            let groupPosition: Int? = we.supersetGroup.map { g in
                                exercises.prefix(exerciseIndex + 1).filter { $0.supersetGroup == g }.count
                            }

                            if isContinuation {
                                SupersetConnector(groupId: we.supersetGroup!)
                            } else {
                                Spacer().frame(height: 16)
                            }

                            ExerciseCard(
                                workoutExercise: we,
                                exerciseIndex: exerciseIndex,
                                supersetGroupId: we.supersetGroup,
                                supersetPosition: groupPosition,
                                canLinkWithNext: exerciseIndex + 1 < exercises.count,
                                history: store.exerciseHistory(for: we.exercise),
                                activeSetIndex: activeSetMap[exerciseIndex] ?? firstUncompletedSet(we),
                                onCompleteSet: { setIndex in
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    // Capture set data before completing for PR check
                                    let completingSet = we.sets[safe: setIndex]
                                    store.completeSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                                    // F-13: PR detection
                                    if let set = completingSet, set.weight > 0, set.reps > 0 {
                                        let exerciseID = we.exercise.id
                                        let histSets = store.exerciseHistoryCache[exerciseID]?.flatMap(\.sets) ?? []
                                        let prevBest = histSets.compactMap { s -> Double? in
                                            guard s.weight > 0 && s.reps > 0 else { return nil }
                                            return SetRecord.e1RM(weight: s.weight, reps: s.reps)
                                        }.max() ?? 0
                                        let thisE1RM = SetRecord.e1RM(weight: set.weight, reps: set.reps)
                                        if thisE1RM > prevBest && prevBest > 0 {
                                            prExerciseName = we.exercise.name
                                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                                            withAnimation(.spring(response: 0.4)) { showPRBanner = true }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                withAnimation(.easeOut(duration: 0.35)) { showPRBanner = false }
                                            }
                                        }
                                    }
                                    advanceAfterComplete(
                                        exerciseIndex: exerciseIndex,
                                        setIndex: setIndex,
                                        exercises: exercises,
                                        we: we,
                                        isLastInGroup: isLastInGroup,
                                        proxy: proxy
                                    )
                                },
                                onUncompleteSet: { setIndex in
                                    store.uncompleteSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                                    // Rewind active pointer if needed
                                    let current = activeSetMap[exerciseIndex] ?? 0
                                    if setIndex < current { activeSetMap[exerciseIndex] = setIndex }
                                },
                                onAddSet: { store.addSet(toExercise: exerciseIndex) },
                                onRemoveSet: { setIndex in
                                    store.removeSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                                },
                                onUpdateSet: { setIndex, weight, reps in
                                    store.updateSet(exerciseIndex: exerciseIndex, setIndex: setIndex, weight: weight, reps: reps)
                                },
                                onUpdateSetTarget: { setIndex, targetWeight, targetReps in
                                    store.updateSetTarget(exerciseIndex: exerciseIndex, setIndex: setIndex, targetWeight: targetWeight, targetReps: targetReps)
                                },
                                onUpdateDrop: { setIndex, dw, dr in
                                    store.updateSetDrop(exerciseIndex: exerciseIndex, setIndex: setIndex, dropWeight: dw, dropReps: dr)
                                },
                                onCompleteDropSet: { setIndex in
                                    store.completeDropSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                                    // Drop set done — if in a superset, now advance
                                    if we.supersetGroup != nil {
                                        advanceAfterComplete(
                                            exerciseIndex: exerciseIndex,
                                            setIndex: setIndex,
                                            exercises: store.activeWorkout?.exercises ?? exercises,
                                            we: we,
                                            isLastInGroup: isLastInGroup,
                                            proxy: proxy
                                        )
                                    }
                                },
                                onUncompleteDropSet: { setIndex in
                                    store.uncompleteDropSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                                },
                                onUpdateFailure: { setIndex, fail in
                                    store.updateSetFailure(exerciseIndex: exerciseIndex, setIndex: setIndex, toFailure: fail)
                                },
                                onRemoveExercise: { store.removeExercise(at: exerciseIndex) },
                                onSwap: {
                                    swapTarget = SwapTarget(
                                        exerciseIndex: exerciseIndex,
                                        exercise: we.exercise,
                                        originalExerciseId: we.exercise.id,
                                        hasTemplate: store.activeTemplateId != nil
                                    )
                                },
                                onLinkSuperset: { store.linkSuperset(at: exerciseIndex) },
                                onUnlinkSuperset: { store.unlinkSuperset(at: exerciseIndex) },
                                variants: store.quickSwapEquipment(for: we.exercise),
                                onQuickSwap: { equip in
                                    if let v = store.bestVariant(equipment: equip, matching: we.exercise) {
                                        store.swapExercise(at: exerciseIndex, with: v)
                                    }
                                },
                                onUpdateSetRPE: { setIndex, rpe in
                                    store.updateSetRPE(exerciseIndex: exerciseIndex, setIndex: setIndex, rpe: rpe)
                                }
                            )
                            .id(we.id)
                        }
                        Spacer().frame(height: 16)

                        Button { showExercisePicker = true } label: {
                            Label("Add Exercise", systemImage: "plus")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(HONTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(HONTheme.accent)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, (restSecondsRemaining > 0 || restTimerExpired) ? 200 : 120)
                    }
                    .padding(.top, 8)
                }

                VStack(spacing: 0) {
                    if restSecondsRemaining > 0 || restTimerExpired {
                        RestTimerBanner(
                            seconds: restSecondsRemaining,
                            duration: restDuration,
                            isExpired: restTimerExpired,
                            onSkip: { stopRestTimer() }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.4), value: restSecondsRemaining > 0 || restTimerExpired)
                    }
                    WorkoutFeelBar(onFinish: onFinish)
                }
            }
            .overlay(alignment: .top) {
                if showPRBanner {
                    HStack(spacing: 8) {
                        Text("🏆 New PR — \(prExerciseName)!")
                            .font(.subheadline.bold())
                            .foregroundStyle(HONTheme.textPrimary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(HONTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation(.easeOut(duration: 0.35)) { showPRBanner = false } }
                    .zIndex(10)
                }
            }
            .animation(.spring(response: 0.4), value: showPRBanner)
            .onChange(of: showPRBanner) { _, isShowing in
                if isShowing {
                    UIAccessibility.post(notification: .announcement,
                        argument: "New personal record on \(prExerciseName)")
                }
            }
            .onChange(of: scrollToId) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .top) }
                scrollToId = nil
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                    )
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HONTheme.accent)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onDisappear { stopRestTimer() }
        .onAppear {
            let suggestions = store.pendingWeightSuggestions
            if !suggestions.isEmpty {
                acceptedSuggestionIds = Set(suggestions.map(\.id))
                showWeightSuggestions = true
            }
            if store.activeWorkout?.readinessBefore == nil && !hasAnyCompletedSets {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showReadinessSheet = true
                }
            }
        }
        .sheet(isPresented: $showWeightSuggestions) {
            WeightSuggestionSheet(
                suggestions: store.pendingWeightSuggestions,
                acceptedIds: $acceptedSuggestionIds
            ) { accepted in
                for s in store.pendingWeightSuggestions where accepted.contains(s.id) {
                    store.applyWeightSuggestion(exerciseId: s.exerciseId, weightKg: s.suggestedWeightKg)
                }
                store.clearWeightSuggestions()
            }
        }
        .sheet(item: $swapTarget) { target in
            ExerciseSwapperView(
                current: target.exercise,
                showTemplateToggle: target.hasTemplate
            ) { exercise, swapForTemplate in
                store.swapExercise(at: target.exerciseIndex, with: exercise)
                if swapForTemplate {
                    store.swapExerciseInTemplate(oldExerciseId: target.originalExerciseId, with: exercise)
                }
            }
            .environment(store)
        }
        .sheet(isPresented: $showReadinessSheet) {
            ReadinessBeforeSheet { rating in
                store.setReadinessBefore(rating)
            }
        }
    }

    // MARK: - Auto-advance logic

    private func firstUncompletedSet(_ we: WorkoutExercise) -> Int {
        we.sets.firstIndex(where: { !$0.isCompleted }) ?? 0
    }

    private func advanceAfterComplete(
        exerciseIndex: Int,
        setIndex: Int,
        exercises: [WorkoutExercise],
        we: WorkoutExercise,
        isLastInGroup: Bool,
        proxy: ScrollViewProxy
    ) {
        let totalSets = exercises[exerciseIndex].sets.count
        // Advance this exercise's active set pointer
        if setIndex + 1 < totalSets {
            activeSetMap[exerciseIndex] = setIndex + 1
        }

        // If this set has a pending drop set, stay on this exercise until it's done.
        let liveSet = store.activeWorkout?.exercises[exerciseIndex].sets[safe: setIndex]
        if liveSet?.dropWeight != nil && liveSet?.isDropCompleted == false { return }

        if let group = we.supersetGroup {
            let groupIndices = exercises.indices.filter { exercises[$0].supersetGroup == group }
            if isLastInGroup {
                // Completed last exercise in round → rest, then jump back to first in group
                startRestTimer()
                if let firstIdx = groupIndices.first {
                    let targetId = exercises[firstIdx].id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        scrollToId = targetId
                    }
                }
            } else {
                // Jump to next exercise in superset (no rest)
                if let myPos = groupIndices.firstIndex(of: exerciseIndex),
                   myPos + 1 < groupIndices.count {
                    let nextIdx = groupIndices[myPos + 1]
                    let targetId = exercises[nextIdx].id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        scrollToId = targetId
                    }
                }
            }
        } else {
            startRestTimer()
        }
    }

    // MARK: - Rest Timer

    private func startRestTimer() {
        guard restDuration > 0 else { return }
        stopRestTimer()
        restTimerExpired = false
        restSecondsRemaining = restDuration
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if restSecondsRemaining > 0 {
                restSecondsRemaining -= 1
                switch restSecondsRemaining {
                case 10, 5:  UIImpactFeedbackGenerator(style: .light).impactOccurred()
                case 3, 2, 1: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                default: break
                }
            } else {
                restTimer?.invalidate()
                restTimer = nil
                restTimerExpired = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        restSecondsRemaining = 0
        restTimerExpired = false
    }
}

// MARK: - Exercise Card

private struct ExerciseCard: View {
    let workoutExercise: WorkoutExercise
    let exerciseIndex: Int
    let supersetGroupId: String?
    let supersetPosition: Int?
    let canLinkWithNext: Bool
    let history: [(date: Date, sets: [SetRecord])]
    let activeSetIndex: Int
    let onCompleteSet: (Int) -> Void
    let onUncompleteSet: (Int) -> Void
    let onAddSet: () -> Void
    let onRemoveSet: (Int) -> Void
    let onUpdateSet: (Int, Double, Int) -> Void
    let onUpdateSetTarget: (Int, Double, Int) -> Void
    let onUpdateDrop: (Int, Double?, Int?) -> Void
    let onCompleteDropSet: (Int) -> Void
    let onUncompleteDropSet: (Int) -> Void
    let onUpdateFailure: (Int, Bool) -> Void
    let onRemoveExercise: () -> Void
    let onSwap: () -> Void
    let onLinkSuperset: () -> Void
    let onUnlinkSuperset: () -> Void
    let variants: [Equipment]
    let onQuickSwap: (Equipment) -> Void
    var onUpdateSetRPE: ((Int, Double?) -> Void)? = nil

    @State private var showPlateCalc = false
    @State private var editingWeight: [Int: String] = [:]
    @State private var editingReps: [Int: String] = [:]
    @State private var editingTargetReps: [Int: String] = [:]
    @State private var editingDropWeight: [Int: String] = [:]
    @State private var editingDropReps: [Int: String] = [:]
    @State private var showDropPanel: Set<Int> = []
    @AppStorage("weightUnitIsKg") private var useKg = true

    // F-13: PR banner state is lifted to ActiveWorkoutView; onCompleteSet callback handles PR detection

    private static let lbsPerKg = 2.20462
    private static let kgPerLb  = 0.453592

    private var equipment: Equipment { workoutExercise.exercise.equipment }

    private var weightColumnLabel: String {
        useKg ? "KG" : "LBS"
    }

    private var equipmentBadge: String? {
        switch equipment {
        case .dumbbell: return "Enter total weight (both dumbbells combined, e.g. 2 × 20 kg = 40)"
        case .barbell:  return "min \(Int(Equipment.barbellBarKg)) kg  (empty bar included)"
        default:        return nil
        }
    }

    // stored = raw entered value; display = same (per-hand label tells the user the convention)
    private func toDisplay(_ storedKg: Double) -> Double { useKg ? storedKg : storedKg * Self.lbsPerKg }
    private func toKg(_ display: Double) -> Double       { useKg ? display  : display * Self.kgPerLb   }

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 10) {
            if let group = supersetGroupId, let pos = supersetPosition {
                Text("\(group)\(pos)")
                    .font(.caption.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(HONTheme.accent.opacity(0.15), in: Capsule())
                    .foregroundStyle(HONTheme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(workoutExercise.exercise.name)
                    .font(.headline)
                Text("\(workoutExercise.exercise.bodyRegion.rawValue) · \(workoutExercise.exercise.equipment.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showPlateCalc = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 11))
                    Text("Plates")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1), in: Capsule())
            }
            .accessibilityLabel("Open plate calculator for \(workoutExercise.exercise.name)")
            Menu {
                Button(action: onSwap) {
                    Label("Swap Exercise", systemImage: "arrow.left.arrow.right")
                }
                if supersetGroupId != nil {
                    Button(action: onUnlinkSuperset) {
                        Label("Remove from Superset", systemImage: "link.badge.minus")
                    }
                }
                Button(role: .destructive, action: onRemoveExercise) {
                    Label("Remove Exercise", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func makeSetRow(setIndex: Int, set: SetRecord) -> some View {
        let totalSets = workoutExercise.sets.count
        SetRow(
            record: set,
            setNumber: setIndex + 1,
            setIndex: setIndex,
            isActive: !set.isCompleted && setIndex == activeSetIndex,
            useKg: useKg,
            weightInput: Binding(
                get: { editingWeight[setIndex] ?? toDisplay(set.weight).weightFormatted },
                set: { editingWeight[setIndex] = $0 }
            ),
            repsInput: Binding(
                get: { editingReps[setIndex] ?? (set.reps > 0 ? "\(set.reps)" : "") },
                set: { editingReps[setIndex] = $0 }
            ),
            targetRepsInput: Binding(
                get: { editingTargetReps[setIndex] ?? (set.targetReps > 0 ? "\(set.targetReps)" : "") },
                set: { editingTargetReps[setIndex] = $0 }
            ),
            dropWeightInput: Binding(
                get: {
                    if let s = editingDropWeight[setIndex] { return s }
                    if let dw = set.dropWeight { return toDisplay(dw).weightFormatted }
                    return ""
                },
                set: { editingDropWeight[setIndex] = $0 }
            ),
            dropRepsInput: Binding(
                get: {
                    if let s = editingDropReps[setIndex] { return s }
                    if let dr = set.dropReps { return "\(dr)" }
                    return ""
                },
                set: { editingDropReps[setIndex] = $0 }
            ),
            showDropPanel: showDropPanel.contains(setIndex),
            onWeightChange: { raw in
                if let v = Double(raw), v > 0 { onUpdateSet(setIndex, toKg(v), set.reps) }
            },
            onWeightStep: { delta in
                let cur = Double(editingWeight[setIndex] ?? toDisplay(set.weight).weightFormatted) ?? toDisplay(set.weight)
                let next: Double
                if useKg {
                    next = max(0, cur + delta)
                } else {
                    // Round to nearest 0.5 lbs to prevent floating-point drift
                    next = max(0, (round((cur + delta) * 2) / 2))
                }
                editingWeight[setIndex] = next.weightFormatted
                onUpdateSet(setIndex, toKg(next), set.reps)
            },
            onRepsChange: { raw in
                if let v = Int(raw) { onUpdateSet(setIndex, set.weight, v) }
            },
            onTargetRepsChange: { raw in
                if let tr = Int(raw) { onUpdateSetTarget(setIndex, set.weight, tr) }
            },
            onComplete: { onCompleteSet(setIndex) },
            onUncomplete: { onUncompleteSet(setIndex) },
            onDelete: { onRemoveSet(setIndex) },
            onToggleDropPanel: {
                withAnimation(.spring(duration: 0.22)) {
                    if showDropPanel.contains(setIndex) {
                        showDropPanel.remove(setIndex)
                    } else {
                        showDropPanel.insert(setIndex)
                        if editingDropReps[setIndex] == nil && set.dropReps == nil {
                            let remaining = set.targetReps - set.reps
                            if remaining > 0 { editingDropReps[setIndex] = "\(remaining)" }
                        }
                    }
                }
            },
            onDropWeightChange: { raw in
                let dw = Double(raw).map { toKg($0) }
                let dr = editingDropReps[setIndex].flatMap(Int.init) ?? set.dropReps
                onUpdateDrop(setIndex, dw, dr)
            },
            onDropRepsChange: { raw in
                let dr = Int(raw)
                let dw = editingDropWeight[setIndex].flatMap(Double.init).map { toKg($0) } ?? set.dropWeight
                onUpdateDrop(setIndex, dw, dr)
            },
            onClearDrop: {
                editingDropWeight.removeValue(forKey: setIndex)
                editingDropReps.removeValue(forKey: setIndex)
                showDropPanel.remove(setIndex)
                onUpdateDrop(setIndex, nil, nil)
            },
            onCompleteDropSet: { onCompleteDropSet(setIndex) },
            onUncompleteDropSet: { onUncompleteDropSet(setIndex) },
            onToggleFailure: {
                onUpdateFailure(setIndex, !set.toFailure)
            },
            onCompleteAsFailed: {
                onUpdateSet(setIndex, set.weight, 0)
                onUpdateFailure(setIndex, true)
                onCompleteSet(setIndex)
            },
        )
        .swipeToDelete { onRemoveSet(setIndex) }
        .padding(.horizontal, 16)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            if !variants.isEmpty {
                EquipmentChipRow(
                    current: equipment,
                    variants: variants,
                    onSelect: onQuickSwap
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }

            Divider().padding(.horizontal, 16)

            if !history.isEmpty {
                ExerciseHistoryMatrix(history: history)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                Divider().padding(.horizontal, 16)
            }

            // Column headers
            HStack(spacing: 6) {
                Spacer().frame(width: 5)   // indicator strip
                Text("SET").frame(width: 22, alignment: .center)
                Button {
                    useKg.toggle()
                    editingWeight = [:]
                    editingDropWeight = [:]
                } label: {
                    HStack(spacing: 3) {
                        Text(weightColumnLabel)
                            .underline()
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 9, weight: .bold))
                    }
                    .frame(width: 98, alignment: .center)
                }
                .foregroundStyle(HONTheme.accent)
                Text("REPS  /  TARGET").frame(maxWidth: .infinity, alignment: .center)
                Spacer().frame(width: 32)
            }
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 2)

            if let badge = equipmentBadge {
                HStack(spacing: 4) {
                    Image(systemName: equipment == .dumbbell ? "dumbbell" : "scalemass")
                        .font(.system(size: 9))
                    Text(badge)
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(HONTheme.accent)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            }

            // Sets
            VStack(spacing: 0) {
                ForEach(Array(workoutExercise.sets.enumerated()), id: \.element.id) { setIndex, set in
                    makeSetRow(setIndex: setIndex, set: set)
                }
            }

            if !workoutExercise.sets.isEmpty && workoutExercise.sets.allSatisfy(\.isCompleted),
               let lastIdx = workoutExercise.sets.indices.last {
                Divider().padding(.horizontal, 16)
                RPERow(rpe: workoutExercise.sets[lastIdx].rpe) { newRPE in
                    onUpdateSetRPE?(lastIdx, newRPE)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            let completedSets = workoutExercise.sets.filter(\.isCompleted)
            if !completedSets.isEmpty {
                Divider().padding(.horizontal, 16)
                HStack {
                    Text("Total Volume")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text({
                        let vol = completedSets.reduce(0.0) { $0 + $1.effectiveVolume(equipment: equipment) }
                        let display = useKg ? vol : vol * Self.lbsPerKg
                        let fmt = display.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f"
                        return String(format: "\(fmt) \(useKg ? "kg" : "lbs")", display)
                    }())
                        .font(.caption.bold()).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Button(action: { withAnimation(.spring(duration: 0.3)) { onAddSet() } }) {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline).foregroundStyle(HONTheme.accent)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .accessibilityLabel("Add set to \(workoutExercise.exercise.name)")
            .padding(.top, 4)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .leading) {
            if supersetGroupId != nil {
                RoundedRectangle(cornerRadius: 3)
                    .fill(HONTheme.accent.opacity(0.7))
                    .frame(width: 4)
                    .padding(.vertical, 8)
                    .padding(.leading, 4)
            }
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal)
        .sheet(isPresented: $showPlateCalc) {
            NavigationStack {
                PlateCalculatorView(initialWeight: workoutExercise.sets.first?.targetWeight)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showPlateCalc = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Set Row

private struct SetRow: View {
    let record: SetRecord
    let setNumber: Int
    let setIndex: Int
    let isActive: Bool
    let useKg: Bool
    @Binding var weightInput: String
    @Binding var repsInput: String
    @Binding var targetRepsInput: String
    @Binding var dropWeightInput: String
    @Binding var dropRepsInput: String
    let showDropPanel: Bool
    let onWeightChange: (String) -> Void
    let onWeightStep: (Double) -> Void
    let onRepsChange: (String) -> Void
    let onTargetRepsChange: (String) -> Void
    let onComplete: () -> Void
    let onUncomplete: () -> Void
    let onDelete: () -> Void
    let onToggleDropPanel: () -> Void
    let onDropWeightChange: (String) -> Void
    let onDropRepsChange: (String) -> Void
    let onClearDrop: () -> Void
    let onCompleteDropSet: () -> Void
    let onUncompleteDropSet: () -> Void
    let onToggleFailure: () -> Void
    var onCompleteAsFailed: (() -> Void)? = nil

    @State private var showZeroRepsAlert = false

    private var accentColor: Color {
        record.isCompleted ? (record.repOutcome == .missed ? AppTheme.warning : AppTheme.positive) : isActive ? AppTheme.primary : .secondary
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main set row
            HStack(spacing: 6) {
                // Active indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? HONTheme.accent : Color.clear)
                    .frame(width: 3, height: 30)

                // Set number
                Text("\(setNumber)")
                    .font(.callout.bold())
                    .foregroundStyle(accentColor)
                    .frame(width: 22, alignment: .center)

                // Weight stepper
                VStack(spacing: 2) {
                    HStack(spacing: 0) {
                        StepButton(symbol: "minus", color: .secondary) { onWeightStep(-2.5) }
                        NumberField(text: $weightInput, placeholder: useKg ? "kg" : "lbs", onSubmit: onWeightChange)
                            .frame(width: 58)
                            .opacity(record.isCompleted ? 0.6 : 1)
                            .accessibilityLabel("Weight for set \(setIndex + 1)")
                        StepButton(symbol: "plus", color: HONTheme.accent) { onWeightStep(2.5) }
                    }
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    // Show auto-fill hint when weight came from last session
                    if !record.isCompleted && record.targetWeight > 0 {
                        Text("↑ last: \(record.targetWeight.weightFormatted)")
                            .font(.system(size: 9))
                            .foregroundStyle(HONTheme.accent.opacity(0.7))
                    }
                }

                // Reps / target — no step buttons so there's room to type
                RepsFractionField(
                    repsInput: $repsInput,
                    targetRepsInput: $targetRepsInput,
                    outcome: record.repOutcome,
                    isCompleted: record.isCompleted,
                    toFailure: record.toFailure,
                    onRepsChange: onRepsChange,
                    onTargetRepsChange: onTargetRepsChange,
                    onToggleFailure: onToggleFailure,
                    setIndex: setIndex
                )
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

                Spacer(minLength: 0)

                // Complete / unlog
                Button {
                    if record.isCompleted {
                        onUncomplete()
                    } else {
                        guard record.reps > 0 else {
                            showZeroRepsAlert = true
                            return
                        }
                        onComplete()
                    }
                } label: {
                    Image(systemName: record.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(record.isCompleted ? accentColor : isActive ? HONTheme.accent : .secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(record.isCompleted ? "Completed set \(setIndex + 1)" : "Complete set \(setIndex + 1)")
                .accessibilityHint(record.isCompleted ? "Double-tap to mark as incomplete" : "Double-tap to mark as complete")
                .alert("No Reps Entered", isPresented: $showZeroRepsAlert) {
                    Button("Enter Reps", role: .cancel) {}
                    if onCompleteAsFailed != nil {
                        Button("Log as Failed Set") { onCompleteAsFailed?() }
                    }
                } message: {
                    Text("Enter reps, or log this as a failed set if you couldn't complete a single rep.")
                }
                .contextMenu {
                    if record.isCompleted {
                        Button {
                            onToggleDropPanel()
                        } label: {
                            Label(showDropPanel || record.dropWeight != nil ? "Hide Drop Weight" : "Add Drop Weight",
                                  systemImage: "arrow.down.circle")
                        }
                    } else {
                        Button("Delete Set", role: .destructive, action: onDelete)
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .setCompletionFlash(isCompleted: record.isCompleted)

            // Drop-set panel
            if showDropPanel || record.dropWeight != nil {
                Divider().padding(.leading, 30).opacity(0.5)
                DropSetPanel(
                    useKg: useKg,
                    mainWeight: record.weight,
                    dropWeightInput: $dropWeightInput,
                    dropRepsInput: $dropRepsInput,
                    remainingReps: max(0, record.targetReps - record.reps),
                    hasData: record.dropWeight != nil,
                    isCompleted: record.isDropCompleted,
                    onDropWeightChange: onDropWeightChange,
                    onDropRepsChange: onDropRepsChange,
                    onClear: onClearDrop,
                    onComplete: onCompleteDropSet,
                    onUncomplete: onUncompleteDropSet
                )
                .padding(.leading, 30)
                .padding(.vertical, 8)
            }

            // "Finish with lighter weight" nudge when set is completed but missed target
            if record.isCompleted && record.repOutcome == .missed && record.dropWeight == nil && !showDropPanel {
                Button(action: onToggleDropPanel) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add Drop Set")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(HONTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(HONTheme.warning, in: Capsule())
                    .padding(.leading, 30)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            record.isCompleted
                ? (record.repOutcome == .missed ? HONTheme.warning.opacity(0.06) : HONTheme.positive.opacity(0.06))
                : isActive ? HONTheme.accent.opacity(0.04) : Color.clear
        )
        .animation(.easeInOut(duration: 0.2), value: record.isCompleted)
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .animation(.spring(duration: 0.22), value: showDropPanel)
    }
}

// MARK: - Step Button

private struct StepButton: View {
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 30, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Drop Set Panel

private struct DropSetPanel: View {
    let useKg: Bool
    let mainWeight: Double
    @Binding var dropWeightInput: String
    @Binding var dropRepsInput: String
    let remainingReps: Int
    let hasData: Bool
    let isCompleted: Bool
    let onDropWeightChange: (String) -> Void
    let onDropRepsChange: (String) -> Void
    let onClear: () -> Void
    let onComplete: () -> Void
    let onUncomplete: () -> Void

    private var dropWeightExceedsMain: Bool {
        guard let dw = Double(dropWeightInput), dw > 0, mainWeight > 0 else { return false }
        return dw >= mainWeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 11))
                    .foregroundStyle(isCompleted ? HONTheme.positive : HONTheme.warning)

                if remainingReps > 0 && !isCompleted {
                    Text("\(remainingReps) left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(HONTheme.warning.opacity(0.85))
                }

                NumberField(text: $dropWeightInput, placeholder: useKg ? "kg" : "lbs", onSubmit: onDropWeightChange)
                    .frame(width: 62)
                    .opacity(isCompleted ? 0.6 : 1)

                Text("×").font(.caption).foregroundStyle(.secondary)

                NumberField(text: $dropRepsInput, placeholder: "reps", isInteger: true, onSubmit: onDropRepsChange)
                    .frame(width: 44)
                    .opacity(isCompleted ? 0.6 : 1)

                Spacer()

                if hasData && !isCompleted {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary).font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                    )
                    isCompleted ? onUncomplete() : onComplete()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isCompleted ? HONTheme.positive : .secondary)
                }
                .disabled(!hasData)
                .opacity(hasData ? 1 : 0.3)
            }

            if dropWeightExceedsMain && !isCompleted {
                Text("Drop weight should be less than the main set weight")
                    .font(.system(size: 10))
                    .foregroundStyle(HONTheme.negative)
            }
        }
    }
}

// MARK: - Weight Suggestion Sheet

private struct WeightSuggestionSheet: View {
    let suggestions: [WeightSuggestion]
    @Binding var acceptedIds: Set<UUID>
    let onApply: (Set<UUID>) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnitIsKg") private var useKg = true

    private var acceptedCount: Int { suggestions.filter { acceptedIds.contains($0.id) }.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header context strip
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(HONTheme.positive)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Coach recommends progressing \(suggestions.count) lift\(suggestions.count == 1 ? "" : "s")")
                            .font(.system(size: 13, weight: .semibold))
                        Text("You hit your targets last session. Accept or skip each change.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(HONTheme.positive.opacity(0.08))

                List {
                    ForEach(suggestions) { suggestion in
                        SuggestionRow(
                            suggestion: suggestion,
                            isAccepted: acceptedIds.contains(suggestion.id),
                            useKg: useKg
                        ) {
                            if acceptedIds.contains(suggestion.id) {
                                acceptedIds.remove(suggestion.id)
                            } else {
                                acceptedIds.insert(suggestion.id)
                            }
                        }
                    }
                }
                .listStyle(.plain)

                // Footer buttons
                VStack(spacing: 10) {
                    Button {
                        onApply(acceptedIds)
                        dismiss()
                    } label: {
                        Text(acceptedCount == 0 ? "Keep Current Weights" : "Apply \(acceptedCount) Change\(acceptedCount == 1 ? "" : "s")")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(acceptedCount > 0 ? HONTheme.positive : Color.secondary.opacity(0.15),
                                        in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(acceptedCount > 0 ? HONTheme.textPrimary : .primary)
                    }

                    if acceptedCount > 0 {
                        Button {
                            acceptedIds = []
                        } label: {
                            Text("Deselect All")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Weight Progression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip All") {
                        store_clearAndDismiss()
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        acceptedIds = Set(suggestions.map(\.id))
                    } label: {
                        Text("Select All")
                    }
                    .disabled(acceptedCount == suggestions.count)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func store_clearAndDismiss() {
        // onApply with empty set = apply nothing; store clears suggestions
        onApply([])
    }
}

private struct SuggestionRow: View {
    let suggestion: WeightSuggestion
    let isAccepted: Bool
    let useKg: Bool
    let onToggle: () -> Void

    private func display(_ kg: Double) -> String {
        let val = useKg ? kg : kg * 2.20462
        let unit = useKg ? "kg" : "lbs"
        let fmt = val.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(val))" : String(format: "%.1f", val)
        return "\(fmt) \(unit)"
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                Image(systemName: isAccepted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isAccepted ? HONTheme.positive : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.exerciseName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(suggestion.reason)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(display(suggestion.currentWeightKg))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .strikethrough(isAccepted)
                        if isAccepted {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundStyle(HONTheme.positive)
                            Text(display(suggestion.suggestedWeightKg))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(HONTheme.positive)
                        }
                    }
                    Text(suggestion.isCompound ? "+\(useKg ? "2.5" : "5.5") \(useKg ? "kg" : "lbs")" : "+\(useKg ? "1.25" : "2.75") \(useKg ? "kg" : "lbs")")
                        .font(.system(size: 10))
                        .foregroundStyle(isAccepted ? HONTheme.positive.opacity(0.8) : Color.secondary.opacity(0.5))
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - RPE Row (B-006: word-based chips)

private struct RPERow: View {
    let rpe: Double?
    let onUpdate: (Double?) -> Void

    @State private var showRPEInfo = false

    // B-006: word chips mapping to internal numeric values
    private struct RPEChip {
        let label: String
        let value: Double
        var color: Color
    }

    private let chips: [RPEChip] = [
        RPEChip(label: "Easy",      value: 6.5,  color: HONTheme.accent),
        RPEChip(label: "Hard",      value: 8.0,  color: HONTheme.positive),
        RPEChip(label: "Very Hard", value: 9.0,  color: HONTheme.warning),
        RPEChip(label: "Max",       value: 10.0, color: HONTheme.negative),
    ]

    /// Returns the closest word label for any numeric RPE value (e.g. old stored values)
    private func closestChip(for val: Double) -> RPEChip? {
        chips.min(by: { abs($0.value - val) < abs($1.value - val) })
    }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                Text("RPE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Button {
                    showRPEInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .frame(width: 46, alignment: .leading)
            .sheet(isPresented: $showRPEInfo) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("RPE — Rate of Perceived Exertion")
                        .font(.headline)
                    Text("How hard did the set feel?\n\nEasy (6.5) — comfortable, could keep going.\nHard (8.0) — challenging, 2 reps left.\nVery Hard (9.0) — near limit, 1 rep left.\nMax (10.0) — nothing left in the tank.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(24)
                .presentationDetents([.medium])
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // Clear button
                    Button {
                        onUpdate(nil)
                    } label: {
                        Text("—")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(rpe == nil ? HONTheme.textPrimary : .secondary)
                            .padding(.horizontal, 8).padding(.vertical, 8)
                            .background(rpe == nil ? Color.secondary : Color.secondary.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)

                    ForEach(chips, id: \.value) { chip in
                        // A chip is "selected" when the stored RPE maps closest to this chip
                        let selected: Bool = {
                            guard let r = rpe else { return false }
                            return closestChip(for: r)?.value == chip.value
                        }()
                        Button {
                            onUpdate(selected ? nil : chip.value)
                        } label: {
                            Text(chip.label)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(selected ? HONTheme.textPrimary : chip.color)
                                .padding(.horizontal, 8).padding(.vertical, 8)
                                .background(selected ? chip.color : chip.color.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Reps Fraction Field

private struct RepsFractionField: View {
    @Binding var repsInput: String
    @Binding var targetRepsInput: String
    let outcome: SetRecord.RepOutcome
    let isCompleted: Bool
    let toFailure: Bool
    let onRepsChange: (String) -> Void
    let onTargetRepsChange: (String) -> Void
    let onToggleFailure: () -> Void
    var setIndex: Int = 0

    private var completedColor: Color {
        switch outcome {
        case .hit:      return HONTheme.positive
        case .exceeded: return HONTheme.accent
        case .missed:   return HONTheme.warning
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            // Actual reps
            NumberField(text: $repsInput, placeholder: "—", isInteger: true, onSubmit: onRepsChange)
                .frame(width: 48)
                .disabled(isCompleted)
                .foregroundStyle(isCompleted ? completedColor : .primary)
                .accessibilityLabel("Reps for set \(setIndex + 1)")

            Text("/").font(.caption).foregroundStyle(.tertiary)

            // Target: either a number field or "F" pill
            if toFailure {
                Button(action: onToggleFailure) {
                    Text("∞")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(HONTheme.textPrimary)
                        .padding(.horizontal, 5).padding(.vertical, 3)
                        .background(HONTheme.negative, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .disabled(isCompleted)
            } else {
                NumberField(text: $targetRepsInput, placeholder: "—", isInteger: true, onSubmit: onTargetRepsChange)
                    .frame(width: 48)
                    .disabled(isCompleted)
                    .foregroundStyle(.secondary)
            }

            // Failure toggle button (only when not yet completed)
            if !isCompleted {
                Button(action: onToggleFailure) {
                    Image(systemName: toFailure ? "xmark.circle.fill" : "infinity")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(toFailure ? HONTheme.negative : Color.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .frame(width: 14)
            } else {
                // Outcome indicator
                switch outcome {
                case .exceeded: Text("↑").font(.caption.bold()).foregroundStyle(completedColor).frame(width: 14)
                case .missed:   Text("↓").font(.caption.bold()).foregroundStyle(completedColor).frame(width: 14)
                default:        Spacer().frame(width: 14)
                }
            }
        }
    }
}

// MARK: - Number Field

private struct NumberField: View {
    @Binding var text: String
    let placeholder: String
    var isInteger: Bool = false
    let onSubmit: (String) -> Void

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(isInteger ? .numberPad : .decimalPad)
            .multilineTextAlignment(.center)
            .font(.body.monospacedDigit())
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 4)
            .onChange(of: text) { _, new in onSubmit(new) }
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                if let tf = obj.object as? UITextField {
                    DispatchQueue.main.async { tf.selectAll(nil) }
                }
            }
    }
}

// MARK: - Rest Timer Banner

private struct RestTimerBanner: View {
    let seconds: Int
    let duration: Int
    var isExpired: Bool = false
    let onSkip: () -> Void

    private var progress: Double {
        guard duration > 0 else { return 1 }
        return isExpired ? 1.0 : 1.0 - Double(seconds) / Double(duration)
    }

    var body: some View {
        if isExpired {
            // Expired state: green, "Tap when ready" label, full progress bar
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest Complete").font(.caption.bold()).foregroundStyle(HONTheme.positive)
                    Text("Tap when ready ✓").font(.title2.bold())
                        .foregroundStyle(HONTheme.positive)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(HONTheme.positive)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(HONTheme.positive.opacity(0.4), lineWidth: 1.5))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .shadow(color: HONTheme.positive.opacity(0.15), radius: 12, y: -2)
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .onTapGesture { onSkip() }
        } else {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest Timer").font(.caption.bold()).foregroundStyle(.secondary)
                    Text(timeString).font(.title2.bold().monospacedDigit())
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2))
                        Capsule().fill(timerColor)
                            .frame(width: geo.size.width * progress)
                            .animation(.linear(duration: 1), value: progress)
                    }
                }
                .frame(height: 8)
                Button("Skip", action: onSkip).font(.subheadline.bold()).foregroundStyle(HONTheme.accent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .shadow(color: .black.opacity(0.1), radius: 12, y: -2)
        }
    }

    private var timeString: String {
        let m = seconds / 60, s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
    private var timerColor: Color { seconds > 30 ? HONTheme.positive : seconds > 10 ? HONTheme.warning : HONTheme.negative }
}

// MARK: - Workout Feel Bar

private struct WorkoutFeelBar: View {
    let onFinish: ((FeelRating?) -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            Text("How did that feel?")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(FeelRating.allCases, id: \.self) { feel in
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onFinish?(feel)
                    } label: {
                        VStack(spacing: 3) {
                            Text(feel.icon)
                                .font(.system(size: 20))
                            Text(feel.rawValue)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            Button("End without rating") {
                onFinish?(nil)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }
}

// MARK: - Exercise History Matrix

private struct ExerciseHistoryMatrix: View {
    let history: [(date: Date, sets: [SetRecord])]

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MM-dd"; return f
    }()
    private var maxSets: Int { history.map(\.sets.count).max() ?? 0 }
    private var ordered: [(date: Date, sets: [SetRecord])] { history.reversed() }
    private static let rowH: CGFloat = 26
    private static let headerH: CGFloat = 20

    var body: some View {
        let visibleRows = min(maxSets, 5)
        let totalH = Self.headerH + CGFloat(visibleRows) * Self.rowH + 6

        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text("").frame(width: 40)
                    ForEach(ordered.indices, id: \.self) { i in
                        Text(Self.dateFmt.string(from: ordered[i].date))
                            .font(.caption2.bold()).foregroundStyle(.secondary)
                            .frame(width: 54, alignment: .center)
                    }
                }
                .frame(height: Self.headerH)

                ForEach(0..<maxSets, id: \.self) { setIndex in
                    HStack(spacing: 0) {
                        Text("S\(setIndex + 1)").font(.caption2.bold()).foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .leading)
                        ForEach(ordered.indices, id: \.self) { sessionIndex in
                            let sets = ordered[sessionIndex].sets
                            if setIndex < sets.count {
                                HistoryCell(set: sets[setIndex]).frame(width: 54, height: Self.rowH)
                            } else {
                                Text("—").font(.caption2).foregroundStyle(.tertiary)
                                    .frame(width: 54, height: Self.rowH, alignment: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: totalH)
    }
}

// MARK: - Superset Connector

private struct SupersetConnector: View {
    let groupId: String
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(HONTheme.accent.opacity(0.5)).frame(width: 3).padding(.leading, 36)
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.swap").font(.caption2.bold())
                Text("Superset \(groupId)").font(.caption2.bold())
            }
            .foregroundStyle(HONTheme.accent)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(HONTheme.accent.opacity(0.1), in: Capsule())
            Spacer()
        }
        .frame(height: 28)
    }
}

// MARK: - Equipment Chip Row

private struct EquipmentChipRow: View {
    let current: Equipment
    let variants: [Equipment]
    let onSelect: (Equipment) -> Void

    private var allOptions: [Equipment] {
        ([current] + variants).sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(allOptions, id: \.self) { equip in
                    let isSelected = equip == current
                    Button {
                        if !isSelected { onSelect(equip) }
                    } label: {
                        Text(equip.chipLabel)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isSelected ? HONTheme.accent : Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(isSelected ? HONTheme.textPrimary : .primary)
                    }
                    .disabled(isSelected)
                }
            }
        }
    }
}

private struct HistoryCell: View {
    let set: SetRecord
    private var hitTarget: Bool {
        guard set.targetReps > 0 else { return set.isCompleted }
        return set.reps >= set.targetReps
    }
    var body: some View {
        Text(set.weight.weightFormatted)
            .font(.caption2.monospacedDigit())
            .frame(width: 54, alignment: .center)
            .padding(.vertical, 5)
            .background(hitTarget ? HONTheme.positive.opacity(0.15) : HONTheme.negative.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(hitTarget ? HONTheme.positive : HONTheme.negative)
            .padding(.horizontal, 2)
    }
}

// MARK: - Swipe-to-Delete Modifier

private struct SwipeToDeleteModifier: ViewModifier {
    let onDelete: () -> Void
    @State private var dragOffset: CGFloat = 0
    private let revealWidth: CGFloat = 72

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            // Red trash button revealed by left swipe
            Button(role: .destructive) {
                withAnimation(.easeOut(duration: 0.18)) { dragOffset = -400 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onDelete() }
            } label: {
                Image(systemName: "trash.fill")
                    .foregroundStyle(HONTheme.textPrimary)
                    .frame(width: revealWidth)
                    .frame(maxHeight: .infinity)
            }
            .background(HONTheme.negative)

            content
                .background(AppTheme.cardBG)
                .offset(x: dragOffset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12, coordinateSpace: .local)
                        .onChanged { v in
                            guard v.translation.width < 0 else { return }
                            dragOffset = max(-revealWidth, v.translation.width)
                        }
                        .onEnded { v in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                dragOffset = v.translation.width < -(revealWidth / 2) ? -revealWidth : 0
                            }
                        }
                )
        }
        .clipped()
    }
}

private extension View {
    func swipeToDelete(action: @escaping () -> Void) -> some View {
        modifier(SwipeToDeleteModifier(onDelete: action))
    }
}

// MARK: - Readiness Before Sheet

private struct ReadinessBeforeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Int) -> Void

    private let options: [(label: String, icon: String, value: Int, detail: String)] = [
        ("Tired",  "😴", 1, "Under-slept, sore, or low energy"),
        ("Normal", "💪", 2, "Feeling baseline — ready to work"),
        ("Strong", "🔥", 3, "High energy, well rested, fired up"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 28)

            VStack(spacing: 8) {
                Text("How are you feeling?")
                    .font(.custom("CormorantGaramond-Light", size: 32))
                    .foregroundStyle(HONTheme.textPrimary)

                Text("Logged before your first set — helps H.O.N. read your session in context.")
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundStyle(HONTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                ForEach(options, id: \.value) { opt in
                    Button {
                        onSelect(opt.value)
                        dismiss()
                    } label: {
                        HStack(spacing: 16) {
                            Text(opt.icon)
                                .font(.system(size: 28))
                                .frame(width: 44)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(opt.label)
                                    .font(.custom("DMSans-SemiBold", size: 16))
                                    .foregroundStyle(HONTheme.textPrimary)
                                Text(opt.detail)
                                    .font(.custom("DMSans-Regular", size: 12))
                                    .foregroundStyle(HONTheme.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(HONTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(HONTheme.accent.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)

            Button("Skip for now") { dismiss() }
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundStyle(HONTheme.textSecondary.opacity(0.6))
                .padding(.top, 20)
                .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity)
        .background(HONTheme.background)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Readiness Prompt Card

private struct ReadinessPromptCard: View {
    let onSelect: (Int) -> Void

    private let options: [(label: String, icon: String, value: Int)] = [
        ("Tired", "😴", 1),
        ("Normal", "💪", 2),
        ("Strong", "🔥", 3),
    ]

    var body: some View {
        VStack(spacing: 10) {
            Text("How are you feeling?")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                ForEach(options, id: \.value) { opt in
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            onSelect(opt.value)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(opt.icon)
                                .font(.title2)
                            Text(opt.label)
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
    }
}
