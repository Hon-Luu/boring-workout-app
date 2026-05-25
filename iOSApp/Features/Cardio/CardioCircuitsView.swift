import SwiftUI

// MARK: - CircuitFormat Color & Description Extensions

extension CircuitFormat {
    var color: Color {
        switch self {
        case .amrap: return HONTheme.accent
        case .emom:  return HONTheme.warning
        }
    }

    var description: String {
        switch self {
        case .amrap: return "Complete as many rounds as possible in the time limit."
        case .emom:  return "Every minute, complete a set exercise. Rest for the remainder of the minute."
        }
    }
}

// MARK: - CardioCircuitsView

struct CardioCircuitsView: View {
    @Environment(SeedStore.self) private var store
    @Environment(HealthKitService.self) private var health
    @State private var showBuilder = false
    @State private var selectedCircuit: CardioCircuit? = nil
    @State private var editingCircuit: CardioCircuit? = nil
    @State private var activeCircuit: CardioCircuit? = nil

    private var amrapCircuits: [CardioCircuit] {
        store.cardioCircuits.filter { $0.format == .amrap }
    }

    private var emomCircuits: [CardioCircuit] {
        store.cardioCircuits.filter { $0.format == .emom }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.cardioCircuits.isEmpty {
                    ContentUnavailableView(
                        "No Circuits",
                        systemImage: "bolt.heart.fill",
                        description: Text("Tap + to build your first HIIT circuit.")
                    )
                } else {
                    List {
                        if !amrapCircuits.isEmpty {
                            Section("AMRAP") {
                                ForEach(amrapCircuits) { circuit in
                                    CircuitRow(circuit: circuit)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedCircuit = circuit }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                store.deleteCircuit(id: circuit.id)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                        if !emomCircuits.isEmpty {
                            Section("EMOM") {
                                ForEach(emomCircuits) { circuit in
                                    CircuitRow(circuit: circuit)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedCircuit = circuit }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                store.deleteCircuit(id: circuit.id)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Circuits")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { restoreActiveSessionIfNeeded() }
            .toolbar {
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
            .sheet(item: $selectedCircuit) { circuit in
                CircuitDetailSheet(circuit: circuit, onStart: {
                    selectedCircuit = nil
                    activeCircuit = circuit
                }, onEdit: { updated in
                    editingCircuit = updated
                    selectedCircuit = nil
                })
                .environment(store)
            }
            .sheet(item: $editingCircuit) { circuit in
                CircuitBuilderView(circuit: circuit)
                    .environment(store)
            }
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

    private func restoreActiveSessionIfNeeded() {
        guard activeCircuit == nil,
              let savedId = UserDefaults.standard.string(forKey: "honcardio_circuit_id"),
              let uuid = UUID(uuidString: savedId),
              let circuit = store.cardioCircuits.first(where: { $0.id == uuid }) else { return }
        let savedTime = UserDefaults.standard.double(forKey: "honcardio_start_time")
        let elapsed = Date().timeIntervalSince1970 - savedTime
        guard elapsed < Double(circuit.durationMinutes * 60) else {
            UserDefaults.standard.removeObject(forKey: "honcardio_circuit_id")
            UserDefaults.standard.removeObject(forKey: "honcardio_start_time")
            return
        }
        activeCircuit = circuit
    }
}

// MARK: - Circuit Row

private struct CircuitRow: View {
    @Environment(SeedStore.self) private var store
    let circuit: CardioCircuit

    private var lastPlayed: Date? {
        store.cardioLog.first(where: { $0.circuitId == circuit.id })?.startedAt
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Format badge
            VStack(spacing: 4) {
                Image(systemName: circuit.format.icon)
                    .font(.title3)
                Text(circuit.format.rawValue)
                    .font(.caption2.bold())
            }
            .foregroundStyle(circuit.format.color)
            .frame(width: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(circuit.displayName)
                    .font(.headline)
                HStack(spacing: 8) {
                    Label("\(circuit.exercises.count) exercises", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("\(circuit.durationMinutes)min", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let date = lastPlayed {
                    Text("Last: \(Self.dateFormatter.string(from: date))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Circuit Detail Sheet

struct CircuitDetailSheet: View {
    @Environment(SeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let circuit: CardioCircuit
    let onStart: () -> Void
    let onEdit: (CardioCircuit) -> Void

    private var lastPlayed: Date? {
        store.cardioLog.first(where: { $0.circuitId == circuit.id })?.startedAt
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Header card
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            Image(systemName: circuit.format.icon)
                                .font(.system(size: 36))
                                .foregroundStyle(circuit.format.color)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(circuit.format.rawValue)
                                    .font(.caption.bold())
                                    .foregroundStyle(circuit.format.color)
                                Text(circuit.format.fullName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(circuit.durationMinutes)")
                                    .font(.title.bold())
                                Text("minutes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                        Text(circuit.format.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))

                    // Last played
                    if let date = lastPlayed {
                        Label("Last played: \(Self.dateFormatter.string(from: date))", systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Exercises
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Exercises")
                            .font(.headline)
                        ForEach(circuit.exercises) { ce in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ce.exercise.name)
                                        .font(.subheadline)
                                    HStack(spacing: 6) {
                                        Text(circuit.format == .amrap ? "\(ce.targetReps) reps/round" : "\(ce.targetReps) reps/min")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let w = ce.weight, w > 0 {
                                            Text(String(format: "· %.1f kg", w))
                                                .font(.caption)
                                                .foregroundStyle(HONTheme.accent.opacity(0.8))
                                        }
                                    }
                                }
                                Spacer()
                                Image(systemName: ce.weight != nil ? "dumbbell.fill" : "figure.run")
                                    .foregroundStyle(ce.weight != nil ? HONTheme.accent.opacity(0.7) : .secondary)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        Button {
                            onEdit(circuit)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.primary)
                        }

                        Button {
                            dismiss()
                            onStart()
                        } label: {
                            Label("Start", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(circuit.format.color, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(HONTheme.textPrimary)
                        }
                    }
                    .fontWeight(.semibold)
                }
                .padding()
            }
            .navigationTitle(circuit.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Circuit Builder View

struct CircuitBuilderView: View {
    @Environment(SeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var circuit: CardioCircuit
    @State private var showExercisePicker = false

    private let durations = [10, 15, 20, 25, 30, 45, 60]
    private let isEditing: Bool

    init(circuit: CardioCircuit?) {
        let c = circuit ?? CardioCircuit()
        _circuit = State(initialValue: c)
        isEditing = circuit != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Circuit Name") {
                    TextField("e.g. Morning Cardio Blast", text: $circuit.name)
                }

                Section("Format") {
                    Picker("Format", selection: $circuit.format) {
                        ForEach(CircuitFormat.allCases, id: \.self) { format in
                            Label(format.rawValue, systemImage: format.icon)
                                .tag(format)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(circuit.format.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Duration") {
                    Picker("Duration", selection: $circuit.durationMinutes) {
                        ForEach(durations, id: \.self) { d in
                            Text("\(d) min").tag(d)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }

                Section("Schedule") {
                    let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { weekday in
                            let isOn = circuit.assignedDays.contains(weekday)
                            Button {
                                if isOn {
                                    circuit.assignedDays.removeAll { $0 == weekday }
                                } else {
                                    circuit.assignedDays.append(weekday)
                                }
                            } label: {
                                Text(dayNames[weekday - 1])
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(isOn ? HONTheme.accent : Color.secondary.opacity(0.12),
                                                in: RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(isOn ? Color.black : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section {
                    ForEach($circuit.exercises) { $ce in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ce.exercise.name)
                                    .font(.subheadline)
                                Text(circuit.format == .amrap ? "reps per round" : "reps per minute")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            // Weight input (optional — nil = bodyweight)
                            HStack(spacing: 4) {
                                Image(systemName: "scalemass")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                TextField("BW", text: Binding(
                                    get: { ce.weight.map { String(format: "%.1f", $0) } ?? "" },
                                    set: { newVal in
                                        let trimmed = newVal.trimmingCharacters(in: .whitespaces)
                                        ce.weight = trimmed.isEmpty ? nil : Double(trimmed)
                                    }
                                ))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                                .font(.subheadline)
                                Text("kg")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Stepper("\(ce.targetReps)", value: $ce.targetReps, in: 1...100)
                                .fixedSize()
                        }
                    }
                    .onMove { from, to in
                        circuit.exercises.move(fromOffsets: from, toOffset: to)
                    }
                    .onDelete { idx in
                        circuit.exercises.remove(atOffsets: idx)
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                    }
                } header: {
                    HStack {
                        Text("Exercises")
                        Spacer()
                        EditButton()
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Circuit" : "New Circuit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.saveCircuit(circuit)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(circuit.exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { exercise, _ in
                    circuit.exercises.append(CircuitExercise(exercise: exercise, targetReps: 10))
                }
                .environment(store)
            }
        }
    }
}
