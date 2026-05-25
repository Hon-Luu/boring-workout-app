import SwiftUI
import WatchKit

// MARK: - Watch Local Storage

@Observable
class WatchLocalStorage {
    static let shared = WatchLocalStorage()

    private let exercisesKey = "watchExercises"
    private let workoutLogKey = "watchWorkoutLog"
    private let templatesKey = "watchTemplates"

    var exercises: [WatchExercise] = []
    var workoutLog: [WatchWorkoutEntry] = []
    var templates: [WatchTemplate] = []

    private init() {
        loadData()
        if exercises.isEmpty {
            seedDefaultExercises()
        }
    }

    func saveData() {
        if let data = try? JSONEncoder().encode(exercises) {
            UserDefaults.standard.set(data, forKey: exercisesKey)
        }
        if let data = try? JSONEncoder().encode(workoutLog) {
            UserDefaults.standard.set(data, forKey: workoutLogKey)
        }
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: templatesKey)
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: exercisesKey),
           let decoded = try? JSONDecoder().decode([WatchExercise].self, from: data) {
            exercises = decoded
        }
        if let data = UserDefaults.standard.data(forKey: workoutLogKey),
           let decoded = try? JSONDecoder().decode([WatchWorkoutEntry].self, from: data) {
            workoutLog = decoded
        }
        if let data = UserDefaults.standard.data(forKey: templatesKey),
           let decoded = try? JSONDecoder().decode([WatchTemplate].self, from: data) {
            templates = decoded
        }
    }

    func logWorkout(exercise: WatchExercise, sets: [WatchSetData]) {
        let entry = WatchWorkoutEntry(
            id: UUID(),
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            date: Date(),
            sets: sets
        )
        workoutLog.insert(entry, at: 0)
        saveData()
    }

    func getLastWorkout(for exerciseId: UUID) -> WatchWorkoutEntry? {
        workoutLog.first { $0.exerciseId == exerciseId }
    }

    private func seedDefaultExercises() {
        exercises = [
            // Chest
            WatchExercise(id: UUID(), name: "Bench Press", bodyPart: "Chest", icon: "rectangle.stack.fill"),
            WatchExercise(id: UUID(), name: "Incline Press", bodyPart: "Chest", icon: "rectangle.stack.fill"),
            WatchExercise(id: UUID(), name: "Push Ups", bodyPart: "Chest", icon: "figure.strengthtraining.traditional"),

            // Back
            WatchExercise(id: UUID(), name: "Deadlift", bodyPart: "Back", icon: "figure.strengthtraining.traditional"),
            WatchExercise(id: UUID(), name: "Barbell Row", bodyPart: "Back", icon: "figure.strengthtraining.traditional"),
            WatchExercise(id: UUID(), name: "Pull Ups", bodyPart: "Back", icon: "figure.strengthtraining.traditional"),
            WatchExercise(id: UUID(), name: "Lat Pulldown", bodyPart: "Back", icon: "figure.strengthtraining.traditional"),

            // Shoulders
            WatchExercise(id: UUID(), name: "Overhead Press", bodyPart: "Shoulders", icon: "figure.arms.open"),
            WatchExercise(id: UUID(), name: "Lateral Raises", bodyPart: "Shoulders", icon: "figure.arms.open"),

            // Arms
            WatchExercise(id: UUID(), name: "Bicep Curls", bodyPart: "Arms", icon: "figure.strengthtraining.functional"),
            WatchExercise(id: UUID(), name: "Tricep Dips", bodyPart: "Arms", icon: "figure.strengthtraining.functional"),
            WatchExercise(id: UUID(), name: "Hammer Curls", bodyPart: "Arms", icon: "figure.strengthtraining.functional"),

            // Legs
            WatchExercise(id: UUID(), name: "Squat", bodyPart: "Legs", icon: "figure.walk"),
            WatchExercise(id: UUID(), name: "Leg Press", bodyPart: "Legs", icon: "figure.walk"),
            WatchExercise(id: UUID(), name: "Lunges", bodyPart: "Legs", icon: "figure.walk"),
            WatchExercise(id: UUID(), name: "Leg Curl", bodyPart: "Legs", icon: "figure.walk"),
            WatchExercise(id: UUID(), name: "Calf Raises", bodyPart: "Legs", icon: "figure.walk"),

            // Core
            WatchExercise(id: UUID(), name: "Plank", bodyPart: "Core", icon: "figure.core.training"),
            WatchExercise(id: UUID(), name: "Crunches", bodyPart: "Core", icon: "figure.core.training"),
        ]
        saveData()
    }
}

