import Foundation
import Observation

// MARK: - HomeCache

/// Lightweight cache for HomeView computed values — rebuilt on background thread.
struct HomeCache {
    let progressTrend: [ExerciseProgress]
    let readiness: ReadinessState
    let todayHints: [UUID: ExerciseTodayHint]
    let exerciseNotes: [UUID: String]

    static let empty = HomeCache(
        progressTrend: [],
        readiness: ReadinessEngine.compute(log: []),
        todayHints: [:],
        exerciseNotes: [:]
    )

    static func build(
        log: [WorkoutLogEntry],
        exercises: [Exercise],
        routines: [WorkoutTemplate]
    ) -> HomeCache {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let todayIds: [UUID] = routines.flatMap { r in
            r.exercises.filter { $0.assignedDays.contains(weekday) }.map(\.exercise.id)
        }
        let hints = WorkoutFeedbackEngine.todayHints(for: todayIds, in: log)
        var notes: [UUID: String] = [:]
        for id in todayIds { notes[id] = WorkoutFeedbackEngine.exerciseNote(for: id, in: log) }
        return HomeCache(
            progressTrend: WorkoutFeedbackEngine.progressTrend(log: log),
            readiness: ReadinessEngine.compute(log: log),
            todayHints: hints,
            exerciseNotes: notes
        )
    }

    /// Single O(n_log) pass: builds both last-performance and full history caches.
    static func buildExerciseCaches(log: [WorkoutLogEntry]) -> (
        lastPerf: [UUID: [SetRecord]],
        history: [UUID: [(date: Date, sets: [SetRecord])]]
    ) {
        var lpCache: [UUID: [SetRecord]] = [:]
        var histMap: [UUID: [(date: Date, sets: [SetRecord])]] = [:]
        for entry in log {
            for we in entry.exercises {
                let sets = we.completedSets
                guard !sets.isEmpty else { continue }
                if lpCache[we.exercise.id] == nil { lpCache[we.exercise.id] = sets }
                histMap[we.exercise.id, default: []].append((entry.startedAt, sets))
            }
        }
        // histMap entries are in log order (newest first since log is newest-first); cap at 20
        let histCache = histMap.mapValues { Array($0.prefix(20)) }
        return (lpCache, histCache)
    }
}

@Observable
class SeedStore {
    static let shared = SeedStore()

    // MARK: - State

    var workoutLog: [WorkoutLogEntry] = []
    var personalRecords: [UUID: PersonalRecord] = [:]
    var activeWorkout: WorkoutLogEntry? = nil
    var newPRs: [PersonalRecord] = []
    var routines: [WorkoutTemplate] = []
    var activeTemplateId: UUID? = nil
    private(set) var analyticsCache: AnalyticsResult = .empty
    private(set) var homeCache: HomeCache = .empty
    /// O(1) lookup: exerciseId → most recent completed sets.
    private(set) var lastPerformanceCache: [UUID: [SetRecord]] = [:]
    /// O(1) lookup: exerciseId → sessions newest-first (capped 20). Used by ExerciseCard history matrix.
    private(set) var exerciseHistoryCache: [UUID: [(date: Date, sets: [SetRecord])]] = [:]
    /// True once the background init load has finished — UI should wait on this.
    private(set) var isLoaded: Bool = false
    var cardioCircuits: [CardioCircuit] = []
    var cardioLog: [CardioLogEntry] = []
    var restDays: [Date] = []
    var pendingWeightSuggestions: [WeightSuggestion] = []
    var userProfile: UserProfile = UserProfile() {
        didSet {
            guard isLoaded else { return }   // suppress during background load
            saveUserProfile()
            refreshAnalytics()
        }
    }

    // Token for in-flight analytics tasks — only the most-recent result is applied.
    private var analyticsPendingToken = UUID()

    // MARK: - Apple Watch

    let watchManager = WatchConnectivityManager.shared

    // Call when the active workout exercise changes so Watch shows the right name
    func notifyWatchActiveExercise(index: Int) {
        guard let workout = activeWorkout,
              index < workout.exercises.count else { return }
        watchManager.sendActiveExercise(workout.exercises[index].exercise.name)
    }

    // Call before a set begins so Watch knows to start recording
    func notifyWatchSetStarted(exerciseIndex: Int, setIndex: Int) {
        guard let workout = activeWorkout,
              exerciseIndex < workout.exercises.count else { return }
        let name = workout.exercises[exerciseIndex].exercise.name
        watchManager.sendSetStarted(exerciseName: name)
    }

    // Attach the Watch velocity profile to a completed set
    func attachVelocityProfile(_ profile: SetVelocityProfile,
                                exerciseIndex: Int, setIndex: Int) {
        guard activeWorkout != nil,
              exerciseIndex < activeWorkout!.exercises.count,
              setIndex < activeWorkout!.exercises[exerciseIndex].sets.count else { return }
        activeWorkout!.exercises[exerciseIndex].sets[setIndex].velocityProfile = profile
    }

    let exercises: [Exercise] = SeedStore.buildExerciseDatabase()

    // MARK: - Computed

