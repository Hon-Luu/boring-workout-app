import Foundation
import CoreMotion
import WatchKit

/// CoreMotion-based rep counting engine for Apple Watch
@Observable
class RepCountingEngine {
    // MARK: - Public State

    /// Current rep count
    private(set) var currentReps: Int = 0

    /// Whether motion tracking is active
    private(set) var isTracking: Bool = false

    /// Confidence in rep detection (0-1)
    private(set) var confidence: Double = 1.0

    /// Timestamps for each detected rep
    private(set) var repTimestamps: [Date] = []

    // MARK: - Private Properties

    private let motionManager = CMMotionManager()
    private var exerciseProfile: ExerciseMotionProfile?

    // Motion data buffers
    private var accelerationHistory: [Double] = []
    private var rotationHistory: [Double] = []

    // Rep detection state
    private var lastPeakTime: Date?
    private var movementPhase: MovementPhase = .neutral
    private var peakValue: Double = 0
    private var valleyValue: Double = 0

    // MARK: - Types

    enum MovementPhase {
        case neutral
        case ascending   // Going up (concentric)
        case peak        // At top of movement
        case descending  // Going down (eccentric)
    }

    enum Axis {
        case accelerationX
        case accelerationY
        case accelerationZ
        case rotationX
        case rotationY
        case rotationZ
    }

    struct ExerciseMotionProfile {
        let primaryAxis: Axis
        let secondaryAxis: Axis?
        let minRepDuration: TimeInterval
        let maxRepDuration: TimeInterval
        let peakThreshold: Double
        let valleyThreshold: Double
        let smoothingWindow: Int

        static let defaultProfile = ExerciseMotionProfile(
            primaryAxis: .accelerationY,
            secondaryAxis: .rotationX,
            minRepDuration: 0.8,
            maxRepDuration: 4.0,
            peakThreshold: 0.6,
            valleyThreshold: -0.4,
            smoothingWindow: 5
        )
    }

    // MARK: - Exercise Profiles

