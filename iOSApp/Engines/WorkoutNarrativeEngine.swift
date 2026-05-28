import Foundation

// MARK: - Phrase bank models

private struct Phrase: Decodable {
    let id: Int
    let phrase: String
}

private struct PhraseBank: Decodable {
    let reps: [String: [Phrase]]
    let weight: [String: [Phrase]]
    let trend: [String: [Phrase]]
    let history: [String: [Phrase]]
    let whats_next: [String: [Phrase]]
    let connective: [String: [Phrase]]
    let frames: [String: [Phrase]]
    let combos: [String: [Phrase]]
}

// MARK: - Exercise analysis

private struct ExerciseAnalysis {
    let exerciseId: UUID
    let name: String
    let isCompound: Bool
    let repOutcome: RepOutcome
    let weightState: WeightState
    let trendKey: String        // "Improving" / "Declining" / "Plateauing Below" / "Plateauing At" / "Omitted"
    let historyKey: String      // "Normal" / "First Time" / "Short Gap" / "Long Gap"
    let hasCompletedDropSet: Bool  // at least one drop set was logged and completed
    let isToFailure: Bool          // at least one set was marked to-failure
    let avgActualReps: Int
    let avgTargetReps: Int
    let weightKg: Double
    let originalWeightKg: Double?
    let nextWeightKg: Double
    let readyToProgress: Bool    // double-progression gate: all sets hit target, no drop sets used
    let isNearTarget: Bool       // pct ∈ [0.85, 0.90), standard mode only — Rec 4
    let isImprovingUnder: Bool   // improving trend while under target — Rec 2
    let needsDeload: Bool        // two consecutive sessions < 65% — Rec 3
    let stuckSessionCount: Int   // consecutive sessions at same weight where !allSetsHitTarget
    let lastSessionAvgReps: Int? // avg reps in most recent prior session; nil when no history

    enum RepOutcome {
        case underSignificant, underSlight, onTarget, overTarget

        static func classify(_ pct: Double) -> RepOutcome {
            if pct <= 0.50 { return .underSignificant }
            if pct <  0.90 { return .underSlight }
            if pct <= 1.10 { return .onTarget }
            return .overTarget
        }

        var comboKey: String {
            switch self {
            case .underSignificant: return "Under Significant"
            case .underSlight:      return "Under Slight"
            case .onTarget:         return "On Target"
            case .overTarget:       return "Over Target"
            }
        }
        var repsKey: String { comboKey + (self == .underSignificant ? " (≤50%)" : self == .underSlight ? " (51–89%)" : self == .onTarget ? " (90–109%)" : " (110%+)") }
    }

    enum WeightState {
        case held
        case droppedCompleted, droppedStillUnder
        case userIncreasedHit, userIncreasedSlightMiss, userIncreasedSignificantMiss, userIncreasedOverTarget

        var comboKey: String {
            switch self {
            case .held:                       return "Held"
            case .droppedCompleted:           return "Dropped → Completed"
            case .droppedStillUnder:          return "Dropped → Still Under"
            case .userIncreasedHit:           return "User Increased → Hit Target"
            case .userIncreasedSlightMiss:    return "User Increased → Slight Miss"
            case .userIncreasedSignificantMiss: return "User Increased → Significant Miss"
            case .userIncreasedOverTarget:    return "User Increased → Over Target"
            }
        }
        var weightBankKey: String {
            switch self {
            case .droppedCompleted:           return "Dropped → Completed Reps"
            case .droppedStillUnder:          return "Dropped → Still Under"
            case .userIncreasedHit:           return "User Increased → Hit Target"
            case .userIncreasedSlightMiss:    return "User Increased → Slight Miss"
            case .userIncreasedSignificantMiss: return "User Increased → Significant Miss"
            case .userIncreasedOverTarget:    return "User Increased → Over Target"
            default:                          return "Held"
            }
        }
    }

    let isPullExercise: Bool

    var isUnder: Bool { repOutcome == .underSlight || repOutcome == .underSignificant }
    var needsAttention: Bool { repOutcome == .underSignificant || weightState == .droppedStillUnder }
    var isReady: Bool { repOutcome == .overTarget || repOutcome == .onTarget }

    var whatsNextKey: String {
        // Deload overrides all other advice — two bad sessions is a reset signal
        if needsDeload { return "Deload — Reset Weight" }
        // Drop set path takes priority when the user actually used one
        if hasCompletedDropSet {
            return isReady ? "Build From Drop Set" : "Use Drop Set Strategy"
        }
        // Stuck escalation — only when holding weight and not ready to progress
        if !readyToProgress && weightState == .held {
            if stuckSessionCount >= 4 { return "Stuck — Extended" }
            if stuckSessionCount >= 3 { return isCompound ? "Stuck — Neural Overload" : "Stuck — Extended" }
            if stuckSessionCount >= 2 { return "Stuck — Rest & Microload" }
        }
        switch (repOutcome, weightState) {
        case (.overTarget, _):                           return readyToProgress ? "Progress Weight" : "Hold Weight — Work Reps"
        case (.onTarget, _) where weightState == .held:  return readyToProgress ? "Progress Weight" : "Hold Weight — Work Reps"
        case (_, .droppedCompleted):                     return "Build From Dropped Weight"
        case (_, .droppedStillUnder):                    return "Consolidate at Dropped Weight"
        case (_, .userIncreasedHit):                     return readyToProgress ? "Confirm New Weight" : "Hold Weight — Work Reps"
        case (_, .userIncreasedOverTarget):              return readyToProgress ? "Progress Weight" : "Hold Weight — Work Reps"
        case (_, .userIncreasedSlightMiss), (_, .userIncreasedSignificantMiss): return "Hold Weight — Work Reps"
        default:                                          return "Hold Weight — Work Reps"
        }
    }

