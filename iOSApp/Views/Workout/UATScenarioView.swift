import SwiftUI

#if DEBUG

// MARK: - Metadata

private struct UATScenario {
    let name: String
    let category: String
    let hint: String
    var needsHON: Bool = false
}

private func buildCatalogue() -> [UATScenario] { [
    // A — Feedback Engine (Home card)
    .init(name: "Empty State",              category: "A · Feedback Engine", hint: "All tabs → empty-state illustrations"),
    .init(name: "Add Weight Signal",         category: "A · Feedback Engine", hint: "Home → bench card: 'Ready to go up' tag (exceeded reps last session)"),
    .init(name: "Standard Progression",      category: "A · Feedback Engine", hint: "Home → OHP card: 'Ready to go up' tag (2+ consecutive clean sessions at target)"),
    .init(name: "Almost Ready to Progress",  category: "A · Feedback Engine", hint: "Home → row card: 'Hold weight' tag; note shows 'One more solid session'"),
    .init(name: "Deload Recommended",        category: "A · Feedback Engine", hint: "Home → feedback card: deadlift shows deload advice"),
    .init(name: "Struggling — Hold Weight",  category: "A · Feedback Engine", hint: "Home → feedback card: squat shows 'Hold weight'"),
    // B — HON Messages
    .init(name: "HON · Session 1",           category: "B · HON Messages", hint: "Home: new-user welcome banner appears", needsHON: true),
    .init(name: "HON · Session 10",          category: "B · HON Messages", hint: "Home: '10 sessions' milestone banner", needsHON: true),
    .init(name: "HON · Session 25",          category: "B · HON Messages", hint: "Home: '25 sessions' milestone banner", needsHON: true),
    .init(name: "HON · Return (14-day gap)", category: "B · HON Messages", hint: "Home: comeback banner (14-day absence → return message fires immediately)", needsHON: true),
    .init(name: "HON · Return (30-day gap)", category: "B · HON Messages", hint: "Home: long-absence comeback banner (30-day gap, same trigger — compare message copy)", needsHON: true),
    .init(name: "HON · Type A Pattern",      category: "B · HON Messages", hint: "Settings → HON Debug: strong day-probability bars; pattern banner fires if today matches dominant day", needsHON: true),
    .init(name: "HON · Frequency Ramp",      category: "B · HON Messages", hint: "Home: high-frequency warning banner (6 sessions last 5 days vs 2/week rolling avg)", needsHON: true),
    .init(name: "HON · Drift Detected",      category: "B · HON Messages", hint: "Navigate Home after applying — drift banner fires on next foreground (checkForDriftOrDeload, not simulateLog)", needsHON: true),
    .init(name: "HON · 12 Consecutive Wks",  category: "B · HON Messages", hint: "Home: '12 consecutive active weeks' milestone banner", needsHON: true),
    .init(name: "HON · Deload Week",         category: "B · HON Messages", hint: "Navigate Home after applying — deload banner fires on next foreground (checkForDriftOrDeload, not simulateLog)", needsHON: true),
    // C — Strength Tiers
    .init(name: "Tier · Beginner",           category: "C · Strength Tiers", hint: "Insights → Strength Score: beginner badge on all lifts"),
    .init(name: "Tier · Developing",         category: "C · Strength Tiers", hint: "Insights → Strength Score: developing/novice tier"),
    .init(name: "Tier · Intermediate",       category: "C · Strength Tiers", hint: "Insights → Strength Score: intermediate tier badge"),
    .init(name: "Tier · Advanced",           category: "C · Strength Tiers", hint: "Insights → Strength Score: advanced tier badge"),
    .init(name: "Tier · Elite",              category: "C · Strength Tiers", hint: "Insights → Strength Score: elite tier — top badge"),
    .init(name: "Tier · Mixed Levels",       category: "C · Strength Tiers", hint: "Insights: some elite, some beginner — imbalanced tiers"),
    // D — Pattern Balance
    .init(name: "Pattern · All 7 Balanced",  category: "D · Pattern Balance", hint: "Insights → pattern radar: even across all 7 movements"),
    .init(name: "Pattern · Push-Heavy",      category: "D · Pattern Balance", hint: "Insights: imbalance warning — too much push, no pull"),
    .init(name: "Pattern · Pull-Heavy",      category: "D · Pattern Balance", hint: "Insights: imbalance — too much pull, no push"),
    .init(name: "Pattern · Leg-Dominant",    category: "D · Pattern Balance", hint: "Insights: lower-body heavy, minimal upper"),
    .init(name: "Pattern · No Legs",         category: "D · Pattern Balance", hint: "Insights: all upper, zero hip hinge / knee flexion"),
    .init(name: "Pattern · Isolation-Only",  category: "D · Pattern Balance", hint: "Insights: no compound moves — curls/raises/extensions only"),
    .init(name: "Pattern · Compound-Only",   category: "D · Pattern Balance", hint: "Insights: no isolation — big lifts only"),
    // E — Equipment Mix
    .init(name: "Equipment · All Barbell",   category: "E · Equipment Mix", hint: "History: all BB tags; Insights: barbell-only profile"),
    .init(name: "Equipment · All Dumbbell",  category: "E · Equipment Mix", hint: "History: all DB entries"),
    .init(name: "Equipment · All Machines",  category: "E · Equipment Mix", hint: "History: machine exercises throughout"),
    .init(name: "Equipment · Bodyweight",    category: "E · Equipment Mix", hint: "History: Pull-Up / Dip at w=0; no e1RM in Lab (excluded when weight=0); History tab shows reps only"),
    .init(name: "Equipment · Full Mix",      category: "E · Equipment Mix", hint: "History: BB/DB/Cable/Machine/BW all present"),
    // F — Personas
    .init(name: "Persona · The Powerlifter", category: "F · Personas", hint: "Big 3 dominant; heavy + low-rep; advanced/elite tiers"),
    .init(name: "Persona · The Bodybuilder", category: "F · Personas", hint: "High volume; lots of isolation; intermediate/advanced tiers"),
    .init(name: "Persona · The Beginner",    category: "F · Personas", hint: "Low weights; beginner tiers; early feedback messages"),
    .init(name: "Persona · The Elite",       category: "F · Personas", hint: "Elite tier across the board; all 7 patterns covered"),
    .init(name: "Persona · The Sporadic",    category: "F · Personas", hint: "Broken streaks; irregular gaps; low pattern confidence"),
    .init(name: "Persona · The Comeback",    category: "F · Personas", hint: "Strong history → 45-day gap → 1 workout today"),
    // G — Edge-case data states
    .init(name: "Edge · Single Workout",     category: "G · Edge Cases", hint: "All tabs → minimum data; 1 session only — check empty-ish states"),
    .init(name: "Edge · Fully Decayed",      category: "G · Edge Cases", hint: "Lab → e1RM at 50% floor (−0.7%/day × 84 days past grace); readiness ~46 (controlled zone, not zero — clamped at 20)"),
    .init(name: "Edge · Two-a-Day",          category: "G · Edge Cases", hint: "History → 2 entries today (AM + PM); verify streak and volume counting"),
    .init(name: "Edge · Mega Log (120)",     category: "G · Edge Cases", hint: "All tabs → 120 sessions over ~1 year; stress-tests list rendering and scroll"),
    // H — Special set types
    .init(name: "Sets · All Drop Sets",      category: "H · Special Sets", hint: "Lab: drop-adjusted e1RM (max of main / drop set); narrative slot only fires during active logging"),
    .init(name: "Sets · All To-Failure",     category: "H · Special Sets", hint: "Lab: toFailure field stored on every set; 'To Failure' connective phrase only fires during active logging"),
    .init(name: "Sets · High RPE (9)",       category: "H · Special Sets", hint: "Lab: Zourdos RPE-adjusted e1RM — higher than raw Epley at same weight; compare scores in Lab"),
    .init(name: "Sets · Mayhew Rep Range",   category: "H · Special Sets", hint: "Lab: 11-20 reps → Mayhew formula (not Epley); all sets included in e1RM (no cutoff at 15)"),
    // I — Streak milestones
    .init(name: "Streak · 7-Day",            category: "I · Streaks", hint: "Progress → 7-day streak counter; HON fires 'consecutive active weeks' or weekly count (not a day-streak banner)", needsHON: true),
    .init(name: "Streak · 30-Day",           category: "I · Streaks", hint: "Progress → 30-day streak counter; HON fires '4 consecutive active weeks' milestone", needsHON: true),
    .init(name: "Streak · Just Broken",      category: "I · Streaks", hint: "Progress → streak = 0; 14-day run ended 2 days ago — verify reset state"),
    .init(name: "Streak · Veteran, Lapsed",  category: "I · Streaks", hint: "Progress → 40 sessions over 6 months, nothing for 3 weeks; streak 0, strong history"),
    // J — Volume / intensity extremes
    .init(name: "Volume · Mega Session",     category: "J · Volume Extremes", hint: "History → 10 exercises × 5 sets (50 sets/session); scroll + render stress"),
    .init(name: "Volume · Micro Session",    category: "J · Volume Extremes", hint: "History → 1 exercise, 2 sets per session; minimum meaningful log entry"),
    .init(name: "Volume · Deload Week",      category: "J · Volume Extremes", hint: "Home: 3 light sessions this week — readiness +12 (today); HON deload fires on next foreground only"),
    // K — Progression arcs
    .init(name: "Arc · Linear PR Run",       category: "K · Progression Arcs", hint: "Lab: 8-week steady weight climb — strength score rising, trend positive"),
    .init(name: "Arc · Injury Return",       category: "K · Progression Arcs", hint: "Lab: strong build → weights crash to 60% → 6-week rebuild; V-shape trend"),
    .init(name: "Arc · Stall → Breakthrough",category: "K · Progression Arcs", hint: "Home: 4-week plateau at same weights, then one big PR session today"),
] }