    private static let profiles: [String: ExerciseMotionProfile] = [
        // Arm curls - wrist rotates significantly
        "Dumbbell Curl": ExerciseMotionProfile(
            primaryAxis: .rotationX,
            secondaryAxis: .accelerationY,
            minRepDuration: 0.8,
            maxRepDuration: 4.0,
            peakThreshold: 1.5,
            valleyThreshold: -1.0,
            smoothingWindow: 5
        ),
        "Barbell Curl": ExerciseMotionProfile(
            primaryAxis: .rotationX,
            secondaryAxis: .accelerationY,
            minRepDuration: 1.0,
            maxRepDuration: 4.0,
            peakThreshold: 1.2,
            valleyThreshold: -0.8,
            smoothingWindow: 5
        ),
        "Chin-up": ExerciseMotionProfile(
            primaryAxis: .accelerationY,
            secondaryAxis: nil,
            minRepDuration: 1.5,
            maxRepDuration: 6.0,
            peakThreshold: 0.8,
            valleyThreshold: -0.5,
            smoothingWindow: 8
        ),

        // Push movements
        "Push-up": ExerciseMotionProfile(
            primaryAxis: .accelerationZ,
            secondaryAxis: .rotationY,
            minRepDuration: 0.6,
            maxRepDuration: 3.0,
            peakThreshold: 0.7,
            valleyThreshold: -0.5,
            smoothingWindow: 5
        ),
        "Flat Bench Press": ExerciseMotionProfile(
            primaryAxis: .accelerationZ,
            secondaryAxis: nil,
            minRepDuration: 1.0,
            maxRepDuration: 4.0,
            peakThreshold: 0.5,
            valleyThreshold: -0.3,
            smoothingWindow: 6
        ),
        "Incline Dumbbell Press": ExerciseMotionProfile(
            primaryAxis: .accelerationZ,
            secondaryAxis: .accelerationY,
            minRepDuration: 1.0,
            maxRepDuration: 4.0,
            peakThreshold: 0.5,
            valleyThreshold: -0.3,
            smoothingWindow: 6
        ),
        "Diamond Push-up": ExerciseMotionProfile(
            primaryAxis: .accelerationZ,
            secondaryAxis: .rotationY,
            minRepDuration: 0.6,
            maxRepDuration: 3.0,
            peakThreshold: 0.7,
            valleyThreshold: -0.5,
            smoothingWindow: 5
        ),

        // Shoulder press - vertical movement
        "Overhead Press": ExerciseMotionProfile(
            primaryAxis: .accelerationY,
            secondaryAxis: .rotationX,
            minRepDuration: 1.0,
            maxRepDuration: 4.0,
            peakThreshold: 1.0,
            valleyThreshold: -0.6,
            smoothingWindow: 6
        ),
        "Dumbbell Shoulder Press": ExerciseMotionProfile(
            primaryAxis: .accelerationY,
            secondaryAxis: .rotationX,
            minRepDuration: 1.0,
            maxRepDuration: 4.0,
            peakThreshold: 1.0,
            valleyThreshold: -0.6,
            smoothingWindow: 6
        ),
        "Lateral Raise": ExerciseMotionProfile(
            primaryAxis: .rotationZ,
            secondaryAxis: .accelerationY,
            minRepDuration: 1.0,
            maxRepDuration: 3.5,
            peakThreshold: 1.0,
            valleyThreshold: -0.6,
            smoothingWindow: 5
        ),

        // Squats - vertical displacement
        "Barbell Squat": ExerciseMotionProfile(
            primaryAxis: .accelerationY,
            secondaryAxis: nil,
            minRepDuration: 1.5,
            maxRepDuration: 5.0,
            peakThreshold: 0.5,
            valleyThreshold: -0.3,
            smoothingWindow: 8
        ),
        "Bodyweight Squat": ExerciseMotionProfile(
            primaryAxis: .accelerationY,
            secondaryAxis: nil,
            minRepDuration: 1.0,
            maxRepDuration: 4.0,
            peakThreshold: 0.6,
            valleyThreshold: -0.4,
            smoothingWindow: 6
        ),

        // Rows
        "Barbell Row": ExerciseMotionProfile(
            primaryAxis: .rotationX,
            secondaryAxis: .accelerationZ,
            minRepDuration: 1.0,
            maxRepDuration: 4.0,
            peakThreshold: 1.2,
            valleyThreshold: -0.8,
            smoothingWindow: 6
        ),

        // Tricep movements
        "Tricep Pushdown": ExerciseMotionProfile(
            primaryAxis: .rotationX,
            secondaryAxis: .accelerationY,
            minRepDuration: 0.8,
            maxRepDuration: 3.0,
            peakThreshold: 1.5,
            valleyThreshold: -1.0,
            smoothingWindow: 5
        ),
        "Skull Crusher": ExerciseMotionProfile(
            primaryAxis: .rotationX,
            secondaryAxis: nil,
            minRepDuration: 1.0,
            maxRepDuration: 3.5,
            peakThreshold: 1.2,
            valleyThreshold: -0.8,
            smoothingWindow: 5
        ),

        // Pull movements
        "Lat Pulldown": ExerciseMotionProfile(
            primaryAxis: .accelerationY,
            secondaryAxis: .rotationX,
            minRepDuration: 1.0,
            maxRepDuration: 4.0,
            peakThreshold: 0.8,
            valleyThreshold: -0.5,
            smoothingWindow: 6
        ),
        "Pull-up": ExerciseMotionProfile(
            primaryAxis: .accelerationY,
            secondaryAxis: nil,
            minRepDuration: 1.5,
            maxRepDuration: 6.0,
            peakThreshold: 0.8,
            valleyThreshold: -0.5,
            smoothingWindow: 8
        ),

        // Hip hinge movements
        "Romanian Deadlift": ExerciseMotionProfile(
            primaryAxis: .accelerationY,
            secondaryAxis: .rotationX,
            minRepDuration: 1.5,
            maxRepDuration: 5.0,
            peakThreshold: 0.4,
            valleyThreshold: -0.3,
            smoothingWindow: 8
        ),
        "Deadlift": ExerciseMotionProfile(
            primaryAxis: .accelerationY,
            secondaryAxis: nil,
            minRepDuration: 2.0,
            maxRepDuration: 6.0,
            peakThreshold: 0.5,
            valleyThreshold: -0.3,
            smoothingWindow: 10
        ),

        // Core movements
        "Crunch": ExerciseMotionProfile(
            primaryAxis: .rotationX,
            secondaryAxis: .accelerationZ,
            minRepDuration: 0.6,
            maxRepDuration: 2.5,
            peakThreshold: 1.0,
            valleyThreshold: -0.7,
            smoothingWindow: 4
        ),
        "Russian Twist": ExerciseMotionProfile(
            primaryAxis: .rotationZ,
            secondaryAxis: nil,
            minRepDuration: 0.4,
            maxRepDuration: 2.0,
            peakThreshold: 1.5,
            valleyThreshold: -1.5,
            smoothingWindow: 4
        )
    ]

    // MARK: - Public API

    /// Start tracking reps for the given exercise
    func startTracking(exerciseName: String) {
        // Find matching profile or use default
        exerciseProfile = Self.profiles[exerciseName] ?? Self.profiles.first(where: { key, _ in
            exerciseName.lowercased().contains(key.lowercased().components(separatedBy: " ").first ?? "")
        })?.value ?? ExerciseMotionProfile.defaultProfile

        // Reset state
        currentReps = 0
        repTimestamps = []
        accelerationHistory = []
        rotationHistory = []
        movementPhase = .neutral
        lastPeakTime = nil
        peakValue = 0
        valleyValue = 0
        confidence = 1.0
        isTracking = true

        // Start motion updates
        guard motionManager.isDeviceMotionAvailable else {
            print("[RepEngine] Device motion not available")
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0  // 50 Hz
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else { return }
            self.processMotion(motion)
        }
    }

