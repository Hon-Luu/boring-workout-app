import SwiftUI

// MARK: - Routine List

struct TemplatesView: View {
    @Environment(SeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editingRoutine: WorkoutTemplate? = nil
    @State private var showNewRoutine = false
    @State private var showQRScanner = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.routines) { routine in
                    RoutineRow(routine: routine)
                        .contentShape(Rectangle())
                        .onTapGesture { editingRoutine = routine }
                }
                .onDelete { offsets in
                    offsets.forEach { store.deleteRoutine(id: store.routines[$0].id) }
                }
            }
            .listStyle(.grouped)
            .overlay {
                if store.routines.isEmpty {
                    ContentUnavailableView(
                        "No Routines",
                        systemImage: "calendar.badge.plus",
                        description: Text("Create a routine to plan your weekly schedule.")
                    )
                }
            }
            .navigationTitle("My Routines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button { showQRScanner = true } label: {
                            Image(systemName: "qrcode.viewfinder")
                        }
                        Button { showNewRoutine = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(item: $editingRoutine) { routine in
                RoutineEditorView(routine: routine)
                    .environment(store)
            }
            .sheet(isPresented: $showNewRoutine) {
                RoutineEditorView(routine: WorkoutTemplate())
                    .environment(store)
            }
            .sheet(isPresented: $showQRScanner) {
                QRRoutineScannerView()
                    .environment(store)
            }
        }
    }
}

private struct RoutineRow: View {
    @Environment(SeedStore.self) private var store
    let routine: WorkoutTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(routine.name.isEmpty ? "Unnamed Routine" : routine.name)
                    .font(.headline)
                Spacer()
                if !routine.circuitIds.isEmpty {
                    Label("\(routine.circuitIds.count)", systemImage: "bolt.heart.fill")
                        .font(.caption.bold())
                        .foregroundStyle(HONTheme.warning)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(HONTheme.warning.opacity(0.12), in: Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if !routine.exercises.isEmpty {
                Text(routine.exercises.map(\.exercise.name).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(scheduleSummary(for: routine))
                    .font(.caption2)
                    .foregroundStyle(HONTheme.accent)
            }
        }
        .padding(.vertical, 4)
    }

    private func scheduleSummary(for routine: WorkoutTemplate) -> String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let hasToday = routine.exercises.contains { $0.assignedDays.contains(weekday) }
        let allDays = Set(routine.exercises.flatMap(\.assignedDays)).sorted()
        let names = allDays.compactMap { TemplateExercise.dayNames[safe: $0] }
        let daysStr = names.joined(separator: " · ")
        return hasToday ? "Today · \(daysStr)" : daysStr
    }
}

// MARK: - Circuit Picker Sheet