// MARK: - View

struct UATScenarioView: View {
    @Environment(SeedStore.self)       private var store
    @Environment(HONHabitEngine.self)  private var habitEngine

    @State private var cycleIndex = 0
    @State private var lastApplied: String? = nil
    @State private var restoreAlert: RestoreAlert? = nil

    enum RestoreAlert: Identifiable {
        case success(count: Int), failure
        var id: Int { switch self { case .success: return 0; case .failure: return 1 } }
    }

    private var catalogue: [UATScenario] { buildCatalogue() }

    var body: some View {
        List {
            cycleSection
            backupSection
            stateSection
            ForEach(categories, id: \.self) { cat in
                categorySection(cat)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("UAT Scenarios")
        .navigationBarTitleDisplayMode(.large)
        .alert(item: $restoreAlert) { alert in
            switch alert {
            case .success(let count):
                return Alert(
                    title: Text("Real Data Restored"),
                    message: Text("\(count) workout\(count == 1 ? "" : "s") loaded. UAT data has been cleared."),
                    dismissButton: .default(Text("Done"))
                )
            case .failure:
                return Alert(
                    title: Text("Nothing to Restore"),
                    message: Text("No backup was found. Apply a scenario first — it auto-saves a backup before replacing your data."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var categories: [String] {
        var seen = Set<String>()
        return catalogue.compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }

    // MARK: Cycle

    private var cycleSection: some View {
        let s = catalogue[cycleIndex]
        return Section {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(s.category.uppercased())
                        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary).kerning(0.5)
                    Spacer()
                    Text("\(cycleIndex + 1) / \(catalogue.count)").font(.caption2).foregroundStyle(.secondary)
                }
                Text(s.name).font(.headline)
                Text(s.hint).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
            HStack(spacing: 8) {
                Button("← Prev") { step(-1) }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                Button("Apply")  { apply(cycleIndex) }.buttonStyle(.borderedProminent).tint(HONTheme.accent).frame(maxWidth: .infinity)
                Button("Next →") { step(+1) }.buttonStyle(.bordered).frame(maxWidth: .infinity)
            }
        } header: { Text("Quick Cycle — tap Next → to advance and apply") }
    }

    private func step(_ delta: Int) {
        cycleIndex = (cycleIndex + delta + catalogue.count) % catalogue.count
        apply(cycleIndex)
    }

    // MARK: Backup

    private var backupSection: some View {
        Section {
            if let date = store.uatBackupDate {
                LabeledContent("Backup saved", value: date.formatted(date: .abbreviated, time: .shortened))
                Button("Restore Real Data") {
                    if store.restoreUATBackup() {
                        lastApplied = "Restored"
                        restoreAlert = .success(count: store.workoutLog.count)
                    } else {
                        restoreAlert = .failure
                    }
                }.foregroundStyle(HONTheme.positive)
                Button("Overwrite Backup with Current") { store.backupForUAT() }.foregroundStyle(.secondary)
            } else {
                Button("Save Backup Now") { store.backupForUAT() }
                Text("Auto-backed up before the first scenario you apply.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: { Text("Your Real Data") }
    }

    // MARK: State

    private var stateSection: some View {
        Section {
            LabeledContent("Workouts", value: "\(store.workoutLog.count)")
            LabeledContent("PRs",      value: "\(store.personalRecords.count)")
            if let d = store.workoutLog.last?.startedAt  { LabeledContent("First", value: d.formatted(date: .abbreviated, time: .omitted)) }
            if let d = store.workoutLog.first?.startedAt { LabeledContent("Last",  value: d.formatted(date: .abbreviated, time: .omitted)) }
            if let n = lastApplied { LabeledContent("Applied", value: n).foregroundStyle(HONTheme.accent) }
        } header: { Text("Current State") }
    }

    // MARK: Category rows

    private func categorySection(_ category: String) -> some View {
        Section(category) {
            ForEach(Array(catalogue.enumerated()), id: \.offset) { idx, s in
                if s.category == category {
                    Button { apply(idx) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: idx == cycleIndex ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(idx == cycleIndex ? HONTheme.accent : Color.secondary.opacity(0.35))
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.name).foregroundStyle(HONTheme.accent)
                                Text(s.hint).font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Apply

    private func apply(_ index: Int) {
        let s   = catalogue[index]
        let log = buildLog(for: index)
        cycleIndex   = index
        lastApplied  = s.name
        store.injectUATScenario(log)
        if s.needsHON {
            habitEngine.resetForDebug()
            habitEngine.simulateLog(entries: log)
        }
    }
}

// MARK: - Log Builder (index → data)

private extension UATScenarioView {
    // swiftlint:disable cyclomatic_complexity
    func buildLog(for i: Int) -> [WorkoutLogEntry] {
        switch i {
        case 0:  return []
        case 1:  return feedbackAddWeight()
        case 2:  return feedbackStandardProgression()
        case 3:  return feedbackAlmostReady()
        case 4:  return feedbackDeload()
        case 5:  return feedbackStruggling()
        case 6:  return honLog(count: 1,  span: 0)
        case 7:  return honLog(count: 10, span: 29)
        case 8:  return honLog(count: 25, span: 72)
        case 9:  return honLapse(days: 14)
        case 10: return honLapse(days: 30)
        case 11: return honTypeA()
        case 12: return honRamp()
        case 13: return honDrift()
        case 14: return honConsecutiveWeeks(12)
        case 15: return honDeload()
        case 16: return strengthTier(bench: 50,  squat: 65,  dead: 80,  ohp: 35)
        case 17: return strengthTier(bench: 70,  squat: 95,  dead: 120, ohp: 47)
        case 18: return strengthTier(bench: 90,  squat: 125, dead: 160, ohp: 60)
        case 19: return strengthTier(bench: 120, squat: 165, dead: 210, ohp: 80)
        case 20: return strengthTier(bench: 160, squat: 220, dead: 280, ohp: 105)
        case 21: return strengthTierMixed()
        case 22: return patternBalanced()
        case 23: return patternPushHeavy()
        case 24: return patternPullHeavy()
        case 25: return patternLegDominant()
        case 26: return patternNoLegs()
        case 27: return patternIsolationOnly()
        case 28: return patternCompoundOnly()
        case 29: return equipmentOnly(.barbell)
        case 30: return equipmentOnly(.dumbbell)
        case 31: return equipmentOnly(.machine)
        case 32: return equipmentBodyweight()
        case 33: return equipmentFull()
        case 34: return personaPowerlifter()
        case 35: return personaBodybuilder()
        case 36: return personaBeginner()
        case 37: return personaElite()
        case 38: return personaSporadic()
        case 39: return personaComeback()
        case 40: return edgeSingleWorkout()
        case 41: return edgeDecayedData()
        case 42: return edgeTwoADay()
        case 43: return edgeMassiveLog()
        case 44: return specialDropSets()
        case 45: return specialToFailure()
        case 46: return specialHighRPE()
        case 47: return specialMayhewReps()
        case 48: return streak7Days()
        case 49: return streak30Days()
        case 50: return streakJustBroken()
        case 51: return streakVeteranLapsed()
        case 52: return volumeMegaSession()
        case 53: return volumeMicroSession()
        case 54: return volumeDeloadWeek()
        case 55: return arcLinearPR()
        case 56: return arcInjuryReturn()
        case 57: return arcStallBreakthrough()
        default: return []
        }
    }
    // swiftlint:enable cyclomatic_complexity
}

// MARK: - Data Helpers

private extension UATScenarioView {
    func ex(_ name: String) -> Exercise { store.exercises.first { $0.name == name } ?? store.exercises[0] }

    func cset(_ w: Double, _ r: Int, target: Int = 0, at t: Date? = nil) -> SetRecord {
        var s = SetRecord(weight: w, reps: r, targetWeight: w, targetReps: target > 0 ? target : r)
        s.isCompleted = true; s.completedAt = t
        return s
    }

    func wex(_ exercise: Exercise, w: Double, reps: [Int], target: Int = 0, base: Date) -> WorkoutExercise {
        WorkoutExercise(exercise: exercise,
                        sets: reps.enumerated().map { i, r in
                            cset(w, r, target: target > 0 ? target : r, at: base.addingTimeInterval(Double(i) * 180))
                        })
    }

    func entry(_ daysAgo: Int, _ exs: [WorkoutExercise], min: Int = 60, name: String = "Strength Workout") -> WorkoutLogEntry {
        let start = Date.ago(daysAgo)
        var e = WorkoutLogEntry(startedAt: start, exercises: exs)
        e.finishedAt = start.addingTimeInterval(Double(min) * 60)
        e.name = name
        return e
    }

    func entryAt(_ date: Date, _ exs: [WorkoutExercise], min: Int = 60, name: String = "Strength Workout") -> WorkoutLogEntry {
        var e = WorkoutLogEntry(startedAt: date, exercises: exs)
        e.finishedAt = date.addingTimeInterval(Double(min) * 60)
        e.name = name
        return e
    }

    func csetDrop(_ w: Double, _ r: Int, dropW: Double, dropR: Int, at t: Date? = nil) -> SetRecord {
        var s = SetRecord(weight: w, reps: r, targetWeight: w, targetReps: r)
        s.isCompleted = true; s.completedAt = t
        s.isDropCompleted = true; s.dropWeight = dropW; s.dropReps = dropR
        return s
    }

    func csetFailure(_ w: Double, _ r: Int, at t: Date? = nil) -> SetRecord {
        var s = SetRecord(weight: w, reps: r, targetWeight: w, targetReps: r + 2)
        s.isCompleted = true; s.completedAt = t
        s.toFailure = true
        return s
    }

    func csetRPE(_ w: Double, _ r: Int, rpe: Double, at t: Date? = nil) -> SetRecord {
        var s = SetRecord(weight: w, reps: r, targetWeight: w, targetReps: r)
        s.isCompleted = true; s.completedAt = t
        s.rpe = rpe
        return s
    }

    func wexDrop(_ exercise: Exercise, w: Double, dropW: Double, reps: Int, sets: Int, base: Date) -> WorkoutExercise {
        WorkoutExercise(exercise: exercise,
                        sets: (0..<sets).map { i in
                            csetDrop(w, reps, dropW: dropW, dropR: max(1, reps - 3),
                                     at: base.addingTimeInterval(Double(i) * 240))
                        })
    }

    func wexFailure(_ exercise: Exercise, w: Double, repsPerSet: [Int], base: Date) -> WorkoutExercise {
        WorkoutExercise(exercise: exercise,
                        sets: repsPerSet.enumerated().map { i, r in
                            csetFailure(w, r, at: base.addingTimeInterval(Double(i) * 210))
                        })
    }

    func wexRPE(_ exercise: Exercise, w: Double, reps: [Int], rpe: Double, base: Date) -> WorkoutExercise {
        WorkoutExercise(exercise: exercise,
                        sets: reps.enumerated().map { i, r in
                            csetRPE(w, r, rpe: rpe, at: base.addingTimeInterval(Double(i) * 240))
                        })
    }
}

// MARK: - A · Feedback Engine

private extension UATScenarioView {
    func feedbackAddWeight() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), ohp = ex("Overhead Press")
        let squat = ex("Barbell Squat"),       dead = ex("Deadlift"), row = ex("Barbell Row")
        return [
            entry(14, [wex(bench, w:90, reps:[5,5,5,5], target:5, base:.ago(14)),
                       wex(ohp,   w:57.5, reps:[8,8,8], target:8, base:.ago(14,900)),
                       wex(row,   w:75,   reps:[8,8,8], target:8, base:.ago(14,1800)),
                       wex(squat, w:120,  reps:[5,5,5,5],target:5,base:.ago(14,2700)),
                       wex(dead,  w:160,  reps:[5,5,5],  target:5,base:.ago(14,3600))]),
            entry(3,  [wex(bench, w:90, reps:[6,6,6,6], target:5, base:.ago(3)),       // exceeded → Add Weight
                       wex(ohp,   w:57.5, reps:[8,8,8], target:8, base:.ago(3,900)),
                       wex(row,   w:75,   reps:[8,8,8], target:8, base:.ago(3,1800)),
                       wex(squat, w:120,  reps:[5,5,5,5],target:5,base:.ago(3,2700)),
                       wex(dead,  w:160,  reps:[5,5,5],  target:5,base:.ago(3,3600))]),
        ]
    }

    func feedbackStandardProgression() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), ohp = ex("Overhead Press"), squat = ex("Barbell Squat")
        return [
            entry(14, [wex(bench, w:90, reps:[5,5,5,5], target:5, base:.ago(14)),
                       wex(ohp,   w:57.5, reps:[8,8,8], target:8, base:.ago(14,900)),
                       wex(squat, w:120,  reps:[5,5,5,5],target:5,base:.ago(14,1800))]),
            entry(7,  [wex(bench, w:90, reps:[5,5,5,5], target:5, base:.ago(7)),
                       wex(ohp,   w:57.5, reps:[8,8,8], target:8, base:.ago(7,900)),   // clean #1
                       wex(squat, w:120,  reps:[5,5,5,5],target:5,base:.ago(7,1800))]),
            entry(3,  [wex(bench, w:90, reps:[5,5,5,5], target:5, base:.ago(3)),
                       wex(ohp,   w:57.5, reps:[8,8,8], target:8, base:.ago(3,900)),   // clean #2 → Standard Progression
                       wex(squat, w:120,  reps:[5,5,5,5],target:5,base:.ago(3,1800))]),
        ]
    }

    func feedbackAlmostReady() -> [WorkoutLogEntry] {
        // Row needs past sessions at repHitRate = 0.75 (stuck, not struggling) so consecutiveStruggle=0.
        // With 4 sets target 8: [8,7,8,8] → 3/4 = 0.75 (isStuck, not isStruggling which needs < 0.75).
        // That breaks consecutiveClean=1 so STANDARD PROGRESSION doesn't fire either.
        // Result: CLOSE BUT NOT READY → hint kind = .hold, label "Hold weight", note = "One more solid session".
        let bench = ex("Barbell Bench Press"), row = ex("Barbell Row")
        return [
            entry(21, [wex(bench, w:87.5, reps:[5,5,5,5], target:5, base:.ago(21)),
                       wex(row,   w:70,   reps:[8,8,8,8], target:8, base:.ago(21,900))]),
            entry(14, [wex(bench, w:87.5, reps:[5,5,5,5], target:5, base:.ago(14)),
                       wex(row,   w:70,   reps:[8,7,8,8], target:8, base:.ago(14,900))]),  // stuck (3/4 = 0.75)
            entry(7,  [wex(bench, w:87.5, reps:[5,5,5,5], target:5, base:.ago(7)),
                       wex(row,   w:70,   reps:[8,8,7,8], target:8, base:.ago(7,900))]),   // stuck (3/4 = 0.75)
            entry(3,  [wex(bench, w:87.5, reps:[5,5,5,5], target:5, base:.ago(3)),
                       wex(row,   w:70,   reps:[8,8,8,8], target:8, base:.ago(3,900))]),   // clean → CLOSE BUT NOT READY
        ]
    }

    func feedbackDeload() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), dead = ex("Deadlift"), squat = ex("Barbell Squat")
        return [
            entry(42, [wex(bench, w:90, reps:[5,5,5,5], target:5, base:.ago(42)),
                       wex(dead,  w:160, reps:[5,5,5,5],target:5, base:.ago(42,1200)),
                       wex(squat, w:120, reps:[5,5,5,5],target:5, base:.ago(42,2400))]),
            entry(28, [wex(bench, w:90, reps:[5,5,5,5],   target:5, base:.ago(28)),
                       wex(dead,  w:162.5, reps:[5,4,3,3],target:5, base:.ago(28,1200)),   // struggle #1
                       wex(squat, w:120, reps:[5,5,5,5],  target:5, base:.ago(28,2400))]),
            entry(14, [wex(bench, w:90, reps:[5,5,5,5],   target:5, base:.ago(14)),
                       wex(dead,  w:160, reps:[5,4,3,3],  target:5, base:.ago(14,1200)),   // struggle #2 → Deload
                       wex(squat, w:120, reps:[5,5,5,5],  target:5, base:.ago(14,2400))]),
            entry(3,  [wex(bench, w:90, reps:[5,5,5,5],   target:5, base:.ago(3)),
                       wex(dead,  w:157.5, reps:[5,4,3,3],target:5, base:.ago(3,1200)),
                       wex(squat, w:120, reps:[5,5,5,5],  target:5, base:.ago(3,2400))]),
        ]
    }

    func feedbackStruggling() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat")
        return [
            entry(21, [wex(bench, w:90, reps:[5,5,5,5],   target:5, base:.ago(21)),
                       wex(squat, w:120, reps:[5,5,5,5],  target:5, base:.ago(21,1200))]),
            entry(14, [wex(bench, w:90, reps:[5,5,5,5],   target:5, base:.ago(14)),
                       wex(squat, w:120, reps:[5,5,5,5],  target:5, base:.ago(14,1200))]),
            entry(7,  [wex(bench, w:90, reps:[5,5,5,5],   target:5, base:.ago(7)),
                       wex(squat, w:120, reps:[5,5,5,5],  target:5, base:.ago(7,1200))]),
            entry(2,  [wex(bench, w:92.5, reps:[5,5,5,5], target:5, base:.ago(2)),
                       wex(squat, w:122.5, reps:[5,5,4,3],target:5, base:.ago(2,1200))]), // first struggle
        ]
    }
}

// MARK: - B · HON Messages

private extension UATScenarioView {
    func honEntry(_ daysAgo: Int, vol: Double = 2400) -> WorkoutLogEntry {
        let bench = ex("Barbell Bench Press")
        return entry(max(0, daysAgo),
                     [wex(bench, w: vol / 24, reps: [8,8,8], target: 8, base: .ago(max(0,daysAgo)))],
                     min: 45, name: "Workout")
    }

    func honLog(count: Int, span: Int) -> [WorkoutLogEntry] {
        let step = span > 0 ? span / max(count - 1, 1) : 0
        return (0..<count).map { i in honEntry(span - i * step) }
    }

    func honLapse(days: Int) -> [WorkoutLogEntry] {
        // Build history up to `days` days ago, then today — gap = exactly `days` days.
        // Previous version filtered on cutoff date and both B3/B4 ended up with the same
        // ~33-day most-recent session regardless of the `days` parameter.
        var log: [WorkoutLogEntry] = []
        var da = days + 60
        while da > days {
            log.append(honEntry(da))
            da -= 4
        }
        log.append(honEntry(days))  // last historical session exactly `days` ago
        log.append(honEntry(0))     // today — gap = `days` days
        return log
    }

    func honTypeA() -> [WorkoutLogEntry] {
        var log: [WorkoutLogEntry] = []
        for week in 0..<12 {
            for off in [0, 2, 4] { log.append(honEntry((11 - week) * 7 + (6 - off))) }
        }
        return log
    }

    func honRamp() -> [WorkoutLogEntry] {
        // Prior history from 63→6 days ago (step 3 = ~2-3 sessions/week).
        // Recent burst: 5 consecutive days ending today. No date overlap between batches.
        var log = (0..<20).map { i in honEntry(6 + (19 - i) * 3) }
        (0..<6).forEach { i in log.append(honEntry(i)) }
        return log
    }

    func honDrift() -> [WorkoutLogEntry] {
        let cutoff = Date().addingTimeInterval(-21 * 86_400)
        let history = (0..<25).map { i in honEntry(89 - i * 3) }.filter { $0.startedAt < cutoff }
        return history + [honEntry(14)]
    }

    func honConsecutiveWeeks(_ n: Int) -> [WorkoutLogEntry] {
        (0..<n).map { w in honEntry((n - 1 - w) * 7 + 2) }
    }

    func honDeload() -> [WorkoutLogEntry] {
        // Prior history from 63→3 days ago (i=19: 63-57=6... use step 3 starting at 63).
        // honEntry(56-19*3) = honEntry(-1) → was clamped to day 0, creating a regular
        // session today that cancelled the deload signal. Fixed: start at 63 so the
        // most recent regular session is 3 days ago, leaving only the low-vol session today.
        var log = (0..<20).map { i in honEntry(63 - i * 3) }  // 63→6 days ago
        log.append(honEntry(0, vol: 200))                       // today: low-volume only
        return log
    }
}

// MARK: - C · Strength Tiers

private extension UATScenarioView {
    func strengthTier(bench bw: Double, squat sw: Double, dead dw: Double, ohp ow: Double) -> [WorkoutLogEntry] {
        let b = ex("Barbell Bench Press"), s = ex("Barbell Squat")
        let d = ex("Deadlift"), o = ex("Overhead Press"), r = ex("Barbell Row")
        return (0..<12).map { i in
            let da = (11 - i) * 7
            return entry(da, [wex(b, w:bw,       reps:[5,5,5,5], target:5, base:.ago(da)),
                              wex(s, w:sw,        reps:[5,5,5,5], target:5, base:.ago(da,900)),
                              wex(d, w:dw,        reps:[5,5,5],   target:5, base:.ago(da,1800)),
                              wex(o, w:ow,        reps:[8,8,8],   target:8, base:.ago(da,2700)),
                              wex(r, w:bw * 0.85, reps:[8,8,8],   target:8, base:.ago(da,3600))])
        }
    }

    func strengthTierMixed() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat")
        let dead  = ex("Deadlift"),            curl  = ex("Dumbbell Curl"), lp = ex("Leg Press")
        return (0..<12).map { i in
            let da = (11 - i) * 7
            return entry(da, [wex(bench, w:130, reps:[5,5,5,5],  target:5,  base:.ago(da)),       // advanced
                              wex(squat, w:80,  reps:[5,5,5,5],  target:5,  base:.ago(da,900)),   // beginner
                              wex(dead,  w:200, reps:[5,5,5],    target:5,  base:.ago(da,1800)),  // elite
                              wex(curl,  w:10,  reps:[12,12,12], target:12, base:.ago(da,2700)),  // beginner
                              wex(lp,    w:250, reps:[10,10,10], target:10, base:.ago(da,3600))]) // intermediate
        }
    }
}

// MARK: - D · Pattern Balance

private extension UATScenarioView {
    func patternBalanced() -> [WorkoutLogEntry] {
        // All 7 movement patterns in every session
        let bench = ex("Barbell Bench Press"),     ohp   = ex("Overhead Press")
        let row   = ex("Barbell Row"),             pull  = ex("Lat Pulldown")
        let dead  = ex("Deadlift"),                squat = ex("Barbell Squat")
        let curl  = ex("Dumbbell Curl")
        return (0..<12).map { i in
            let da = (11 - i) * 5
            return entry(da, [wex(bench, w:85,  reps:[6,6,6],    target:6,  base:.ago(da)),
                              wex(ohp,   w:55,  reps:[8,8,8],    target:8,  base:.ago(da,900)),
                              wex(row,   w:75,  reps:[8,8,8],    target:8,  base:.ago(da,1800)),
                              wex(pull,  w:65,  reps:[10,10,10], target:10, base:.ago(da,2700)),
                              wex(dead,  w:150, reps:[5,5,5],    target:5,  base:.ago(da,3600)),
                              wex(squat, w:120, reps:[5,5,5],    target:5,  base:.ago(da,4500)),
                              wex(curl,  w:18,  reps:[12,12,12], target:12, base:.ago(da,5400))],
                         min: 80, name: "Full Body")
        }
    }

    func patternPushHeavy() -> [WorkoutLogEntry] {
        let bench   = ex("Barbell Bench Press"), incline = ex("Incline Barbell Press")
        let ohp     = ex("Overhead Press"),      dbOhp   = ex("Dumbbell Shoulder Press")
        let dip     = ex("Dip")
        return (0..<12).map { i in
            let da = (11 - i) * 5
            return entry(da, [wex(bench,   w:90, reps:[5,5,5,5],  target:5,  base:.ago(da)),
                              wex(incline, w:75, reps:[6,6,6],    target:6,  base:.ago(da,900)),
                              wex(ohp,     w:60, reps:[8,8,8],    target:8,  base:.ago(da,1800)),
                              wex(dbOhp,   w:28, reps:[10,10,10], target:10, base:.ago(da,2700)),
                              wex(dip,     w:20, reps:[12,12,12], target:12, base:.ago(da,3600))],
                         name: "Push Day")
        }
    }

    func patternPullHeavy() -> [WorkoutLogEntry] {
        let dead = ex("Deadlift"),         row  = ex("Barbell Row"),       pullUp = ex("Pull-Up")
        let lpd  = ex("Lat Pulldown"),     cable = ex("Seated Cable Row"), face   = ex("Face Pull")
        return (0..<12).map { i in
            let da = (11 - i) * 5
            return entry(da, [wex(dead,   w:150, reps:[5,5,5],    target:5,  base:.ago(da)),
                              wex(row,    w:80,  reps:[8,8,8],    target:8,  base:.ago(da,900)),
                              wex(pullUp, w:0,   reps:[8,8,8],    target:8,  base:.ago(da,1800)),
                              wex(lpd,    w:70,  reps:[10,10,10], target:10, base:.ago(da,2700)),
                              wex(cable,  w:65,  reps:[12,12,12], target:12, base:.ago(da,3600)),
                              wex(face,   w:30,  reps:[15,15,15], target:15, base:.ago(da,4500))],
                         name: "Pull Day")
        }
    }

    func patternLegDominant() -> [WorkoutLogEntry] {
        let squat = ex("Barbell Squat"),     dead = ex("Deadlift"),  rdl = ex("Romanian Deadlift")
        let lp    = ex("Leg Press"),         lcurl = ex("Leg Curl"), lext = ex("Leg Extension")
        return (0..<12).map { i in
            let da = (11 - i) * 5
            return entry(da, [wex(squat, w:130, reps:[5,5,5,5],  target:5,  base:.ago(da)),
                              wex(dead,  w:170, reps:[5,5,5],    target:5,  base:.ago(da,1200)),
                              wex(rdl,   w:100, reps:[10,10,10], target:10, base:.ago(da,2400)),
                              wex(lp,    w:200, reps:[12,12,12], target:12, base:.ago(da,3300)),
                              wex(lcurl, w:50,  reps:[15,15,15], target:15, base:.ago(da,4200)),
                              wex(lext,  w:60,  reps:[15,15,15], target:15, base:.ago(da,5100))],
                         min: 75, name: "Leg Day")
        }
    }

    func patternNoLegs() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), ohp = ex("Overhead Press")
        let row   = ex("Barbell Row"),         pull = ex("Lat Pulldown")
        let curl  = ex("Dumbbell Curl"),        tri  = ex("Tricep Pushdown")
        return (0..<12).map { i in
            let da = (11 - i) * 5
            return entry(da, [wex(bench, w:90, reps:[5,5,5,5],  target:5,  base:.ago(da)),
                              wex(ohp,   w:60, reps:[8,8,8],    target:8,  base:.ago(da,900)),
                              wex(row,   w:80, reps:[8,8,8],    target:8,  base:.ago(da,1800)),
                              wex(pull,  w:70, reps:[10,10,10], target:10, base:.ago(da,2700)),
                              wex(curl,  w:18, reps:[12,12,12], target:12, base:.ago(da,3600)),
                              wex(tri,   w:40, reps:[12,12,12], target:12, base:.ago(da,4500))],
                         name: "Upper Body")
        }
    }

    func patternIsolationOnly() -> [WorkoutLogEntry] {
        let curl  = ex("Dumbbell Curl"),    tri   = ex("Tricep Pushdown")
        let lat   = ex("Lateral Raise"),    fly   = ex("Dumbbell Fly")
        let lcurl = ex("Leg Curl"),          lext  = ex("Leg Extension")
        return (0..<12).map { i in
            let da = (11 - i) * 5
            return entry(da, [wex(curl,  w:16, reps:[15,15,15], target:15, base:.ago(da)),
                              wex(tri,   w:35, reps:[15,15,15], target:15, base:.ago(da,600)),
                              wex(lat,   w:10, reps:[15,15,15], target:15, base:.ago(da,1200)),
                              wex(fly,   w:16, reps:[12,12,12], target:12, base:.ago(da,1800)),
                              wex(lcurl, w:45, reps:[15,15,15], target:15, base:.ago(da,2400)),
                              wex(lext,  w:50, reps:[15,15,15], target:15, base:.ago(da,3000))],
                         min: 50, name: "Isolation Day")
        }
    }

    func patternCompoundOnly() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), ohp  = ex("Overhead Press"), squat = ex("Barbell Squat")
        let dead  = ex("Deadlift"),            row  = ex("Barbell Row"),    pull  = ex("Pull-Up")
        let rdl   = ex("Romanian Deadlift")
        return (0..<12).map { i in
            let da = (11 - i) * 5
            return entry(da, [wex(bench, w:90,  reps:[5,5,5,5], target:5, base:.ago(da)),
                              wex(ohp,   w:60,  reps:[5,5,5],   target:5, base:.ago(da,900)),
                              wex(squat, w:125, reps:[5,5,5,5], target:5, base:.ago(da,1800)),
                              wex(dead,  w:160, reps:[5,5,5],   target:5, base:.ago(da,2700)),
                              wex(row,   w:80,  reps:[5,5,5],   target:5, base:.ago(da,3600)),
                              wex(pull,  w:0,   reps:[8,8,8],   target:8, base:.ago(da,4500)),
                              wex(rdl,   w:100, reps:[8,8,8],   target:8, base:.ago(da,5400))],
                         min: 80, name: "Compound Day")
        }
    }
}