// MARK: - Watch Data Models

struct WatchExercise: Identifiable, Codable {
    let id: UUID
    let name: String
    let bodyPart: String
    let icon: String
}

struct WatchSetData: Identifiable, Codable {
    let id: UUID
    var setNumber: Int
    var weight: Double
    var reps: Int
    var isComplete: Bool
}

struct WatchWorkoutEntry: Identifiable, Codable {
    let id: UUID
    let exerciseId: UUID
    let exerciseName: String
    let date: Date
    let sets: [WatchSetData]

    var totalVolume: Double {
        sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
}

struct WatchTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var exerciseIds: [UUID]
}

// MARK: - Standalone Main View

struct StandaloneMainView: View {
    @State private var storage = WatchLocalStorage.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Quick Start
            StandaloneQuickStartView()
                .tag(0)

            // History
            StandaloneHistoryView()
                .tag(1)

            // Browse Exercises
            StandaloneBrowseView()
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Quick Start View

struct StandaloneQuickStartView: View {
    @State private var storage = WatchLocalStorage.shared
    @State private var selectedExercise: WatchExercise?

    // Recent exercises (last 5 unique)
    private var recentExercises: [WatchExercise] {
        var seen = Set<UUID>()
        var result: [WatchExercise] = []

        for entry in storage.workoutLog.prefix(20) {
            if !seen.contains(entry.exerciseId),
               let exercise = storage.exercises.first(where: { $0.id == entry.exerciseId }) {
                seen.insert(entry.exerciseId)
                result.append(exercise)
            }
            if result.count >= 5 { break }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Quick Start")
                    .font(.headline)

                if recentExercises.isEmpty {
                    Text("Start your first workout!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(recentExercises) { exercise in
                        Button {
                            selectedExercise = exercise
                        } label: {
                            HStack {
                                Image(systemName: exercise.icon)
                                    .foregroundColor(.blue)

                                Text(exercise.name)
                                    .font(.caption)
                                    .lineLimit(1)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Browse all button
                NavigationLink {
                    StandaloneBrowseView()
                } label: {
                    Text("Browse All")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .sheet(item: $selectedExercise) { exercise in
            StandaloneWorkoutView(exercise: exercise)
        }
    }
}

// MARK: - Browse Exercises View

struct StandaloneBrowseView: View {
    @State private var storage = WatchLocalStorage.shared
    @State private var selectedExercise: WatchExercise?

    private var bodyParts: [String] {
        Array(Set(storage.exercises.map { $0.bodyPart })).sorted()
    }

    var body: some View {
        List {
            ForEach(bodyParts, id: \.self) { bodyPart in
                Section(bodyPart) {
                    ForEach(storage.exercises.filter { $0.bodyPart == bodyPart }) { exercise in
                        Button {
                            selectedExercise = exercise
                        } label: {
                            HStack {
                                Text(exercise.name)
                                    .font(.caption)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Exercises")
        .sheet(item: $selectedExercise) { exercise in
            StandaloneWorkoutView(exercise: exercise)
        }
    }
}

// MARK: - Standalone Workout View

struct StandaloneWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var storage = WatchLocalStorage.shared

    let exercise: WatchExercise

    @State private var sets: [WatchSetData] = []
    @State private var currentSetIndex = 0
    @State private var showRestTimer = false
    @State private var restTimeRemaining = 90
    @State private var isComplete = false

    private var lastWorkout: WatchWorkoutEntry? {
        storage.getLastWorkout(for: exercise.id)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header
            Text(exercise.name)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            if showRestTimer {
                // Rest timer
                VStack(spacing: 8) {
                    Text("REST")
                        .font(.caption2)
                        .foregroundColor(.orange)

                    Text(formatTime(restTimeRemaining))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)

                    Button("Skip") {
                        WKInterfaceDevice.current().play(.click)
                        showRestTimer = false
                        currentSetIndex += 1
                    }
                    .font(.caption2)
                }
            } else if isComplete {
                // Completion view
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)

                    Text("Workout Complete!")
                        .font(.headline)

                    Button("Done") {
                        saveAndDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if currentSetIndex < sets.count {
                // Active set
                StandaloneSetView(
                    setData: $sets[currentSetIndex],
                    previousSet: lastWorkout?.sets.first { $0.setNumber == currentSetIndex + 1 },
                    onComplete: {
                        completeSet()
                    }
                )

                // Set indicator
                HStack(spacing: 4) {
                    ForEach(0..<sets.count, id: \.self) { index in
                        Circle()
                            .fill(index < currentSetIndex ? Color.green :
                                    index == currentSetIndex ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 4)

                // Add set button
                Button {
                    addSet()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .onAppear {
            initializeSets()
            startRestTimerIfNeeded()
        }
    }

    private func initializeSets() {
        if let last = lastWorkout {
            // Copy from last workout
            sets = last.sets.map { prev in
                WatchSetData(
                    id: UUID(),
                    setNumber: prev.setNumber,
                    weight: prev.weight,
                    reps: prev.reps,
                    isComplete: false
                )
            }
        } else {
            // Default 3 sets
            sets = (1...3).map { num in
                WatchSetData(
                    id: UUID(),
                    setNumber: num,
                    weight: 0,
                    reps: 10,
                    isComplete: false
                )
            }
        }
    }

    private func addSet() {
        let nextNum = (sets.map { $0.setNumber }.max() ?? 0) + 1
        let lastSet = sets.last
        sets.append(WatchSetData(
            id: UUID(),
            setNumber: nextNum,
            weight: lastSet?.weight ?? 0,
            reps: lastSet?.reps ?? 10,
            isComplete: false
        ))
        WKInterfaceDevice.current().play(.click)
    }

    private func completeSet() {
        WKInterfaceDevice.current().play(.success)
        sets[currentSetIndex].isComplete = true

        if currentSetIndex >= sets.count - 1 {
            // All sets complete
            isComplete = true
        } else {
            // Start rest timer
            restTimeRemaining = 90
            showRestTimer = true
            startRestTimerIfNeeded()
        }
    }

    private func startRestTimerIfNeeded() {
        guard showRestTimer else { return }

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if restTimeRemaining > 0 {
                restTimeRemaining -= 1

                if restTimeRemaining <= 3 && restTimeRemaining > 0 {
                    WKInterfaceDevice.current().play(.click)
                }

                if restTimeRemaining == 0 {
                    timer.invalidate()
                    WKInterfaceDevice.current().play(.notification)
                    showRestTimer = false
                    currentSetIndex += 1
                }
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func saveAndDismiss() {
        let completedSets = sets.filter { $0.isComplete }
        if !completedSets.isEmpty {
            storage.logWorkout(exercise: exercise, sets: completedSets)
        }
        dismiss()
    }
}

// MARK: - Standalone Set View

struct StandaloneSetView: View {
    @Binding var setData: WatchSetData
    let previousSet: WatchSetData?
    let onComplete: () -> Void

    @State private var tempWeight: Double
    @State private var tempReps: Int

    init(setData: Binding<WatchSetData>, previousSet: WatchSetData?, onComplete: @escaping () -> Void) {
        self._setData = setData
        self.previousSet = previousSet
        self.onComplete = onComplete
        self._tempWeight = State(initialValue: setData.wrappedValue.weight)
        self._tempReps = State(initialValue: setData.wrappedValue.reps)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Weight
            HStack {
                Button {
                    tempWeight = max(0, tempWeight - 2.5)
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)

                VStack(spacing: 0) {
                    Text("\(Int(tempWeight))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("kg")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 60)

                Button {
                    tempWeight += 2.5
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)
            }

            // Reps
            HStack {
                Button {
                    tempReps = max(1, tempReps - 1)
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)

                VStack(spacing: 0) {
                    Text("\(tempReps)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("reps")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 60)

                Button {
                    tempReps += 1
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)
            }

            // Previous reference
            if let prev = previousSet {
                Text("Last: \(Int(prev.weight))kg × \(prev.reps)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Complete button
            Button {
                setData.weight = tempWeight
                setData.reps = tempReps
                onComplete()
            } label: {
                Image(systemName: "checkmark")
                    .font(.title2)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }
}

// MARK: - History View

struct StandaloneHistoryView: View {
    @State private var storage = WatchLocalStorage.shared

    private var groupedByDate: [(date: Date, entries: [WatchWorkoutEntry])] {
        let calendar = Calendar.current
        var groups: [Date: [WatchWorkoutEntry]] = [:]

        for entry in storage.workoutLog {
            let day = calendar.startOfDay(for: entry.date)
            groups[day, default: []].append(entry)
        }

        return groups.map { (date: $0.key, entries: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if storage.workoutLog.isEmpty {
                Text("No workouts yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(groupedByDate.prefix(7), id: \.date) { group in
                    Section(formatDate(group.date)) {
                        ForEach(group.entries) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.exerciseName)
                                    .font(.caption)

                                Text("\(entry.sets.count) sets")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    StandaloneMainView()
}
