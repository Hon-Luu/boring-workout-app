import SwiftUI

// MARK: - Shared grouping helper

private func groupedByMonth(_ log: [WorkoutLogEntry]) -> [(String, [WorkoutLogEntry])] {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    let dict = Dictionary(grouping: log) { formatter.string(from: $0.startedAt) }
    return dict.sorted { a, b in
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        let da = df.date(from: a.key) ?? Date.distantPast
        let db = df.date(from: b.key) ?? Date.distantPast
        return da > db
    }
}

// MARK: - History Tab View

struct HistoryView: View {
    @Environment(SeedStore.self) private var store
    @State private var selectedEntry: WorkoutLogEntry? = nil
    @State private var searchText = ""

    private var filteredLog: [WorkoutLogEntry] {
        guard !searchText.isEmpty else { return store.workoutLog }
        return store.workoutLog.filter { entry in
            entry.exercises.contains { we in
                we.exercise.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.workoutLog.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "calendar.badge.clock",
                        description: Text("Your completed workouts will appear here.")
                    )
                } else if !searchText.isEmpty && filteredLog.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if searchText.isEmpty {
                    List {
                        ForEach(groupedByMonth(store.workoutLog), id: \.0) { month, entries in
                            Section(month) {
                                ForEach(entries) { entry in
                                    WorkoutHistoryRow(entry: entry)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedEntry = entry }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    List(filteredLog) { entry in
                        WorkoutHistoryRow(entry: entry, highlightExercise: searchText)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedEntry = entry }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search by exercise")
            .sheet(item: $selectedEntry) { entry in
                WorkoutDetailView(entry: entry)
            }
        }
    }
}

// MARK: - Settings-compatible history list (no NavigationStack)

struct WorkoutHistorySettingsView: View {
    @Environment(SeedStore.self) private var store
    @State private var selectedEntry: WorkoutLogEntry? = nil
    @State private var searchText = ""

    private var filteredLog: [WorkoutLogEntry] {
        guard !searchText.isEmpty else { return store.workoutLog }
        return store.workoutLog.filter { entry in
            entry.exercises.contains {
                $0.exercise.name.localizedCaseInsensitiveContains(searchText)
            } || entry.startedAt.formatted(.dateTime.month(.wide).day().year())
                    .localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if store.workoutLog.isEmpty {
                ContentUnavailableView(
                    "No Workouts Yet",
                    systemImage: "calendar.badge.clock",
                    description: Text("Your completed workouts will appear here.")
                )
            } else if filteredLog.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(groupedByMonth(filteredLog), id: \.0) { month, entries in
                        Section(month) {
                            ForEach(entries) { entry in
                                WorkoutHistoryRow(
                                    entry: entry,
                                    highlightExercise: searchText
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { selectedEntry = entry }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Workout History")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search exercises or dates")
        .sheet(item: $selectedEntry) { entry in
            WorkoutDetailView(entry: entry)
        }
    }
}

// MARK: - History Row

struct WorkoutHistoryRow: View {
    let entry: WorkoutLogEntry
    var highlightExercise: String = ""

    private var matchedSets: String? {
        guard !highlightExercise.isEmpty else { return nil }
        let matches = entry.exercises.filter {
            $0.exercise.name.localizedCaseInsensitiveContains(highlightExercise)
        }
        guard !matches.isEmpty else { return nil }
        return matches.map { we in
            let sets = we.completedSets
            guard !sets.isEmpty else { return we.exercise.name }
            let best = sets.max { $0.weight < $1.weight }
            if let b = best {
                return "\(we.exercise.name): \(b.weight.weightFormatted) kg × \(b.reps)"
            }
            return we.exercise.name
        }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(entry.startedAt, format: .dateTime.day())
                    .font(.title2.bold())
                Text(entry.startedAt, format: .dateTime.weekday(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.startedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.headline)
                if let match = matchedSets {
                    Text(match)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                } else {
                    Text(entry.muscleGroups)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Label(entry.formattedDuration, systemImage: "clock")
                    Label("\(entry.totalSets) sets", systemImage: "list.number")
                    Label("\(Int(entry.totalVolume)) kg", systemImage: "scalemass")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Workout Detail (read + edit)

struct WorkoutDetailView: View {
    let entry: WorkoutLogEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(SeedStore.self) private var store

    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false

    // Always reads from the store so edits reflect immediately when the edit sheet closes.
    private var liveEntry: WorkoutLogEntry {
        store.workoutLog.first { $0.id == entry.id } ?? entry
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 20) {
                        StatPill(label: "Duration", value: liveEntry.formattedDuration)
                        StatPill(label: "Sets",     value: "\(liveEntry.totalSets)")
                        StatPill(label: "Volume",   value: "\(Int(liveEntry.totalVolume)) kg")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                ForEach(liveEntry.exercises) { we in
                    Section(we.exercise.name) {
                        ForEach(Array(we.sets.enumerated()), id: \.element.id) { i, set in
                            if set.isCompleted {
                                HStack {
                                    Text("Set \(i + 1)")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(set.weight.weightFormatted) kg × \(set.reps) reps")
                                        .font(.body.monospacedDigit())
                                    if set.estimated1RM > 0 {
                                        Text("≈\(Int(set.estimated1RM)) 1RM")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        HStack {
                            Text("Volume")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(we.totalVolume)) kg")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(liveEntry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showEditSheet = true }
                }
            }
            .confirmationDialog(
                "Delete this workout?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    store.deleteWorkoutLogEntry(id: liveEntry.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showEditSheet) {
                EditWorkoutSheet(entry: liveEntry)
            }
        }
    }
}

// MARK: - Edit Workout Sheet

struct EditWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SeedStore.self) private var store

    @State private var edited: WorkoutLogEntry
    @State private var showDeleteConfirm = false

    init(entry: WorkoutLogEntry) {
        _edited = State(initialValue: entry)
    }

    @ViewBuilder
    private func equipChip(_ equip: Equipment, selected: Bool, exIdx: Int) -> some View {
        Button {
            guard !selected,
                  let variant = store.bestVariant(equipment: equip, matching: edited.exercises[exIdx].exercise)
            else { return }
            edited.exercises[exIdx].exercise = variant
        } label: {
            Text(equip.chipLabel)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(selected ? HONTheme.accent : Color.secondary.opacity(0.15),
                            in: Capsule())
                .foregroundStyle(selected ? Color.black : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(selected)
    }

    var body: some View {
        NavigationStack {
            List {
                // Workout name
                Section("Workout Name") {
                    TextField("Name", text: $edited.name)
                }

                // Stats summary (live)
                Section {
                    HStack(spacing: 20) {
                        StatPill(label: "Sets",   value: "\(edited.totalSets)")
                        StatPill(label: "Volume", value: "\(Int(edited.totalVolume)) kg")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

                // Exercises
                ForEach(Array(edited.exercises.indices), id: \.self) { exIdx in
                    Section {
                        ForEach(Array(edited.exercises[exIdx].sets.indices), id: \.self) { setIdx in
                            EditableSetRow(
                                setNumber: setIdx + 1,
                                weight: $edited.exercises[exIdx].sets[setIdx].weight,
                                reps: $edited.exercises[exIdx].sets[setIdx].reps,
                                isCompleted: $edited.exercises[exIdx].sets[setIdx].isCompleted
                            )
                        }
                        .onDelete { offsets in
                            edited.exercises[exIdx].sets.remove(atOffsets: offsets)
                        }

                        // Add set button
                        Button {
                            let last = edited.exercises[exIdx].sets.last
                            var newSet = SetRecord(
                                weight: last?.weight ?? 0,
                                reps: last?.reps ?? 0
                            )
                            newSet.isCompleted = true
                            edited.exercises[exIdx].sets.append(newSet)
                        } label: {
                            Label("Add Set", systemImage: "plus.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(edited.exercises[exIdx].exercise.name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Button(role: .destructive) {
                                    edited.exercises.remove(at: exIdx)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.red.opacity(0.7))
                                }
                            }
                            // Equipment chips
                            let ex = edited.exercises[exIdx].exercise
                            let current = ex.equipment
                            let swappable = store.quickSwapEquipment(for: ex)
                            if !swappable.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        equipChip(current, selected: true, exIdx: exIdx)
                                        ForEach(swappable, id: \.self) { equip in
                                            equipChip(equip, selected: false, exIdx: exIdx)
                                        }
                                    }
                                    .padding(.bottom, 2)
                                }
                            }
                        }
                        .textCase(nil)
                    }
                }

                // Delete workout
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.updateLoggedEntry(edited)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Delete this workout? This can't be undone.",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Workout", role: .destructive) {
                    store.deleteWorkoutLogEntry(id: edited.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .interactiveDismissDisabled(true)
        }
    }
}

// MARK: - Editable Set Row

private struct EditableSetRow: View {
    let setNumber: Int
    @Binding var weight: Double
    @Binding var reps: Int
    @Binding var isCompleted: Bool

    @State private var weightText: String = ""
    @State private var repsText: String = ""

    var body: some View {
        HStack(spacing: 10) {
            // Completed toggle
            Button {
                isCompleted.toggle()
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? .green : .secondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)

            Text("Set \(setNumber)")
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            Spacer()

            // Weight field
            TextField("0", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .font(.body.monospacedDigit())
                .onChange(of: weightText) { _, new in
                    if let v = Double(new) { weight = v }
                }

            Text("kg ×")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            // Reps field
            TextField("0", text: $repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 40)
                .font(.body.monospacedDigit())
                .onChange(of: repsText) { _, new in
                    if let v = Int(new) { reps = v }
                }

            Text("reps")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .onAppear {
            weightText = weight == 0 ? "" : weight.weightFormatted
            repsText = reps == 0 ? "" : "\(reps)"
        }
    }
}
