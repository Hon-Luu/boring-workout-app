import Foundation

// MARK: - ActivitySession Protocol

protocol ActivitySession: Identifiable {
    var id: UUID { get }
    var startedAt: Date { get }
    var feelRating: FeelRating? { get }
}

// MARK: - Enums

enum MovementPattern: String, CaseIterable, Codable {
    case horizontalPush = "Horizontal Push"
    case verticalPush   = "Vertical Push"
    case horizontalPull = "Horizontal Pull"
    case verticalPull   = "Vertical Pull"
    case hipHinge       = "Hip Hinge"
    case kneeFlexion    = "Knee Flexion"
    case isolation      = "Isolation"

    var shortName: String {
        switch self {
        case .horizontalPush: return "H. Push"
        case .verticalPush:   return "V. Push"
        case .horizontalPull: return "H. Pull"
        case .verticalPull:   return "V. Pull"
        case .hipHinge:       return "Hip Hinge"
        case .kneeFlexion:    return "Squat/Lunge"
        case .isolation:      return "Isolation"
        }
    }

    var icon: String {
        switch self {
        case .horizontalPush: return "arrow.right.circle.fill"
        case .verticalPush:   return "arrow.up.circle.fill"
        case .horizontalPull: return "arrow.left.circle.fill"
        case .verticalPull:   return "arrow.down.circle.fill"
        case .hipHinge:       return "figure.strengthtraining.traditional"
        case .kneeFlexion:    return "figure.run"
        case .isolation:      return "dumbbell.fill"
        }
    }

    /// Minimum Detectable Change (kg) — below this threshold a delta is within measurement noise.
    /// Source: reliability meta-analyses (Grgic et al., 2020, Sports Med; ACSM MSSE 2021).
    var mdc: Double {
        switch self {
        case .horizontalPush: return 3.3    // bench press ±3.3 kg
        case .verticalPush:   return 4.0
        case .horizontalPull: return 4.5
        case .verticalPull:   return 4.0
        case .hipHinge:       return 7.5    // deadlift / RDL ±7.5 kg
        case .kneeFlexion:    return 7.5    // squat ±7.5 kg
        case .isolation:      return 2.5
        }
    }
}

// Simplified grouping of the 7 movement patterns into 4 buckets
enum PatternGroup: String, CaseIterable, Codable {
    case push      = "Push"
    case pull      = "Pull"
    case legs      = "Legs"
    case isolation = "Isolation"

    var patterns: [MovementPattern] {
        switch self {
        case .push:      return [.horizontalPush, .verticalPush]
        case .pull:      return [.horizontalPull, .verticalPull]
        case .legs:      return [.hipHinge, .kneeFlexion]
        case .isolation: return [.isolation]
        }
    }

    var icon: String {
        switch self {
        case .push:      return "arrow.up.circle.fill"
        case .pull:      return "arrow.down.circle.fill"
        case .legs:      return "figure.run"
        case .isolation: return "dumbbell.fill"
        }
    }
}

enum BodyRegion: String, CaseIterable, Codable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case legs = "Legs"
    case core = "Core"

    var icon: String {
        switch self {
        case .chest: return "figure.arms.open"
        case .back: return "figure.strengthtraining.traditional"
        case .shoulders: return "bolt.fill"
        case .arms: return "hand.raised.fill"
        case .legs: return "figure.run"
        case .core: return "circle.grid.cross.fill"
        }
    }
}

enum Equipment: String, CaseIterable, Codable {
    case barbell    = "Barbell"
    case dumbbell   = "Dumbbell"
    case ezBar      = "EZ Bar"
    case straightBar = "Straight Bar"
    case cable      = "Cable"
    case machine    = "Machine"
    case bodyweight = "Bodyweight"
    case kettlebell = "Kettlebell"
}

extension Equipment {
    var chipLabel: String {
        switch self {
        case .barbell:     return "BB"
        case .dumbbell:    return "DB"
        case .ezBar:       return "EZ"
        case .straightBar: return "SB"
        case .cable:       return "Cable"
        case .machine:     return "Machine"
        case .bodyweight:  return "BW"
        case .kettlebell:  return "KB"
        }
    }

