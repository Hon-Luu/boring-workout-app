import SwiftUI

#if DEBUG

// MARK: - UAT Scenario View

struct UATScenarioView: View {
    @Environment(SeedStore.self) private var store
    @State private var lastApplied: String? = nil

    var body: some View {
        List {
            currentStateSection
            newUserSection
            earlyUserSection
            progressionSection
            returningSection
            workoutStyleSection
            edgeCasesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("UAT Scenarios")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Sections

    private var currentStateSection: some View {
        Section {
            LabeledContent("Total Workouts",   value: "\(store.workoutLog.count)")
            LabeledContent("Personal Records", value: "\(store.personalRecords.count)")
            if let first = store.workoutLog.last?.startedAt {
                LabeledContent("First Workout", value: first.formatted(date: .abbreviated, time: .omitted))
            }
            if let last = store.workoutLog.first?.startedAt {
                LabeledContent("Last Workout",  value: last.formatted(date: .abbreviated, time: .omitted))
            }
            if let name = lastApplied {
                LabeledContent("Last Applied", value: name).foregroundStyle(HONTheme.accent)
            }
            Button("Clear All Data", role: .destructive) { apply("Empty", emptyScenario()) }
        } header: { Text("Current State") }
    }

    private var newUserSection: some View {
        Section {
            cell("Brand-New User",
                 "Empty log — tests empty-state UI across all tabs") {
                apply("Brand-New User", emptyScenario())
            }
            cell("First Workout Done Today",
                 "1 workout just finished — tests day-1 experience & no-history states") {
                apply("First Workout Done Today", firstWorkoutScenario())
            }
        } header: { Text("New User") }
        .foregroundStyle(HONTheme.accent)
    }

    private var earlyUserSection: some View {
        Section {
            cell("Week 1 (3 workouts)",
                 "3 workouts over 5 days — tests early habit detection, sparse charts") {
                apply("Week 1", week1Scenario())
            }
            cell("1 Month Consistent (3×/week)",
                 "~12 sessions MWF — tests habit pattern, beginner feedback, early progress lines") {
                apply("1 Month Consistent", oneMonthScenario())
            }
        } header: { Text("Early User") }
        .foregroundStyle(HONTheme.accent)
    }

    private var progressionSection: some View {
        Section {
            cell("3 Months — Clear Progression",
                 "~36 sessions, steady weight increases, first PRs — tests progress charts & PR highlights") {
                apply("3 Months Progression", threeMonthScenario())
            }
            cell("6 Months — Full Analytics",
                 "~72 sessions, strength tiers active, all engines running — tests analytics depth") {
                apply("6 Months Full Analytics", sixMonthScenario())
            }
            cell("Upper/Lower Split (Varied Exercises)",
                 "30 sessions alternating upper/lower with 6+ exercises each — tests exercise variety display") {
                apply("Upper/Lower Varied", variedSplitScenario())
            }
        } header: { Text("Established User") }
        .foregroundStyle(HONTheme.accent)
    }

    private var returningSection: some View {
        Section {
            cell("Return After 14-Day Break",
                 "40 workouts then 14-day gap then 1 today — tests comeback messaging") {
                apply("Return (14d break)", returningScenario(daysGone: 14))
            }
            cell("Return After 30-Day Break",
                 "40 workouts then 30-day gap then 1 today — tests lapse detection") {
                apply("Return (30d break)", returningScenario(daysGone: 30))
            }
            cell("Sporadic Lifter",
                 "20 workouts over 90 days with random multi-week gaps — tests low-confidence habit display") {
                apply("Sporadic Lifter", sporadicScenario())
            }
        } header: { Text("Returning / Irregular") }
        .foregroundStyle(HONTheme.accent)
    }

    private var workoutStyleSection: some View {
        Section {
            cell("Short Sessions Only (15–20 min)",
                 "20 workouts, 2–3 exercises each — tests compact duration & volume display") {
                apply("Short Sessions", shortSessionsScenario())
            }
            cell("Marathon Sessions (90–120 min)",
                 "20 workouts, 8–10 exercises, 4+ sets each — tests large-volume UI, long exercise lists") {
                apply("Marathon Sessions", marathonSessionsScenario())
            }
        } header: { Text("Workout Style") }
        .foregroundStyle(HONTheme.accent)
    }

    private var edgeCasesSection: some View {
        Section {
            cell("Deload Week",
                 "20 normal sessions then 3 recent at 50% volume — tests deload detection & feedback") {
                apply("Deload Week", deloadScenario())
            }
            cell("Plateau Zone (4 weeks stagnant)",
                 "24 sessions, weights stuck for last 4 weeks — tests plateau/hold feedback") {
                apply("Plateau Zone", plateauScenario())
            }
            cell("Single Exercise — Bench Only",
                 "30 sessions of only bench press — tests single-exercise analytics & insights") {
                apply("Bench Only", benchOnlyScenario())
            }
        } header: { Text("Edge Cases") }
        .foregroundStyle(HONTheme.accent)
    }

    // MARK: - Cell Builder

    private func cell(_ title: String, _ description: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).foregroundStyle(HONTheme.accent)
                Text(description).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Apply

    private func apply(_ name: String, _ log: [WorkoutLogEntry]) {
        store.injectUATScenario(log)
        lastApplied = name
    }
}

// MARK: - Scenario Generators

private extension UATScenarioView {

    // MARK: Data Helpers

    func ex(_ name: String) -> Exercise {
        store.exercises.first { $0.name == name } ?? store.exercises[0]
    }

    func set(_ weight: Double, reps: Int, targetReps: Int = 0, at date: Date? = nil) -> SetRecord {
        var s = SetRecord(weight: weight, reps: reps, targetWeight: weight,
                          targetReps: targetReps > 0 ? targetReps : reps)
        s.isCompleted = true
        s.completedAt = date
        return s
    }

    func workEx(_ exercise: Exercise, weight: Double, reps: [Int], targetReps: Int = 0, base: Date) -> WorkoutExercise {
        let sets = reps.enumerated().map { i, r in
            set(weight, reps: r, targetReps: targetReps > 0 ? targetReps : r,
                at: base.addingTimeInterval(Double(i) * 180))
        }
        return WorkoutExercise(exercise: exercise, sets: sets)
    }

    func entry(daysAgo: Int, exercises: [WorkoutExercise], minutes: Int = 60, name: String = "Strength Workout") -> WorkoutLogEntry {
        let start = Date().addingTimeInterval(-Double(daysAgo) * 86_400)
        var e = WorkoutLogEntry(startedAt: start, exercises: exercises)
        e.finishedAt = start.addingTimeInterval(Double(minutes) * 60)
        e.name = name
        return e
    }

    // MARK: 1 — Empty

    func emptyScenario() -> [WorkoutLogEntry] { [] }

    // MARK: 2 — First Workout Today

    func firstWorkoutScenario() -> [WorkoutLogEntry] {
        let base = Date().addingTimeInterval(-35 * 60)
        return [
            entry(daysAgo: 0, exercises: [
                workEx(ex("Barbell Bench Press"), weight: 60, reps: [5,5,5], targetReps: 5, base: base),
                workEx(ex("Overhead Press"),      weight: 40, reps: [8,8,8], targetReps: 8, base: base.addingTimeInterval(720)),
            ], minutes: 35, name: "Push Day")
        ]
    }

    // MARK: 3 — Week 1

    func week1Scenario() -> [WorkoutLogEntry] {
        [
            entry(daysAgo: 5, exercises: [
                workEx(ex("Barbell Bench Press"), weight: 60,  reps: [5,5,5],   targetReps: 5, base: .ago(days: 5)),
                workEx(ex("Overhead Press"),      weight: 40,  reps: [8,8,8],   targetReps: 8, base: .ago(days: 5, offset: 720)),
            ], minutes: 35, name: "Push Day"),
            entry(daysAgo: 3, exercises: [
                workEx(ex("Barbell Squat"),        weight: 80,  reps: [5,5,5],   targetReps: 5, base: .ago(days: 3)),
                workEx(ex("Deadlift"),             weight: 100, reps: [5,5,5],   targetReps: 5, base: .ago(days: 3, offset: 900)),
            ], minutes: 40, name: "Leg Day"),
            entry(daysAgo: 0, exercises: [
                workEx(ex("Barbell Bench Press"), weight: 62.5, reps: [5,5,5],  targetReps: 5, base: .ago(days: 0)),
                workEx(ex("Barbell Row"),          weight: 60,  reps: [8,8,8],   targetReps: 8, base: .ago(days: 0, offset: 720)),
            ], minutes: 38, name: "Push / Pull"),
        ]
    }

    // MARK: 4 — 1 Month Consistent

    func oneMonthScenario() -> [WorkoutLogEntry] {
        // 12 sessions over 28 days, every ~2-3 days, alternating A/B
        let schedule: [(daysAgo: Int, isA: Bool)] = [
            (28,true),(26,false),(23,true),(21,false),
            (18,true),(16,false),(13,true),(11,false),
            (8,true),(6,false),(3,true),(1,false)
        ]
        return schedule.enumerated().map { idx, s in
            let week   = idx / 2
            let bw     = 60.0  + Double(week) * 2.5
            let ohpW   = 40.0  + Double(week) * 1.25
            let rowW   = 60.0  + Double(week) * 2.5
            let sqW    = 80.0  + Double(week) * 2.5
            let dlW    = 100.0 + Double(week) * 5.0
            let base   = Date.ago(days: s.daysAgo)
            if s.isA {
                return entry(daysAgo: s.daysAgo, exercises: [
                    workEx(ex("Barbell Bench Press"), weight: bw,   reps: [5,5,5,5], targetReps: 5, base: base),
                    workEx(ex("Overhead Press"),      weight: ohpW, reps: [8,8,8],   targetReps: 8, base: base.addingTimeInterval(900)),
                    workEx(ex("Barbell Row"),          weight: rowW, reps: [8,8,8],   targetReps: 8, base: base.addingTimeInterval(1800)),
                ], minutes: 55, name: "Push/Pull A")
            } else {
                return entry(daysAgo: s.daysAgo, exercises: [
                    workEx(ex("Barbell Squat"), weight: sqW, reps: [5,5,5,5], targetReps: 5, base: base),
                    workEx(ex("Deadlift"),      weight: dlW, reps: [5,5,5],   targetReps: 5, base: base.addingTimeInterval(1200)),
                ], minutes: 45, name: "Leg Day B")
            }
        }
    }

    // MARK: 5 — 3 Months Progression

    func threeMonthScenario() -> [WorkoutLogEntry] {
        var entries: [WorkoutLogEntry] = []
        // 36 sessions over 90 days, every ~2.5 days average
        let sessionCount = 36
        for i in 0..<sessionCount {
            let daysAgo = Int(Double(sessionCount - 1 - i) * 2.5)
            let week    = i / 3
            let isA     = i % 2 == 0

            // Weight increases every 2 weeks (~8 sessions)
            let progression = Double(week) / 2.0   // 0, 0.5, 1.0, ...
            let bw  = 60.0  + progression * 5.0    // 60→90 over 3 months
            let ohpW = 40.0 + progression * 2.5    // 40→55
            let sqW  = 80.0 + progression * 7.5    // 80→120
            let dlW  = 100.0 + progression * 10.0  // 100→160
            let rowW = 60.0  + progression * 5.0   // 60→90
            let base = Date.ago(days: daysAgo)

            if isA {
                entries.append(entry(daysAgo: daysAgo, exercises: [
                    workEx(ex("Barbell Bench Press"), weight: bw,   reps: [5,5,5,5], targetReps: 5, base: base),
                    workEx(ex("Overhead Press"),      weight: ohpW, reps: [8,8,8],   targetReps: 8, base: base.addingTimeInterval(900)),
                    workEx(ex("Barbell Row"),          weight: rowW, reps: [8,8,8],   targetReps: 8, base: base.addingTimeInterval(1800)),
                ], minutes: 55, name: "Push / Pull"))
            } else {
                entries.append(entry(daysAgo: daysAgo, exercises: [
                    workEx(ex("Barbell Squat"), weight: sqW, reps: [5,5,5,5], targetReps: 5, base: base),
                    workEx(ex("Deadlift"),      weight: dlW, reps: [5,5,5],   targetReps: 5, base: base.addingTimeInterval(1200)),
                ], minutes: 50, name: "Legs"))
            }
        }
        return entries
    }

    // MARK: 6 — 6 Months Full Analytics

    func sixMonthScenario() -> [WorkoutLogEntry] {
        var entries: [WorkoutLogEntry] = []
        let sessionCount = 72
        for i in 0..<sessionCount {
            let daysAgo    = Int(Double(sessionCount - 1 - i) * 2.5)
            let week       = i / 3
            let sessionMod = i % 3   // 0 = push, 1 = pull/legs, 2 = arms/shoulders

            let prog = Double(week) / 3.0
            let bw   = 70.0  + prog * 25.0    // 70→95
            let ohpW = 45.0  + prog * 15.0    // 45→60
            let sqW  = 90.0  + prog * 35.0    // 90→125
            let dlW  = 120.0 + prog * 40.0    // 120→160
            let rowW = 65.0  + prog * 25.0    // 65→90
            let lpdW = 55.0  + prog * 20.0    // 55→75
            let dbpW = 30.0  + prog * 10.0    // 30→40 per hand
            let lgpW = 120.0 + prog * 60.0    // 120→180 (leg press)
            let base = Date.ago(days: daysAgo)

            switch sessionMod {
            case 0: // Push
                entries.append(entry(daysAgo: daysAgo, exercises: [
                    workEx(ex("Barbell Bench Press"),    weight: bw,   reps: [5,5,5,5], targetReps: 5, base: base),
                    workEx(ex("Incline Barbell Press"),  weight: bw * 0.85, reps: [6,6,6], targetReps: 6, base: base.addingTimeInterval(900)),
                    workEx(ex("Overhead Press"),         weight: ohpW, reps: [8,8,8],   targetReps: 8, base: base.addingTimeInterval(1800)),
                    workEx(ex("Dumbbell Fly"),           weight: 20.0, reps: [12,12,12], targetReps: 12, base: base.addingTimeInterval(2700)),
                ], minutes: 65, name: "Push Day"))
            case 1: // Pull + Legs
                entries.append(entry(daysAgo: daysAgo, exercises: [
                    workEx(ex("Barbell Squat"),    weight: sqW,  reps: [5,5,5,5], targetReps: 5, base: base),
                    workEx(ex("Deadlift"),         weight: dlW,  reps: [5,5,4],   targetReps: 5, base: base.addingTimeInterval(1200)),
                    workEx(ex("Barbell Row"),      weight: rowW, reps: [8,8,8],   targetReps: 8, base: base.addingTimeInterval(2400)),
                    workEx(ex("Lat Pulldown"),     weight: lpdW, reps: [10,10,10], targetReps: 10, base: base.addingTimeInterval(3300)),
                ], minutes: 70, name: "Pull / Legs"))
            default: // Arms + Shoulders
                entries.append(entry(daysAgo: daysAgo, exercises: [
                    workEx(ex("Dumbbell Shoulder Press"), weight: dbpW, reps: [10,10,10], targetReps: 10, base: base),
                    workEx(ex("Lateral Raise"),           weight: 12,   reps: [15,15,15], targetReps: 15, base: base.addingTimeInterval(600)),
                    workEx(ex("Dumbbell Curl"),           weight: 16,   reps: [12,12,12], targetReps: 12, base: base.addingTimeInterval(1200)),
                    workEx(ex("Tricep Pushdown"),         weight: 40,   reps: [12,12,12], targetReps: 12, base: base.addingTimeInterval(1800)),
                    workEx(ex("Leg Press"),               weight: lgpW, reps: [12,12,12], targetReps: 12, base: base.addingTimeInterval(2400)),
                ], minutes: 60, name: "Arms / Shoulders"))
            }
        }
        return entries
    }

    // MARK: 7 — Upper/Lower Varied Split

    func variedSplitScenario() -> [WorkoutLogEntry] {
        var entries: [WorkoutLogEntry] = []
        for i in 0..<30 {
            let daysAgo = Int(Double(29 - i) * 3.0)
            let prog    = Double(i) / 29.0
            let base    = Date.ago(days: daysAgo)
            let isUpper = i % 2 == 0

            if isUpper {
                entries.append(entry(daysAgo: daysAgo, exercises: [
                    workEx(ex("Barbell Bench Press"),   weight: 75.0 + prog*10, reps: [6,6,6,6],   targetReps: 6, base: base),
                    workEx(ex("Dumbbell Bench Press"),  weight: 32.0 + prog*5,  reps: [10,10,10],  targetReps: 10, base: base.addingTimeInterval(900)),
                    workEx(ex("Seated Cable Row"),      weight: 65.0 + prog*10, reps: [10,10,10],  targetReps: 10, base: base.addingTimeInterval(1800)),
                    workEx(ex("Dumbbell Shoulder Press"),weight: 22.0 + prog*4, reps: [12,12,12],  targetReps: 12, base: base.addingTimeInterval(2700)),
                    workEx(ex("Lateral Raise"),         weight: 10.0 + prog*3,  reps: [15,15,15],  targetReps: 15, base: base.addingTimeInterval(3300)),
                    workEx(ex("Cable Curl"),            weight: 35.0 + prog*5,  reps: [12,12,12],  targetReps: 12, base: base.addingTimeInterval(3900)),
                    workEx(ex("Rope Pushdown"),         weight: 30.0 + prog*5,  reps: [12,12,12],  targetReps: 12, base: base.addingTimeInterval(4500)),
                ], minutes: 75, name: "Upper Body"))
            } else {
                entries.append(entry(daysAgo: daysAgo, exercises: [
                    workEx(ex("Barbell Squat"),        weight: 95.0 + prog*15,  reps: [6,6,6,6],  targetReps: 6,  base: base),
                    workEx(ex("Romanian Deadlift"),    weight: 85.0 + prog*10,  reps: [10,10,10], targetReps: 10, base: base.addingTimeInterval(1200)),
                    workEx(ex("Leg Press"),            weight: 140.0 + prog*20, reps: [12,12,12], targetReps: 12, base: base.addingTimeInterval(2100)),
                    workEx(ex("Leg Extension"),        weight: 55.0 + prog*10,  reps: [15,15,15], targetReps: 15, base: base.addingTimeInterval(2700)),
                    workEx(ex("Leg Curl"),             weight: 45.0 + prog*8,   reps: [15,15,15], targetReps: 15, base: base.addingTimeInterval(3300)),
                    workEx(ex("Standing Calf Raise"),  weight: 60.0 + prog*10,  reps: [20,20,20], targetReps: 20, base: base.addingTimeInterval(3900)),
                ], minutes: 70, name: "Lower Body"))
            }
        }
        return entries
    }

    // MARK: 8 — Return After Break

    func returningScenario(daysGone: Int) -> [WorkoutLogEntry] {
        var entries: [WorkoutLogEntry] = []
        // 40 workouts before the gap
        let historyStart = daysGone + 120
        for i in 0..<40 {
            let daysAgo = historyStart - Int(Double(i) * 3.0)
            guard daysAgo > daysGone else { break }
            let prog    = Double(i) / 39.0
            let bw      = 80.0 + prog * 12.0
            let sqW     = 100.0 + prog * 20.0
            let dlW     = 130.0 + prog * 25.0
            let base    = Date.ago(days: daysAgo)
            if i % 2 == 0 {
                entries.append(entry(daysAgo: daysAgo, exercises: [
                    workEx(ex("Barbell Bench Press"), weight: bw,  reps: [5,5,5,5], targetReps: 5, base: base),
                    workEx(ex("Overhead Press"),      weight: 52,  reps: [8,8,8],   targetReps: 8, base: base.addingTimeInterval(900)),
                    workEx(ex("Barbell Row"),          weight: 75,  reps: [8,8,8],   targetReps: 8, base: base.addingTimeInterval(1800)),
                ], minutes: 55, name: "Push / Pull"))
            } else {
                entries.append(entry(daysAgo: daysAgo, exercises: [
                    workEx(ex("Barbell Squat"), weight: sqW, reps: [5,5,5,5], targetReps: 5, base: base),
                    workEx(ex("Deadlift"),      weight: dlW, reps: [5,5,5],   targetReps: 5, base: base.addingTimeInterval(1200)),
                ], minutes: 45, name: "Legs"))
            }
        }
        // 1 comeback workout today — lighter weights after the break
        let comebackBase = Date.ago(days: 0)
        entries.append(entry(daysAgo: 0, exercises: [
            workEx(ex("Barbell Bench Press"), weight: 77.5, reps: [5,5,5,4], targetReps: 5, base: comebackBase),
            workEx(ex("Barbell Squat"),       weight: 90,   reps: [5,5,5,5], targetReps: 5, base: comebackBase.addingTimeInterval(900)),
            workEx(ex("Overhead Press"),      weight: 47.5, reps: [8,8,7],   targetReps: 8, base: comebackBase.addingTimeInterval(1800)),
        ], minutes: 50, name: "Back At It"))
        return entries
    }

    // MARK: 9 — Sporadic Lifter

    func sporadicScenario() -> [WorkoutLogEntry] {
        // Irregular days — some weeks 2-3 sessions, then 2-3 week gaps
        let daysAgo = [88, 85, 72, 69, 67, 52, 49, 35, 33, 30, 17, 15, 11, 8, 6, 4, 2, 1]
        return daysAgo.enumerated().map { i, d in
            let base = Date.ago(days: d)
            return entry(daysAgo: d, exercises: [
                workEx(ex("Barbell Bench Press"), weight: 70.0 + Double(i) * 0.5, reps: [5,5,5], targetReps: 5, base: base),
                workEx(ex("Barbell Squat"),       weight: 90.0 + Double(i) * 0.5, reps: [5,5,5], targetReps: 5, base: base.addingTimeInterval(900)),
            ], minutes: 40, name: "Workout")
        }
    }

    // MARK: 10 — Short Sessions Only

    func shortSessionsScenario() -> [WorkoutLogEntry] {
        return (0..<20).map { i in
            let daysAgo = (19 - i) * 4
            let base    = Date.ago(days: daysAgo)
            let prog    = Double(i) / 19.0
            return entry(daysAgo: daysAgo, exercises: [
                workEx(ex("Barbell Bench Press"), weight: 60.0 + prog * 10, reps: [5,5],    targetReps: 5, base: base),
                workEx(ex("Barbell Squat"),       weight: 80.0 + prog * 15, reps: [5,5],    targetReps: 5, base: base.addingTimeInterval(600)),
                workEx(ex("Deadlift"),            weight: 100.0 + prog * 20, reps: [3,3],   targetReps: 5, base: base.addingTimeInterval(1200)),
            ], minutes: 18, name: "Quick Session")
        }
    }

    // MARK: 11 — Marathon Sessions

    func marathonSessionsScenario() -> [WorkoutLogEntry] {
        return (0..<20).map { i in
            let daysAgo = (19 - i) * 4
            let base    = Date.ago(days: daysAgo)
            let prog    = Double(i) / 19.0
            return entry(daysAgo: daysAgo, exercises: [
                workEx(ex("Barbell Bench Press"),     weight: 80.0 + prog*10,  reps: [5,5,5,5,5],   targetReps: 5,  base: base),
                workEx(ex("Incline Barbell Press"),   weight: 65.0 + prog*8,   reps: [6,6,6,6],      targetReps: 6,  base: base.addingTimeInterval(1200)),
                workEx(ex("Overhead Press"),          weight: 50.0 + prog*7,   reps: [8,8,8,8],      targetReps: 8,  base: base.addingTimeInterval(2400)),
                workEx(ex("Barbell Row"),             weight: 75.0 + prog*10,  reps: [8,8,8,8],      targetReps: 8,  base: base.addingTimeInterval(3600)),
                workEx(ex("Lat Pulldown"),            weight: 65.0 + prog*8,   reps: [10,10,10,10],  targetReps: 10, base: base.addingTimeInterval(4800)),
                workEx(ex("Barbell Squat"),           weight: 100.0 + prog*15, reps: [5,5,5,5],      targetReps: 5,  base: base.addingTimeInterval(6000)),
                workEx(ex("Romanian Deadlift"),       weight: 90.0 + prog*12,  reps: [10,10,10],     targetReps: 10, base: base.addingTimeInterval(7200)),
                workEx(ex("Dumbbell Curl"),           weight: 18.0 + prog*3,   reps: [12,12,12],     targetReps: 12, base: base.addingTimeInterval(8100)),
                workEx(ex("Tricep Pushdown"),         weight: 40.0 + prog*5,   reps: [12,12,12],     targetReps: 12, base: base.addingTimeInterval(8700)),
                workEx(ex("Lateral Raise"),           weight: 12.0 + prog*2,   reps: [15,15,15],     targetReps: 15, base: base.addingTimeInterval(9300)),
            ], minutes: Int(95 + prog * 20), name: "Full Body Marathon")
        }
    }

    // MARK: 12 — Deload Week

    func deloadScenario() -> [WorkoutLogEntry] {
        var entries: [WorkoutLogEntry] = []
        // 20 normal sessions over 60 days
        for i in 0..<20 {
            let daysAgo = (19 - i) * 3 + 7
            let prog    = Double(i) / 19.0
            let bw      = 80.0 + prog * 10.0
            let sqW     = 100.0 + prog * 15.0
            let base    = Date.ago(days: daysAgo)
            if i % 2 == 0 {
                entries.append(entry(daysAgo: daysAgo, exercises: [
                    workEx(ex("Barbell Bench Press"), weight: bw,  reps: [5,5,5,5], targetReps: 5, base: base),
                    workEx(ex("Overhead Press"),      weight: 52,  reps: [8,8,8],   targetReps: 8, base: base.addingTimeInterval(900)),
                ], minutes: 55))
            } else {
                entries.append(entry(daysAgo: daysAgo, exercises: [
                    workEx(ex("Barbell Squat"), weight: sqW, reps: [5,5,5,5], targetReps: 5, base: base),
                    workEx(ex("Deadlift"),      weight: 140, reps: [5,5,5],   targetReps: 5, base: base.addingTimeInterval(1200)),
                ], minutes: 45))
            }
        }
        // Deload sessions: last 3 days at ~50% volume
        let deloadWeights: [(bench: Double, sq: Double)] = [(45, 55), (47.5, 57.5), (50, 60)]
        for (i, dw) in deloadWeights.enumerated() {
            let daysAgo = (2 - i)
            let base    = Date.ago(days: daysAgo)
            entries.append(entry(daysAgo: daysAgo, exercises: [
                workEx(ex("Barbell Bench Press"), weight: dw.bench, reps: [5,5,5], targetReps: 5, base: base),
                workEx(ex("Barbell Squat"),       weight: dw.sq,   reps: [5,5,5], targetReps: 5, base: base.addingTimeInterval(900)),
            ], minutes: 35, name: "Deload"))
        }
        return entries
    }

    // MARK: 13 — Plateau Zone

    func plateauScenario() -> [WorkoutLogEntry] {
        var entries: [WorkoutLogEntry] = []
        // 20 sessions with progression, then 8 sessions with no increase
        for i in 0..<28 {
            let daysAgo = (27 - i) * 3
            let isPlateauPhase = i >= 20
            let prog    = isPlateauPhase ? 1.0 : Double(i) / 19.0
            let bw      = 80.0 + prog * 10.0   // plateaus at 90 for last 8 sessions
            let sqW     = 100.0 + prog * 15.0  // plateaus at 115
            let base    = Date.ago(days: daysAgo)
            if i % 2 == 0 {
                entries.append(entry(daysAgo: daysAgo, exercises: [
                    workEx(ex("Barbell Bench Press"), weight: bw,  reps: [5,5,5,5], targetReps: 5, base: base),
                    workEx(ex("Overhead Press"),      weight: 55,  reps: [8,8,8],   targetReps: 8, base: base.addingTimeInterval(900)),
                ], minutes: 55))
            } else {
                entries.append(entry(daysAgo: daysAgo, exercises: [
                    workEx(ex("Barbell Squat"), weight: sqW, reps: [5,5,5,5], targetReps: 5, base: base),
                    workEx(ex("Deadlift"),      weight: 140, reps: [5,5,5],   targetReps: 5, base: base.addingTimeInterval(1200)),
                ], minutes: 45))
            }
        }
        return entries
    }

    // MARK: 14 — Bench Only

    func benchOnlyScenario() -> [WorkoutLogEntry] {
        return (0..<30).map { i in
            let daysAgo = (29 - i) * 3
            let prog    = Double(i) / 29.0
            let bw      = 60.0 + prog * 30.0   // 60→90 over 30 sessions
            let base    = Date.ago(days: daysAgo)
            return entry(daysAgo: daysAgo, exercises: [
                workEx(ex("Barbell Bench Press"), weight: bw, reps: [5,5,5,5,5], targetReps: 5, base: base),
            ], minutes: 25, name: "Bench Only")
        }
    }
}

// MARK: - Date Helper

private extension Date {
    static func ago(days: Int, offset: TimeInterval = 0) -> Date {
        Date().addingTimeInterval(-Double(days) * 86_400 + offset)
    }
}

#endif