// MARK: - E · Equipment Mix

private extension UATScenarioView {
    func equipmentOnly(_ equipment: Equipment) -> [WorkoutLogEntry] {
        let pool = store.exercises.filter { $0.equipment == equipment }.prefix(5)
        guard !pool.isEmpty else { return [] }
        // Use realistic per-equipment reference weights so strength tiers aren't inflated.
        // Dumbbell w = per-hand; barbell/machine w = total loaded.
        let refWeight: Double
        switch equipment {
        case .dumbbell:    refWeight = 25   // ~intermediate per-hand (e.g., 25 kg DB press)
        case .barbell:     refWeight = 80   // ~intermediate total (80 kg bench)
        case .machine:     refWeight = 60   // ~intermediate stack weight
        case .kettlebell:  refWeight = 20   // standard 20 kg kettlebell
        default:           refWeight = 40
        }
        return (0..<12).map { i in
            let da = (11 - i) * 6
            return entry(da, pool.enumerated().map { j, ex in
                wex(ex, w: refWeight, reps: [8,8,8], target: 8, base: .ago(da, Double(j) * 900))
            })
        }
    }

    func equipmentBodyweight() -> [WorkoutLogEntry] {
        // Bodyweight at w=0 — no e1RM computable (excluded by progressTrend guard).
        // Tests History tab rep-only display and that Lab/Lab trend shows nothing for these exercises.
        let pullUp = ex("Pull-Up"), dip = ex("Dip")
        let pool = [pullUp, dip].filter { $0.equipment == .bodyweight }
        guard !pool.isEmpty else { return [] }
        return (0..<12).map { i in
            let da = (11 - i) * 6
            return entry(da, pool.enumerated().map { j, exercise in
                wex(exercise, w: 0, reps: [10, 10, 8], target: 10, base: .ago(da, Double(j) * 900))
            }, name: "Bodyweight Session")
        }
    }

