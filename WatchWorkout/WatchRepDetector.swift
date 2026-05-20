import Foundation
import CoreMotion

// MARK: - Rep Detection State Machine
//
// Algorithm overview:
//   1. CMMotionManager samples userAcceleration at 50 Hz
//   2. Exponential Moving Average (α=0.12) smooths the signal
//   3. Auto-calibration: largest-variance axis in the first 1.5 s becomes
//      the "primary axis" for that set (handles any wrist orientation)
//   4. State machine: idle → eccentric → concentric → idle
//      - eccentric: primary axis < −threshold for ≥ minPhaseDuration
//      - concentric: primary axis > +threshold for ≥ minPhaseDuration
//      - idle: |primary axis| < threshold sustained for ≥ restDuration
//   5. Rep counted on concentric→idle transition
//   6. Per-phase accumulators → duration + mean |accel| = speed proxy
//
// Velocity-Based Training (VBT) fatigue:
//   velocityLoss = (rep1_concentric_speed − repN_concentric_speed)
//               / rep1_concentric_speed  × 100
//   > 20% loss → near failure; > 30% → stop the set

final class WatchRepDetector: NSObject, ObservableObject {

    // ── Published state ────────────────────────────────────────────────────
    @Published var reps: [RepEvent] = []
    @Published var currentPhase: RepPhase = .idle
    @Published var velocityLossPct: Double = 0
    @Published var lastConcentricSpeed: Double = 0
    @Published var isCalibrating: Bool = false

    // Callbacks
    var onRepCompleted: ((RepEvent) -> Void)?

    // ── Constants ──────────────────────────────────────────────────────────
    private let sampleRate:       Double = 50.0   // Hz
    private let alpha:            Double = 0.12   // EMA smoothing
    private let threshold:        Double = 0.28   // g — min acceleration to count as movement
    private let minPhaseDuration: TimeInterval = 0.20  // s — prevents noise bursts counting
    private let maxPhaseDuration: TimeInterval = 6.0   // s — reset if phase too long
    private let restDuration:     TimeInterval = 0.35  // s of sub-threshold to confirm idle
    private let calibrationTime:  TimeInterval = 1.5   // s of data before axis lock-in

    // ── Internal state ─────────────────────────────────────────────────────
    private let motionManager = CMMotionManager()
    private var smoothed: Double = 0

    // Calibration
    private var calibrationBuffer: [(x: Double, y: Double, z: Double)] = []
    private var primaryAxis: KeyPath<CMAcceleration, Double> = \.y
    private var axisLocked = false

    // Phase tracking
    private enum InternalPhase { case idle, eccentric, concentric }
    private var internalPhase: InternalPhase = .idle
    private var phaseStartTime: Date = Date()
    private var subThresholdStart: Date? = nil

    // Per-phase accumulators
    private var eccentricAccumulator: Double = 0
    private var eccentricSamples: Int = 0
    private var eccentricStart: Date = Date()

    private var concentricAccumulator: Double = 0
    private var concentricSamples: Int = 0
    private var concentricStart: Date = Date()
    private var peakConcentric: Double = 0

    // Velocity loss tracking
    private var baselineConcentricSpeed: Double? = nil

    // ── Public API ─────────────────────────────────────────────────────────

