import SwiftUI

// MARK: - Unified history item

private enum HistoryItem: Identifiable {
    case strength(WorkoutLogEntry)
    case cardio(CardioLogEntry)
    case general(GeneralActivityEntry)

    var id: UUID {
        switch self {
        case .strength(let e): return e.id
        case .cardio(let e):   return e.id
        case .general(let e):  return e.id
        }
    }

    var date: Date {
        switch self {
        case .strength(let e): return e.startedAt
        case .cardio(let e):   return e.startedAt
        case .general(let e):  return e.startedAt
        }
    }
}

// MARK: - Shared grouping helpers

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

private func groupedByMonth(_ items: [HistoryItem]) -> [(String, [HistoryItem])] {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    let dict = Dictionary(grouping: items) { formatter.string(from: $0.date) }
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
    @AppStorage("weightUnitIsKg") private var weightUnitIsKg = true
    @State private var selectedEntry: WorkoutLogEntry? = nil
    @State private var selectedCardioEntry: CardioLogEntry? = nil
    @State private var showLogActivity = false
    @State private var searchText = ""

    private var allItems: [HistoryItem] {
        let s = store.workoutLog.map { HistoryItem.strength($0) }
        let c = store.cardioLog.map  { HistoryItem.cardio($0) }
        let g = store.generalLog.map { HistoryItem.general($0) }
        return (s + c + g).sorted { $0.date > $1.date }
    }

    private var filteredItems: [HistoryItem] {
        guard !searchText.isEmpty else { return allItems }
        let q = searchText.lowercased()
        return allItems.filter { item in
            switch item {
            case .strength(let e):
                return e.exercises.contains { $0.exercise.name.lowercased().contains(q) }
            case .cardio(let e):
                return e.circuitName.lowercased().contains(q) ||
                       e.exercises.contains { $0.exercise.name.lowercased().contains(q) }
            case .general(let e):
                return e.activityType.rawValue.lowercased().contains(q) ||
                       e.notes.lowercased().contains(q)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.workoutLog.isEmpty && store.cardioLog.isEmpty && store.generalLog.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "calendar.badge.clock",
                        description: Text("Complete your first workout to start building your history. Tap Workout below to get started.")
                    )
                } else if !searchText.isEmpty && filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        Section("Tools") {
                            NavigationLink("Plate Calculator") { PlateCalculatorView() }
                            NavigationLink("1RM Calculator") { StandaloneE1RMView() }
                        }
                        ForEach(groupedByMonth(filteredItems), id: \.0) { month, items in
                            Section(month) {
                                ForEach(items) { item in
                                    switch item {
                                    case .strength(let e):
                                        WorkoutHistoryRow(entry: e, highlightExercise: searchText.isEmpty ? "" : searchText)
                                            .contentShape(Rectangle())
                                            .onTapGesture { selectedEntry = e }
                                    case .cardio(let e):
                                        CardioHistoryRow(entry: e)
                                            .contentShape(Rectangle())
                                            .onTapGesture { selectedCardioEntry = e }
                                    case .general(let e):
                                        GeneralActivityRow(entry: e)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search workouts, exercises, circuits, activities")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLogActivity = true
                    } label: {
                        Label("Log Activity", systemImage: "plus.circle")
                    }
                }
            }
            .sheet(item: $selectedEntry) { entry in
                WorkoutDetailView(entry: entry)
            }
            .sheet(item: $selectedCardioEntry) { entry in
                CardioSessionDetailView(entry: entry)
            }
            .sheet(isPresented: $showLogActivity) {
                LogGeneralActivitySheet()
                    .environment(store)
            }
        }
    }
}

// MARK: - Cardio History Row

private struct CardioHistoryRow: View {
    let entry: CardioLogEntry