    func equipmentFull() -> [WorkoutLogEntry] {
        let bb  = ex("Barbell Bench Press"),  db   = ex("Dumbbell Curl")
        let cbl = ex("Seated Cable Row"),     mch  = ex("Leg Press")
        let bw  = ex("Pull-Up"),              kb   = ex("Goblet Squat")
        return (0..<12).map { i in
            let da = (11 - i) * 6
            return entry(da, [wex(bb,  w:85,  reps:[5,5,5,5],  target:5,  base:.ago(da)),
                              wex(db,  w:16,  reps:[12,12,12], target:12, base:.ago(da,900)),
                              wex(cbl, w:65,  reps:[10,10,10], target:10, base:.ago(da,1800)),
                              wex(mch, w:150, reps:[12,12,12], target:12, base:.ago(da,2700)),
                              wex(bw,  w:0,   reps:[8,8,8],    target:8,  base:.ago(da,3600)),
                              wex(kb,  w:24,  reps:[12,12,12], target:12, base:.ago(da,4500))],
                         min: 70, name: "Full Mix")
        }
    }
}

// MARK: - F · Personas

private extension UATScenarioView {
    func personaPowerlifter() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat")
        let dead  = ex("Deadlift"),            ohp   = ex("Overhead Press")
        return (0..<24).map { i in
            let da   = (23 - i) * 7
            let prog = Double(i) / 23.0
            return entry(da, [wex(bench, w:120+prog*20, reps:[3,3,3,3,3], target:3, base:.ago(da)),
                              wex(squat, w:160+prog*25, reps:[3,3,3,3,3], target:3, base:.ago(da,1200)),
                              wex(dead,  w:200+prog*30, reps:[2,2,2],     target:2, base:.ago(da,2400)),
                              wex(ohp,   w:80+prog*10,  reps:[5,5,5],     target:5, base:.ago(da,3300))],
                         min: 90, name: "Powerlifting")
        }
    }

    func personaBodybuilder() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"),  incline = ex("Incline Dumbbell Press")
        let fly   = ex("Cable Fly"),             pull    = ex("Lat Pulldown")
        let row   = ex("Seated Cable Row"),      curl    = ex("Dumbbell Curl")
        let tri   = ex("Rope Pushdown"),          lat     = ex("Lateral Raise")
        let lp    = ex("Leg Press"),              lcurl   = ex("Leg Curl")
        return (0..<36).map { i in
            let da   = (35 - i) * 5
            let p    = Double(i) / 35.0
            return entry(da, [wex(bench,   w:80+p*10,  reps:[10,10,10,10], target:10, base:.ago(da)),
                              wex(incline,  w:26+p*5,   reps:[12,12,12],    target:12, base:.ago(da,900)),
                              wex(fly,      w:40+p*5,   reps:[15,15,15],    target:15, base:.ago(da,1800)),
                              wex(pull,     w:60+p*10,  reps:[12,12,12],    target:12, base:.ago(da,2700)),
                              wex(row,      w:55+p*10,  reps:[12,12,12],    target:12, base:.ago(da,3600)),
                              wex(curl,     w:14+p*4,   reps:[15,15,15],    target:15, base:.ago(da,4500)),
                              wex(tri,      w:35+p*5,   reps:[15,15,15],    target:15, base:.ago(da,5400)),
                              wex(lat,      w:10+p*3,   reps:[20,20,20],    target:20, base:.ago(da,6300)),
                              wex(lp,       w:140+p*20, reps:[12,12,12],    target:12, base:.ago(da,7200)),
                              wex(lcurl,    w:50+p*8,   reps:[15,15,15],    target:15, base:.ago(da,8100))],
                         min: Int(90 + p*15), name: "Body Split")
        }
    }

    func personaBeginner() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat"), dead = ex("Deadlift")
        return (0..<6).map { i in
            let da = (5 - i) * 4; let p = Double(i) / 5.0
            return entry(da, [wex(bench, w:40+p*5, reps:[5,5,5], target:5, base:.ago(da)),
                              wex(squat, w:60+p*5, reps:[5,5,5], target:5, base:.ago(da,900)),
                              wex(dead,  w:80+p*5, reps:[5,5,5], target:5, base:.ago(da,1800))],
                         min: 35, name: "Beginner Workout")
        }
    }

    func personaElite() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat"), dead = ex("Deadlift")
        let ohp   = ex("Overhead Press"),      row   = ex("Barbell Row"),   pull = ex("Pull-Up")
        let rdl   = ex("Romanian Deadlift")
        return (0..<52).map { i in
            let da = (51 - i) * 7
            return entry(da, [wex(bench, w:155, reps:[3,3,3,3], target:3, base:.ago(da)),
                              wex(squat, w:210, reps:[3,3,3,3], target:3, base:.ago(da,1200)),
                              wex(dead,  w:270, reps:[3,3,3],   target:3, base:.ago(da,2400)),
                              wex(ohp,   w:100, reps:[5,5,5],   target:5, base:.ago(da,3300)),
                              wex(row,   w:120, reps:[5,5,5],   target:5, base:.ago(da,4200)),
                              wex(pull,  w:40,  reps:[8,8,8],   target:8, base:.ago(da,5100)),
                              wex(rdl,   w:150, reps:[6,6,6],   target:6, base:.ago(da,6000))],
                         min: 100, name: "Elite Training")
        }
    }

    func personaSporadic() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat")
        let days  = [88,85,72,69,67,52,49,46,35,33,28,17,15,8,6,3]
        return days.enumerated().map { i, da in
            let p = Double(i) / Double(days.count - 1)
            return entry(da, [wex(bench, w:70+p*5, reps:[5,5,5], target:5, base:.ago(da)),
                              wex(squat, w:90+p*5, reps:[5,5,5], target:5, base:.ago(da,900))],
                         min: 40)
        }
    }

    func personaComeback() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat"), dead = ex("Deadlift")
        var log = (0..<20).map { i -> WorkoutLogEntry in
            let da = 160 - i * 6; let p = Double(i) / 19.0
            return entry(da, [wex(bench, w:85+p*10,  reps:[5,5,5,5], target:5, base:.ago(da)),
                              wex(squat, w:110+p*15, reps:[5,5,5,5], target:5, base:.ago(da,1200)),
                              wex(dead,  w:140+p*20, reps:[5,5,5],   target:5, base:.ago(da,2400))],
                         min: 60)
        }
        log.append(entry(0, [wex(bench, w:80,  reps:[5,5,5,4], target:5, base:.ago(0)),
                             wex(squat, w:100, reps:[5,5,5,5], target:5, base:.ago(0,1200)),
                             wex(dead,  w:130, reps:[5,5,5],   target:5, base:.ago(0,2400))],
                         min: 55, name: "Back At It"))
        return log
    }
}

