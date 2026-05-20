import SwiftUI

#if DEBUG

struct HONDebugView: View {
    @Environment(HONHabitEngine.self) private var engine
    @Environment(SeedStore.self) private var store
    @State private var previewMessage: HONPendingMessage? = nil

    var body: some View {
        List {
            systemStateSection
            patternSection
            messagesSection
            scenariosSection
            actionsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("HON Debug")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $previewMessage) { msg in
            HONMessagePreviewSheet(message: msg)
        }
    }

    // MARK: - Sections

    private var systemStateSection: some View {
        Section("System State") {
            row("Phase",              engine.userRecord.phase.displayName)
            row("User Type",          engine.userRecord.userType.displayName)
            row("Total Sessions",     "\(engine.userRecord.totalSessions)")
            row("Age (weeks)",        "\(engine.userRecord.ageWeeks)")
            row("Active Weeks",       "\(engine.userRecord.activeWeeks)")
            row("Consecutive Weeks",  "\(engine.userRecord.consecutiveActiveWeeks)")
            row("Pattern Confidence", String(format: "%.0f%%", engine.userRecord.patternConfidence * 100))
            row("Pending Messages",   "\(engine.userRecord.pendingMessages.filter { $0.deliveredAt == nil }.count) undelivered")
            if let lapse = engine.userRecord.lapseStart {
                row("Last Session", lapse.formatted(date: .abbreviated, time: .omitted))
            }
        }
    }