    /// Weight the user enters in the UI (total weight for all equipment types).
    /// Returns the effective weight used for all strength calculations.
    // stored = what the user enters:
    //   dumbbell     → total weight (both dumbbells combined, e.g. 2×20 kg = enter 40)
    //   barbell      → total loaded weight; floors at bar weight so entering 0 = empty bar
    //   ezBar        → total loaded weight; floors at EZ bar weight (10 kg)
    //   straightBar  → total loaded weight; floors at straight bar weight (6 kg)
    //   others       → as entered

    func effectiveWeight(_ entered: Double) -> Double {
        switch self {
        case .dumbbell:    return entered
        case .barbell:     return max(entered, Equipment.barbellBarKg)
        case .ezBar:       return max(entered, Equipment.ezBarKg)
        case .straightBar: return max(entered, Equipment.straightBarKg)
        default:           return entered
        }
    }

    static let barbellBarKg: Double   = 20
    static let ezBarKg: Double        = 10
    static let straightBarKg: Double  = 6
}

// MARK: - Exercise

struct Exercise: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let bodyRegion: BodyRegion
    let equipment: Equipment
    let isCompound: Bool
    let movementPattern: MovementPattern

    init(id: UUID, name: String, bodyRegion: BodyRegion, equipment: Equipment,
         isCompound: Bool, movementPattern: MovementPattern = .isolation) {
        self.id = id; self.name = name; self.bodyRegion = bodyRegion
        self.equipment = equipment; self.isCompound = isCompound
        self.movementPattern = movementPattern
    }

    // Machines where the logged weight is the counterbalance, not the load.
    // Effective load = bodyweight − loggedWeight (higher assist → lighter work).
    var isAssistedCounterweight: Bool {
        name == "Assisted Pull-Up Machine" || name == "Assisted Dip Machine"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, bodyRegion, equipment, isCompound, movementPattern
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self,            forKey: .id)
        name            = try c.decode(String.self,          forKey: .name)
        bodyRegion      = try c.decode(BodyRegion.self,      forKey: .bodyRegion)
        equipment       = try c.decode(Equipment.self,       forKey: .equipment)
        isCompound      = try c.decode(Bool.self,            forKey: .isCompound)
        movementPattern = try c.decodeIfPresent(MovementPattern.self, forKey: .movementPattern) ?? .isolation
    }
}

// MARK: - Set

