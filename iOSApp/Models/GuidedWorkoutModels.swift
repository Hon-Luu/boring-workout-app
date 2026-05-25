import Foundation

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

    init(exercise: Exercise, targetSets: Int, targetReps: Int, targetWeight: Double = 0) {
        self.id = UUID()
        self.exercise = exercise
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.completedSets = []
    }

    var isComplete: Bool { completedSets.filter(\.isCompleted).count >= targetSets }
    var nextSetNumber: Int { completedSets.filter(\.isCompleted).count + 1 }
}