    var connectiveKey: String {
        // Near-target (85–89%) gets its own encouraging key before the standard under check
        if isNearTarget { return "Near Target / Building" }
        // Improving trend while under: use positive connective to reflect direction
        if isImprovingUnder { return "On Target / Progress" }
        switch repOutcome {
        case .underSlight, .underSignificant:
            if weightState == .droppedCompleted || weightState == .droppedStillUnder { return "Weight Drop / Reset" }
            return "Under / Building"
        case .onTarget:  return "On Target / Progress"
        case .overTarget: return "Over Target / Strong"
        }
    }
}

// MARK: - Narrative format

private enum NarrativeFormat: CaseIterable {
    /// Standard: frame → reps → weight → trend → next → connective (existing behavior)
    case standard
    /// Prescription-led: recommendation first, evidence second
    case prescriptionLed
    /// Sparse: single most informative sentence only
    case sparse
    /// Comparison-led: delta vs last session as the opener
    case comparisonLed

    static func select(for workout: WorkoutLogEntry) -> NarrativeFormat {
        // Deterministic per session (hourly bucket), cycles through all 4 formats so
        // the user sees a structurally different narrative every ~4 workouts.
        let hourBucket = Int(workout.startedAt.timeIntervalSince1970 / 3600)
        return NarrativeFormat.allCases[hourBucket % NarrativeFormat.allCases.count]
    }
}

// MARK: - Engine

enum WorkoutNarrativeEngine {

    static func generate(workout: WorkoutLogEntry, history: [WorkoutLogEntry],
                          isMindBodyOverconfident: Bool = false,
                          feelRating: FeelRating? = nil,
                          streakDays: Int = 0,
                          isComeback: Bool = false) -> String {
        guard let bank = loadBank() else { return legacyFallback(workout: workout, history: history) }
        let cal = Calendar.current
        let profile = UserCoachProfileEngine.load()
        // Rec 5: beginner mode for first ~60 workouts (≈5 months at 3×/week)
        let isBeginnerMode = history.count < 60

        let analyses: [ExerciseAnalysis] = workout.exercises.compactMap { we in
            let completed = we.completedSets
            guard !completed.isEmpty else { return nil }
            let exerciseHistory = history.compactMap { entry -> (date: Date, sets: [SetRecord])? in
                guard let match = entry.exercises.first(where: { $0.exercise.id == we.exercise.id }) else { return nil }
                return (entry.startedAt, match.completedSets)
            }
            return analyze(we, exerciseHistory: exerciseHistory, calendar: cal, workoutDate: workout.startedAt, isBeginnerMode: isBeginnerMode)
        }

        guard !analyses.isEmpty else { return "" }

        let format = NarrativeFormat.select(for: workout)
        // Use the feel from the workout record if not explicitly provided
        let effectiveFeel = feelRating ?? workout.feelRating
        var text = analyses.count == 1
            ? assembleSingle(analyses[0], bank: bank, workout: workout, profile: profile,
                             isMindBodyOverconfident: isMindBodyOverconfident, format: format)
            : assembleMulti(analyses, bank: bank, isMindBodyOverconfident: isMindBodyOverconfident,
                            format: format, feelRating: effectiveFeel,
                            streakDays: streakDays, isComeback: isComeback)

        // For single-exercise sessions, append feel closing (except .normal)
        if analyses.count == 1, let feel = effectiveFeel, feel != .normal {
            text += " \(feelClosingSentence(feel))"
        }

        // Streak and comeback context (N-001) — prepend before trimming
        if let milestone = streakMilestoneSentence(streakDays: streakDays) {
            text = milestone + " " + text
        } else if isComeback {
            text = comebackSentence() + " " + text
        }

        // Append best-day observation as a final sentence when it's applicable
        if let bestDay = bestDayObservation(workout: workout, profile: profile) {
            text += " \(bestDay)"
        }

        return String(text.prefix(420))
    }

    private static func feelClosingSentence(_ feel: FeelRating) -> String {
        switch feel {
        case .strong, .easy:
            let opts = ["That felt right. Build on it.",
                        "When it flows like this, trust it.",
                        "Good energy today. Keep that standard."]
            return opts[Int.random(in: 0..<opts.count)]
        case .normal:
            return "Solid work regardless of how it felt."
        case .tired:
            return "Earned. Recovery matters — prioritise sleep and protein today."
        case .brutal:
            return "Session felt brutal — recovery nutrition in the next 90 minutes matters."
        }
    }

    private static func streakMilestoneSentence(streakDays: Int) -> String? {
        switch streakDays {
        case 7:   return "A full week of sessions."
        case 14:  return "Two weeks consistent."
        case 30:  return "30 sessions. Consistency is compounding."
        case 60:  return "60 days — this is your identity now."
        case 100: return "100. You're the kind of person who shows up."
        default:  return nil
        }
    }

    private static func comebackSentence() -> String {
        let opts = ["Back after a break — the work restarts here.",
                    "Comeback session. Every return counts."]
        return opts[Int.random(in: 0..<opts.count)]
    }

