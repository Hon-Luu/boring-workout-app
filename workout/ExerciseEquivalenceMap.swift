import Foundation

// MARK: - ExerciseEquivalenceMap

/// Static groups of exercises that are direct substitutes for each other
/// (same movement pattern and joint angles, different equipment/load type).
///
/// Used by quickSwapEquipment and bestVariant so that swapping Barbell Bench →
/// Dumbbell Bench → Barbell Bench always returns to the original exercise.
struct ExerciseEquivalenceMap {

    // Each inner array is one equivalence group.
    // Adding an exercise here does NOT change its properties — it only scopes
    // which alternatives the swap chips surface.
    static let groups: [[String]] = [
        // ── CHEST ────────────────────────────────────────────────────────────
        ["Barbell Bench Press", "Dumbbell Bench Press", "Chest Press Machine",
         "Smith Machine Bench Press", "Hammer Strength Chest Press"],

        ["Incline Barbell Press", "Incline Dumbbell Press", "Incline Chest Press Machine",
         "Smith Machine Incline Press"],

        ["Decline Chest Press Machine"],

        ["Dip", "Assisted Dip Machine"],

        ["Push-Up", "Incline Push-Up", "Decline Push-Up", "Diamond Push-Up", "Wide Push-Up"],

        ["Cable Fly", "Dumbbell Fly", "Cable Crossover", "Pec Deck"],

        // ── SHOULDERS ────────────────────────────────────────────────────────
        ["Overhead Press", "Dumbbell Shoulder Press", "Machine Shoulder Press",
         "Smith Machine Overhead Press", "Arnold Press", "Hammer Strength Shoulder Press"],

        ["Pike Push-Up"],

        ["Lateral Raise", "Cable Lateral Raise", "Machine Lateral Raise"],

        ["Rear Delt Fly", "Rear Delt Machine", "Cable Rear Delt Fly"],

        // ── BACK ─────────────────────────────────────────────────────────────
        ["Deadlift", "Smith Machine Deadlift", "Sumo Deadlift"],

        ["Barbell Row", "Single-Arm Dumbbell Row", "Seated Cable Row", "T-Bar Row",
         "Low Row Machine", "Chest-Supported Row Machine", "Smith Machine Row",
         "Seated Row Machine (Neutral)", "Hammer Strength Row"],

        ["Pull-Up", "Chin-Up", "Assisted Pull-Up Machine"],

        ["Lat Pulldown", "Reverse Grip Lat Pulldown", "Hammer Strength Lat Pulldown"],

        ["Face Pull"],

        ["Lat Pullover Machine", "Nautilus Pullover Machine"],

        // ── ARMS ─────────────────────────────────────────────────────────────
        ["Barbell Curl", "Dumbbell Curl", "Cable Curl", "Machine Bicep Curl",
         "Preacher Curl Machine"],

        ["Hammer Curl", "Cable Hammer Curl"],

        ["Tricep Pushdown", "Rope Pushdown"],

        ["Skull Crusher", "Close-Grip Bench Press", "Smith Machine Close-Grip Press",
         "Overhead Tricep Extension", "Cable Overhead Tricep Extension",
         "Tricep Machine", "Tricep Extension Machine"],

        // ── LEGS ─────────────────────────────────────────────────────────────
        ["Barbell Squat", "Smith Machine Squat", "Hack Squat Machine",
         "Belt Squat Machine", "Pendulum Squat Machine", "Goblet Squat",
         "Bodyweight Squat"],

        ["Leg Press", "Single-Leg Press", "Vertical Leg Press"],

        ["Bulgarian Split Squat", "Smith Machine Split Squat"],

        ["Walking Lunge", "Smith Machine Lunge", "Bodyweight Lunge",
         "Reverse Lunge", "Jump Lunge"],

        ["Romanian Deadlift", "Smith Machine Romanian Deadlift"],

        ["Hip Thrust", "Hip Thrust Machine", "Smith Machine Hip Thrust",
         "Glute Bridge"],

        ["Jump Squat", "Box Jump", "Jump Lunge"],

        // ── CORE ─────────────────────────────────────────────────────────────
        ["Plank", "Dead Bug", "Hollow Body Hold"],

        ["Hanging Leg Raise", "Captain's Chair Leg Raise"],

        ["Sit-Up", "GHD Sit-Up"],

        ["Bicycle Crunch", "Russian Twist", "Seated Oblique Machine", "Rotary Torso Machine"],

        ["Ab Wheel Rollout"],

        ["Cable Crunch", "Machine Crunch"],

        ["Mountain Climber", "Bear Crawl", "Burpee", "Inchworm"],
    ]

    // MARK: - Reverse index (built once)

    private static let nameToGroupIndex: [String: Int] = {
        var map: [String: Int] = [:]
        for (i, group) in groups.enumerated() {
            for name in group { map[name] = i }
        }
        return map
    }()

    // MARK: - Public API

    /// Returns all exercise names in the same equivalence group as `exercise`,
    /// excluding the exercise itself. Returns nil if the exercise is not in any group.
    static func equivalentNames(for exercise: Exercise) -> [String]? {
        guard let idx = nameToGroupIndex[exercise.name] else { return nil }
        let names = groups[idx].filter { $0 != exercise.name }
        return names.isEmpty ? nil : names
    }

    /// Returns true when both exercises belong to the same equivalence group.
    static func areEquivalent(_ a: Exercise, _ b: Exercise) -> Bool {
        guard let idxA = nameToGroupIndex[a.name],
              let idxB = nameToGroupIndex[b.name] else { return false }
        return idxA == idxB
    }
}