// MARK: - G · Edge Cases

private extension UATScenarioView {
    func edgeSingleWorkout() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat"), dead = ex("Deadlift")
        return [entry(0, [wex(bench, w:80,  reps:[5,5,5], target:5, base:.ago(0)),
                          wex(squat, w:100, reps:[5,5,5], target:5, base:.ago(0, 900)),
                          wex(dead,  w:120, reps:[5,5,5], target:5, base:.ago(0, 1800))],
                      min: 40, name: "First Workout")]
    }

    func edgeDecayedData() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat"), dead = ex("Deadlift")
        // Span 365→98 days ago — well past 14-day no-decay window; e1RM decays to 50% floor
        return (0..<15).map { i in
            let da = 365 - i * 18
            return entry(da, [wex(bench, w:90,  reps:[5,5,5,5], target:5, base:.ago(da)),
                              wex(squat, w:120, reps:[5,5,5,5], target:5, base:.ago(da, 1200)),
                              wex(dead,  w:150, reps:[5,5,5],   target:5, base:.ago(da, 2400))],
                         min: 65)
        }
    }

    func edgeTwoADay() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), row   = ex("Barbell Row")
        let squat = ex("Barbell Squat"),       dead  = ex("Deadlift")
        var log = (0..<8).map { i -> WorkoutLogEntry in
            let da = (8 - i) * 7
            return entry(da, [wex(bench, w:85,  reps:[5,5,5,5], target:5, base:.ago(da)),
                              wex(row,   w:70,  reps:[8,8,8],   target:8, base:.ago(da, 900)),
                              wex(squat, w:115, reps:[5,5,5,5], target:5, base:.ago(da, 1800)),
                              wex(dead,  w:150, reps:[5,5,5],   target:5, base:.ago(da, 2700))])
        }
        let amBase = Date().addingTimeInterval(-8.0 * 3600)
        log.append(entryAt(amBase,
                            [wex(bench, w:87.5, reps:[5,5,5,5], target:5, base:amBase),
                             wex(row,   w:72.5, reps:[8,8,8],   target:8, base:amBase.addingTimeInterval(900))],
                            min: 45, name: "AM — Upper"))
        let pmBase = Date().addingTimeInterval(-2.0 * 3600)
        log.append(entryAt(pmBase,
                            [wex(squat, w:117.5, reps:[5,5,5,5], target:5, base:pmBase),
                             wex(dead,  w:152.5, reps:[5,5,5],   target:5, base:pmBase.addingTimeInterval(1200))],
                            min: 50, name: "PM — Lower"))
        return log.sorted { $0.startedAt > $1.startedAt }
    }

    func edgeMassiveLog() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat")
        let dead  = ex("Deadlift"),            row   = ex("Barbell Row")
        return (0..<120).map { i in
            let da = (119 - i) * 3
            let p  = Double(i) / 119.0
            return entry(da, [wex(bench, w:70 + p * 25, reps:[5,5,5,5], target:5, base:.ago(da)),
                              wex(squat, w:90 + p * 35, reps:[5,5,5,5], target:5, base:.ago(da, 1200)),
                              wex(dead,  w:110 + p * 45, reps:[5,5,5],  target:5, base:.ago(da, 2400)),
                              wex(row,   w:60 + p * 20, reps:[8,8,8],   target:8, base:.ago(da, 3600))],
                         min: 65)
        }
    }
}