    private static func bestDayObservation(workout: WorkoutLogEntry, profile: UserCoachProfile) -> String? {
        guard profile.hasSufficientData,
              let bestDay = profile.bestWeekday,
              let dayName = profile.bestWeekdayName else { return nil }
        let todayWeekday = Calendar.current.component(.weekday, from: workout.startedAt)
        guard todayWeekday == bestDay else { return nil }
        // Only add on strong-feeling sessions so it doesn't clash with struggle messages
        guard let feel = workout.feelRating, feel == .strong || feel == .normal else { return nil }
        return "(\(dayName) sessions are consistently your strongest — today fits the pattern.)"
    }

    // MARK: - Analysis

    private static func analyze(
        _ we: WorkoutExercise,
        exerciseHistory: [(date: Date, sets: [SetRecord])],
        calendar: Calendar,
        workoutDate: Date,
        isBeginnerMode: Bool
    ) -> ExerciseAnalysis {
        let completed = we.completedSets

        // Resolve failure intent before classifying reps — a to-failure set is
        // always a "hit" regardless of the rep count logged.
        let isToFailure = completed.contains { $0.toFailure }

        let totalActual = completed.reduce(0) { $0 + $1.reps }
        let totalTarget = completed.reduce(0) { $0 + max($1.targetReps, 1) }
        let pct = Double(totalActual) / Double(max(totalTarget, 1))

        // Rec 5: widen "on target" band for beginners to reduce early discouragement
        let lowerBound = isBeginnerMode ? 0.80 : 0.90
        let upperBound = isBeginnerMode ? 1.15 : 1.10

        // Rec 4: near-target zone — 85–89% in standard mode only (beginner gets wider on-target band)
        let isNearTarget = !isToFailure && !isBeginnerMode && pct >= 0.85 && pct < 0.90

        let rawRepOutcome: ExerciseAnalysis.RepOutcome
        if isToFailure {
            rawRepOutcome = .onTarget
        } else if pct <= 0.50 {
            rawRepOutcome = .underSignificant
        } else if pct < lowerBound {
            rawRepOutcome = .underSlight
        } else if pct <= upperBound {
            rawRepOutcome = .onTarget
        } else {
            rawRepOutcome = .overTarget
        }
        var repOutcome = rawRepOutcome

        let avgActual = Int((Double(totalActual) / Double(completed.count)).rounded())
        let avgTarget = Int((Double(totalTarget) / Double(completed.count)).rounded())

        // Weight — floor barbell at bar weight so "0 entered = empty bar" shows as 20 kg.
        let rawWeight = completed.first?.weight ?? 0
        let weightKg: Double = we.exercise.equipment == .barbell
            ? max(rawWeight, Equipment.barbellBarKg)
            : rawWeight

        // Prescribed weight — same floor so the drop/increase comparison stays valid.
        let rawPrescribed = completed.first?.targetWeight ?? rawWeight
        let prescribedWeight: Double = we.exercise.equipment == .barbell
            ? max(rawPrescribed, Equipment.barbellBarKg)
            : rawPrescribed

        let weightState: ExerciseAnalysis.WeightState
        let originalWeightKg: Double?

        if weightKg < prescribedWeight * 0.98 {
            originalWeightKg = prescribedWeight
            // Failure at a dropped weight is "completed" — user chose the weight intentionally.
            weightState = (repOutcome == .onTarget || repOutcome == .overTarget) ? .droppedCompleted : .droppedStillUnder
        } else if weightKg > prescribedWeight * 1.02 {
            originalWeightKg = nil
            switch repOutcome {
            case .overTarget:       weightState = .userIncreasedOverTarget
            case .onTarget:         weightState = .userIncreasedHit
            case .underSlight:      weightState = .userIncreasedSlightMiss
            case .underSignificant: weightState = .userIncreasedSignificantMiss
            }
        } else {
            originalWeightKg = nil
            weightState = .held
        }

        // Rec 1: user voluntarily increased weight and hit ≥75% reps — positive tone, not discouraging
        if weightState == .userIncreasedSlightMiss && pct >= 0.75 {
            repOutcome = .onTarget
        }

        // Trend — requires 3+ previous sessions
        let trendKey: String
        if exerciseHistory.count >= 3 {
            let rates = exerciseHistory.prefix(3).map { session -> Double in
                let actual = session.sets.reduce(0) { $0 + $1.reps }
                let target = session.sets.reduce(0) { $0 + max($1.targetReps, 1) }
                return Double(actual) / Double(max(target, 1))
            }.reversed().map { $0 }  // oldest first
            let delta = rates.last! - rates.first!
            let latestRate = rates.last!
            if delta > 0.08 { trendKey = "Improving" }
            else if delta < -0.08 { trendKey = "Declining" }
            else if latestRate < 0.9 { trendKey = "Plateauing Below Target" }
            else { trendKey = "Plateauing At Target" }
        } else {
            trendKey = "Omitted"
        }

        // Rec 2: under + improving trend — signals the right direction, use softer language
        let isImprovingUnder = trendKey == "Improving" && repOutcome == .underSlight

        // Rec 3: deload trigger — two consecutive sessions under 65% is a reset signal
        let needsDeload: Bool
        if pct < 0.65, let prevSession = exerciseHistory.first {
            let prevActual = prevSession.sets.reduce(0) { $0 + $1.reps }
            let prevTarget = prevSession.sets.reduce(0) { $0 + max($1.targetReps, 1) }
            let prevPct = Double(prevActual) / Double(max(prevTarget, 1))
            needsDeload = prevPct < 0.65
        } else {
            needsDeload = false
        }

        // Stuck count — consecutive prior sessions at same weight (±2%) where not all sets hit target
        var stuckSessionCount = 0
        for session in exerciseHistory {
            let sessionWeight = session.sets.first?.weight ?? 0
            guard abs(sessionWeight - weightKg) <= weightKg * 0.02 else { break }
            let sessionAllHit = session.sets.allSatisfy { $0.reps >= $0.targetReps }
            if !sessionAllHit {
                stuckSessionCount += 1
            } else {
                break
            }
        }

        // History state
        let historyKey: String
        if exerciseHistory.isEmpty {
            historyKey = "First Time"
        } else {
            let lastDate = exerciseHistory.first!.date
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDate),
                                               to: calendar.startOfDay(for: workoutDate)).day ?? 0
            if days >= 14 { historyKey = "Long Gap" }
            else if days >= 7 { historyKey = "Short Gap" }
            else { historyKey = "Normal" }
        }

        let hasCompletedDropSet = completed.contains { $0.isDropCompleted }

        // Double-progression gate: ALL sets must hit their target reps and no drop sets used.
        // Fall back to aggregate performance when no targets are set.
        let hasValidTargets = !completed.isEmpty && completed.allSatisfy { $0.targetReps > 0 }
        let allSetsHitTarget = hasValidTargets
            ? completed.allSatisfy { $0.reps >= $0.targetReps }
            : (repOutcome == .onTarget || repOutcome == .overTarget)
        let readyToProgress = allSetsHitTarget && !hasCompletedDropSet

        // Percentage-based increment (~2.5 % compound, ~1.5 % isolation), rounded to nearest 0.5 kg.
        let rawIncrement = weightKg * (we.exercise.isCompound ? 0.025 : 0.015)
        let cappedIncrement = min(max(round(rawIncrement / 0.5) * 0.5, 0.5),
                                  we.exercise.isCompound ? 5.0 : 2.5)

        let nextWeightKg: Double
        if needsDeload {
            // Two consecutive bad sessions → drop ~10 %, rounded to 0.5 kg
            nextWeightKg = max(round(weightKg * 0.9 / 0.5) * 0.5, 0)
        } else if weightState == .userIncreasedSlightMiss || weightState == .userIncreasedSignificantMiss {
            // User tried a heavier weight and missed — hold there; earn it before adding more
            nextWeightKg = weightKg
        } else if hasCompletedDropSet {
            // Drop set used — user is at the edge of capacity; consolidate before advancing
            nextWeightKg = weightKg
        } else if readyToProgress {
            // All sets hit target with no drops — earned the increase
            nextWeightKg = weightKg + cappedIncrement
        } else if stuckSessionCount >= 4 {
            // Extended stall — planned deload to 90%, rebuild from there
            nextWeightKg = max(round(weightKg * 0.9 / 0.5) * 0.5, 0)
        } else if stuckSessionCount >= 3 && we.exercise.isCompound {
            // Neural overload technique — try ~10% heavier for 3–5 reps to break the stall
            nextWeightKg = round(weightKg * 1.10 / 0.5) * 0.5
        } else if stuckSessionCount >= 3 {
            // Isolation exercises don't benefit from neural overload — deload instead
            nextWeightKg = max(round(weightKg * 0.9 / 0.5) * 0.5, 0)
        } else {
            // Not all sets hit target yet — hold current weight
            nextWeightKg = weightKg
        }

        let isPullExercise = we.exercise.movementPattern == .horizontalPull
            || we.exercise.movementPattern == .verticalPull

        let lastSessionAvgReps: Int? = exerciseHistory.first.map { session in
            guard !session.sets.isEmpty else { return 0 }
            return Int((Double(session.sets.reduce(0) { $0 + $1.reps }) / Double(session.sets.count)).rounded())
        }

        return ExerciseAnalysis(
            exerciseId: we.exercise.id,
            name: we.exercise.name,
            isCompound: we.exercise.isCompound,
            repOutcome: repOutcome,
            weightState: weightState,
            trendKey: trendKey,
            historyKey: historyKey,
            hasCompletedDropSet: hasCompletedDropSet,
            isToFailure: isToFailure,
            avgActualReps: avgActual,
            avgTargetReps: avgTarget,
            weightKg: weightKg,
            originalWeightKg: originalWeightKg,
            nextWeightKg: nextWeightKg,
            readyToProgress: readyToProgress,
            isNearTarget: isNearTarget,
            isImprovingUnder: isImprovingUnder,
            needsDeload: needsDeload,
            stuckSessionCount: stuckSessionCount,
            lastSessionAvgReps: lastSessionAvgReps,
            isPullExercise: isPullExercise
        )
    }

    // MARK: - Single exercise narrative

    private static func assembleSingle(_ a: ExerciseAnalysis, bank: PhraseBank,
                                        workout: WorkoutLogEntry, profile: UserCoachProfile,
                                        isMindBodyOverconfident: Bool = false,
                                        format: NarrativeFormat = .standard) -> String {
        // CON-06: Neural Overload is counterproductive when physiology is overconfident (HRV low, feel high)
        let effectiveWhatsNextKey = (a.whatsNextKey == "Stuck — Neural Overload" && isMindBodyOverconfident)
            ? "Stuck — Rest & Microload" : a.whatsNextKey
        let nextKeyBase = "\(effectiveWhatsNextKey)|Single"

        // ── Sparse: single highest-priority sentence ───────────────────────
        if format == .sparse {
            if a.needsDeload {
                return "\(a.name) has hit a wall — dropping to \(a.nextWeightKg.weightFormatted) kg to rebuild."
            }
            if a.readyToProgress {
                return "\(a.name) is ready for \(a.nextWeightKg.weightFormatted) kg — all sets completed cleanly."
            }
            if a.stuckSessionCount >= 3 {
                let n = a.stuckSessionCount + 1
                return "\(a.name) has been at \(a.weightKg.weightFormatted) kg for \(n) sessions without breaking through."
            }
            if a.trendKey == "Improving" {
                return "\(a.name) is trending up — reps have climbed over the past few sessions."
            }
            if a.trendKey == "Declining" {
                return "\(a.name) is slipping — reps have been falling session to session."
            }
            if let p = pick(bank.whats_next[nextKeyBase] ?? [], exerciseId: a.exerciseId, category: "next") {
                return fill(p.phrase, a)
            }
            // Sparse falls through to standard when no clear signal
        }

        // ── Comparison-led: delta vs last session as opener ────────────────
        // Skip for first-time or long-gap sessions where the comparison is stale/missing
        if format == .comparisonLed && a.historyKey != "Long Gap" {
            var parts: [String] = []
            if let lastReps = a.lastSessionAvgReps {
                let delta = a.avgActualReps - lastReps
                if delta > 0 {
                    let s = delta == 1 ? "" : "s"
                    parts.append("\(a.name): \(delta) more rep\(s) than last session at \(a.weightKg.weightFormatted) kg.")
                } else if delta < 0 {
                    let d = abs(delta)
                    let s = d == 1 ? "" : "s"
                    parts.append("\(a.name): \(d) fewer rep\(s) than last session.")
                } else {
                    parts.append("\(a.name): same rep count as last session at \(a.weightKg.weightFormatted) kg — consistent.")
                }
            } else {
                let repsKey = "\(a.repOutcome.repsKey)|Single Exercise"
                if let p = pick(bank.reps[repsKey] ?? [], exerciseId: a.exerciseId, category: "reps") {
                    parts.append(fill(p.phrase, a))
                }
            }
            if a.trendKey != "Omitted", let p = pick(bank.trend[a.trendKey] ?? [], exerciseId: a.exerciseId, category: "trend") {
                parts.append(fill(p.phrase, a))
            }
            if let p = pick(bank.whats_next[nextKeyBase] ?? [], exerciseId: a.exerciseId, category: "next") {
                parts.append(fill(p.phrase, a))
            }
            if !parts.isEmpty { return parts.prefix(3).joined(separator: " ") }
            // Falls through to standard when empty
        }

        // ── Prescription-led: recommendation first, evidence second ─────────
        if format == .prescriptionLed {
            var parts: [String] = []
            // N-003: prepend a reflection bridge before the prescription sentence
            let bridge = reflectionBridges[Int.random(in: 0..<reflectionBridges.count)]
            if let p = pick(bank.whats_next[nextKeyBase] ?? [], exerciseId: a.exerciseId, category: "next") {
                parts.append(bridge + " " + fill(p.phrase, a))
            }
            // Brief programmatic evidence — avoids echoing the same slot from the bank
            let shortfall = a.avgTargetReps - a.avgActualReps
            let evidence: String
            if a.readyToProgress {
                evidence = "All \(a.avgTargetReps) reps completed across every set."
            } else if a.isUnder && shortfall > 0 {
                let s = shortfall == 1 ? "" : "s"
                evidence = "\(shortfall) rep\(s) short of target — keep building."
            } else if a.repOutcome == .overTarget {
                evidence = "Hit \(a.avgActualReps) vs a target of \(a.avgTargetReps) — well over."
            } else {
                evidence = "Rep count landed on target at \(a.weightKg.weightFormatted) kg."
            }
            parts.append(evidence)
            if let add = profileAddendum(a: a, workout: workout, profile: profile) {
                parts.append(add)
            } else if let p = pick(bank.connective[a.connectiveKey] ?? [], exerciseId: a.exerciseId, category: "conn") {
                parts.append(fill(p.phrase, a))
            }
            if !parts.isEmpty { return parts.prefix(3).joined(separator: " ") }
            // Falls through to standard when empty
        }

        // ── Standard (default + fallback for other formats) ─────────────────
        // Combo template key: "{rep}|{weight}|{trend}|{history}"
        let trendCombo = a.trendKey == "Omitted" ? "Omitted" : a.trendKey.replacingOccurrences(of: " Target", with: "")
        let comboKey   = "\(a.repOutcome.comboKey)|\(a.weightState.comboKey)|\(trendCombo)|\(a.historyKey)"

        if let phrases = bank.combos[comboKey], !phrases.isEmpty,
           let chosen = pick(phrases, exerciseId: a.exerciseId, category: "combo") {
            return fill(chosen.phrase, a)
        }

        var parts: [String] = []

        let frameKey = a.isUnder ? "All Missed — Single Exercise" : "All Hit — Single Exercise"
        if let p = pick(bank.frames[frameKey] ?? [], exerciseId: a.exerciseId, category: "frame") {
            parts.append(fill(p.phrase, a))
        }

        let repsKey = "\(a.repOutcome.repsKey)|Single Exercise"
        if let p = pick(bank.reps[repsKey] ?? [], exerciseId: a.exerciseId, category: "reps") {
            parts.append(fill(p.phrase, a))
        }

        if a.hasCompletedDropSet {
            if let p = pick(bank.weight["Drop Set — Completed"] ?? [], exerciseId: a.exerciseId, category: "drop") {
                parts.append(fill(p.phrase, a))
            }
        } else if a.weightState != .held {
            if let p = pick(bank.weight[a.weightState.weightBankKey] ?? [], exerciseId: a.exerciseId, category: "weight") {
                parts.append(fill(p.phrase, a))
            }
        }

        if a.isToFailure {
            if let p = pick(bank.connective["To Failure"] ?? [], exerciseId: a.exerciseId, category: "failure") {
                parts.append(fill(p.phrase, a))
            }
        } else if a.trendKey != "Omitted", let p = pick(bank.trend[a.trendKey] ?? [], exerciseId: a.exerciseId, category: "trend") {
            parts.append(fill(p.phrase, a))
        }

        if a.historyKey != "Normal", let p = pick(bank.history[a.historyKey] ?? [], exerciseId: a.exerciseId, category: "hist") {
            let histPhrase = fill(p.phrase, a)
            // B-008a: ensure gap phrases reference the specific exercise, not just general training
            let exerciseSpecific = histPhrase.localizedCaseInsensitiveContains(a.name)
                ? histPhrase
                : "\(a.name): \(histPhrase)"
            parts.insert(exerciseSpecific, at: 0)
        }

        if let p = pick(bank.whats_next[nextKeyBase] ?? [], exerciseId: a.exerciseId, category: "next") {
            parts.append(fill(p.phrase, a))
        }

        if a.needsDeload && a.isPullExercise {
            parts.append("Dropping the weight lets you hit more quality reps — volume through clean reps beats failed attempts at heavy weight.")
        }

        if let addendum = profileAddendum(a: a, workout: workout, profile: profile) {
            parts.append(addendum)
        } else if let p = pick(bank.connective[a.connectiveKey] ?? [], exerciseId: a.exerciseId, category: "conn") {
            parts.append(fill(p.phrase, a))
        }

        return parts.prefix(4).joined(separator: " ")
    }

    // MARK: - Profile-cited coaching addendum

    private static func profileAddendum(a: ExerciseAnalysis, workout: WorkoutLogEntry,
                                         profile: UserCoachProfile) -> String? {
        guard profile.hasSufficientData else { return nil }

        // ── Heading into a new weight: warn about first-attempt pattern ────────
        if a.readyToProgress && profile.firstAttemptIsHard {
            return "Worth knowing: your data shows you usually need 2 sessions before a new weight sticks — don't read too much into today."
        }

        // ── Stuck plateau: contextualize against personal breakthrough timing ──
        if a.stuckSessionCount >= 2, let avg = profile.avgBreakthroughSessions {
            let avgRounded = max(2, Int(avg.rounded()))
            if a.stuckSessionCount < avgRounded {
                return "Your pattern shows breakthroughs usually come after about \(avgRounded) sessions — you're at session \(a.stuckSessionCount). Still in range."
            } else if a.stuckSessionCount >= avgRounded + 1 {
                return "You're past your typical breakthrough window on this plateau. This one may need a different approach."
            }
        }

        // ── Readiness delta: pre/post mismatch is worth naming ────────────────
        if let pre = workout.readinessBefore, let post = workout.feelRating {
            let postN: Int
            switch post {
            case .easy:   postN = 1
            case .strong: postN = 2
            case .normal: postN = 3
            case .tired:  postN = 4
            case .brutal: postN = 5
            }
            if postN - pre >= 2 {
                return "You came in tired and still hit your numbers — that's worth noting."
            } else if pre - postN >= 2 && a.isUnder {
                return "You went in feeling strong but the session was tough — that kind of hidden fatigue doesn't show up until the bar moves."
            }
        }

        return nil
    }

    // MARK: - Multi exercise narrative

    private static let reflectionBridges = [
        "Solid work.", "That session counted.", "Clean execution.",
        "Good effort today.", "The work was done.", "Earned.",
        "Strong output.", "Well executed.", "That's the standard.",
        "Consistent."
    ]

    private static func assembleMulti(_ analyses: [ExerciseAnalysis], bank: PhraseBank,
                                       isMindBodyOverconfident: Bool = false,
                                       format: NarrativeFormat = .standard,
                                       feelRating: FeelRating? = nil,
                                       streakDays: Int = 0,
                                       isComeback: Bool = false) -> String {
        let hitCount    = analyses.filter { $0.isReady }.count
        let missedCount = analyses.filter { $0.isUnder }.count
        let total       = analyses.count

        let frameType: String
        if hitCount == total         { frameType = "All Hit — Multiple Exercises" }
        else if missedCount == total { frameType = "All Missed — Multiple Exercises" }
        else if hitCount > missedCount { frameType = "Mixed — Majority Hit" }
        else if missedCount > hitCount { frameType = "Mixed — Majority Missed" }
        else                         { frameType = "Mixed — Exactly Half" }

        let anchorId = analyses.first?.exerciseId ?? UUID()
        let lead = mostCritical(analyses)
        let leadNextKey = (lead.whatsNextKey == "Stuck — Neural Overload" && isMindBodyOverconfident)
            ? "Stuck — Rest & Microload" : lead.whatsNextKey
        let nextKeyBase = "\(leadNextKey)|Single"

        // ── Sparse: frame + most critical action ────────────────────────────
        if format == .sparse {
            var parts: [String] = []
            if let p = pick(bank.frames[frameType] ?? [], exerciseId: anchorId, category: "frame") {
                parts.append(fill(p.phrase, analyses.first!, second: analyses.dropFirst().first))
            }
            if let p = pick(bank.whats_next[nextKeyBase] ?? [], exerciseId: lead.exerciseId, category: "next") {
                parts.append(fill(p.phrase, lead))
            }
            return parts.prefix(2).joined(separator: " ")
        }

        // ── Prescription-led: what's changing next session, then context ─────
        if format == .prescriptionLed {
            let progressing = analyses.filter { $0.readyToProgress && !$0.needsDeload }
            let deloading   = analyses.filter { $0.needsDeload }
            var parts: [String] = []
            // N-003: prepend reflection bridge
            let bridge = reflectionBridges[Int.random(in: 0..<reflectionBridges.count)]
            if !progressing.isEmpty {
                let names = progressing.prefix(2).map(\.name).joined(separator: " and ")
                let verb  = progressing.count == 1 ? "goes" : "go"
                parts.append("\(bridge) \(names) \(verb) up next session.")
            }
            for d in deloading.prefix(2) {
                parts.append("\(d.name) drops to \(d.nextWeightKg.weightFormatted) kg — needs a reset.")
            }
            if parts.isEmpty {
                if let p = pick(bank.frames[frameType] ?? [], exerciseId: anchorId, category: "frame") {
                    parts.append(fill(p.phrase, analyses.first!, second: analyses.dropFirst().first))
                }
            }
            if let p = pick(bank.whats_next[nextKeyBase] ?? [], exerciseId: lead.exerciseId, category: "next") {
                parts.append(fill(p.phrase, lead))
            }
            return parts.prefix(3).joined(separator: " ")
        }

        // ── Comparison-led: exercises up/down vs last session ────────────────
        if format == .comparisonLed {
            let improved = analyses.filter { $0.lastSessionAvgReps != nil && $0.avgActualReps > ($0.lastSessionAvgReps ?? 0) }
            let declined = analyses.filter { $0.lastSessionAvgReps != nil && $0.avgActualReps < ($0.lastSessionAvgReps ?? 0) }
            if !improved.isEmpty || !declined.isEmpty {
                var parts: [String] = []
                if improved.count > 0 && declined.count == 0 {
                    let s = improved.count == 1 ? "" : "s"
                    let prefix = improved.count == total ? "All" : "\(improved.count)"
                    parts.append("\(prefix) exercise\(s) improved on last session.")
                } else if declined.count > 0 && improved.count == 0 {
                    let s = declined.count == 1 ? "" : "s"
                    let prefix = declined.count == total ? "All" : "\(declined.count)"
                    parts.append("\(prefix) exercise\(s) came in below last session.")
                } else {
                    let upS = improved.count == 1 ? "" : "s"
                    let dnS = declined.count == 1 ? "" : "s"
                    parts.append("\(improved.count) exercise\(upS) up, \(declined.count)\(dnS.isEmpty ? "" : " exercise\(dnS)") down vs last session.")
                }
                if let p = pick(bank.whats_next[nextKeyBase] ?? [], exerciseId: lead.exerciseId, category: "next") {
                    parts.append(fill(p.phrase, lead))
                }
                return parts.prefix(2).joined(separator: " ")
            }
            // Falls through to standard when no comparison data
        }

        // ── Standard ─────────────────────────────────────────────────────────
        var parts: [String] = []

        if let p = pick(bank.frames[frameType] ?? [], exerciseId: anchorId, category: "frame") {
            parts.append(fill(p.phrase, analyses.first!, second: analyses.dropFirst().first))
        }

        let notableExercises = mostNotable(analyses)
        let repOutcomeForScope = dominantOutcome(analyses)
        let repsKey: String
        if total >= 4 {
            repsKey = "\(repOutcomeForScope.repsKey)|4+ Exercises"
        } else {
            let allSame = analyses.allSatisfy { $0.repOutcome.comboKey == analyses[0].repOutcome.comboKey }
            let scope   = allSame ? "2–3 Same Outcome" : "2–3 Mixed"
            let outcomeKey = allSame ? repOutcomeForScope : dominantMissed(analyses) ?? repOutcomeForScope
            repsKey = "\(outcomeKey.repsKey)|\(scope)"
        }

        if let p = pick(bank.reps[repsKey] ?? [], exerciseId: anchorId, category: "reps") {
            parts.append(fillMulti(p.phrase, notableExercises))
        }

        if let p = pick(bank.whats_next[nextKeyBase] ?? [], exerciseId: lead.exerciseId, category: "next") {
            parts.append(fill(p.phrase, lead))
        }

        // N-005: feel-responsive closing sentence for multi-exercise sessions
        if let feel = feelRating {
            let closing = feelClosingSentence(feel)
            if feel != .normal || analyses.count >= 2 {
                parts.append(closing)
            }
        }

        return parts.prefix(3).joined(separator: " ")
    }

    // MARK: - Helpers

    private static func mostNotable(_ analyses: [ExerciseAnalysis]) -> [ExerciseAnalysis] {
        let urgent = analyses.filter { $0.needsAttention }
        let rest   = analyses.filter { !$0.needsAttention }
        return Array((urgent + rest).prefix(3))
    }

    private static func mostCritical(_ analyses: [ExerciseAnalysis]) -> ExerciseAnalysis {
        analyses.sorted { lhs, rhs in
            if lhs.needsAttention != rhs.needsAttention { return lhs.needsAttention }
            return lhs.repOutcome.comboKey < rhs.repOutcome.comboKey
        }.first ?? analyses[0]
    }

    private static func dominantOutcome(_ analyses: [ExerciseAnalysis]) -> ExerciseAnalysis.RepOutcome {
        let counts = Dictionary(grouping: analyses, by: { $0.repOutcome.comboKey }).mapValues(\.count)
        let top = counts.max(by: { $0.value < $1.value })?.key
        return analyses.first(where: { $0.repOutcome.comboKey == top })?.repOutcome ?? .onTarget
    }

    private static func dominantMissed(_ analyses: [ExerciseAnalysis]) -> ExerciseAnalysis.RepOutcome? {
        analyses.first(where: { $0.isUnder })?.repOutcome
    }

    // MARK: - Variable substitution

    private static func fill(_ template: String, _ a: ExerciseAnalysis, second: ExerciseAnalysis? = nil) -> String {
        var s = template
        s = s.replacingOccurrences(of: "{exercise}", with: a.name)
        s = s.replacingOccurrences(of: "{exercise1}", with: a.name)
        s = s.replacingOccurrences(of: "{exercise2}", with: second?.name ?? a.name)
        s = s.replacingOccurrences(of: "{actual}", with: "\(a.avgActualReps)")
        s = s.replacingOccurrences(of: "{target}", with: "\(a.avgTargetReps)")
        s = s.replacingOccurrences(of: "{weight}", with: "\(a.weightKg.weightFormatted) kg")
        s = s.replacingOccurrences(of: "{original_weight}", with: "\((a.originalWeightKg ?? a.weightKg).weightFormatted) kg")
        s = s.replacingOccurrences(of: "{next_weight}", with: "\(a.nextWeightKg.weightFormatted) kg")
        s = s.replacingOccurrences(of: "{previous_weight}", with: "\((a.originalWeightKg ?? a.weightKg).weightFormatted) kg")
        s = s.replacingOccurrences(of: "\\{[^}]+\\}", with: "", options: .regularExpression)
        return s
    }

    private static func fillMulti(_ template: String, _ exercises: [ExerciseAnalysis]) -> String {
        var s = template
        for (i, ex) in exercises.enumerated() {
            if i == 0 { s = s.replacingOccurrences(of: "{exercise}", with: ex.name) }
            s = s.replacingOccurrences(of: "{exercise\(i+1)}", with: ex.name)
            if i == 0 {
                s = s.replacingOccurrences(of: "{actual}", with: "\(ex.avgActualReps)")
                s = s.replacingOccurrences(of: "{target}", with: "\(ex.avgTargetReps)")
            }
        }
        s = s.replacingOccurrences(of: "\\{[^}]+\\}", with: "", options: .regularExpression)
        return s
    }

    // MARK: - Phrase rotation

    private static let usageKey = "phraseUsage_v1"

    private static func pick(_ phrases: [Phrase], exerciseId: UUID, category: String) -> Phrase? {
        guard !phrases.isEmpty else { return nil }
        let recent = recentlyUsed(exerciseId: exerciseId, category: category)
        let unused = phrases.filter { !recent.contains($0.id) }
        let pool = unused.isEmpty ? phrases : unused
        let chosen = pool[Int.random(in: 0..<pool.count)]
        recordUsed(id: chosen.id, exerciseId: exerciseId, category: category)
        return chosen
    }

    private static func recentlyUsed(exerciseId: UUID, category: String) -> [Int] {
        let key = "\(exerciseId)|\(category)"
        guard let data = UserDefaults.standard.data(forKey: usageKey),
              let dict = try? JSONDecoder().decode([String: [Int]].self, from: data),
              let used = dict[key] else { return [] }
        return used
    }

    private static func recordUsed(id: Int, exerciseId: UUID, category: String) {
        let key = "\(exerciseId)|\(category)"
        var dict: [String: [Int]] = [:]
        if let data = UserDefaults.standard.data(forKey: usageKey),
           let decoded = try? JSONDecoder().decode([String: [Int]].self, from: data) {
            dict = decoded
        }
        var used = dict[key] ?? []
        used.append(id)
        if used.count > 10 { used.removeFirst(used.count - 10) }
        dict[key] = used
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: usageKey)
        }
    }

    // MARK: - Phrase bank loader

    private static var _bank: PhraseBank? = nil

    private static func loadBank() -> PhraseBank? {
        if _bank != nil { return _bank }
        guard let url = Bundle.main.url(forResource: "phrase_bank", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        _bank = try? JSONDecoder().decode(PhraseBank.self, from: data)
        return _bank
    }

    // MARK: - Fallback

    private static func legacyFallback(workout: WorkoutLogEntry, history: [WorkoutLogEntry]) -> String {
        WorkoutFeedbackEngine.sessionNarrative(workout: workout, history: history)
    }
}