    var currentStreak: Int {
        guard !workoutLog.isEmpty else { return 0 }
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        for entry in workoutLog {
            let entryDay = calendar.startOfDay(for: entry.startedAt)
            if entryDay == checkDate || entryDay == calendar.date(byAdding: .day, value: -1, to: checkDate)! {
                if entryDay != checkDate { checkDate = entryDay }
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Workout Management

    func startWorkout() {
        let entry = WorkoutLogEntry(startedAt: Date(), exercises: [])
        activeWorkout = entry
        pendingWeightSuggestions = computeWeightSuggestions(for: entry)
        watchManager.sendWorkoutStarted()
    }

    func addExercise(_ exercise: Exercise) {
        guard activeWorkout != nil else { return }
        let last = lastPerformance(for: exercise)
        let sets: [SetRecord] = last.isEmpty
            ? (0..<3).map { _ in SetRecord(weight: 0, reps: 0, targetWeight: 0, targetReps: 0) }
            : last.map { prev in
                SetRecord(
                    weight: prev.weight,
                    reps: 0,
                    targetWeight: prev.weight,
                    targetReps: prev.reps
                )
            }
        let we = WorkoutExercise(exercise: exercise, sets: sets)
        activeWorkout!.exercises.append(we)
    }

    func removeExercise(at index: Int) {
        guard activeWorkout != nil, index < activeWorkout!.exercises.count else { return }
        activeWorkout!.exercises.remove(at: index)
    }

    func addSet(toExercise exerciseIndex: Int) {
        guard activeWorkout != nil, exerciseIndex < activeWorkout!.exercises.count else { return }
        let last = activeWorkout!.exercises[exerciseIndex].sets.last
        let newSet = SetRecord(
            weight: last?.weight ?? 0,
            reps: last?.reps ?? 0,
            targetWeight: last?.targetWeight ?? last?.weight ?? 0,
            targetReps: last?.targetReps ?? last?.reps ?? 0
        )
        activeWorkout!.exercises[exerciseIndex].sets.append(newSet)
    }

    func removeSet(exerciseIndex: Int, setIndex: Int) {
        guard activeWorkout != nil,
              exerciseIndex < activeWorkout!.exercises.count,
              setIndex < activeWorkout!.exercises[exerciseIndex].sets.count else { return }
        activeWorkout!.exercises[exerciseIndex].sets.remove(at: setIndex)
    }

    func updateSet(exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int) {
        guard activeWorkout != nil,
              exerciseIndex < activeWorkout!.exercises.count,
              setIndex < activeWorkout!.exercises[exerciseIndex].sets.count else { return }
        activeWorkout!.exercises[exerciseIndex].sets[setIndex].weight = weight
        activeWorkout!.exercises[exerciseIndex].sets[setIndex].reps = reps
    }

    /// Weeks since the user's first recorded workout — used for neural vs. hypertrophy phase labeling.
    var trainingAgeWeeks: Int {
        guard let first = workoutLog.min(by: { $0.startedAt < $1.startedAt })?.startedAt else { return 0 }
        return max(0, Int(Date().timeIntervalSince(first) / (7 * 86_400)))
    }

    func updateSetRPE(exerciseIndex: Int, setIndex: Int, rpe: Double?) {
        guard activeWorkout != nil,
              exerciseIndex < activeWorkout!.exercises.count,
              setIndex < activeWorkout!.exercises[exerciseIndex].sets.count else { return }
        activeWorkout!.exercises[exerciseIndex].sets[setIndex].rpe = rpe
    }

    func updateSetFailure(exerciseIndex: Int, setIndex: Int, toFailure: Bool) {
        guard activeWorkout != nil,
              exerciseIndex < activeWorkout!.exercises.count,
              setIndex < activeWorkout!.exercises[exerciseIndex].sets.count else { return }
        activeWorkout!.exercises[exerciseIndex].sets[setIndex].toFailure = toFailure
    }

    func updateSetDrop(exerciseIndex: Int, setIndex: Int, dropWeight: Double?, dropReps: Int?) {
        guard activeWorkout != nil,
              exerciseIndex < activeWorkout!.exercises.count,
              setIndex < activeWorkout!.exercises[exerciseIndex].sets.count else { return }
        activeWorkout!.exercises[exerciseIndex].sets[setIndex].dropWeight = dropWeight
        activeWorkout!.exercises[exerciseIndex].sets[setIndex].dropReps  = dropReps
    }

    func completeDropSet(exerciseIndex: Int, setIndex: Int) {
        guard activeWorkout != nil,
              exerciseIndex < activeWorkout!.exercises.count,
              setIndex < activeWorkout!.exercises[exerciseIndex].sets.count else { return }
        activeWorkout!.exercises[exerciseIndex].sets[setIndex].isDropCompleted = true
    }

    func uncompleteDropSet(exerciseIndex: Int, setIndex: Int) {
        guard activeWorkout != nil,
              exerciseIndex < activeWorkout!.exercises.count,
              setIndex < activeWorkout!.exercises[exerciseIndex].sets.count else { return }
        activeWorkout!.exercises[exerciseIndex].sets[setIndex].isDropCompleted = false
    }

    func updateSetTarget(exerciseIndex: Int, setIndex: Int, targetWeight: Double, targetReps: Int) {
        guard activeWorkout != nil,
              exerciseIndex < activeWorkout!.exercises.count,
              setIndex < activeWorkout!.exercises[exerciseIndex].sets.count else { return }
        // Propagate targetReps to every set so the coach evaluates all sets consistently.
        // (Changing "I want 10 reps" is an intent for the whole exercise, not just one set.)
        for i in activeWorkout!.exercises[exerciseIndex].sets.indices {
            activeWorkout!.exercises[exerciseIndex].sets[i].targetReps = targetReps
        }
        activeWorkout!.exercises[exerciseIndex].sets[setIndex].targetWeight = targetWeight
    }

    func applyWeightSuggestion(exerciseId: UUID, weightKg: Double) {
        guard activeWorkout != nil,
              let exIdx = activeWorkout!.exercises.firstIndex(where: { $0.exercise.id == exerciseId }) else { return }
        for i in activeWorkout!.exercises[exIdx].sets.indices {
            activeWorkout!.exercises[exIdx].sets[i].weight       = weightKg
            activeWorkout!.exercises[exIdx].sets[i].targetWeight = weightKg
        }
    }

    func clearWeightSuggestions() {
        pendingWeightSuggestions = []
    }

    private func computeWeightSuggestions(for workout: WorkoutLogEntry) -> [WeightSuggestion] {
        var suggestions: [WeightSuggestion] = []
        for we in workout.exercises {
            let last = lastPerformance(for: we.exercise)
            guard !last.isEmpty else { continue }
            let currentWeight = last.first?.weight ?? 0
            guard currentWeight > 0 else { continue }

            let totalActual = last.reduce(0) { $0 + $1.reps }
            let totalTarget = last.reduce(0) { $0 + max($1.targetReps, 1) }
            let pct = Double(totalActual) / Double(max(totalTarget, 1))
            guard pct >= 0.90 else { continue }

            let increment       = we.exercise.isCompound ? 2.5 : 1.25
            let suggestedWeight = currentWeight + increment
            let reason          = pct > 1.10 ? "Exceeded target reps last session"
                                             : "Hit all reps last session"

            suggestions.append(WeightSuggestion(
                id: UUID(),
                exerciseId: we.exercise.id,
                exerciseName: we.exercise.name,
                currentWeightKg: currentWeight,
                suggestedWeightKg: suggestedWeight,
                reason: reason,
                isCompound: we.exercise.isCompound
            ))
        }
        return suggestions
    }

    func completeSet(exerciseIndex: Int, setIndex: Int) {
        guard activeWorkout != nil,
              exerciseIndex < activeWorkout!.exercises.count,
              setIndex < activeWorkout!.exercises[exerciseIndex].sets.count else { return }
        activeWorkout!.exercises[exerciseIndex].sets[setIndex].isCompleted = true
        activeWorkout!.exercises[exerciseIndex].sets[setIndex].completedAt = Date()
    }

    func finishWorkout(feel: FeelRating? = nil) {
        watchManager.sendWorkoutEnded()
        guard var workout = activeWorkout else { return }
        workout.finishedAt = Date()
        workout.feelRating = feel

        if workout.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let regions = workout.exercises.map(\.exercise.bodyRegion.rawValue)
            let unique = NSOrderedSet(array: regions).array as! [String]
            workout.name = unique.prefix(2).joined(separator: " & ") + " Workout"
        }

        // Detect PRs
        newPRs = []
        for we in workout.exercises {
            for set in we.completedSets {
                let e1rm = set.estimated1RM
                if e1rm > 0 {
                    let existing = personalRecords[we.exercise.id]
                    if existing == nil || e1rm > existing!.estimated1RM {
                        let pr = PersonalRecord(
                            exerciseId: we.exercise.id,
                            exerciseName: we.exercise.name,
                            weight: set.weight,
                            reps: set.reps,
                            estimated1RM: e1rm,
                            date: Date()
                        )
                        personalRecords[we.exercise.id] = pr
                        if existing != nil { newPRs.append(pr) }
                    }
                }
            }
        }

        workoutLog.insert(workout, at: 0)
        activeWorkout = nil
        activeTemplateId = nil
        save()
        refreshAnalytics()
        UserCoachProfileEngine.refreshIfNeeded(log: workoutLog)
    }

    func setReadinessBefore(_ rating: Int) {
        guard activeWorkout != nil else { return }
        activeWorkout!.readinessBefore = rating
    }

    func uncompleteSet(exerciseIndex: Int, setIndex: Int) {
        guard activeWorkout != nil,
              exerciseIndex < activeWorkout!.exercises.count,
              setIndex < activeWorkout!.exercises[exerciseIndex].sets.count else { return }
        activeWorkout!.exercises[exerciseIndex].sets[setIndex].isCompleted = false
        activeWorkout!.exercises[exerciseIndex].sets[setIndex].completedAt = nil
    }

    func updateWorkoutHeartRate(id: UUID, bpm: Double) {
        guard let i = workoutLog.firstIndex(where: { $0.id == id }) else { return }
        workoutLog[i].averageHeartRate = bpm
        save()
    }

    func updateWorkoutCalories(id: UUID, calories: Double) {
        guard let i = workoutLog.firstIndex(where: { $0.id == id }) else { return }
        workoutLog[i].activeCalories = calories
        save()
    }

    func updateLoggedEntry(_ entry: WorkoutLogEntry) {
        guard let i = workoutLog.firstIndex(where: { $0.id == entry.id }) else { return }
        workoutLog[i] = entry
        save()
        refreshAnalytics()
    }

    func deleteWorkoutLogEntry(id: UUID) {
        workoutLog.removeAll { $0.id == id }
        save()
        refreshAnalytics()
    }

    func deleteExerciseFromWorkout(workoutId: UUID, exerciseId: UUID) {
        guard let wi = workoutLog.firstIndex(where: { $0.id == workoutId }) else { return }
        workoutLog[wi].exercises.removeAll { $0.exercise.id == exerciseId }
        if workoutLog[wi].exercises.isEmpty {
            workoutLog.remove(at: wi)
        }
        save()
        refreshAnalytics()
    }

    func discardWorkout() {
        activeWorkout = nil
        activeTemplateId = nil
    }

    var isTodayRestDay: Bool {
        let cal = Calendar.current
        return restDays.contains { cal.isDateInToday($0) }
    }

    func logRestDay() {
        guard !isTodayRestDay else { return }
        restDays.append(Date())
        saveRestDays()
    }

    func removeRestDay(for date: Date) {
        let cal = Calendar.current
        restDays.removeAll { cal.isDate($0, inSameDayAs: date) }
        saveRestDays()
    }

    private func saveRestDays() {
        let days = restDays
        let key = restDaysKey
        DispatchQueue.global(qos: .background).async {
            if let data = try? JSONEncoder().encode(days) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    func swapExercise(at index: Int, with exercise: Exercise) {
        guard activeWorkout != nil, index < activeWorkout!.exercises.count else { return }
        let existing = activeWorkout!.exercises[index]
        let last = lastPerformance(for: exercise)
        // Preserve any already-completed sets; replace only uncompleted sets with
        // last-performance targets for the new exercise.
        let sets: [SetRecord] = existing.sets.enumerated().map { i, current in
            guard !current.isCompleted else { return current }
            let ref = last.indices.contains(i) ? last[i] : last.first
            return SetRecord(
                weight: ref?.weight ?? 0,
                reps: 0,
                targetWeight: ref?.weight ?? 0,
                targetReps: ref?.reps ?? 0
            )
        }
        activeWorkout!.exercises[index] = WorkoutExercise(exercise: exercise, sets: sets)
    }

    // MARK: - Routine Management

    func todayRoutines() -> [WorkoutTemplate] {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return routines.filter { $0.exercises.contains { $0.assignedDays.contains(weekday) } }
    }

    func todayExercises(for routine: WorkoutTemplate) -> [TemplateExercise] {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return routine.exercises.filter { $0.assignedDays.contains(weekday) }
    }

    func startWorkout(fromRoutine routine: WorkoutTemplate) {
        let weekday = Calendar.current.component(.weekday, from: Date())
        startWorkout(fromRoutine: routine, weekday: weekday)
    }

    /// weekday: nil = all exercises; 1=Sun…7=Sat = that day only
    func startWorkout(fromRoutine routine: WorkoutTemplate, weekday: Int?) {
        let templateExercises: [TemplateExercise]
        if let weekday {
            templateExercises = routine.exercises.filter { $0.assignedDays.contains(weekday) }
        } else {
            templateExercises = routine.exercises
        }

        // Build all WorkoutExercises locally first — assign once to produce a single @Observable notification.
        var workoutExercises: [WorkoutExercise] = []
        for te in templateExercises {
            let last = lastPerformance(for: te.exercise)
            var sets: [SetRecord] = last.isEmpty
                ? (0..<3).map { _ in SetRecord(weight: 0, reps: 0, targetWeight: 0, targetReps: te.targetReps) }
                : last.map { prev in
                    SetRecord(
                        weight: prev.weight, reps: 0,
                        targetWeight: prev.weight,
                        targetReps: te.targetReps > 0 ? te.targetReps : prev.reps
                    )
                }
            // Ensure targetReps from template is applied even when history exists
            for i in sets.indices where sets[i].targetReps == 0 {
                sets[i].targetReps = te.targetReps
            }
            var we = WorkoutExercise(exercise: te.exercise, sets: sets)
            we.supersetGroup = te.supersetGroup
            workoutExercises.append(we)
        }

        var entry = WorkoutLogEntry(startedAt: Date(), exercises: workoutExercises)
        entry.name = routine.name
        activeWorkout = entry
        activeTemplateId = routine.id
        pendingWeightSuggestions = computeWeightSuggestions(for: entry)
        watchManager.sendWorkoutStarted()
    }

    func addOrUpdateRoutine(_ routine: WorkoutTemplate) {
        if let i = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[i] = routine
        } else {
            routines.append(routine)
        }
        saveRoutines()
    }

    func deleteRoutine(id: UUID) {
        routines.removeAll { $0.id == id }
        saveRoutines()
    }

    func swapExerciseInTemplate(oldExerciseId: UUID, with newExercise: Exercise) {
        guard let ri = routines.firstIndex(where: { $0.id == activeTemplateId }),
              let ei = routines[ri].exercises.firstIndex(where: { $0.exercise.id == oldExerciseId })
        else { return }
        let old = routines[ri].exercises[ei]
        routines[ri].exercises[ei] = TemplateExercise(
            exercise: newExercise,
            targetSets: old.targetSets,
            targetReps: old.targetReps,
            assignedDays: old.assignedDays,
            supersetGroup: old.supersetGroup
        )
        saveRoutines()
    }

    // MARK: - Superset Management

    func nextSupersetGroupId() -> String {
        let used = Set((activeWorkout?.exercises ?? []).compactMap(\.supersetGroup))
        for char in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" {
            let s = String(char)
            if !used.contains(s) { return s }
        }
        return "A"
    }

    func linkSuperset(at index: Int) {
        guard activeWorkout != nil,
              index + 1 < activeWorkout!.exercises.count else { return }
        let groupId = activeWorkout!.exercises[index].supersetGroup
                   ?? activeWorkout!.exercises[index + 1].supersetGroup
                   ?? nextSupersetGroupId()
        activeWorkout!.exercises[index].supersetGroup = groupId
        activeWorkout!.exercises[index + 1].supersetGroup = groupId
    }

    func unlinkSuperset(at index: Int) {
        guard activeWorkout != nil, index < activeWorkout!.exercises.count else { return }
        guard let group = activeWorkout!.exercises[index].supersetGroup else { return }
        let members = activeWorkout!.exercises.indices.filter {
            activeWorkout!.exercises[$0].supersetGroup == group
        }
        if members.count <= 2 {
            members.forEach { activeWorkout!.exercises[$0].supersetGroup = nil }
        } else {
            activeWorkout!.exercises[index].supersetGroup = nil
        }
    }

    func saveRoutines() {
        if let data = try? JSONEncoder().encode(routines) {
            UserDefaults.standard.set(data, forKey: templatesKey)
        }
    }

    func persistImport() {
        save()
        refreshAnalytics()
    }

    // MARK: - Cardio Circuit Management

    func saveCircuit(_ circuit: CardioCircuit) {
        if let i = cardioCircuits.firstIndex(where: { $0.id == circuit.id }) {
            cardioCircuits[i] = circuit
        } else {
            cardioCircuits.append(circuit)
        }
        if let data = try? JSONEncoder().encode(cardioCircuits) {
            UserDefaults.standard.set(data, forKey: cardioCircuitsKey)
        }
    }

    func deleteCircuit(id: UUID) {
        cardioCircuits.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(cardioCircuits) {
            UserDefaults.standard.set(data, forKey: cardioCircuitsKey)
        }
    }

    func saveCardioSession(_ entry: CardioLogEntry) {
        cardioLog.insert(entry, at: 0)
        save()
    }

    // MARK: - Lookup

    func lastPerformance(for exercise: Exercise) -> [SetRecord] {
        lastPerformanceCache[exercise.id] ?? []
    }

    /// Returns up to `limit` past sessions for an exercise, newest first. O(1) from cache.
    func exerciseHistory(for exercise: Exercise, limit: Int = 20) -> [(date: Date, sets: [SetRecord])] {
        let sessions = exerciseHistoryCache[exercise.id] ?? []
        return limit >= sessions.count ? sessions : Array(sessions.prefix(limit))
    }

    func personalRecord(for exercise: Exercise) -> PersonalRecord? {
        personalRecords[exercise.id]
    }

    /// Fast chip-render query — O(n_exercises), no log scan.
    /// Returns which equipment types have a variant for the given exercise.
    /// Scopes candidates to the equivalence group when one exists.
    func quickSwapEquipment(for exercise: Exercise) -> [Equipment] {
        let candidates: [Exercise]
        if let equivalentNames = ExerciseEquivalenceMap.equivalentNames(for: exercise) {
            let nameSet = Set(equivalentNames)
            candidates = exercises.filter { nameSet.contains($0.name) }
        } else {
            candidates = exercises.filter {
                $0.id != exercise.id &&
                $0.bodyRegion == exercise.bodyRegion &&
                $0.movementPattern == exercise.movementPattern
            }
        }
        return Equipment.allCases.filter { equip in
            equip != exercise.equipment && candidates.contains { $0.equipment == equip }
        }
    }

    /// Tap-time resolution — called only when the user taps a chip.
    /// Prefers candidates in the same equivalence group; falls back to region+pattern match.
    /// Within candidates, prefers the one with the most recent history, then alphabetically.
    func bestVariant(equipment equip: Equipment, matching exercise: Exercise) -> Exercise? {
        let candidates: [Exercise]
        if let equivalentNames = ExerciseEquivalenceMap.equivalentNames(for: exercise) {
            let nameSet = Set(equivalentNames)
            candidates = exercises.filter { nameSet.contains($0.name) && $0.equipment == equip }
        } else {
            candidates = exercises.filter {
                $0.id != exercise.id &&
                $0.bodyRegion == exercise.bodyRegion &&
                $0.movementPattern == exercise.movementPattern &&
                $0.equipment == equip
            }
        }
        guard !candidates.isEmpty else { return nil }
        return candidates.first(where: { !lastPerformance(for: $0).isEmpty }) ?? candidates[0]
    }

    // MARK: - Persistence

    private let logKey          = "workoutLog_v1"
    private let prKey           = "personalRecords_v1"
    private let seedKey         = "sampleDataSeeded_v4"
    private let templatesKey    = "templates_v1"
    private let userProfileKey  = "userProfile_v1"
    private let cardioCircuitsKey = "cardioCircuits_v1"
    private let cardioLogKey      = "cardioLog_v1"
    private let restDaysKey       = "restDays_v1"

    func saveUserProfile() {
        if let data = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(data, forKey: userProfileKey)
        }
    }

    private func save() {
        let log  = workoutLog
        let prs  = personalRecords
        let cLog = cardioLog
        let lk   = logKey
        let pk   = prKey
        let clk  = cardioLogKey
        DispatchQueue.global(qos: .background).async {
            if let data = try? JSONEncoder().encode(log) {
                UserDefaults.standard.set(data, forKey: lk)
            }
            if let data = try? JSONEncoder().encode(prs) {
                UserDefaults.standard.set(data, forKey: pk)
            }
            if let data = try? JSONEncoder().encode(cLog) {
                UserDefaults.standard.set(data, forKey: clk)
            }
        }
    }

    private init() {
        // Capture keys as locals so the background closure never touches @Observable properties
        let lk = logKey, pk = prKey, tk = templatesKey, upk = userProfileKey, sk = seedKey
        let ck = cardioCircuitsKey, clk = cardioLogKey, rdk = restDaysKey
        let exs = exercises   // `let` — safe to read from any thread

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            var log       = [WorkoutLogEntry]()
            var prs       = [UUID: PersonalRecord]()
            var templates = [WorkoutTemplate]()
            var profile   = UserProfile()
            var circuits  = [CardioCircuit]()
            var cLog      = [CardioLogEntry]()
            var rDays     = [Date]()

            if let d = UserDefaults.standard.data(forKey: lk),
               let v = try? JSONDecoder().decode([WorkoutLogEntry].self, from: d)       { log       = v }
            if let d = UserDefaults.standard.data(forKey: pk),
               let v = try? JSONDecoder().decode([UUID: PersonalRecord].self, from: d)  { prs       = v }
            if let d = UserDefaults.standard.data(forKey: tk),
               let v = try? JSONDecoder().decode([WorkoutTemplate].self, from: d)       { templates = v }
            if let d = UserDefaults.standard.data(forKey: upk),
               let v = try? JSONDecoder().decode(UserProfile.self, from: d)             { profile   = v }
            if let d = UserDefaults.standard.data(forKey: ck),
               let v = try? JSONDecoder().decode([CardioCircuit].self, from: d)         { circuits  = v }
            if let d = UserDefaults.standard.data(forKey: clk),
               let v = try? JSONDecoder().decode([CardioLogEntry].self, from: d)        { cLog      = v }
            if let d = UserDefaults.standard.data(forKey: rdk),
               let v = try? JSONDecoder().decode([Date].self, from: d)                  { rDays     = v }

            let needsSeed = !UserDefaults.standard.bool(forKey: sk)
            if needsSeed {
                log = []; prs = [:]
                UserDefaults.standard.removeObject(forKey: lk)
                UserDefaults.standard.removeObject(forKey: pk)
                UserDefaults.standard.set(true, forKey: sk)
            }

            // Phase 1: hand raw data to main thread immediately — app is visible now.
            DispatchQueue.main.async { [self] in
                workoutLog     = log
                personalRecords = prs
                routines       = templates
                userProfile    = profile   // didSet is no-op while isLoaded == false
                cardioCircuits = circuits
                cardioLog      = cLog
                restDays       = rDays
                isLoaded       = true      // UI appears
                if needsSeed {
                    injectSampleData()
                    refreshAnalytics()     // analytics from seed data, not the empty `log`
                }
            }

            // Phase 2: heavy analytics — runs while UI is already showing.
            // For the seed path refreshAnalytics() above handles it.
            guard !needsSeed else { return }
            let (lpCache, histCache) = HomeCache.buildExerciseCaches(log: log)
            let analytics = StrengthAnalyticsEngine.compute(log: log, exercises: exs, userProfile: profile)
            let home      = HomeCache.build(log: log, exercises: exs, routines: templates)

            DispatchQueue.main.async { [self] in
                analyticsCache       = analytics
                homeCache            = home
                lastPerformanceCache = lpCache
                exerciseHistoryCache = histCache
            }
        }
    }

