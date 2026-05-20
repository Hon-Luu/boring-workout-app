import Foundation

// MARK: - CircuitFormat

enum CircuitFormat: String, Codable, CaseIterable {
    case amrap = "AMRAP"
    case emom  = "EMOM"

    var fullName: String {
        switch self {
        case .amrap: return "As Many Rounds As Possible"
        case .emom:  return "Every Minute On the Minute"
        }
    }

    var icon: String {
        switch self {
        case .amrap: return "repeat.circle.fill"
        case .emom:  return "timer"
        }
    }
}

// MARK: - CircuitExercise

struct CircuitExercise: Identifiable, Codable {
    var id: UUID
    var exercise: Exercise
    var targetReps: Int

    init(id: UUID = UUID(), exercise: Exercise, targetReps: Int = 10) {
        self.id = id
        self.exercise = exercise
        self.targetReps = targetReps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decodeIfPresent(UUID.self,     forKey: .id)         ?? UUID()
        exercise   = try c.decodeIfPresent(Exercise.self, forKey: .exercise)   ?? Exercise(id: UUID(), name: "Unknown", bodyRegion: .core, equipment: .bodyweight, isCompound: false)
        targetReps = try c.decodeIfPresent(Int.self,      forKey: .targetReps) ?? 10
    }
}

// MARK: - CardioCircuit

struct CardioCircuit: Identifiable, Codable {
    var id: UUID
    var name: String
    var format: CircuitFormat
    var durationMinutes: Int
    var exercises: [CircuitExercise]
    var createdAt: Date
    var assignedDays: [Int] = []  // Calendar.weekday: 1=Sun … 7=Sat

    var displayName: String {
        name.isEmpty ? "\(format.rawValue) Circuit" : name
    }

    var dayScheduleLabel: String {
        guard !assignedDays.isEmpty else { return "No days" }
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return assignedDays.sorted().compactMap { $0 >= 1 && $0 <= 7 ? names[$0 - 1] : nil }.joined(separator: " · ")
    }

    init(id: UUID = UUID(), name: String = "", format: CircuitFormat = .amrap,
         durationMinutes: Int = 20, exercises: [CircuitExercise] = [],
         createdAt: Date = Date(), assignedDays: [Int] = []) {
        self.id = id
        self.name = name
        self.format = format
        self.durationMinutes = durationMinutes
        self.exercises = exercises
        self.createdAt = createdAt
        self.assignedDays = assignedDays
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decodeIfPresent(UUID.self,             forKey: .id)              ?? UUID()
        name            = try c.decodeIfPresent(String.self,           forKey: .name)            ?? ""
        format          = try c.decodeIfPresent(CircuitFormat.self,    forKey: .format)          ?? .amrap
        durationMinutes = try c.decodeIfPresent(Int.self,              forKey: .durationMinutes) ?? 20
        exercises       = try c.decodeIfPresent([CircuitExercise].self, forKey: .exercises)      ?? []
        createdAt       = try c.decodeIfPresent(Date.self,             forKey: .createdAt)       ?? Date()
        assignedDays    = try c.decodeIfPresent([Int].self,            forKey: .assignedDays)    ?? []
    }
}

// MARK: - CircuitRoundResult

struct CircuitRoundResult: Identifiable, Codable {
    var id: UUID
    var round: Int
    var exerciseId: UUID
    var exerciseName: String
    var repsCompleted: Int

    init(id: UUID = UUID(), round: Int, exerciseId: UUID, exerciseName: String, repsCompleted: Int) {
        self.id = id
        self.round = round
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.repsCompleted = repsCompleted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decodeIfPresent(UUID.self,   forKey: .id)            ?? UUID()
        round         = try c.decodeIfPresent(Int.self,    forKey: .round)         ?? 0
        exerciseId    = try c.decodeIfPresent(UUID.self,   forKey: .exerciseId)    ?? UUID()
        exerciseName  = try c.decodeIfPresent(String.self, forKey: .exerciseName)  ?? ""
        repsCompleted = try c.decodeIfPresent(Int.self,    forKey: .repsCompleted) ?? 0
    }
}

// MARK: - CardioLogEntry

struct CardioLogEntry: Identifiable, Codable {
    var id: UUID
    var circuitId: UUID?
    var circuitName: String
    var format: CircuitFormat
    var durationMinutes: Int
    var exercises: [CircuitExercise]
    var results: [CircuitRoundResult]
    var startedAt: Date
    var finishedAt: Date?

    // MARK: Computed

    var totalReps: Int {
        results.reduce(0) { $0 + $1.repsCompleted }
    }

    var completedRounds: Int {
        guard !exercises.isEmpty else { return 0 }
        switch format {
        case .amrap:
            let maxRound = results.map(\.round).max() ?? -1
            return maxRound + 1
        case .emom:
            let maxMinute = results.map(\.round).max() ?? -1
            return maxMinute + 1
        }
    }

    var formattedDuration: String {
        guard let end = finishedAt else { return "\(durationMinutes)m" }
        let secs = Int(end.timeIntervalSince(startedAt))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    init(id: UUID = UUID(), circuitId: UUID? = nil, circuitName: String, format: CircuitFormat,
         durationMinutes: Int, exercises: [CircuitExercise], results: [CircuitRoundResult],
         startedAt: Date = Date(), finishedAt: Date? = nil) {
        self.id = id
        self.circuitId = circuitId
        self.circuitName = circuitName
        self.format = format
        self.durationMinutes = durationMinutes
        self.exercises = exercises
        self.results = results
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decodeIfPresent(UUID.self,               forKey: .id)              ?? UUID()
        circuitId       = try c.decodeIfPresent(UUID.self,               forKey: .circuitId)
        circuitName     = try c.decodeIfPresent(String.self,             forKey: .circuitName)     ?? ""
        format          = try c.decodeIfPresent(CircuitFormat.self,      forKey: .format)          ?? .amrap
        durationMinutes = try c.decodeIfPresent(Int.self,                forKey: .durationMinutes) ?? 20
        exercises       = try c.decodeIfPresent([CircuitExercise].self,  forKey: .exercises)       ?? []
        results         = try c.decodeIfPresent([CircuitRoundResult].self, forKey: .results)       ?? []
        startedAt       = try c.decodeIfPresent(Date.self,               forKey: .startedAt)       ?? Date()
        finishedAt      = try c.decodeIfPresent(Date.self,               forKey: .finishedAt)
    }
}
