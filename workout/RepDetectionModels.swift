import Foundation

// MARK: - Rep Phase

enum RepPhase: String, Codable {
    case idle
    case eccentric   // lowering / lengthening phase
    case concentric  // lifting / shortening phase
}

// MARK: - Single Rep Event

struct RepEvent: Identifiable, Codable {
    let id: UUID
    let repNumber: Int           // 1-based within the set
    let timestamp: Date

    // Phase durations (seconds)
    let eccentricDuration: TimeInterval
    let concentricDuration: TimeInterval

    // Acceleration-based speed proxies (m/s²) — mean |userAcceleration| during each phase
    let eccentricSpeed: Double
    let concentricSpeed: Double

    // Peak concentric acceleration — best proxy for "bar speed"
    let peakConcentricAccel: Double

    // Velocity loss vs rep 1 of the set (0.0 = baseline, 0.25 = 25% loss)
    let velocityLossFraction: Double

    init(
        repNumber: Int,
        eccentricDuration: TimeInterval,
        concentricDuration: TimeInterval,
        eccentricSpeed: Double,
        concentricSpeed: Double,
        peakConcentricAccel: Double,
        velocityLossFraction: Double
    ) {
        self.id = UUID()
        self.repNumber = repNumber
        self.timestamp = Date()
        self.eccentricDuration = eccentricDuration
        self.concentricDuration = concentricDuration
        self.eccentricSpeed = eccentricSpeed
        self.concentricSpeed = concentricSpeed
        self.peakConcentricAccel = peakConcentricAccel
        self.velocityLossFraction = velocityLossFraction
    }

    var totalDuration: TimeInterval { eccentricDuration + concentricDuration }

    // Tempo string e.g. "3.1 / 1.4" (ecc / con seconds)
    var tempoString: String {
        String(format: "%.1fs ecc  /  %.1fs con", eccentricDuration, concentricDuration)
    }
}

// MARK: - Set Velocity Profile

struct SetVelocityProfile: Codable {
    let exerciseName: String
    let reps: [RepEvent]
    let recordedAt: Date

    init(exerciseName: String, reps: [RepEvent]) {
        self.exerciseName = exerciseName
        self.reps = reps
        self.recordedAt = Date()
    }

    var repCount: Int { reps.count }

    // Concentric speed of the first rep — the "fresh" baseline
    var baselineConcentricSpeed: Double? { reps.first?.concentricSpeed }

    // Velocity loss % comparing last rep to first rep
    var velocityLossPct: Double {
        guard let baseline = baselineConcentricSpeed, baseline > 0,
              let last = reps.last else { return 0 }
        return (baseline - last.concentricSpeed) / baseline * 100.0
    }

    var fatigueLevel: VBTFatigueLevel { VBTFatigueLevel(velocityLossPct: velocityLossPct) }

    var averageConcentricSpeed: Double {
        guard !reps.isEmpty else { return 0 }
        return reps.map(\.concentricSpeed).reduce(0, +) / Double(reps.count)
    }

    var averageEccentricSpeed: Double {
        guard !reps.isEmpty else { return 0 }
        return reps.map(\.eccentricSpeed).reduce(0, +) / Double(reps.count)
    }

    var averageEccentricDuration: TimeInterval {
        guard !reps.isEmpty else { return 0 }
        return reps.map(\.eccentricDuration).reduce(0, +) / Double(reps.count)
    }

    var averageConcentricDuration: TimeInterval {
        guard !reps.isEmpty else { return 0 }
        return reps.map(\.concentricDuration).reduce(0, +) / Double(reps.count)
    }
}

// MARK: - VBT Fatigue Level

enum VBTFatigueLevel: String, Codable {
    case fresh         = "Fresh"
    case moderate      = "Moderate"
    case high          = "High"
    case nearFailure   = "Near Failure"

    init(velocityLossPct: Double) {
        switch velocityLossPct {
        case ..<10:  self = .fresh
        case ..<20:  self = .moderate
        case ..<30:  self = .high
        default:     self = .nearFailure
        }
    }

    var color: String {   // named for cross-platform use (Watch + iPhone)
        switch self {
        case .fresh:       return "green"
        case .moderate:    return "yellow"
        case .high:        return "orange"
        case .nearFailure: return "red"
        }
    }

    var icon: String {
        switch self {
        case .fresh:       return "bolt.fill"
        case .moderate:    return "bolt.badge.clock"
        case .high:        return "exclamationmark.triangle"
        case .nearFailure: return "xmark.octagon.fill"
        }
    }

    var recommendation: String {
        switch self {
        case .fresh:       return "Full capacity — push harder if needed"
        case .moderate:    return "Good set — moderate fatigue building"
        case .high:        return "High fatigue — 1–2 reps from failure"
        case .nearFailure: return "Stop or spot — very close to failure"
        }
    }
}

// MARK: - WatchConnectivity Message Keys

enum WatchMessageKey {
    static let type              = "type"
    static let repEvent          = "repEvent"
    static let setProfile        = "setProfile"
    static let currentExercise   = "exercise"
    static let workoutStarted    = "workoutStarted"
    static let workoutEnded      = "workoutEnded"
    static let setStarted        = "setStarted"
    static let setEnded          = "setEnded"
    static let requestSync       = "requestSync"
}

enum WatchMessageType: String {
    case repDetected     = "repDetected"
    case setComplete     = "setComplete"
    case workoutStarted  = "workoutStarted"
    case workoutEnded    = "workoutEnded"
    case setStarted      = "setStarted"
    case activeExercise  = "activeExercise"
    case syncRequest     = "syncRequest"
}
