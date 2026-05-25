import Foundation
import WatchConnectivity

/// Manages WatchConnectivity on the Watch side
@Observable
class WatchSessionManager: NSObject {
    static let shared = WatchSessionManager()

    // MARK: - Published State

    /// Currently active workout session
    var activeSession: WatchWorkoutSession?

    /// Whether connected to iPhone
    var isConnected: Bool = false

    // MARK: - Private Properties

    private var wcSession: WCSession?

    // MARK: - Initialization

    override init() {
        super.init()
        setupWatchConnectivity()
    }

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }

        wcSession = WCSession.default
        wcSession?.delegate = self
        wcSession?.activate()
    }

    // MARK: - Public API

    /// Complete the current set with rep count
    func completeSet(reps: Int, confidence: Double) {
        guard let session = activeSession else { return }

        let setNumber = session.completedSets + 1

        let update = WatchWorkoutUpdate(
            sessionId: session.sessionId,
            setNumber: setNumber,
            actualReps: reps,
            weight: session.setRecords[session.completedSets].weight,
            motionConfidence: confidence
        )

        // Update local state
        var updatedSession = session
        if setNumber <= updatedSession.setRecords.count {
            updatedSession.setRecords[setNumber - 1].actualReps = reps
            updatedSession.setRecords[setNumber - 1].isCompleted = true
            updatedSession.completedSets = setNumber
            activeSession = updatedSession
        }

        // Send to iPhone
        sendUpdate(update)

        // Check if workout complete
        if updatedSession.completedSets >= updatedSession.plannedSets {
            endWorkout()
        }
    }

    /// Adjust rep count for current set
    func adjustReps(_ setNumber: Int, to reps: Int) {
        guard var session = activeSession else { return }

        if setNumber <= session.setRecords.count {
            session.setRecords[setNumber - 1].actualReps = reps
            activeSession = session
        }

        // Send adjustment to iPhone
        let message: [String: Any] = [
            "command": WatchCommand.adjustReps.rawValue,
            "setNumber": setNumber,
            "reps": reps
        ]

        wcSession?.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    /// Skip rest timer
    func skipRestTimer() {
        let message: [String: Any] = [
            "command": WatchCommand.skipRestTimer.rawValue
        ]

        wcSession?.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    /// End the current workout
    func endWorkout() {
        let message: [String: Any] = [
            "command": WatchCommand.endSession.rawValue
        ]

        wcSession?.sendMessage(message, replyHandler: nil, errorHandler: nil)
        activeSession = nil
    }

    // MARK: - Private Methods

    private func sendUpdate(_ update: WatchWorkoutUpdate) {
        guard let wcSession = wcSession, wcSession.isReachable else { return }

        do {
            let payload = try JSONEncoder().encode(update)
            let message: [String: Any] = [
                "command": WatchCommand.completeSet.rawValue,
                "payload": payload
            ]

            wcSession.sendMessage(message, replyHandler: nil, errorHandler: { error in
                print("[Watch] Failed to send update: \(error.localizedDescription)")
            })
        } catch {
            print("[Watch] Failed to encode update: \(error)")
        }
    }

    private func handleMessage(_ message: [String: Any]) {
        guard let commandString = message["command"] as? String,
              let command = WatchCommand(rawValue: commandString) else {
            return
        }

        switch command {
        case .startSession:
            handleStartSession(message)

        case .endSession:
            activeSession = nil

        case .adjustWeight:
            handleWeightAdjustment(message)

        case .startRestTimer:
            // Rest timer is handled by UI
            break

        case .ping:
            // Respond to ping
            wcSession?.sendMessage(["command": WatchCommand.pong.rawValue], replyHandler: nil, errorHandler: nil)

        default:
            break
        }
    }

    private func handleStartSession(_ message: [String: Any]) {
        guard let payloadData = message["payload"] as? Data,
              let session = try? JSONDecoder().decode(WatchWorkoutSession.self, from: payloadData) else {
            return
        }

        activeSession = session
    }

    private func handleWeightAdjustment(_ message: [String: Any]) {
        guard let setNumber = message["setNumber"] as? Int,
              let weight = message["weight"] as? Double,
              var session = activeSession else {
            return
        }

        if setNumber <= session.setRecords.count {
            session.setRecords[setNumber - 1].weight = weight
            activeSession = session
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("[Watch] Activation failed: \(error.localizedDescription)")
                self.isConnected = false
            } else {
                self.isConnected = activationState == .activated && session.isReachable
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
        }
    }

    // MARK: - Receiving Messages

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.handleMessage(message)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleMessage(message)

            // Acknowledge receipt
            if let commandString = message["command"] as? String,
               let command = WatchCommand(rawValue: commandString) {
                if command == .ping {
                    replyHandler(["command": WatchCommand.pong.rawValue])
                } else {
                    replyHandler(["received": true])
                }
            } else {
                replyHandler(["received": true])
            }
        }
    }
}