    func startDetection(exerciseName: String) {
        reset()
        guard motionManager.isDeviceMotionAvailable else { return }
        isCalibrating = true

        motionManager.deviceMotionUpdateInterval = 1.0 / sampleRate
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.processSample(motion.userAcceleration)
        }
    }

    func stopDetection() -> SetVelocityProfile {
        motionManager.stopDeviceMotionUpdates()
        let profile = SetVelocityProfile(exerciseName: "", reps: reps)
        reset()
        return profile
    }

    func reset() {
        reps = []
        currentPhase = .idle
        velocityLossPct = 0
        lastConcentricSpeed = 0
        smoothed = 0
        calibrationBuffer = []
        axisLocked = false
        isCalibrating = false
        internalPhase = .idle
        subThresholdStart = nil
        baselineConcentricSpeed = nil
        resetPhaseAccumulators()
    }

    // ── Sample processing ──────────────────────────────────────────────────

    private func processSample(_ accel: CMAcceleration) {
        // Calibration: collect samples to find dominant axis
        if !axisLocked {
            calibrationBuffer.append((accel.x, accel.y, accel.z))
            if Double(calibrationBuffer.count) / sampleRate >= calibrationTime {
                lockPrimaryAxis()
            }
            return
        }

        let raw = accel[keyPath: primaryAxis]
        // EMA smoothing
        smoothed = alpha * raw + (1 - alpha) * smoothed

        updateStateMachine(smoothed: smoothed, absAccel: abs(raw))
    }

    // ── Axis calibration ───────────────────────────────────────────────────

    private func lockPrimaryAxis() {
        let xs = calibrationBuffer.map(\.x)
        let ys = calibrationBuffer.map(\.y)
        let zs = calibrationBuffer.map(\.z)

        let varX = variance(xs); let varY = variance(ys); let varZ = variance(zs)

        if varX >= varY && varX >= varZ       { primaryAxis = \.x }
        else if varY >= varX && varY >= varZ  { primaryAxis = \.y }
        else                                   { primaryAxis = \.z }

        axisLocked = true
        isCalibrating = false
        calibrationBuffer = []
    }

    private func variance(_ vals: [Double]) -> Double {
        guard vals.count > 1 else { return 0 }
        let mean = vals.reduce(0, +) / Double(vals.count)
        return vals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(vals.count)
    }

    // ── State machine ──────────────────────────────────────────────────────

    private func updateStateMachine(smoothed: Double, absAccel: Double) {
        let now = Date()
        let phaseDuration = now.timeIntervalSince(phaseStartTime)

        switch internalPhase {

        case .idle:
            if smoothed < -threshold {
                // Start tracking a potential eccentric phase
                enterEccentric(at: now)
            } else if smoothed > threshold {
                // Some exercises start concentric (e.g., squat from top)
                enterConcentric(at: now)
            }

        case .eccentric:
            // Accumulate speed data
            eccentricAccumulator += absAccel
            eccentricSamples += 1

            if phaseDuration > maxPhaseDuration {
                // Phase too long — reset (between-set noise)
                enterIdle(at: now)
            } else if smoothed > -threshold * 0.5 {
                // Signal is rising back toward zero — turnaround happening
                if smoothed > threshold {
                    enterConcentric(at: now)
                } else {
                    // Brief transition — wait to see if concentric starts
                }
            }

        case .concentric:
            concentricAccumulator += absAccel
            concentricSamples += 1
            if absAccel > peakConcentric { peakConcentric = absAccel }

            if phaseDuration > maxPhaseDuration {
                enterIdle(at: now)
            } else if smoothed < threshold * 0.5 {
                // Concentric ending — check sub-threshold duration for rep confirmation
                if subThresholdStart == nil { subThresholdStart = now }
                let subDuration = now.timeIntervalSince(subThresholdStart!)
                if subDuration >= restDuration {
                    completeRep(at: now)
                    enterIdle(at: now)
                }
            } else {
                subThresholdStart = nil
            }
        }
    }

    // ── Phase transitions ──────────────────────────────────────────────────

    private func enterIdle(at date: Date) {
        internalPhase = .idle
        phaseStartTime = date
        subThresholdStart = nil
        DispatchQueue.main.async { self.currentPhase = .idle }
    }

    private func enterEccentric(at date: Date) {
        guard internalPhase != .eccentric else { return }
        internalPhase = .eccentric
        phaseStartTime = date
        eccentricStart = date
        eccentricAccumulator = 0
        eccentricSamples = 0
        subThresholdStart = nil
        DispatchQueue.main.async { self.currentPhase = .eccentric }
    }

    private func enterConcentric(at date: Date) {
        guard internalPhase != .concentric else { return }
        let eccentricDur = date.timeIntervalSince(eccentricStart)
        // Only accept eccentric if it was a plausible duration
        guard eccentricDur >= minPhaseDuration || internalPhase == .idle else { return }

        internalPhase = .concentric
        phaseStartTime = date
        concentricStart = date
        concentricAccumulator = 0
        concentricSamples = 0
        peakConcentric = 0
        subThresholdStart = nil
        DispatchQueue.main.async { self.currentPhase = .concentric }
    }

    // ── Rep completion ─────────────────────────────────────────────────────

    private func completeRep(at date: Date) {
        let eccDur  = concentricStart.timeIntervalSince(eccentricStart)
        let conDur  = date.timeIntervalSince(concentricStart)

        guard eccDur >= minPhaseDuration, conDur >= minPhaseDuration else { return }

        let eccSpeed = eccentricSamples > 0 ? eccentricAccumulator / Double(eccentricSamples) : 0
        let conSpeed = concentricSamples > 0 ? concentricAccumulator / Double(concentricSamples) : 0

        if baselineConcentricSpeed == nil { baselineConcentricSpeed = conSpeed }

        let lossF: Double = {
            guard let base = baselineConcentricSpeed, base > 0 else { return 0 }
            return max(0, (base - conSpeed) / base)
        }()

        let event = RepEvent(
            repNumber:            reps.count + 1,
            eccentricDuration:    eccDur,
            concentricDuration:   conDur,
            eccentricSpeed:       eccSpeed,
            concentricSpeed:      conSpeed,
            peakConcentricAccel:  peakConcentric,
            velocityLossFraction: lossF
        )

        DispatchQueue.main.async {
            self.reps.append(event)
            self.lastConcentricSpeed = conSpeed
            self.velocityLossPct = lossF * 100
            self.onRepCompleted?(event)
        }

        resetPhaseAccumulators()
    }

    private func resetPhaseAccumulators() {
        eccentricAccumulator = 0; eccentricSamples = 0
        concentricAccumulator = 0; concentricSamples = 0
        peakConcentric = 0
    }
}
