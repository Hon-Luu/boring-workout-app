import Foundation

// MARK: - Plan Feedback (P-001)

struct PlanFeedback: Codable {
    var id: UUID = UUID()
    var planId: UUID
    var action: String   // "started" or "skipped"
    var timestamp: Date
    var focusRegions: [BodyRegion]
}

// MARK: - Guided Workout Plan

struct GuidedWorkoutPlan: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let bodyRegions: [BodyRegion]
    let exercises: [GuidedExercise]
    let estimatedMinutes: Int
    let intensity: Intensity
    let coachNote: String
    /// T-003: split description (e.g. "Full Body", "Upper Body", "Push")
    var splitLabel: String = ""
    /// T-003: progression rationale (e.g. "Progressive overload — weight nudged up from last session")
    var progressionNote: String? = nil
    /// T-003: recovery / gap note (e.g. "Gap detected — intensity eased to rebuild consistency")
    var recoveryNote: String? = nil

    enum Intensity: String {
        case light    = "Light"
        case moderate = "Moderate"
        case heavy    = "Heavy"

        var color: String {
            switch self {
            case .light:    return "green"
            case .moderate: return "orange"
            case .heavy:    return "red"
            }
        }
    }
}

// MARK: - Guided Exercise

struct GuidedExercise: Identifiable {
    let id: UUID
    let exercise: Exercise
    let targetSets: Int
    let targetReps: Int
    let targetWeight: Double   // 0 = use last performance or bodyweight
    var completedSets: [SetRecord]
    /// T-014: performance trend tag — set by WorkoutPlanEngine when analytics are available
    var performanceTag: String? = nil

    init(exercise: Exercise, targetSets: Int, targetReps: Int, targetWeight: Double = 0, performanceTag: String? = nil) {
        self.id = UUID()
        self.exercise = exercise
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.completedSets = []
        self.performanceTag = performanceTag
    }

    var isComplete: Bool { completedSets.filter(\.isCompleted).count >= targetSets }
    var nextSetNumber: Int { completedSets.filter(\.isCompleted).count + 1 }
}