    func refreshAnalytics() {
        let token        = UUID()
        analyticsPendingToken = token
        let log          = workoutLog
        let exs          = exercises
        let profile      = userProfile
        let routinesCopy = routines
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let (lpCache, histCache) = HomeCache.buildExerciseCaches(log: log)
            let result = StrengthAnalyticsEngine.compute(log: log, exercises: exs, userProfile: profile)
            let home   = HomeCache.build(log: log, exercises: exs, routines: routinesCopy)
            DispatchQueue.main.async {
                guard self?.analyticsPendingToken == token else { return }
                self?.analyticsCache       = result
                self?.homeCache            = home
                self?.lastPerformanceCache = lpCache
                self?.exerciseHistoryCache = histCache
            }
        }
    }

    private func injectSampleData() {
        let cal = Calendar.current
        let todayWeekday = cal.component(.weekday, from: Date())

        func ex(_ name: String) -> Exercise { exercises.first { $0.name == name }! }
        let bench    = ex("Barbell Bench Press")
        let ohp      = ex("Overhead Press")
        let barbRow  = ex("Barbell Row")
        let deadlift = ex("Deadlift")
        let squat    = ex("Barbell Squat")

        // MARK: Inject demo routine (all days so Today's Plan always shows)
        if routines.isEmpty {
            let allDays = [1,2,3,4,5,6,7]
            var routine = WorkoutTemplate(name: "Main Strength")
            routine.exercises = [
                TemplateExercise(exercise: bench,    targetSets: 4, targetReps: 5, assignedDays: allDays),
                TemplateExercise(exercise: squat,    targetSets: 4, targetReps: 5, assignedDays: allDays),
                TemplateExercise(exercise: deadlift, targetSets: 4, targetReps: 5, assignedDays: allDays),
                TemplateExercise(exercise: ohp,      targetSets: 3, targetReps: 8, assignedDays: allDays),
                TemplateExercise(exercise: barbRow,  targetSets: 3, targetReps: 8, assignedDays: allDays),
            ]
            routines = [routine]
            saveRoutines()
        }

        // MARK: Build workout log — 5 sessions over 8 weeks
        // Each session is designed to hit a specific feedback engine branch:
        //   Bench     → "Add weight NOW"      (strong: all sets exceeded target reps)
        //   OHP       → "Standard progression" (2 consecutive clean sessions, score ≥ 72)
        //   Barbell Row → "Close but not ready" (current clean, but avg score 60–71)
        //   Deadlift  → "Deload"              (2+ past sessions struggling, hitRate < 0.75)
        //   Squat     → "Struggling"           (current session below target, 1st occurrence)

        func makeSet(_ weight: Double, _ actual: Int, _ target: Int, _ time: Date) -> SetRecord {
            var s = SetRecord()
            s.weight = weight; s.reps = actual
            s.targetWeight = weight; s.targetReps = target
            s.isCompleted = true; s.completedAt = time
            return s
        }

        func makeWE(_ exercise: Exercise, _ weight: Double, _ reps: [Int], _ targetReps: Int, _ baseDate: Date) -> WorkoutExercise {
            let sets = reps.enumerated().map { i, r in
                makeSet(weight, r, targetReps,
                        baseDate.addingTimeInterval(TimeInterval(i) * 180))
            }
            return WorkoutExercise(exercise: exercise, sets: sets)
        }

        func makeEntry(daysAgo: Int, wes: [WorkoutExercise], name: String) -> WorkoutLogEntry {
            let start = Date().addingTimeInterval(-Double(daysAgo) * 86400)
            var e = WorkoutLogEntry(startedAt: start, exercises: wes)
            e.finishedAt = start.addingTimeInterval(4500)
            e.name = name
            return e
        }

        let s1 = makeEntry(daysAgo: 56, wes: [
            makeWE(bench,    80,    [5,5,5,5], 5, Date().addingTimeInterval(-56*86400)),
            makeWE(ohp,      50,    [8,8,8],   8, Date().addingTimeInterval(-56*86400 + 1200)),
            makeWE(barbRow,  60,    [8,8,8],   8, Date().addingTimeInterval(-56*86400 + 2400)),
            makeWE(deadlift, 140,   [5,5,5,5], 5, Date().addingTimeInterval(-56*86400 + 3600)),
            makeWE(squat,    100,   [5,5,5,5], 5, Date().addingTimeInterval(-56*86400 + 4800)),
        ], name: "Strength Workout")

        let s2 = makeEntry(daysAgo: 42, wes: [
            makeWE(bench,    82.5,  [5,5,5,5], 5, Date().addingTimeInterval(-42*86400)),
            makeWE(ohp,      52.5,  [8,8,8],   8, Date().addingTimeInterval(-42*86400 + 1200)),
            makeWE(barbRow,  62.5,  [8,8,8],   8, Date().addingTimeInterval(-42*86400 + 2400)),
            makeWE(deadlift, 142.5, [5,5,5,5], 5, Date().addingTimeInterval(-42*86400 + 3600)),
            makeWE(squat,    100,   [5,5,5,5], 5, Date().addingTimeInterval(-42*86400 + 4800)),
        ], name: "Strength Workout")

        let s3 = makeEntry(daysAgo: 28, wes: [
            makeWE(bench,    85,    [5,5,5,5], 5, Date().addingTimeInterval(-28*86400)),
            makeWE(ohp,      55,    [8,8,8],   8, Date().addingTimeInterval(-28*86400 + 1200)),
            makeWE(barbRow,  67.5,  [8,8,8],   8, Date().addingTimeInterval(-28*86400 + 2400)),
            // Deadlift starts struggling — hitRate 1/4 = 0.25
            makeWE(deadlift, 142.5, [5,4,3,3], 5, Date().addingTimeInterval(-28*86400 + 3600)),
            makeWE(squat,    100,   [5,5,5,5], 5, Date().addingTimeInterval(-28*86400 + 4800)),
        ], name: "Strength Workout")

        let s4 = makeEntry(daysAgo: 14, wes: [
            makeWE(bench,    90,    [5,5,5,5], 5, Date().addingTimeInterval(-14*86400)),
            makeWE(ohp,      57.5,  [8,8,8],   8, Date().addingTimeInterval(-14*86400 + 1200)),
            // Row misses last set — not clean, score ~46
            makeWE(barbRow,  70,    [8,8,6],   8, Date().addingTimeInterval(-14*86400 + 2400)),
            // Deadlift still struggling — hitRate 1/4 = 0.25
            makeWE(deadlift, 140,   [5,4,3,3], 5, Date().addingTimeInterval(-14*86400 + 3600)),
            makeWE(squat,    100,   [5,5,5,5], 5, Date().addingTimeInterval(-14*86400 + 4800)),
        ], name: "Strength Workout")

        // Most recent session (3 days ago) — this is what the recap card shows
        let s5 = makeEntry(daysAgo: 3, wes: [
            // Bench: all sets +1 rep surplus → isStrong → "Add weight NOW"
            makeWE(bench,    90,    [6,6,6,6], 5, Date().addingTimeInterval(-3*86400)),
            // OHP: 2 consecutive clean sessions, score 75 → "Standard progression"
            makeWE(ohp,      57.5,  [8,8,8],   8, Date().addingTimeInterval(-3*86400 + 1200)),
            // Row: clean this session but avg score ~65 → "Close but not ready"
            makeWE(barbRow,  70,    [8,8,8],   8, Date().addingTimeInterval(-3*86400 + 2400)),
            // Deadlift: 2 past struggling sessions → "Deload to 125kg"
            makeWE(deadlift, 137.5, [5,4,3,3], 5, Date().addingTimeInterval(-3*86400 + 3600)),
            // Squat: struggling this session (first time) → "Hold weight"
            makeWE(squat,    100,   [5,5,4,3], 5, Date().addingTimeInterval(-3*86400 + 4800)),
        ], name: "Strength Workout")

        workoutLog = [s5, s4, s3, s2, s1]

        for entry in workoutLog {
            for we in entry.exercises {
                for set in we.completedSets {
                    let e1rm = set.estimated1RM
                    guard e1rm > 0 else { continue }
                    let existing = personalRecords[we.exercise.id]
                    if existing == nil || e1rm > existing!.estimated1RM {
                        personalRecords[we.exercise.id] = PersonalRecord(
                            exerciseId: we.exercise.id,
                            exerciseName: we.exercise.name,
                            weight: set.weight,
                            reps: set.reps,
                            estimated1RM: e1rm,
                            date: entry.startedAt
                        )
                    }
                }
            }
        }
        save()
    }

    // MARK: - UAT

    #if DEBUG
    /// Replaces the entire workout log with `log`, rebuilds personal records, and refreshes analytics.
    func injectUATScenario(_ log: [WorkoutLogEntry]) {
        workoutLog = log.sorted { $0.startedAt > $1.startedAt }
        personalRecords = [:]
        for entry in workoutLog {
            for we in entry.exercises {
                for set in we.completedSets {
                    let e1rm = set.estimated1RM
                    guard e1rm > 0 else { continue }
                    let existing = personalRecords[we.exercise.id]
                    if existing == nil || e1rm > existing!.estimated1RM {
                        personalRecords[we.exercise.id] = PersonalRecord(
                            exerciseId:    we.exercise.id,
                            exerciseName:  we.exercise.name,
                            weight:        set.weight,
                            reps:          set.reps,
                            estimated1RM:  e1rm,
                            date:          entry.startedAt
                        )
                    }
                }
            }
        }
        persistImport()
    }
    #endif

    // MARK: - Exercise Database

    private static func ex(
        _ uuidSuffix: String,
        _ name: String,
        _ region: BodyRegion,
        _ equip: Equipment,
        compound: Bool = true,
        pattern: MovementPattern = .isolation
    ) -> Exercise {
        let id = UUID(uuidString: "00000000-0000-0000-0000-\(uuidSuffix.padding(toLength: 12, withPad: "0", startingAt: 0))")!
        return Exercise(id: id, name: name, bodyRegion: region, equipment: equip, isCompound: compound, movementPattern: pattern)
    }

    private static func buildExerciseDatabase() -> [Exercise] {
        [
            // CHEST
            ex("010001", "Barbell Bench Press",              .chest,     .barbell,    compound: true,  pattern: .horizontalPush),
            ex("010002", "Incline Barbell Press",            .chest,     .barbell,    compound: true,  pattern: .horizontalPush),
            ex("010003", "Dumbbell Bench Press",             .chest,     .dumbbell,   compound: true,  pattern: .horizontalPush),
            ex("010004", "Incline Dumbbell Press",           .chest,     .dumbbell,   compound: true,  pattern: .horizontalPush),
            ex("010005", "Cable Fly",                        .chest,     .cable,      compound: false, pattern: .isolation),
            ex("010006", "Dumbbell Fly",                     .chest,     .dumbbell,   compound: false, pattern: .isolation),
            ex("010007", "Push-Up",                          .chest,     .bodyweight, compound: true,  pattern: .horizontalPush),
            ex("010008", "Dip",                              .chest,     .bodyweight, compound: true,  pattern: .horizontalPush),
            ex("010009", "Chest Press Machine",              .chest,     .machine,    compound: true,  pattern: .horizontalPush),
            ex("010010", "Pec Deck",                         .chest,     .machine,    compound: false, pattern: .isolation),
            ex("010011", "Cable Crossover",                  .chest,     .cable,      compound: false, pattern: .isolation),
            ex("010012", "Smith Machine Bench Press",        .chest,     .machine,    compound: true,  pattern: .horizontalPush),
            ex("010013", "Smith Machine Incline Press",      .chest,     .machine,    compound: true,  pattern: .horizontalPush),
            ex("010014", "Incline Chest Press Machine",      .chest,     .machine,    compound: true,  pattern: .horizontalPush),
            ex("010015", "Decline Chest Press Machine",      .chest,     .machine,    compound: true,  pattern: .horizontalPush),
            ex("010016", "Hammer Strength Chest Press",      .chest,     .machine,    compound: true,  pattern: .horizontalPush),

            // BACK
            ex("020001", "Deadlift",                         .back,      .barbell,    compound: true,  pattern: .hipHinge),
            ex("020002", "Barbell Row",                      .back,      .barbell,    compound: true,  pattern: .horizontalPull),
            ex("020003", "Pull-Up",                          .back,      .bodyweight, compound: true,  pattern: .verticalPull),
            ex("020004", "Lat Pulldown",                     .back,      .cable,      compound: true,  pattern: .verticalPull),
            ex("020005", "Seated Cable Row",                 .back,      .cable,      compound: true,  pattern: .horizontalPull),
            ex("020006", "Single-Arm Dumbbell Row",          .back,      .dumbbell,   compound: true,  pattern: .horizontalPull),
            ex("020007", "Face Pull",                        .back,      .cable,      compound: false, pattern: .horizontalPull),
            ex("020008", "T-Bar Row",                        .back,      .barbell,    compound: true,  pattern: .horizontalPull),
            ex("020009", "Assisted Pull-Up Machine",         .back,      .machine,    compound: true,  pattern: .verticalPull),
            ex("020010", "Low Row Machine",                  .back,      .machine,    compound: true,  pattern: .horizontalPull),
            ex("020011", "Smith Machine Row",                .back,      .machine,    compound: true,  pattern: .horizontalPull),
            ex("020012", "Chest-Supported Row Machine",      .back,      .machine,    compound: true,  pattern: .horizontalPull),
            ex("020013", "High Row Machine",                 .back,      .machine,    compound: true,  pattern: .verticalPull),
            ex("020014", "Lat Pullover Machine",             .back,      .machine,    compound: false, pattern: .isolation),
            ex("020015", "Hammer Strength Row",              .back,      .machine,    compound: true,  pattern: .horizontalPull),
            ex("020016", "Reverse Grip Lat Pulldown",        .back,      .cable,      compound: true,  pattern: .verticalPull),
            ex("020017", "Smith Machine Deadlift",           .back,      .machine,    compound: true,  pattern: .hipHinge),
            ex("020018", "Hammer Strength Lat Pulldown",     .back,      .machine,    compound: true,  pattern: .verticalPull),
            ex("020019", "Nautilus Pullover Machine",        .back,      .machine,    compound: false, pattern: .isolation),
            ex("020020", "Seated Row Machine (Neutral)",     .back,      .machine,    compound: true,  pattern: .horizontalPull),

            // SHOULDERS
            ex("030001", "Overhead Press",                   .shoulders, .barbell,    compound: true,  pattern: .verticalPush),
            ex("030002", "Dumbbell Shoulder Press",          .shoulders, .dumbbell,   compound: true,  pattern: .verticalPush),
            ex("030003", "Lateral Raise",                    .shoulders, .dumbbell,   compound: false, pattern: .isolation),
            ex("030004", "Cable Lateral Raise",              .shoulders, .cable,      compound: false, pattern: .isolation),
            ex("030005", "Rear Delt Fly",                    .shoulders, .dumbbell,   compound: false, pattern: .isolation),
            ex("030006", "Arnold Press",                     .shoulders, .dumbbell,   compound: true,  pattern: .verticalPush),
            ex("030007", "Machine Shoulder Press",           .shoulders, .machine,    compound: true,  pattern: .verticalPush),
            ex("030008", "Rear Delt Machine",                .shoulders, .machine,    compound: false, pattern: .isolation),
            ex("030009", "Smith Machine Overhead Press",     .shoulders, .machine,    compound: true,  pattern: .verticalPush),
            ex("030010", "Machine Lateral Raise",            .shoulders, .machine,    compound: false, pattern: .isolation),
            ex("030011", "Cable Rear Delt Fly",              .shoulders, .cable,      compound: false, pattern: .isolation),
            ex("030012", "Hammer Strength Shoulder Press",   .shoulders, .machine,    compound: true,  pattern: .verticalPush),
            ex("030013", "Trap / Shrug Machine",             .shoulders, .machine,    compound: false, pattern: .isolation),
            ex("030014", "Machine Upright Row",              .shoulders, .machine,    compound: false, pattern: .isolation),

            // ARMS
            ex("040001", "Barbell Curl",                     .arms,      .barbell,    compound: false, pattern: .isolation),
            ex("040002", "Dumbbell Curl",                    .arms,      .dumbbell,   compound: false, pattern: .isolation),
            ex("040003", "Hammer Curl",                      .arms,      .dumbbell,   compound: false, pattern: .isolation),
            ex("040004", "Cable Curl",                       .arms,      .cable,      compound: false, pattern: .isolation),
            ex("040005", "Tricep Pushdown",                  .arms,      .cable,      compound: false, pattern: .isolation),
            ex("040006", "Skull Crusher",                    .arms,      .barbell,    compound: false, pattern: .isolation),
            ex("040007", "Overhead Tricep Extension",        .arms,      .dumbbell,   compound: false, pattern: .isolation),
            ex("040008", "Close-Grip Bench Press",           .arms,      .barbell,    compound: true,  pattern: .horizontalPush),
            ex("040009", "Machine Bicep Curl",               .arms,      .machine,    compound: false, pattern: .isolation),
            ex("040010", "Tricep Machine",                   .arms,      .machine,    compound: false, pattern: .isolation),
            ex("040011", "Preacher Curl Machine",            .arms,      .machine,    compound: false, pattern: .isolation),
            ex("040012", "Smith Machine Close-Grip Press",   .arms,      .machine,    compound: true,  pattern: .horizontalPush),
            ex("040013", "Cable Overhead Tricep Extension",  .arms,      .cable,      compound: false, pattern: .isolation),
            ex("040014", "Rope Pushdown",                    .arms,      .cable,      compound: false, pattern: .isolation),
            ex("040015", "Cable Hammer Curl",                .arms,      .cable,      compound: false, pattern: .isolation),
            ex("040016", "Reverse Curl",                     .arms,      .barbell,    compound: false, pattern: .isolation),
            ex("040017", "Assisted Dip Machine",             .arms,      .machine,    compound: true,  pattern: .horizontalPush),
            ex("040018", "Tricep Extension Machine",         .arms,      .machine,    compound: false, pattern: .isolation),
            ex("040019", "Wrist Curl Machine",               .arms,      .machine,    compound: false, pattern: .isolation),

            // LEGS
            ex("050001", "Barbell Squat",                    .legs,      .barbell,    compound: true,  pattern: .kneeFlexion),
            ex("050002", "Romanian Deadlift",                .legs,      .barbell,    compound: true,  pattern: .hipHinge),
            ex("050003", "Leg Press",                        .legs,      .machine,    compound: true,  pattern: .kneeFlexion),
            ex("050004", "Leg Curl",                         .legs,      .machine,    compound: false, pattern: .isolation),
            ex("050005", "Leg Extension",                    .legs,      .machine,    compound: false, pattern: .isolation),
            ex("050006", "Bulgarian Split Squat",            .legs,      .dumbbell,   compound: true,  pattern: .kneeFlexion),
            ex("050007", "Walking Lunge",                    .legs,      .dumbbell,   compound: true,  pattern: .kneeFlexion),
            ex("050008", "Standing Calf Raise",              .legs,      .machine,    compound: false, pattern: .isolation),
            ex("050009", "Hip Thrust",                       .legs,      .barbell,    compound: true,  pattern: .hipHinge),
            ex("050010", "Goblet Squat",                     .legs,      .kettlebell, compound: true,  pattern: .kneeFlexion),
            ex("050011", "Smith Machine Squat",              .legs,      .machine,    compound: true,  pattern: .kneeFlexion),
            ex("050012", "Smith Machine Romanian Deadlift",  .legs,      .machine,    compound: true,  pattern: .hipHinge),
            ex("050013", "Smith Machine Hip Thrust",         .legs,      .machine,    compound: true,  pattern: .hipHinge),
            ex("050014", "Smith Machine Lunge",              .legs,      .machine,    compound: true,  pattern: .kneeFlexion),
            ex("050015", "Hack Squat Machine",               .legs,      .machine,    compound: true,  pattern: .kneeFlexion),
            ex("050016", "Seated Leg Curl",                  .legs,      .machine,    compound: false, pattern: .isolation),
            ex("050017", "Lying Leg Curl",                   .legs,      .machine,    compound: false, pattern: .isolation),
            ex("050018", "Seated Calf Raise",                .legs,      .machine,    compound: false, pattern: .isolation),
            ex("050019", "Hip Abduction Machine",            .legs,      .machine,    compound: false, pattern: .isolation),
            ex("050020", "Hip Adduction Machine",            .legs,      .machine,    compound: false, pattern: .isolation),
            ex("050021", "Glute Kickback Machine",           .legs,      .machine,    compound: false, pattern: .isolation),
            ex("050022", "Hip Thrust Machine",               .legs,      .machine,    compound: true,  pattern: .hipHinge),
            ex("050023", "Single-Leg Press",                 .legs,      .machine,    compound: true,  pattern: .kneeFlexion),
            ex("050024", "Sumo Deadlift",                    .legs,      .barbell,    compound: true,  pattern: .hipHinge),
            ex("050025", "Smith Machine Split Squat",        .legs,      .machine,    compound: true,  pattern: .kneeFlexion),
            ex("050026", "Pendulum Squat Machine",           .legs,      .machine,    compound: true,  pattern: .kneeFlexion),
            ex("050027", "Belt Squat Machine",               .legs,      .machine,    compound: true,  pattern: .kneeFlexion),
            ex("050028", "Nordic Hamstring Curl",            .legs,      .machine,    compound: false, pattern: .isolation),
            ex("050029", "Reverse Hyper Machine",            .legs,      .machine,    compound: false, pattern: .hipHinge),
            ex("050030", "Vertical Leg Press",               .legs,      .machine,    compound: true,  pattern: .kneeFlexion),
            ex("050031", "Donkey Calf Raise Machine",        .legs,      .machine,    compound: false, pattern: .isolation),
            ex("050032", "Leg Press Calf Raise",             .legs,      .machine,    compound: false, pattern: .isolation),

            // CORE
            ex("060001", "Plank",                            .core,      .bodyweight, compound: false, pattern: .isolation),
            ex("060002", "Cable Crunch",                     .core,      .cable,      compound: false, pattern: .isolation),
            ex("060003", "Hanging Leg Raise",                .core,      .bodyweight, compound: false, pattern: .isolation),
            ex("060004", "Ab Wheel Rollout",                 .core,      .bodyweight, compound: false, pattern: .isolation),
            ex("060005", "Russian Twist",                    .core,      .bodyweight, compound: false, pattern: .isolation),
            ex("060006", "Dead Bug",                         .core,      .bodyweight, compound: false, pattern: .isolation),
            ex("060007", "Machine Crunch",                   .core,      .machine,    compound: false, pattern: .isolation),
            ex("060008", "Back Extension Machine",           .core,      .machine,    compound: false, pattern: .isolation),
            ex("060009", "Seated Oblique Machine",           .core,      .machine,    compound: false, pattern: .isolation),
            ex("060010", "Cable Woodchop",                   .core,      .cable,      compound: false, pattern: .isolation),
            ex("060011", "Rotary Torso Machine",             .core,      .machine,    compound: false, pattern: .isolation),
            ex("060012", "Captain's Chair Leg Raise",        .core,      .bodyweight, compound: false, pattern: .isolation),
            ex("060013", "GHD Sit-Up",                       .core,      .machine,    compound: false, pattern: .isolation),
            ex("060014", "Back Extension (GHD)",             .core,      .machine,    compound: false, pattern: .isolation),
            ex("060015", "Sit-Up",                           .core,      .bodyweight, compound: false, pattern: .isolation),
            ex("060016", "Bicycle Crunch",                   .core,      .bodyweight, compound: false, pattern: .isolation),
            ex("060017", "Flutter Kick",                     .core,      .bodyweight, compound: false, pattern: .isolation),
            ex("060018", "V-Up",                             .core,      .bodyweight, compound: false, pattern: .isolation),
            ex("060019", "Superman",                         .core,      .bodyweight, compound: false, pattern: .isolation),
            ex("060020", "Hollow Body Hold",                 .core,      .bodyweight, compound: false, pattern: .isolation),
            ex("060021", "Mountain Climber",                 .core,      .bodyweight, compound: true,  pattern: .isolation),
            ex("060022", "Bear Crawl",                       .core,      .bodyweight, compound: true,  pattern: .isolation),
            ex("060023", "Inchworm",                         .core,      .bodyweight, compound: true,  pattern: .isolation),
            ex("060024", "Burpee",                           .core,      .bodyweight, compound: true,  pattern: .isolation),

            // LEGS – BODYWEIGHT
            ex("050033", "Bodyweight Squat",                 .legs,      .bodyweight, compound: true,  pattern: .kneeFlexion),
            ex("050034", "Bodyweight Lunge",                 .legs,      .bodyweight, compound: true,  pattern: .kneeFlexion),
            ex("050035", "Reverse Lunge",                    .legs,      .bodyweight, compound: true,  pattern: .kneeFlexion),
            ex("050036", "Lateral Lunge",                    .legs,      .bodyweight, compound: true,  pattern: .kneeFlexion),
            ex("050037", "Wall Sit",                         .legs,      .bodyweight, compound: false, pattern: .isolation),
            ex("050038", "Glute Bridge",                     .legs,      .bodyweight, compound: true,  pattern: .hipHinge),
            ex("050039", "Jump Squat",                       .legs,      .bodyweight, compound: true,  pattern: .kneeFlexion),
            ex("050040", "Jump Lunge",                       .legs,      .bodyweight, compound: true,  pattern: .kneeFlexion),
            ex("050041", "Box Jump",                         .legs,      .bodyweight, compound: true,  pattern: .kneeFlexion),
            ex("050042", "Step-Up",                          .legs,      .bodyweight, compound: true,  pattern: .kneeFlexion),
            ex("050043", "High Knees",                       .legs,      .bodyweight, compound: false, pattern: .isolation),
            ex("050044", "Jumping Jack",                     .legs,      .bodyweight, compound: false, pattern: .isolation),

            // CHEST – PUSH VARIATIONS
            ex("010017", "Incline Push-Up",                  .chest,     .bodyweight, compound: true,  pattern: .horizontalPush),
            ex("010018", "Decline Push-Up",                  .chest,     .bodyweight, compound: true,  pattern: .horizontalPush),
            ex("010019", "Diamond Push-Up",                  .chest,     .bodyweight, compound: true,  pattern: .horizontalPush),
            ex("010020", "Wide Push-Up",                     .chest,     .bodyweight, compound: true,  pattern: .horizontalPush),

            // SHOULDERS – PIKE PUSH-UP
            ex("030015", "Pike Push-Up",                     .shoulders, .bodyweight, compound: true,  pattern: .verticalPush),

            // BACK – CHIN-UP
            ex("020021", "Chin-Up",                          .back,      .bodyweight, compound: true,  pattern: .verticalPull),
        ]
    }
}
