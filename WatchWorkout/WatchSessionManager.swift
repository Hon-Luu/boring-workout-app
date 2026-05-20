import Foundation
import WatchConnectivity

// MARK: - Watch-side session coordinator
//
// Manages the rep detector, sends events to iPhone via WatchConnectivity,
// and tracks workout/set state from iPhone instructions.

final class WatchSessionManager: NSObject, ObservableObject {

    // ── Published state ────────────────────────────────────────────────────
    @Published var isWorkoutActive: Bool = false
    @Published var currentExerciseName: String = "Tap iPhone to start"
    @Published var isSetRecording: Bool = false
    @Published var reps: [RepEvent] = []
    @Published var currentPhase: RepPhase = .idle
    @Published var velocityLossPct: Double = 0
    @Published var lastRepSpeed: Double = 0
    @Published var fatigueLevel: VBTFatigueLevel = .fresh
    @Published var isWatchConnected: Bool = false

    // ── Dependencies ───────────────────────────────────────────────────────
    let detector = WatchRepDetector()
    private var session: WCSession?

    override init() {
        super.init()
        setupConnectivity()
        bindDetector()
    }

    // ── WatchConnectivity setup ────────────────────────────────────────────

    private func setupConnectivity() {
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // ── Detector binding ───────────────────────────────────────────────────

    private func bindDetector() {
        detector.onRepCompleted = { [weak self] event in
            guard let self else { return }
            DispatchQueue.main.async {
                self.reps = self.detector.reps
                self.currentPhase = self.detector.currentPhase
                self.velocityLossPct = self.detector.velocityLossPct
                self.lastRepSpeed = self.detector.lastConcentricSpeed
                self.fatigueLevel = VBTFatigueLevel(velocityLossPct: self.detector.velocityLossPct)
                self.sendRepToPhone(event)
            }
        }
    }

    // ── User actions ───────────────────────────────────────────────────────

    func startSet() {
        reps = []
        isSetRecording = true
        detector.startDetection(exerciseName: currentExerciseName)
        sendToPhone([WatchMessageKey.type: WatchMessageType.setStarted.rawValue,
                     WatchMessageKey.currentExercise: currentExerciseName])
    }

    func endSet() {
        let profile = detector.stopDetection()
        isSetRecording = false
        currentPhase = .idle
        // Build a proper profile with the exercise name
        let fullProfile = SetVelocityProfile(exerciseName: currentExerciseName, reps: reps)
        sendSetProfileToPhone(fullProfile)
        reps = []
    }

    func cancelSet() {
        _ = detector.stopDetection()
        isSetRecording = false
        currentPhase = .idle
        reps = []
    }

    // ── Send to iPhone ─────────────────────────────────────────────────────

    private func sendRepToPhone(_ event: RepEvent) {
        guard let data = try? JSONEncoder().encode(event) else { return }
        sendToPhone([
            WatchMessageKey.type: WatchMessageType.repDetected.rawValue,
            WatchMessageKey.repEvent: data
        ])
    }

    private func sendSetProfileToPhone(_ profile: SetVelocityProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        let msg: [String: Any] = [
            WatchMessageKey.type: WatchMessageType.setComplete.rawValue,
            WatchMessageKey.setProfile: data
        ]
        if let session, session.isReachable {
            session.sendMessage(msg, replyHandler: nil, errorHandler: nil)
        } else {
            session?.transferUserInfo(msg)
        }
    }

    private func sendToPhone(_ message: [String: Any]) {
        guard let session, session.activationState == .activated else { return }
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }
}

// MARK: - WCSessionDelegate (Watch side)

extension WatchSessionManager: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = (state == .activated)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let typeRaw = message[WatchMessageKey.type] as? String,
              let type = WatchMessageType(rawValue: typeRaw) else { return }

        DispatchQueue.main.async {
            switch type {
            case .workoutStarted:
                self.isWorkoutActive = true
            case .workoutEnded:
                self.isWorkoutActive = false
                if self.isSetRecording { self.cancelSet() }
            case .activeExercise:
                if let name = message[WatchMessageKey.currentExercise] as? String {
                    self.currentExerciseName = name
                }
            default:
                break
            }
        }
    }
}