// MARK: - H · Special Sets

private extension UATScenarioView {
    func specialDropSets() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), row  = ex("Barbell Row")
        let curl  = ex("Dumbbell Curl"),       tri  = ex("Tricep Pushdown")
        return (0..<8).map { i in
            let da = (7 - i) * 7
            return entry(da, [wexDrop(bench, w:90, dropW:70, reps:6, sets:4, base:.ago(da)),
                              wexDrop(row,   w:75, dropW:55, reps:8, sets:3, base:.ago(da, 1000)),
                              wexDrop(curl,  w:18, dropW:13, reps:10, sets:3, base:.ago(da, 2000)),
                              wexDrop(tri,   w:40, dropW:30, reps:10, sets:3, base:.ago(da, 3000))],
                         min: 65, name: "Drop Set Session")
        }
    }

    func specialToFailure() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat")
        let row   = ex("Barbell Row"),         curl  = ex("Dumbbell Curl")
        return (0..<8).map { i in
            let da = (7 - i) * 7
            return entry(da, [wexFailure(bench, w:85,  repsPerSet:[8,7,6,5],  base:.ago(da)),
                              wexFailure(squat, w:100, repsPerSet:[10,9,8,7], base:.ago(da, 1200)),
                              wexFailure(row,   w:70,  repsPerSet:[10,9,8],   base:.ago(da, 2200)),
                              wexFailure(curl,  w:16,  repsPerSet:[12,11,10], base:.ago(da, 3000))],
                         min: 60, name: "Failure Training")
        }
    }

    func specialHighRPE() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat")
        let dead  = ex("Deadlift"),            ohp   = ex("Overhead Press")
        return (0..<10).map { i in
            let da = (9 - i) * 7
            return entry(da, [wexRPE(bench, w:105, reps:[3,3,3,3], rpe:9.0, base:.ago(da)),
                              wexRPE(squat, w:140, reps:[3,3,3,3], rpe:9.0, base:.ago(da, 1200)),
                              wexRPE(dead,  w:180, reps:[2,2,2],   rpe:9.0, base:.ago(da, 2400)),
                              wexRPE(ohp,   w:72,  reps:[5,5,5],   rpe:8.0, base:.ago(da, 3300))],
                         min: 80, name: "Heavy Day (RPE 9)")
        }
    }

    func specialMayhewReps() -> [WorkoutLogEntry] {
        let pull  = ex("Lat Pulldown"),     row   = ex("Seated Cable Row")
        let lp    = ex("Leg Press"),        curl  = ex("Dumbbell Curl")
        let lat   = ex("Lateral Raise"),    tri   = ex("Tricep Pushdown")
        return (0..<10).map { i in
            let da = (9 - i) * 6
            return entry(da, [wex(pull, w:60,  reps:[15,13,12], target:15, base:.ago(da)),
                              wex(row,  w:55,  reps:[15,13,12], target:15, base:.ago(da, 800)),
                              wex(lp,   w:130, reps:[15,13,12], target:15, base:.ago(da, 1600)),
                              wex(curl, w:14,  reps:[15,13,12], target:15, base:.ago(da, 2400)),
                              wex(lat,  w:9,   reps:[15,15,15], target:15, base:.ago(da, 3200)),
                              wex(tri,  w:35,  reps:[15,13,12], target:15, base:.ago(da, 4000))],
                         min: 55, name: "Hypertrophy — Mayhew Range")
        }
    }
}

