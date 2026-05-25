import Foundation

// MARK: - GeneralActivityEntry

struct GeneralActivityEntry: Identifiable, Codable, ActivitySession {
    var id: UUID = UUID()
    var activityType: GeneralActivityType
    var durationMinutes: Int
    var intensityLevel: IntensityLevel
    var notes: String = ""
    var startedAt: Date
    var feelRating: FeelRating? = nil

    enum GeneralActivityType: String, Codable, CaseIterable {
        case yoga       = "Yoga"
        case cycling    = "Cycling"
        case swimming   = "Swimming"
        case hiking     = "Hiking"
        case pilates    = "Pilates"
        case martialArts = "Martial Arts"
        case dance      = "Dance"
        case sports     = "Sports"
        case mobility   = "Mobility / Stretching"
        case other      = "Other"

        var icon: String {
            switch self {
            case .yoga:        return "figure.mind.and.body"
            case .cycling:     return "figure.outdoor.cycle"
            case .swimming:    return "figure.pool.swim"
            case .hiking:      return "figure.hiking"
            case .pilates:     return "figure.pilates"
            case .martialArts: return "figure.martial.arts"
            case .dance:       return "figure.dance"
            case .sports:      return "sportscourt.fill"
            case .mobility:    return "figure.flexibility"
            case .other:       return "star.circle.fill"
            }
        }
    }

    enum IntensityLevel: String, Codable, CaseIterable {
        case light    = "Light"
        case moderate = "Moderate"
        case vigorous = "Vigorous"

        var readinessCredit: Double {
            switch self {
            case .light:    return 0.3
            case .moderate: return 0.6
            case .vigorous: return 1.0
            }
        }

        var color: String {
            switch self {
            case .light:    return "green"
            case .moderate: return "orange"
            case .vigorous: return "red"
            }
        }
    }
}

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
    var weight: Double? = nil   // nil = bodyweight, non-nil = kg

    init(id: UUID = UUID(), exercise: Exercise, targetReps: Int = 10, weight: Double? = nil) {
        self.id = id
        self.exercise = exercise
        self.targetReps = targetReps
        self.weight = weight
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decodeIfPresent(UUID.self,     forKey: .id)         ?? UUID()
        exercise   = try c.decodeIfPresent(Exercise.self, forKey: .exercise)   ?? Exercise(id: UUID(), name: "Unknown", bodyRegion: .core, equipment: .bodyweight, isCompound: false)
        targetReps = try c.decodeIfPresent(Int.self,      forKey: .targetReps) ?? 10
        weight     = try c.decodeIfPresent(Double.self,   forKey: .weight)
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
    var weightUsed: Double? = nil   // records the actual weight used that round

    init(id: UUID = UUID(), round: Int, exerciseId: UUID, exerciseName: String, repsCompleted: Int, weightUsed: Double? = nil) {
        self.id = id
        self.round = round
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.repsCompleted = repsCompleted
        self.weightUsed = weightUsed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decodeIfPresent(UUID.self,   forKey: .id)            ?? UUID()
        round         = try c.decodeIfPresent(Int.self,    forKey: .round)         ?? 0
        exerciseId    = try c.decodeIfPresent(UUID.self,   forKey: .exerciseId)    ?? UUID()
        exerciseName  = try c.decodeIfPresent(String.self, forKey: .exerciseName)  ?? ""
        repsCompleted = try c.decodeIfPresent(Int.self,    forKey: .repsCompleted) ?? 0
        weightUsed    = try c.decodeIfPresent(Double.self, forKey: .weightUsed)
    }
}

// MARK: - CardioLogEntry

struct CardioLogEntry: Identifiable, Codable, ActivitySession {
    var id: UUID
    var circuitId: UUID?
    var circuitName: String
    var format: CircuitFormat
    var durationMinutes: Int
    var exercises: [CircuitExercise]
    var results: [CircuitRoundResult]
    var startedAt: Date
    var finishedAt: Date?
    var feelRating: FeelRating? = nil

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

    var isWeightedSession: Bool {
        exercises.contains { $0.weight != nil }
    }

    var totalVolume: Double {  // reps × weight, similar to strength tonnage
        var vol = 0.0
        for result in results {
            if let w = result.weightUsed, w > 0 {
                vol += Double(result.repsCompleted) * w
            }
        }
        return vol
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
         startedAt: Date = Date(), finishedAt: Date? = nil, feelRating: FeelRating? = nil) {
        self.id = id
        self.circuitId = circuitId
        self.circuitName = circuitName
        self.format = format
        self.durationMinutes = durationMinutes
        self.exercises = exercises
        self.results = results
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.feelRating = feelRating
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
        feelRating      = try c.decodeIfPresent(FeelRating.self,         forKey: .feelRating)
    }
}