struct SetRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var weight: Double = 0
    var reps: Int = 0
    var targetWeight: Double = 0
    var targetReps: Int = 0
    var isCompleted: Bool = false
    var completedAt: Date? = nil
    var velocityProfile: SetVelocityProfile? = nil
    var dropWeight: Double? = nil
    var dropReps: Int? = nil
    var isDropCompleted: Bool = false
    var toFailure: Bool = false
    var rpe: Double? = nil   // Rate of Perceived Exertion (6–10 scale); enables RPE-adjusted e1RM

    // Custom decoder so new fields (toFailure, rpe, drop*) don't break existing stored data
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decodeIfPresent(UUID.self,                forKey: .id)              ?? UUID()
        weight          = try c.decodeIfPresent(Double.self,              forKey: .weight)           ?? 0
        reps            = try c.decodeIfPresent(Int.self,                 forKey: .reps)             ?? 0
        targetWeight    = try c.decodeIfPresent(Double.self,              forKey: .targetWeight)     ?? 0
        targetReps      = try c.decodeIfPresent(Int.self,                 forKey: .targetReps)       ?? 0
        isCompleted     = try c.decodeIfPresent(Bool.self,                forKey: .isCompleted)      ?? false
        completedAt     = try c.decodeIfPresent(Date.self,                forKey: .completedAt)
        velocityProfile = try c.decodeIfPresent(SetVelocityProfile.self,  forKey: .velocityProfile)
        dropWeight      = try c.decodeIfPresent(Double.self,              forKey: .dropWeight)
        dropReps        = try c.decodeIfPresent(Int.self,                 forKey: .dropReps)
        isDropCompleted = try c.decodeIfPresent(Bool.self,                forKey: .isDropCompleted)  ?? false
        toFailure       = try c.decodeIfPresent(Bool.self,                forKey: .toFailure)        ?? false
        rpe             = try c.decodeIfPresent(Double.self,              forKey: .rpe)
    }

    init() {}

    init(weight: Double = 0, reps: Int = 0, targetWeight: Double = 0, targetReps: Int = 0) {
        self.weight = weight
        self.reps = reps
        self.targetWeight = targetWeight
        self.targetReps = targetReps
    }

    // MARK: Volume

    var volume: Double { weight * Double(reps) + (dropWeight ?? 0) * Double(dropReps ?? 0) }

    func effectiveVolume(equipment: Equipment) -> Double {
        let main = equipment.effectiveWeight(weight) * Double(reps)
        let drop = dropWeight.map { equipment.effectiveWeight($0) * Double(dropReps ?? 0) } ?? 0
        return main + drop
    }

    // MARK: e1RM — formula routing by rep range (peer-reviewed)
    // ≤10 reps: Epley (validated ±2–5%)
    // 11–20 reps: Mayhew (better accuracy at higher reps; validated up to ~20 reps)
    // 1 rep: exact; >20 reps: error too large to trust — return 0

    static func epley(_ w: Double, _ r: Int) -> Double    { w * (1.0 + Double(r) / 30.0) }
    static func mayhew(_ w: Double, _ r: Int) -> Double   { w / (0.522 + 0.419 * exp(-0.055 * Double(r))) }

    static func e1RM(weight w: Double, reps r: Int) -> Double {
        guard w > 0, r > 0 else { return 0 }
        switch r {
        case 1:       return w
        case 2...10:  return epley(w, r)
        case 11...20: return mayhew(w, r)
        default:      return 0   // >20 reps: formula error too large to trust
        }
    }

    var e1RMIsReliable: Bool { reps >= 1 && reps <= 20 && weight > 0 }

    var estimated1RM: Double { SetRecord.e1RM(weight: weight, reps: reps) }

    // Equipment-aware e1RM (bilateral total for dumbbell; bar-floored for barbell)
    func effectiveE1RM(equipment: Equipment) -> Double {
        SetRecord.e1RM(weight: equipment.effectiveWeight(weight), reps: reps)
    }

    // Bilateral-adjusted e1RM for aggregated strength scores.
    // Bilateral deficit: simultaneous bilateral force ≈ 92% of summed unilateral maxima
    // (Botton et al., 2016, Front Physiol). Only applied to dumbbell (already bilateral-summed).
    func bilateralAdjustedE1RM(equipment: Equipment) -> Double {
        let raw = effectiveE1RM(equipment: equipment)
        return equipment == .dumbbell ? raw * 0.92 : raw
    }

    // Drop-set-aware e1RM: takes the max of the main set and the drop set.
    // Drop sets at lower weight with many reps can sometimes yield a higher e1RM estimate
    // than a heavy main set done for very few reps (e.g. 25×1 + drop 20×8: drop wins).
    // This prevents drop-set training from creating false e1RM regressions in progress tracking.
    func dropAdjustedE1RM(equipment: Equipment) -> Double {
        let mainE1RM = bilateralAdjustedE1RM(equipment: equipment)
        guard isDropCompleted,
              let dw = dropWeight, dw > 0,
              let dr = dropReps, dr > 0, dr <= 20 else {
            return mainE1RM
        }
        let dropW   = equipment.effectiveWeight(dw)
        let dropRaw = SetRecord.e1RM(weight: dropW, reps: dr)
        let dropE1RM = equipment == .dumbbell ? dropRaw * 0.92 : dropRaw
        return max(mainE1RM, dropE1RM)
    }

    // RPE-adjusted e1RM (Zourdos et al., 2016, JSCR)
    // Estimates rested 1RM by accounting for reps-in-reserve at the logged RPE.
    // rpe: 6 = trivial, 10 = true max (no reps left)
    func rpeAdjustedE1RM(equipment: Equipment) -> Double? {
        guard let rpe, rpe >= 6, rpe <= 10, reps > 0 else { return nil }
        let w = equipment.effectiveWeight(weight)
        guard w > 0 else { return nil }
        let rir = 10.0 - rpe
        let totalReps = Double(reps) + rir
        let divisor = 1.0 - totalReps / 40.9   // Zourdos load-velocity conversion
        guard divisor > 0 else { return nil }
        let raw = w / divisor
        return equipment == .dumbbell ? raw * 0.92 : raw
    }

    // MARK: Outcome

    enum RepOutcome { case hit, exceeded, missed }
    var repOutcome: RepOutcome {
        guard isCompleted else { return .hit }
        if toFailure { return .hit }
        guard targetReps > 0 else { return .hit }
        if reps == targetReps { return .hit }
        return reps > targetReps ? .exceeded : .missed
    }
}