// MARK: - I · Streaks

private extension UATScenarioView {
    func streak7Days() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat"), row = ex("Barbell Row")
        return (0..<7).map { i in
            let da = 6 - i
            return entry(da, [wex(bench, w:85,  reps:[5,5,5,5], target:5, base:.ago(da)),
                              wex(squat, w:110, reps:[5,5,5,5], target:5, base:.ago(da, 900)),
                              wex(row,   w:70,  reps:[8,8,8],   target:8, base:.ago(da, 1800))],
                         min: 50)
        }
    }

    func streak30Days() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat"), row = ex("Barbell Row")
        return (0..<30).map { i in
            let da = 29 - i
            return entry(da, [wex(bench, w:85,  reps:[5,5,5,5], target:5, base:.ago(da)),
                              wex(squat, w:110, reps:[5,5,5,5], target:5, base:.ago(da, 900)),
                              wex(row,   w:70,  reps:[8,8,8],   target:8, base:.ago(da, 1800))],
                         min: 50)
        }
    }

    func streakJustBroken() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat")
        // Sessions 15→2 days ago; yesterday (1 day ago) missing → streak resets to 0
        return (0..<14).map { i in
            let da = 15 - i
            return entry(da, [wex(bench, w:82,  reps:[5,5,5,5], target:5, base:.ago(da)),
                              wex(squat, w:105, reps:[5,5,5,5], target:5, base:.ago(da, 900))],
                         min: 45)
        }
    }

    func streakVeteranLapsed() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat"), dead = ex("Deadlift")
        // 40 sessions over 6 months; most recent 21 days ago — streak 0, rich history
        return (0..<40).map { i in
            let da = 21 + (39 - i) * 4   // 177 → 21 days ago
            return entry(da, [wex(bench, w:88,  reps:[5,5,5,5], target:5, base:.ago(da)),
                              wex(squat, w:115, reps:[5,5,5,5], target:5, base:.ago(da, 1200)),
                              wex(dead,  w:145, reps:[5,5,5],   target:5, base:.ago(da, 2400))],
                         min: 65)
        }
    }
}

