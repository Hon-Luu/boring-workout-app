import Foundation

// MARK: - Watch Sync Models
// These models are shared between iOS and watchOS targets for WatchConnectivity

/// Session sent from iPhone to Watch when starting a workout
struct WatchWorkoutSession: Codable {
    let sessionId: UUID
    let exerciseName: String
    let bodyPart: String
    let startTime: Date
    let plannedSets: Int
    var completedSets: Int
    var setRecords: [WatchSetRecord]
    let restTimerDuration: Int
    let previousBest: PreviousBestInfo?

    init(
        sessionId: UUID = UUID(),
        exerciseName: String,
        bodyPart: String,
        startTime: Date = Date(),
        plannedSets: Int,
        completedSets: Int = 0,
        setRecords: [WatchSetRecord],
        restTimerDuration: Int,
        previousBest: PreviousBestInfo? = nil
    ) {
        self.sessionId = sessionId
        self.exerciseName = exerciseName
        self.bodyPart = bodyPart
        self.startTime = startTime
        self.plannedSets = plannedSets
        self.completedSets = completedSets
        self.setRecords = setRecords
        self.restTimerDuration = restTimerDuration
        self.previousBest = previousBest
    }
}

/// Individual set record for Watch sync
struct WatchSetRecord: Codable, Identifiable {
    let id: UUID
    let setNumber: Int
    var targetReps: Int
    var actualReps: Int
    var weight: Double
    var isCompleted: Bool
    var repTimestamps: [Date]

    init(
        id: UUID = UUID(),
        setNumber: Int,
        targetReps: Int,
        actualReps: Int = 0,
        weight: Double,
        isCompleted: Bool = false,
        repTimestamps: [Date] = []
    ) {
        self.id = id
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.actualReps = actualReps
        self.weight = weight
        self.isCompleted = isCompleted
        self.repTimestamps = repTimestamps
    }
}

/// Previous best performance for motivation display
struct PreviousBestInfo: Codable {
    let weight: Double
    let reps: Int
    let date: Date
    let estimated1RM: Double

    init(weight: Double, reps: Int, date: Date) {
        self.weight = weight
        self.reps = reps
        self.date = date
        self.estimated1RM = weight * (1.0 + Double(reps) / 30.0)
    }
}

/// Update sent from Watch to iPhone after completing a set
struct WatchWorkoutUpdate: Codable {
    let sessionId: UUID
    let setNumber: Int
    let actualReps: Int
    let weight: Double
    let completedAt: Date
    let motionConfidence: Double  // 0-1 confidence in rep detection accuracy
    let repTimestamps: [Date]

    init(
        sessionId: UUID,
        setNumber: Int,
        actualReps: Int,
        weight: Double,
        completedAt: Date = Date(),
        motionConfidence: Double = 1.0,
        repTimestamps: [Date] = []
    ) {
        self.sessionId = sessionId
        self.setNumber = setNumber
        self.actualReps = actualReps
        self.weight = weight
        self.completedAt = completedAt
        self.motionConfidence = motionConfidence
        self.repTimestamps = repTimestamps
    }
}

/// Commands exchanged between iPhone and Watch
enum WatchCommand: String, Codable {
    case startSession       // iPhone -> Watch: Begin workout tracking
    case endSession         // Bidirectional: End current workout
    case startSet           // iPhone -> Watch: Begin tracking current set
    case completeSet        // Watch -> iPhone: Set finished with rep count
    case startRestTimer     // Bidirectional: Start rest timer
    case skipRestTimer      // Watch -> iPhone: User skipped rest
    case adjustReps         // Watch -> iPhone: Manual rep adjustment
    case adjustWeight       // iPhone -> Watch: Weight changed
    case ping               // Bidirectional: Check connectivity
    case pong               // Bidirectional: Response to ping
}

/// Message wrapper for WatchConnectivity
struct WatchMessage: Codable {
    let command: WatchCommand
    let payload: Data?
    let timestamp: Date

    init(command: WatchCommand, payload: Data? = nil) {
        self.command = command
        self.payload = payload
        self.timestamp = Date()
    }

    /// Encode an object to use as payload
    static func encode<T: Encodable>(_ object: T) -> Data? {
        try? JSONEncoder().encode(object)
    }

    /// Decode payload to a specific type
    func decodePayload<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = payload else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Notification Names for Watch Updates

extension Notification.Name {
    /// Posted when Watch sends a workout update (set completion, rep adjustment)
    static let watchWorkoutUpdate = Notification.Name("watchWorkoutUpdate")

    /// Posted when Watch connection state changes
    static let watchConnectionStateChanged = Notification.Name("watchConnectionStateChanged")

    /// Posted when Watch session starts
    static let watchSessionStarted = Notification.Name("watchSessionStarted")

    /// Posted when Watch session ends
    static let watchSessionEnded = Notification.Name("watchSessionEnded")
}

// MARK: - Watch Connection State

enum WatchConnectionState: String {
    case notSupported       // WatchConnectivity not available
    case notPaired          // No Watch paired
    case notReachable       // Watch paired but not reachable
    case connected          // Watch paired and reachable
}
