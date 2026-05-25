import Foundation
import WatchConnectivity
import Combine

// MARK: - iPhone-side WatchConnectivity manager

final class WatchConnectivityManager: NSObject, ObservableObject {

    static let shared = WatchConnectivityManager()

    // ── Published state ────────────────────────────────────────────────────

    @Published var isWatchPaired: Bool = false
    @Published var isWatchReachable: Bool = false
    @Published var isWatchAppInstalled: Bool = false

    // Live data for the currently active set
    @Published var liveRepEvents: [RepEvent] = []
    @Published var currentRepCount: Int = 0
    @Published var currentPhase: RepPhase = .idle
    @Published var lastRepSpeed: Double = 0          // m/s² proxy
    @Published var velocityLossPct: Double = 0

    // Completed set profiles received from Watch
    @Published var completedSetProfiles: [SetVelocityProfile] = []

    // Callbacks for SeedStore integration
    var onRepDetected: ((RepEvent) -> Void)?
    var onSetComplete: ((SetVelocityProfile) -> Void)?

    // ── Session ────────────────────────────────────────────────────────────

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    private override init() {
        super.init()
        activate()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // ── Send to Watch ──────────────────────────────────────────────────────

    func sendWorkoutStarted() {
        send([WatchMessageKey.type: WatchMessageType.workoutStarted.rawValue])
    }

    func sendWorkoutEnded() {
        send([WatchMessageKey.type: WatchMessageType.workoutEnded.rawValue])
        clearLiveData()
    }

    func sendActiveExercise(_ name: String) {
        send([
            WatchMessageKey.type: WatchMessageType.activeExercise.rawValue,
            WatchMessageKey.currentExercise: name
        ])
    }

    func sendSetStarted(exerciseName: String) {
        clearLiveData()
        send([
            WatchMessageKey.type: WatchMessageType.setStarted.rawValue,
            WatchMessageKey.currentExercise: exerciseName
        ])
    }

    // ── Private helpers ────────────────────────────────────────────────────

    private func send(_ message: [String: Any]) {
        guard let session, session.activationState == .activated,
              session.isReachable else { return }
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    private func clearLiveData() {
        DispatchQueue.main.async {
            self.liveRepEvents = []
            self.currentRepCount = 0
            self.currentPhase = .idle
            self.lastRepSpeed = 0
            self.velocityLossPct = 0
        }
    }

    private func handle(repEvent: RepEvent) {
        DispatchQueue.main.async {
            self.liveRepEvents.append(repEvent)
            self.currentRepCount = repEvent.repNumber
            self.lastRepSpeed = repEvent.concentricSpeed
            self.velocityLossPct = repEvent.velocityLossFraction * 100
            self.onRepDetected?(repEvent)
        }
    }

    private func handle(setProfile: SetVelocityProfile) {
        DispatchQueue.main.async {
            self.completedSetProfiles.append(setProfile)
            self.onSetComplete?(setProfile)
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isWatchPaired        = session.isPaired
            self.isWatchReachable     = session.isReachable
            self.isWatchAppInstalled  = session.isWatchAppInstalled
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchPaired        = session.isPaired
            self.isWatchReachable     = session.isReachable
            self.isWatchAppInstalled  = session.isWatchAppInstalled
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let typeRaw = message[WatchMessageKey.type] as? String,
              let type = WatchMessageType(rawValue: typeRaw) else { return }

        switch type {
        case .repDetected:
            if let data = message[WatchMessageKey.repEvent] as? Data,
               let event = try? JSONDecoder().decode(RepEvent.self, from: data) {
                handle(repEvent: event)
            }

        case .setComplete:
            if let data = message[WatchMessageKey.setProfile] as? Data,
               let profile = try? JSONDecoder().decode(SetVelocityProfile.self, from: data) {
                handle(setProfile: profile)
            }

        default:
            break
        }
    }

    // Receives transferred user info when Watch app runs in background
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        self.session(session, didReceiveMessage: userInfo)
    }
}