// MARK: - Warm-Up Set Suggestion (F-35)

struct WarmupSet {
    let percentage: Double
    let reps: Int
    let weight: Double
    var displayPct: String { "\(Int(percentage * 100))%" }
}

// MARK: - Workout Exercise

struct WorkoutExercise: Identifiable, Codable {
    var id: UUID = UUID()
    var exercise: Exercise
    var sets: [SetRecord]
    var notes: String = ""
    var supersetGroup: String? = nil  // e.g. "A", "B" — exercises sharing a letter are a superset

    var completedSets: [SetRecord] { sets.filter(\.isCompleted) }
    var totalVolume: Double { completedSets.reduce(0) { $0 + $1.volume } }
    var bestSet: SetRecord? { completedSets.max(by: { $0.estimated1RM < $1.estimated1RM }) }

    // F-35: Warm-up set suggestions based on the first working set's target weight.
    // Returns three warm-up steps at 40/60/80 % of working weight, rounded to nearest 2.5 kg.
    var warmupSets: [WarmupSet] {
        guard let working = sets.first(where: { $0.targetWeight > 0 }), working.targetWeight > 0 else { return [] }
        let w = working.targetWeight
        return [
            WarmupSet(percentage: 0.40, reps: 10, weight: (w * 0.40 / 2.5).rounded() * 2.5),
            WarmupSet(percentage: 0.60, reps: 5,  weight: (w * 0.60 / 2.5).rounded() * 2.5),
            WarmupSet(percentage: 0.80, reps: 3,  weight: (w * 0.80 / 2.5).rounded() * 2.5),
        ]
    }
}

// MARK: - Feel Rating

enum FeelRating: String, CaseIterable, Codable {
    case easy   = "Easy"
    case strong = "Strong"
    case normal = "Normal"
    case tired  = "Tired"
    case brutal = "Brutal"

    var costMultiplier: Double {
        switch self {
        case .easy:   return 0.80
        case .strong: return 0.85
        case .normal: return 1.00
        case .tired:  return 1.20
        case .brutal: return 1.40
        }
    }

    var icon: String {
        switch self {
        case .easy:   return "😌"
        case .strong: return "🔥"
        case .normal: return "💪"
        case .tired:  return "😴"
        case .brutal: return "😤"
        }
    }
}

// MARK: - Workout Log Entry

struct WorkoutLogEntry: Identifiable, Codable, ActivitySession {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var finishedAt: Date? = nil
    var name: String = ""
    var exercises: [WorkoutExercise] = []
    var notes: String = ""
    var averageHeartRate: Double? = nil
    var activeCalories: Double? = nil     // kcal burned, from HealthKit
    var feelRating: FeelRating? = nil
    var readinessBefore: Int? = nil   // 1=Tired, 2=Normal, 3=Strong — captured before first set

    var duration: TimeInterval {
        (finishedAt ?? Date()).timeIntervalSince(startedAt)
    }
    var totalVolume: Double { exercises.reduce(0) { $0 + $1.totalVolume } }
    var totalSets: Int { exercises.reduce(0) { $0 + $1.completedSets.count } }