// MARK: - J · Volume Extremes

private extension UATScenarioView {
    func volumeMegaSession() -> [WorkoutLogEntry] {
        let bench  = ex("Barbell Bench Press"), incline = ex("Incline Barbell Press")
        let ohp    = ex("Overhead Press"),      dip     = ex("Dip")
        let row    = ex("Barbell Row"),          pull    = ex("Lat Pulldown")
        let cable  = ex("Seated Cable Row"),     pullUp  = ex("Pull-Up")
        let squat  = ex("Barbell Squat"),        lp      = ex("Leg Press")
        return (0..<8).map { i in
            let da = (7 - i) * 7
            return entry(da, [wex(bench,   w:85,  reps:[8,8,8,8,8],     target:8,  base:.ago(da)),
                              wex(incline, w:70,  reps:[10,10,10,10,10], target:10, base:.ago(da, 1000)),
                              wex(ohp,     w:55,  reps:[8,8,8,8,8],     target:8,  base:.ago(da, 2000)),
                              wex(dip,     w:15,  reps:[12,12,12,12,12], target:12, base:.ago(da, 3000)),
                              wex(row,     w:75,  reps:[8,8,8,8,8],     target:8,  base:.ago(da, 4000)),
                              wex(pull,    w:65,  reps:[10,10,10,10,10], target:10, base:.ago(da, 5000)),
                              wex(cable,   w:60,  reps:[12,12,12,12,12], target:12, base:.ago(da, 6000)),
                              wex(pullUp,  w:0,   reps:[8,8,8,8,8],     target:8,  base:.ago(da, 7000)),
                              wex(squat,   w:110, reps:[8,8,8,8,8],     target:8,  base:.ago(da, 8000)),
                              wex(lp,      w:160, reps:[12,12,12,12,12], target:12, base:.ago(da, 9000))],
                         min: 130, name: "Volume Mega Session")
        }
    }

    func volumeMicroSession() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press")
        return (0..<8).map { i in
            let da = (7 - i) * 7
            return entry(da, [wex(bench, w:80, reps:[5,5], target:5, base:.ago(da))],
                         min: 15, name: "Quick Session")
        }
    }

    func volumeDeloadWeek() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat")
        let dead  = ex("Deadlift"),            ohp   = ex("Overhead Press"), row = ex("Barbell Row")
        var log = (0..<8).map { i -> WorkoutLogEntry in
            let da = (8 - i) * 7; let p = Double(i) / 7.0
            return entry(da, [wex(bench, w:88 + p * 5,  reps:[5,5,5,5], target:5, base:.ago(da)),
                              wex(squat, w:118 + p * 8, reps:[5,5,5,5], target:5, base:.ago(da, 1200)),
                              wex(dead,  w:148 + p * 10,reps:[5,5,5],   target:5, base:.ago(da, 2400)),
                              wex(ohp,   w:59 + p * 3,  reps:[8,8,8],   target:8, base:.ago(da, 3300)),
                              wex(row,   w:74 + p * 5,  reps:[8,8,8],   target:8, base:.ago(da, 4200))],
                         min: 70)
        }
        for da in [4, 2, 0] {
            log.append(entry(da, [wex(bench, w:47.5, reps:[5,5,5], target:5, base:.ago(da)),
                                  wex(squat, w:60,   reps:[5,5,5], target:5, base:.ago(da, 1200)),
                                  wex(dead,  w:75,   reps:[5,5,5], target:5, base:.ago(da, 2400))],
                             min: 40, name: "Deload"))
        }
        return log.sorted { $0.startedAt > $1.startedAt }
    }
}

// MARK: - K · Progression Arcs

private extension UATScenarioView {
    func arcLinearPR() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat")
        let dead  = ex("Deadlift"),            ohp   = ex("Overhead Press")
        // 24 sessions over 8 weeks — weight climbs every session
        return (0..<24).map { i in
            let da = (23 - i) * 3
            let p  = Double(i) / 23.0
            return entry(da, [wex(bench, w:80  + p * 22.5, reps:[5,5,5,5], target:5, base:.ago(da)),
                              wex(squat, w:100 + p * 32.5, reps:[5,5,5,5], target:5, base:.ago(da, 1200)),
                              wex(dead,  w:130 + p * 35,   reps:[5,5,5],   target:5, base:.ago(da, 2400)),
                              wex(ohp,   w:55  + p * 12.5, reps:[5,5,5],   target:5, base:.ago(da, 3300))],
                         min: 70, name: "Strength")
        }
    }

    func arcInjuryReturn() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), squat = ex("Barbell Squat"), dead = ex("Deadlift")
        // Build-up: 12 sessions 84→29 days ago, peaking near 95/130/165
        let buildUp: [WorkoutLogEntry] = (0..<12).map { i in
            let da = 84 - i * 5; let p = Double(i) / 11.0
            return entry(da, [wex(bench, w:75 + p * 20, reps:[5,5,5,5], target:5, base:.ago(da)),
                              wex(squat, w:95 + p * 35, reps:[5,5,5,5], target:5, base:.ago(da, 1200)),
                              wex(dead,  w:120 + p * 45, reps:[5,5,5],  target:5, base:.ago(da, 2400))],
                         min: 65)
        }
        // Recovery: 6 sessions last 24 days, weights ~60% of peak, slowly rebuilding
        let recovery: [WorkoutLogEntry] = (0..<6).map { i in
            let da = 24 - i * 4; let p = Double(i) / 5.0
            return entry(da, [wex(bench, w:57 + p * 15, reps:[5,5,5], target:5, base:.ago(da)),
                              wex(squat, w:75 + p * 20, reps:[5,5,5], target:5, base:.ago(da, 1200)),
                              wex(dead,  w:95 + p * 25, reps:[5,5,5], target:5, base:.ago(da, 2400))],
                         min: 45, name: "Rehab — Strength")
        }
        return (buildUp + recovery).sorted { $0.startedAt > $1.startedAt }
    }

    func arcStallBreakthrough() -> [WorkoutLogEntry] {
        let bench = ex("Barbell Bench Press"), ohp = ex("Overhead Press"), row = ex("Barbell Row")
        // 4-week plateau: same weights, reps hit but never exceeded
        let plateau: [WorkoutLogEntry] = (0..<12).map { i in
            let da = 42 - i * 3
            return entry(da, [wex(bench, w:95,   reps:[5,5,5,5], target:5, base:.ago(da)),
                              wex(ohp,   w:62.5, reps:[8,8,8],   target:8, base:.ago(da, 900)),
                              wex(row,   w:78,   reps:[8,8,8],   target:8, base:.ago(da, 1800))],
                         min: 60)
        }
        // Breakthrough: heavier weight, all sets exceeded — triggers Add Weight signal
        let breakthrough = entry(0, [wex(bench, w:100, reps:[5,5,5,6], target:5, base:.ago(0)),
                                     wex(ohp,   w:65,  reps:[8,8,9,9], target:8, base:.ago(0, 900)),
                                     wex(row,   w:80,  reps:[8,8,8,9], target:8, base:.ago(0, 1800))],
                                 min: 60, name: "Breakthrough Session")
        return ([breakthrough] + plateau).sorted { $0.startedAt > $1.startedAt }
    }
}

// MARK: - Date Helper

private extension Date {
    static func ago(_ days: Int, _ offsetSec: Double = 0) -> Date {
        Date().addingTimeInterval(-Double(days) * 86_400 + offsetSec)
    }
}

#endif