private struct CircuitPickerSheet: View {
    @Environment(SeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showBuilder = false

    let attachedIds: [UUID]
    let onAttach: (UUID) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if store.cardioCircuits.isEmpty {
                    ContentUnavailableView(
                        "No Circuits Yet",
                        systemImage: "bolt.heart.fill",
                        description: Text("Create a circuit first, then attach it to this routine.")
                    )
                } else {
                    List {
                        ForEach(store.cardioCircuits) { circuit in
                            let isAttached = attachedIds.contains(circuit.id)
                            Button {
                                if !isAttached {
                                    onAttach(circuit.id)
                                    dismiss()
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: circuit.format.icon)
                                        .foregroundStyle(circuit.format.color)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(circuit.displayName)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Text("\(circuit.format.rawValue) · \(circuit.durationMinutes) min · \(circuit.exercises.count) exercises")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if isAttached {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(HONTheme.positive)
                                    }
                                }
                            }
                            .disabled(isAttached)
                        }
                    }
                }
            }
            .navigationTitle("Add Circuit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBuilder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showBuilder) {
                CircuitBuilderView(circuit: nil)
                    .environment(store)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Routine Editor

struct RoutineEditorView: View {
    @Environment(SeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var routine: WorkoutTemplate
    @State private var showExercisePicker = false
    @State private var showCircuitPicker = false

    init(routine: WorkoutTemplate) {
        _routine = State(initialValue: routine)
    }

    private var attachedCircuits: [CardioCircuit] {
        routine.circuitIds.compactMap { id in store.cardioCircuits.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine Name") {
                    TextField("e.g. Push Day", text: $routine.name)
                }

                Section {
                    ForEach(Array(routine.exercises.enumerated()), id: \.element.id) { i, te in
                        let prevGroup = i > 0 ? routine.exercises[i - 1].supersetGroup : nil
                        let isLinkedAbove = te.supersetGroup != nil && te.supersetGroup == prevGroup
                        let supersetPos: Int? = te.supersetGroup.map { g in
                            routine.exercises.prefix(i + 1).filter { $0.supersetGroup == g }.count
                        }
                        let canLink = i + 1 < routine.exercises.count

                        if isLinkedAbove {
                            SupersetDivider(groupId: te.supersetGroup!)
                                .listRowBackground(HONTheme.warning.opacity(0.04))
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        }

                        RoutineExerciseRow(
                            te: $routine.exercises[i],
                            supersetGroupId: te.supersetGroup,
                            supersetPosition: supersetPos,
                            canLinkWithNext: canLink,
                            onLinkWithNext: { linkSuperset(at: i) },
                            onUnlink: { unlinkSuperset(at: i) }
                        )
                    }
                    .onDelete { routine.exercises.remove(atOffsets: $0) }
                    .onMove { routine.exercises.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Exercises")
                } footer: {
                    if routine.exercises.isEmpty {
                        Text("Add exercises, tag days, and pair any two into a superset via the ··· menu.")
                    }
                }

                Section {
                    ForEach(attachedCircuits) { circuit in
                        HStack(spacing: 12) {
                            Image(systemName: circuit.format.icon)
                                .foregroundStyle(circuit.format.color)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(circuit.displayName)
                                    .font(.subheadline)
                                Text("\(circuit.format.rawValue) · \(circuit.durationMinutes) min · \(circuit.exercises.count) exercises")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                routine.circuitIds.removeAll { $0 == circuit.id }
                            } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                        }
                    }

                    Button {
                        showCircuitPicker = true
                    } label: {
                        Label("Add Circuit", systemImage: "bolt.heart.fill")
                            .foregroundStyle(HONTheme.warning)
                    }
                } header: {
                    Text("Cardio Circuits")
                } footer: {
                    if attachedCircuits.isEmpty {
                        Text("Attach circuits to this routine. You can start them from the workout screen.")
                    }
                }

                Section {
                    let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(1...7, id: \.self) { weekday in
                            let isOn = routine.restDayWeekdays.contains(weekday)
                            Button {
                                if isOn {
                                    routine.restDayWeekdays.removeAll { $0 == weekday }
                                } else {
                                    routine.restDayWeekdays.append(weekday)
                                }
                            } label: {
                                Text(days[weekday - 1])
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(isOn ? HONTheme.warning.opacity(0.18) : Color.secondary.opacity(0.08),
                                                in: RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(isOn ? HONTheme.warning : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Rest Days")
                } footer: {
                    Text("Mark planned rest days for this routine. They'll appear on the home screen as a reminder.")
                        .font(.caption2)
                }
            }
            .navigationTitle(routine.name.isEmpty ? "New Routine" : routine.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.addOrUpdateRoutine(routine)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(routine.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .keyboard) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(title: "Add Exercise") { exercise, _ in
                    routine.exercises.append(TemplateExercise(exercise: exercise))
                }
                .environment(store)
            }
            .sheet(isPresented: $showCircuitPicker) {
                CircuitPickerSheet(attachedIds: routine.circuitIds) { id in
                    if !routine.circuitIds.contains(id) {
                        routine.circuitIds.append(id)
                    }
                }
                .environment(store)
            }
        }
    }

    // MARK: - Superset helpers

    private func nextGroupId() -> String {
        let used = Set(routine.exercises.compactMap(\.supersetGroup))
        for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" {
            let s = String(c)
            if !used.contains(s) { return s }
        }
        return "A"
    }

    private func linkSuperset(at i: Int) {
        guard i + 1 < routine.exercises.count else { return }
        let groupId = routine.exercises[i].supersetGroup
                   ?? routine.exercises[i + 1].supersetGroup
                   ?? nextGroupId()
        routine.exercises[i].supersetGroup = groupId
        routine.exercises[i + 1].supersetGroup = groupId
    }

    private func unlinkSuperset(at i: Int) {
        guard let group = routine.exercises[i].supersetGroup else { return }
        let members = routine.exercises.indices.filter { routine.exercises[$0].supersetGroup == group }
        if members.count <= 2 {
            members.forEach { routine.exercises[$0].supersetGroup = nil }
        } else {
            routine.exercises[i].supersetGroup = nil
        }
    }
}

// MARK: - Superset divider between paired rows

private struct SupersetDivider: View {
    let groupId: String

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(HONTheme.warning.opacity(0.5))
                .frame(width: 3, height: 20)
                .padding(.leading, 16)
            Image(systemName: "link")
                .font(.caption2.bold())
                .foregroundStyle(HONTheme.warning)
            Text("Superset \(groupId)")
                .font(.caption2.bold())
                .foregroundStyle(HONTheme.warning)
            Spacer()
        }
        .frame(height: 24)
        .background(HONTheme.warning.opacity(0.06))
    }
}

// MARK: - Per-exercise row

private struct RoutineExerciseRow: View {
    @Binding var te: TemplateExercise
    let supersetGroupId: String?
    let supersetPosition: Int?
    let canLinkWithNext: Bool
    let onLinkWithNext: () -> Void
    let onUnlink: () -> Void

    private static let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
    private static let weekdays = Array(1...7)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let group = supersetGroupId, let pos = supersetPosition {
                    Text("\(group)\(pos)")
                        .font(.caption.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(HONTheme.warning.opacity(0.15), in: Capsule())
                        .foregroundStyle(HONTheme.warning)
                }
                Text(te.exercise.name)
                    .font(.subheadline.bold())
                Spacer()
                Menu {
                    if supersetGroupId != nil {
                        Button(role: .destructive, action: onUnlink) {
                            Label("Remove from Superset", systemImage: "link.badge.minus")
                        }
                    } else if canLinkWithNext {
                        Button(action: onLinkWithNext) {
                            Label("Pair with Next as Superset", systemImage: "link.badge.plus")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }
            }

            HStack(spacing: 16) {
                Stepper(value: $te.targetSets, in: 1...10) {
                    HStack(spacing: 4) {
                        Text("\(te.targetSets)")
                            .font(.headline)
                            .frame(width: 28, alignment: .trailing)
                        Text("sets").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Stepper(value: $te.targetReps, in: 1...50) {
                    HStack(spacing: 4) {
                        Text("\(te.targetReps)")
                            .font(.headline)
                            .frame(width: 28, alignment: .trailing)
                        Text("reps").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(Self.weekdays, id: \.self) { weekday in
                    let isOn = te.assignedDays.contains(weekday)
                    Button {
                        if isOn { te.assignedDays.removeAll { $0 == weekday } }
                        else { te.assignedDays.append(weekday) }
                    } label: {
                        Text(Self.dayNames[weekday - 1])
                            .font(.caption2.bold())
                            .frame(width: 28, height: 28)
                            .background(isOn ? HONTheme.accent : Color.secondary.opacity(0.15), in: Circle())
                            .foregroundStyle(isOn ? HONTheme.textPrimary : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(supersetGroupId != nil ? HONTheme.warning.opacity(0.04) : Color.clear)
        .overlay(alignment: .leading) {
            if supersetGroupId != nil {
                RoundedRectangle(cornerRadius: 2)
                    .fill(HONTheme.warning.opacity(0.6))
                    .frame(width: 3)
                    .padding(.vertical, 4)
            }
        }
    }
}