    var formattedDuration: String {
        let d = Int(duration)
        let h = d / 3600, m = (d % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    var muscleGroups: String {
        let regions = exercises.map(\.exercise.bodyRegion.rawValue)
        let unique = NSOrderedSet(array: regions).array as! [String]
        return unique.prefix(3).joined(separator: ", ")
    }
}

// MARK: - Workout Template

struct WorkoutTemplate: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String = "My Routine"
    var exercises: [TemplateExercise] = []
    var circuitIds: [UUID] = []
    var restDayWeekdays: [Int] = []

    // Custom decoder so circuitIds/restDayWeekdays (added later) don't break existing stored data
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decodeIfPresent(UUID.self,               forKey: .id)               ?? UUID()
        name             = try c.decodeIfPresent(String.self,             forKey: .name)             ?? "My Routine"
        exercises        = try c.decodeIfPresent([TemplateExercise].self, forKey: .exercises)        ?? []
        circuitIds       = try c.decodeIfPresent([UUID].self,             forKey: .circuitIds)       ?? []
        restDayWeekdays  = try c.decodeIfPresent([Int].self,              forKey: .restDayWeekdays)  ?? []
    }

    init(name: String = "My Routine", exercises: [TemplateExercise] = [], circuitIds: [UUID] = [], restDayWeekdays: [Int] = []) {
        self.id              = UUID()
        self.name            = name
        self.exercises       = exercises
        self.circuitIds      = circuitIds
        self.restDayWeekdays = restDayWeekdays
    }
}

struct TemplateExercise: Identifiable, Codable {
    var id: UUID = UUID()
    let exercise: Exercise
    var targetSets: Int = 3
    var targetReps: Int = 10
    var assignedDays: [Int] = []    // Calendar.weekday: 1=Sun … 7=Sat
    var supersetGroup: String? = nil // e.g. "A", "B" — shared letter = paired

    static let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let shortDayNames = ["", "S", "M", "T", "W", "T", "F", "S"]

    var dayLabel: String {
        guard !assignedDays.isEmpty else { return "No days" }
        return assignedDays.sorted()
            .compactMap { Self.dayNames[safe: $0] }
            .joined(separator: " · ")
    }
}

// MARK: - Personal Record

struct PersonalRecord: Identifiable, Codable {
    var id: UUID = UUID()
    let exerciseId: UUID
    let exerciseName: String
    var weight: Double
    var reps: Int
    var estimated1RM: Double
    var date: Date = Date()
}

// MARK: - Weight History (F-12)

struct WeightEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let kg: Double
}

// MARK: - User Body Profile

struct UserProfile: Codable, Equatable {
    var bodyWeightKg: Double?         // reflects the most recent WeightEntry; required for normalized PSI and relative strength
    var weightHistory: [WeightEntry] = []
    var age: Int?                      // used for age-adjusted tier thresholds
    var bodyFatPercent: Double?        // from smart scale: body fat %
    var muscleMassPercent: Double?     // from smart scale: lean body mass % (not skeletal muscle %; range ~50–90)
    var boneMassKg: Double?            // from smart scale: bone mass in kg
    var waterPercent: Double?          // from smart scale: body water %
    var heightCm: Double?              // for future BMI / relative scaling
    /// Expert override for fatigue decay α. nil = auto (tier-based); valid range 0.03–0.10
    var customFatigueDecay: Double?

    var hasBodyComposition: Bool {
        bodyFatPercent != nil || muscleMassPercent != nil
    }

    var leanMassKg: Double? {
        guard let bw = bodyWeightKg, let bf = bodyFatPercent else { return nil }
        return bw * (1.0 - bf / 100.0)
    }

    var muscleMassKg: Double? {
        guard let bw = bodyWeightKg, let mm = muscleMassPercent else { return nil }
        return bw * mm / 100.0
    }
}

// MARK: - Weight Suggestion

struct WeightSuggestion: Identifiable {
    let id: UUID
    let exerciseId: UUID
    let exerciseName: String
    let currentWeightKg: Double
    let suggestedWeightKg: Double
    let reason: String
    let isCompound: Bool
}

// MARK: - Helpers

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Double {
    var weightFormatted: String {
        truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(self))" : String(format: "%.1f", self)
    }
}