    /// Stop tracking reps
    func stopTracking() {
        motionManager.stopDeviceMotionUpdates()
        isTracking = false
    }

    /// Manually adjust rep count
    func adjustReps(_ delta: Int) {
        currentReps = max(0, currentReps + delta)
        // Manual adjustment reduces confidence
        confidence = max(0.5, confidence - 0.1)
    }

    /// Reset for next set
    func reset() {
        currentReps = 0
        repTimestamps = []
        accelerationHistory = []
        rotationHistory = []
        movementPhase = .neutral
        lastPeakTime = nil
        peakValue = 0
        valleyValue = 0
        confidence = 1.0
    }

    // MARK: - Motion Processing

    private func processMotion(_ motion: CMDeviceMotion) {
        guard let profile = exerciseProfile else { return }

        // Get primary axis value
        let primaryValue = getAxisValue(motion, axis: profile.primaryAxis)

        // Add to history
        accelerationHistory.append(primaryValue)

        // Keep buffer limited (about 2 seconds at 50Hz)
        if accelerationHistory.count > 100 {
            accelerationHistory.removeFirst()
        }

        // Need enough data for smoothing
        guard accelerationHistory.count >= profile.smoothingWindow else { return }

        // Apply smoothing (simple moving average)
        let smoothedValue = smoothedAverage(profile.smoothingWindow)

        // Detect rep using state machine
        detectRep(value: smoothedValue, profile: profile)
    }

    private func getAxisValue(_ motion: CMDeviceMotion, axis: Axis) -> Double {
        switch axis {
        case .accelerationX:
            return motion.userAcceleration.x
        case .accelerationY:
            return motion.userAcceleration.y
        case .accelerationZ:
            return motion.userAcceleration.z
        case .rotationX:
            return motion.rotationRate.x
        case .rotationY:
            return motion.rotationRate.y
        case .rotationZ:
            return motion.rotationRate.z
        }
    }

    private func smoothedAverage(_ window: Int) -> Double {
        let values = Array(accelerationHistory.suffix(window))
        return values.reduce(0, +) / Double(values.count)
    }

    private func detectRep(value: Double, profile: ExerciseMotionProfile) {
        let now = Date()

        switch movementPhase {
        case .neutral:
            // Looking for start of movement
            if value > profile.peakThreshold * 0.5 {
                movementPhase = .ascending
                peakValue = value
            } else if value < profile.valleyThreshold * 0.5 {
                movementPhase = .descending
                valleyValue = value
            }

        case .ascending:
            // Track peak
            if value > peakValue {
                peakValue = value
            }
            // Detect transition to descending
            if value < peakValue * 0.7 && peakValue > profile.peakThreshold {
                movementPhase = .peak
            }

        case .peak:
            // Wait for descent
            if value < profile.valleyThreshold * 0.5 {
                movementPhase = .descending
                valleyValue = value
            }

        case .descending:
            // Track valley
            if value < valleyValue {
                valleyValue = value
            }
            // Detect return to neutral/ascending = rep complete
            if value > valleyValue + abs(profile.valleyThreshold * 0.5) {
                // Validate rep timing
                if let lastTime = lastPeakTime {
                    let duration = now.timeIntervalSince(lastTime)
                    if duration >= profile.minRepDuration && duration <= profile.maxRepDuration {
                        registerRep()
                    } else if duration < profile.minRepDuration {
                        // Too fast - might be noise, don't count but don't reset
                        confidence = max(0.5, confidence - 0.1)
                    }
                    // If too slow, just reset state without counting
                } else {
                    // First rep - count it
                    registerRep()
                }

                // Reset for next rep
                lastPeakTime = now
                movementPhase = .neutral
                peakValue = 0
                valleyValue = 0
            }
        }
    }

    private func registerRep() {
        currentReps += 1
        repTimestamps.append(Date())

        // Haptic feedback
        WKInterfaceDevice.current().play(.click)

        // Update confidence based on consistency
        if repTimestamps.count >= 2 {
            let intervals = zip(repTimestamps.dropFirst(), repTimestamps).map { $0.timeIntervalSince($1) }
            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
            let variance = intervals.map { pow($0 - avgInterval, 2) }.reduce(0, +) / Double(intervals.count)
            let stdDev = sqrt(variance)

            // More consistent timing = higher confidence
            if stdDev < 0.5 {
                confidence = min(1.0, confidence + 0.05)
            } else if stdDev > 1.0 {
                confidence = max(0.6, confidence - 0.05)
            }
        }
    }
}