    var body: some View {
        HStack(spacing: 12) {
            // Format icon badge
            VStack(spacing: 2) {
                Image(systemName: entry.format.icon)
                    .font(.title3)
                Text(entry.format.rawValue)
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(entry.format.color)
            .frame(width: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.circuitName)
                    .font(.headline)
                HStack(spacing: 8) {
                    Label(entry.formattedDuration, systemImage: "clock")
                    Label("\(entry.completedRounds) \(entry.format == .amrap ? "rounds" : "min")", systemImage: "arrow.clockwise")
                    Label("\(entry.totalReps) reps", systemImage: "figure.run")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if entry.isWeightedSession && entry.totalVolume > 0 {
                    Text(String(format: "%.0f kg·reps", entry.totalVolume))
                        .font(.caption2)
                        .foregroundStyle(HONTheme.accent.opacity(0.8))
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - General Activity Row

private struct GeneralActivityRow: View {
    let entry: GeneralActivityEntry

    private var intensityColor: Color {
        switch entry.intensityLevel {
        case .light:    return HONTheme.positive
        case .moderate: return HONTheme.warning
        case .vigorous: return HONTheme.negative
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Activity icon badge
            VStack(spacing: 2) {
                Image(systemName: entry.activityType.icon)
                    .font(.title3)
                Text(entry.startedAt, format: .dateTime.day())
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(HONTheme.accent)
            .frame(width: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.activityType.rawValue)
                    .font(.headline)
                HStack(spacing: 8) {
                    Label("\(entry.durationMinutes) min", systemImage: "clock")
                    Text(entry.intensityLevel.rawValue)
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(intensityColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(intensityColor)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Cardio Session Detail View

private struct CardioSessionDetailView: View {
    let entry: CardioLogEntry
    @Environment(\.dismiss) private var dismiss

    private var shareText: String {
        let dateStr = entry.startedAt.formatted(.dateTime.month(.wide).day().year())
        let roundsLabel = entry.format == .amrap ? "rounds" : "min"
        var lines: [String] = [
            "Boring Workout — \(dateStr)",
            "\(entry.circuitName) · \(entry.format.rawValue)",
            "\(entry.formattedDuration) · \(entry.completedRounds) \(roundsLabel) · \(entry.totalReps) reps",
            ""
        ]
        for ce in entry.exercises {
            let relevant = entry.results.filter { $0.exerciseId == ce.id }
            let total = relevant.reduce(0) { $0 + $1.repsCompleted }
            var line = "\(ce.exercise.name): \(total) reps"
            if let w = ce.weight, w > 0 { line += " @ \(w.weightFormatted) kg" }
            lines.append(line)
        }
        lines.append("")
        lines.append("Tracked with H.O.N")
        return lines.joined(separator: "\n")
    }

    private var totalRepsPerExercise: [(exercise: CircuitExercise, total: Int, avg: Double)] {
        entry.exercises.map { ce in
            let relevant = entry.results.filter { $0.exerciseId == ce.id }
            let total = relevant.reduce(0) { $0 + $1.repsCompleted }
            let avg = relevant.isEmpty ? 0.0 : Double(total) / Double(relevant.count)
            return (ce, total, avg)
        }
    }

    private var roundBreakdown: [(round: Int, total: Int)] {
        guard entry.format == .amrap else { return [] }
        let maxRound = entry.results.map(\.round).max() ?? -1
        guard maxRound >= 0 else { return [] }
        return (0...maxRound).map { r in
            let total = entry.results.filter { $0.round == r }.reduce(0) { $0 + $1.repsCompleted }
            return (r, total)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Date header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.startedAt, format: .dateTime.month(.wide).day().year())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Image(systemName: entry.format.icon)
                            Text(entry.format.rawValue)
                        }
                        .font(.caption.bold())
                        .foregroundStyle(entry.format.color)
                    }
                    .padding(.horizontal)

                    // Stats row
                    HStack(spacing: 0) {
                        detailStatCell(value: "\(entry.completedRounds)", label: entry.format == .amrap ? "rounds" : "minutes")
                        Divider().frame(height: 40)
                        detailStatCell(value: "\(entry.totalReps)", label: "total reps")
                        Divider().frame(height: 40)
                        detailStatCell(value: entry.formattedDuration, label: "duration")
                        if entry.isWeightedSession && entry.totalVolume > 0 {
                            Divider().frame(height: 40)
                            detailStatCell(value: String(format: "%.0f", entry.totalVolume), label: "kg·reps")
                        }
                    }
                    .padding()
                    .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Per-exercise breakdown
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Exercise Breakdown")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(totalRepsPerExercise, id: \.exercise.id) { row in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.exercise.exercise.name)
                                        .font(.subheadline)
                                    if let w = row.exercise.weight, w > 0 {
                                        Text(String(format: "%.1f kg", w))
                                            .font(.caption)
                                            .foregroundStyle(HONTheme.accent.opacity(0.8))
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(row.total) reps total")
                                        .font(.subheadline.bold())
                                    Text(String(format: "%.1f avg/\(entry.format == .amrap ? "round" : "min")", row.avg))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal)
                        }
                    }

                    // AMRAP round breakdown (≤10 rounds)
                    if entry.format == .amrap && roundBreakdown.count <= 10 && !roundBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Rounds Breakdown")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(roundBreakdown, id: \.round) { row in
                                HStack {
                                    Text("Round \(row.round + 1)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(row.total) reps")
                                        .font(.subheadline.bold())
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(entry.circuitName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func detailStatCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
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
    @AppStorage("weightUnitIsKg") private var weightUnitIsKg = true

    private func displayWeight(_ kg: Double) -> String {
        let val = weightUnitIsKg ? kg : kg * 2.20462
        return "\(Int(val.rounded())) \(weightUnitIsKg ? "kg" : "lbs")"
    }

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
                    Label(displayWeight(entry.totalVolume), systemImage: "scalemass")
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
    @AppStorage("weightUnitIsKg") private var weightUnitIsKg = true

    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false

    // Always reads from the store so edits reflect immediately when the edit sheet closes.
    private var liveEntry: WorkoutLogEntry {
        store.workoutLog.first { $0.id == entry.id } ?? entry
    }

    private func displayWeight(_ kg: Double) -> String {
        let val = weightUnitIsKg ? kg : kg * 2.20462
        return "\(Int(val.rounded())) \(weightUnitIsKg ? "kg" : "lbs")"
    }

    private var shareText: String {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .none
        let dur = liveEntry.finishedAt.map { Int($0.timeIntervalSince(liveEntry.startedAt) / 60) }.map { "\($0) min" } ?? ""
        var lines = ["💪 \(df.string(from: liveEntry.startedAt)) · \(dur)", ""]
        for we in liveEntry.exercises {
            if let best = we.sets.filter({ $0.isCompleted && $0.weight > 0 && $0.reps > 0 })
                .max(by: { SetRecord.e1RM(weight: $0.weight, reps: $0.reps) < SetRecord.e1RM(weight: $1.weight, reps: $1.reps) }) {
                let e1rm = Int((SetRecord.e1RM(weight: best.weight, reps: best.reps) / 5.0).rounded() * 5.0)
                lines.append("  \(we.exercise.name): \(Int(best.weight))kg × \(best.reps)  (~\(e1rm)kg 1RM)")
            }
        }
        lines += ["", "Tracked with H.O.N — boringworkout.app"]
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 20) {
                        StatPill(label: "Duration", value: liveEntry.formattedDuration)
                        StatPill(label: "Sets",     value: "\(liveEntry.totalSets)")
                        StatPill(label: "Volume",   value: displayWeight(liveEntry.totalVolume))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                ForEach(liveEntry.exercises) { we in
                    Section(we.exercise.name) {
                        ForEach(Array(we.sets.enumerated()), id: \.element.id) { i, set in
                            if set.isCompleted {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text("Set \(i + 1)")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(displayWeight(set.weight)) × \(set.reps) reps")
                                            .font(.body.monospacedDigit())
                                        if set.estimated1RM > 0 {
                                            Text("≈\(Int(set.estimated1RM)) 1RM")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    if set.isDropCompleted,
                                       let dw = set.dropWeight, dw > 0,
                                       let dr = set.dropReps, dr > 0 {
                                        HStack {
                                            Text("↳ Drop")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text("\(displayWeight(dw)) × \(dr) reps")
                                                .font(.subheadline.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        HStack {
                            Text("Volume")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(displayWeight(we.totalVolume))
                                .fontWeight(.semibold)
                        }
                    }
                }

                if !liveEntry.exercises.isEmpty {
                    Section {
                        Text("Tip: increase load by no more than 10% per week to avoid injury.")
                            .font(.caption2).foregroundStyle(.secondary.opacity(0.5))
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
                    HStack(spacing: 16) {
                        ShareLink(item: shareText) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Button("Edit") { showEditSheet = true }
                    }
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
                                isCompleted: $edited.exercises[exIdx].sets[setIdx].isCompleted,
                                dropWeight: $edited.exercises[exIdx].sets[setIdx].dropWeight,
                                dropReps: $edited.exercises[exIdx].sets[setIdx].dropReps,
                                isDropCompleted: $edited.exercises[exIdx].sets[setIdx].isDropCompleted
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
                                        .foregroundStyle(HONTheme.negative.opacity(0.7))
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
    @Binding var dropWeight: Double?
    @Binding var dropReps: Int?
    @Binding var isDropCompleted: Bool

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var dropWeightText: String = ""
    @State private var dropRepsText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main set row
            HStack(spacing: 10) {
                Button {
                    isCompleted.toggle()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isCompleted ? HONTheme.positive : .secondary)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)

                Text("Set \(setNumber)")
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)

                Spacer()

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

            // Drop set row — shown when a drop set exists
            if isDropCompleted {
                HStack(spacing: 10) {
                    Button {
                        isDropCompleted = false
                        dropWeight = nil
                        dropReps = nil
                        dropWeightText = ""
                        dropRepsText = ""
                    } label: {
                        Image(systemName: "arrow.turn.down.right")
                            .foregroundStyle(HONTheme.accent)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)

                    Text("Drop")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .frame(width: 44, alignment: .leading)

                    Spacer()

                    TextField("0", text: $dropWeightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                        .font(.subheadline.monospacedDigit())
                        .onChange(of: dropWeightText) { _, new in
                            dropWeight = Double(new)
                        }

                    Text("kg ×")
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    TextField("0", text: $dropRepsText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 40)
                        .font(.subheadline.monospacedDigit())
                        .onChange(of: dropRepsText) { _, new in
                            dropReps = Int(new)
                        }

                    Text("reps")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .padding(.leading, 28)
            }
        }
        .onAppear {
            weightText     = weight == 0 ? "" : weight.weightFormatted
            repsText       = reps == 0 ? "" : "\(reps)"
            if let dw = dropWeight { dropWeightText = dw.weightFormatted }
            if let dr = dropReps   { dropRepsText   = "\(dr)" }
        }
    }
}