    private var patternSection: some View {
        Section("Day Pattern (8-week rolling)") {
            let probs = engine.userRecord.dayProbabilities
            if probs.isEmpty {
                Text("No data yet — log a few weeks of sessions").foregroundStyle(.secondary).font(.caption)
            } else {
                ForEach(probs, id: \.dayIndex) { dp in
                    HStack(spacing: 8) {
                        Text(dp.dayName)
                            .font(.caption.monospaced())
                            .frame(width: 30, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.secondary.opacity(0.15))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(dp.probability >= 0.5 ? HONTheme.accent : Color.secondary.opacity(0.4))
                                    .frame(width: max(0, geo.size.width * dp.probability))
                            }
                        }
                        .frame(height: 10)
                        Text(String(format: "%.0f%%", dp.probability * 100))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var messagesSection: some View {
        let all = engine.userRecord.pendingMessages
        return Section("Message Queue (\(all.count) total)") {
            if all.isEmpty {
                Text("No messages generated yet").foregroundStyle(.secondary).font(.caption)
            } else {
                ForEach(all) { msg in
                    Button { previewMessage = msg } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Image(systemName: msg.icon).foregroundStyle(HONTheme.accent)
                                Text(msg.kind.displayName).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                if msg.deliveredAt != nil {
                                    Text("✓ Delivered").font(.caption2).foregroundStyle(.secondary)
                                } else {
                                    Text("Pending").font(.caption2).foregroundStyle(HONTheme.accent)
                                }
                            }
                            Text(msg.message).font(.caption2).lineLimit(2).foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var scenariosSection: some View {
        Section("QA Scenarios") {
            scenarioButton("1 · Session 1 (new user)")          { simulateSessions(1, spanDays: 2) }
            scenarioButton("2 · Session 10 milestone")          { simulateSessions(10, spanDays: 30) }
            scenarioButton("3 · Session 25 milestone")          { simulateSessions(25, spanDays: 70) }
            scenarioButton("4 · Return after 14-day lapse")     { simulateLapse(daysGone: 14) }
            scenarioButton("5 · Return after 30-day lapse")     { simulateLapse(daysGone: 30) }
            scenarioButton("6 · Type A pattern (12wks MWF)")    { simulateTypeAPattern() }
            scenarioButton("7 · Ramp detection (3× usual)")     { simulateRamp() }
            scenarioButton("8 · Drift detection")               { simulateDrift() }
            scenarioButton("9 · 12 consecutive weeks")          { simulateConsecutiveWeeks(12) }
            scenarioButton("10 · Deload week")                  { simulateDeload() }
        }
        .foregroundStyle(HONTheme.accent)
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button("Run against real log") {
                if let entry = store.workoutLog.first {
                    engine.onSessionLogged(entry: entry, fullLog: store.workoutLog)
                }
            }
            Button("Check Drift / Deload") {
                engine.checkForDriftOrDeload()
            }
            Button("Show next in-app message") {
                previewMessage = engine.inAppMessage ?? engine.userRecord.pendingMessages.first(where: { $0.deliveredAt == nil })
            }
            Button("Dismiss in-app message") {
                engine.dismissInAppMessage()
            }
            Button("Reset engine", role: .destructive) {
                engine.resetForDebug()
            }
        }
    }

    // MARK: - Scenario Simulations

    private func simulateSessions(_ count: Int, spanDays: Int) {
        engine.resetForDebug()
        let log = fakeLog(count: count, spanDays: spanDays)
        engine.simulateLog(entries: log)
    }

    private func simulateLapse(daysGone: Int) {
        engine.resetForDebug()
        let cutoff = Date().addingTimeInterval(-Double(daysGone) * 86_400)
        var log = fakeLog(count: 15, spanDays: 90).filter { $0.startedAt < cutoff }
        log.append(fakeEntry(daysAgo: 0))
        engine.simulateLog(entries: log)
    }

    private func simulateTypeAPattern() {
        engine.resetForDebug()
        var log: [WorkoutLogEntry] = []
        for week in 0..<12 {
            for dayOffset in [0, 2, 4] {   // Mon, Wed, Fri
                let daysAgo = (11 - week) * 7 + (6 - dayOffset)
                log.append(fakeEntry(daysAgo: daysAgo))
            }
        }
        engine.simulateLog(entries: log)
    }

    private func simulateRamp() {
        engine.resetForDebug()
        var log = fakeLog(count: 20, spanDays: 60)
        for i in 0..<6 { log.append(fakeEntry(daysAgo: i)) }
        engine.simulateLog(entries: log)
    }

    private func simulateDrift() {
        engine.resetForDebug()
        let history = fakeLog(count: 25, spanDays: 90)
            .filter { $0.startedAt < Date().addingTimeInterval(-21 * 86_400) }
        let recent  = fakeLog(count: 1, spanDays: 14)
        engine.simulateLog(entries: history + recent)
    }

    private func simulateConsecutiveWeeks(_ n: Int) {
        engine.resetForDebug()
        let log = (0..<n).map { week -> WorkoutLogEntry in
            fakeEntry(daysAgo: (n - 1 - week) * 7 + 2)
        }
        engine.simulateLog(entries: log)
    }

    private func simulateDeload() {
        engine.resetForDebug()
        var log = fakeLog(count: 20, spanDays: 56)
        let deloadEntry = fakeEntry(daysAgo: 0, volumeKg: 200)  // light volume
        log.append(deloadEntry)
        engine.simulateLog(entries: log)
    }

    // MARK: - Fake Data Helpers

    private func fakeLog(count: Int, spanDays: Int) -> [WorkoutLogEntry] {
        let step = max(1, spanDays / max(count, 1))
        return (0..<count).map { i in fakeEntry(daysAgo: spanDays - i * step) }
    }

    private func fakeEntry(daysAgo: Int, volumeKg: Double = 2400) -> WorkoutLogEntry {
        let date = Date().addingTimeInterval(-Double(max(0, daysAgo)) * 86_400)
        var s1 = SetRecord(weight: volumeKg / 24, reps: 8)
        s1.isCompleted = true
        let s2 = s1; let s3 = s1
        let exercise = Exercise(
            id: UUID(), name: "Bench Press",
            bodyRegion: .chest, equipment: .barbell, isCompound: true,
            movementPattern: .horizontalPush
        )
        let workoutEx = WorkoutExercise(exercise: exercise, sets: [s1, s2, s3])
        return WorkoutLogEntry(
            startedAt: date, finishedAt: date.addingTimeInterval(3600),
            exercises: [workoutEx]
        )
    }

    // MARK: - Helpers

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label, value: value)
    }

    private func scenarioButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
    }
}

// MARK: - Message Preview Sheet

struct HONMessagePreviewSheet: View {
    let message: HONPendingMessage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: message.icon)
                .font(.system(size: 44))
                .foregroundStyle(HONTheme.accent)

            Text(message.message)
                .font(.custom("CormorantGaramond-Light", size: 22))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 4) {
                Text(message.kind.displayName.uppercased())
                    .font(.custom("DMSans-Medium", size: 10))
                    .kerning(0.8)
                    .foregroundStyle(.secondary)
                Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Button("Dismiss") { dismiss() }
                .buttonStyle(.bordered)
                .tint(HONTheme.accent)
        }
        .padding(32)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#endif
