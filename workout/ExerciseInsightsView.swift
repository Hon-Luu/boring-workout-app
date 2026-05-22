import SwiftUI
import Charts

// MARK: - Exercise Insights Tab

struct ExerciseInsightsView: View {
    @Environment(SeedStore.self) private var store
    @State private var searchText = ""

    private var allExercisesWithHistory: [(exercise: Exercise, sessionCount: Int)] {
        var seen = Set<UUID>()
        var result: [(Exercise, Int)] = []
        for entry in store.workoutLog {
            for we in entry.exercises {
                if seen.insert(we.exercise.id).inserted {
                    let count = store.exerciseHistoryCache[we.exercise.id]?.count ?? 1
                    result.append((we.exercise, count))
                }
            }
        }
        return result.sorted { $0.0.name < $1.0.name }
    }

    private var filtered: [(exercise: Exercise, sessionCount: Int)] {
        guard !searchText.isEmpty else { return allExercisesWithHistory }
        return allExercisesWithHistory.filter {
            $0.exercise.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var relStrengthMap: [UUID: RelativeStrengthPoint] {
        var map: [UUID: RelativeStrengthPoint] = [:]
        for rsp in store.analyticsCache.strengthScore.relativeStrengths {
            map[rsp.exercise.id] = rsp
        }
        return map
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.workoutLog.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "dumbbell",
                        description: Text("Complete a workout to see your exercise insights.")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(filtered, id: \.exercise.id) { item in
                            NavigationLink {
                                ExerciseInsightDetailView(
                                    exercise: item.exercise,
                                    relStrength: relStrengthMap[item.exercise.id]
                                )
                            } label: {
                                ExerciseInsightRow(
                                    exercise: item.exercise,
                                    sessionCount: item.sessionCount,
                                    relStrength: relStrengthMap[item.exercise.id],
                                    bodyweightSet: store.userProfile.bodyWeightKg != nil
                                )
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Insights")
            .searchable(text: $searchText, prompt: "Search exercises")
        }
    }
}

// MARK: - List Row

private struct ExerciseInsightRow: View {
    let exercise: Exercise
    let sessionCount: Int
    let relStrength: RelativeStrengthPoint?
    var bodyweightSet: Bool = false

    private var showsBar: Bool { relStrength != nil || bodyweightSet }

    var body: some View {
        VStack(alignment: .leading, spacing: showsBar ? 10 : 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name)
                    .font(.system(.body).weight(.medium))
                Spacer(minLength: 12)
                Text("\(sessionCount) session\(sessionCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let rs = relStrength {
                ExerciseTierBar(relStrength: rs, compact: true)
            } else if bodyweightSet {
                ExerciseTierGoalBar()
            }
        }
        .padding(.vertical, showsBar ? 6 : 2)
    }
}

private struct ExerciseTierGoalBar: View {
    private static let labels = ["BEG", "INT", "ADV", "ELITE"]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.08))
                        .frame(height: 4)
                }
            }
            HStack(spacing: 0) {
                ForEach(Array(Self.labels.enumerated()), id: \.offset) { i, label in
                    Text(label)
                        .font(.system(size: 8, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                        .frame(maxWidth: .infinity,
                               alignment: i == 0 ? .leading : i == 3 ? .trailing : .center)
                }
            }
            Text("Log more sessions to unlock tier")
                .font(.system(size: 8))
                .foregroundStyle(Color.secondary.opacity(0.4))
        }
    }
}

// MARK: - BEG / INT / ADV / ELITE bar
// Equal-zone layout: each tier occupies 25% of the bar width.
// Progress within each tier is linear within its zone, so the fill
// never visually spills into the next zone.

struct ExerciseTierBar: View {
    let relStrength: RelativeStrengthPoint
    var compact: Bool = false

    private static let tierLabels: [String] = ["BEG", "INT", "ADV", "ELITE"]
    private static let tierColors: [Color] = [
        HONTheme.tierBeginner, HONTheme.tierIntermediate,
        HONTheme.tierAdvanced,  HONTheme.tierElite
    ]

    // Maps to 0.0–1.0 with EQUAL zones: Beg 0–0.25, Int 0.25–0.5, Adv 0.5–0.75, Elite 0.75–1.0
    private var progress: Double {
        let rs = relStrength.relativeStrength
        let t  = relStrength.thresholds
        switch relStrength.tier {
        case .beginner:
            let frac = rs / max(t.beginner, 0.001)
            return 0.25 * min(max(frac, 0.02), 1.0)
        case .intermediate:
            let frac = (rs - t.beginner) / max(t.intermediate - t.beginner, 0.001)
            return 0.25 + 0.25 * min(max(frac, 0), 1.0)
        case .advanced:
            let frac = (rs - t.intermediate) / max(t.advanced - t.intermediate, 0.001)
            return 0.50 + 0.25 * min(max(frac, 0), 1.0)
        case .elite:
            let frac = (rs - t.advanced) / max(t.advanced * 0.3, 0.001)
            return 0.75 + 0.25 * min(max(frac, 0), 1.0)
        }
    }

    private var tierIndex: Int {
        switch relStrength.tier {
        case .beginner: return 0; case .intermediate: return 1
        case .advanced: return 2; case .elite:        return 3
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 4 equal background segments
                    HStack(spacing: 2) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Self.tierColors[i].opacity(i == tierIndex ? 0.18 : 0.08))
                        }
                    }
                    // Filled portion — capped within the current tier's zone
                    RoundedRectangle(cornerRadius: 2)
                        .fill(HONTheme.tier(relStrength.tier))
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: compact ? 4 : 6)

            // Tier labels — only the current tier is colored
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    Text(Self.tierLabels[i])
                        .font(.system(size: 8, weight: i == tierIndex ? .bold : .regular, design: .rounded))
                        .foregroundStyle(
                            i == tierIndex
                                ? Self.tierColors[i]
                                : Color.secondary.opacity(0.35)
                        )
                        .frame(maxWidth: .infinity,
                               alignment: i == 0 ? .leading : i == 3 ? .trailing : .center)
                }
            }

            if !compact {
                // Ratio — helps the user sanity-check the calculation
                Text(String(format: "%.2f× BW", relStrength.relativeStrength))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Detail View

struct ExerciseInsightDetailView: View {
    @Environment(SeedStore.self) private var store
    let exercise: Exercise
    let relStrength: RelativeStrengthPoint?

    @State private var selectedSession: WorkoutLogEntry? = nil

    // Derived from store on each access
    private var history: [(date: Date, sets: [SetRecord])] {
        (store.exerciseHistoryCache[exercise.id] ?? [])
            .sorted { $0.date < $1.date }
    }

    private struct E1RMPoint: Identifiable {
        let id = UUID()
        let date: Date
        let e1RM: Double
        let bestWeight: Double
        let bestReps: Int
        let volume: Double
        let setCount: Int
        let entryId: UUID?
    }

    private var dataPoints: [E1RMPoint] {
        let bw = store.userProfile.bodyWeightKg
        let assisted = exercise.isAssistedCounterweight
        return history.compactMap { session in
            let completed = session.sets.filter { $0.isCompleted && $0.weight > 0 && $0.reps > 0 }
            guard !completed.isEmpty else { return nil }
            // For assisted machines pick the set with the lowest assist (hardest = best effective load).
            let best = assisted
                ? (completed.min { $0.weight < $1.weight } ?? completed[0])
                : completed.max { epley($0, bw: bw, assisted: false) < epley($1, bw: bw, assisted: false) }!
            let vol = completed.reduce(0.0) {
                let load = assisted ? max(0, (bw ?? 0) - $1.weight) : $1.weight
                return $0 + load * Double($1.reps)
            }
            let entry = store.workoutLog.first {
                abs($0.startedAt.timeIntervalSince(session.date)) < 60
                    && $0.exercises.contains { $0.exercise.id == exercise.id }
            }
            return E1RMPoint(
                date: session.date, e1RM: epley(best, bw: bw, assisted: assisted),
                bestWeight: best.weight, bestReps: best.reps,
                volume: vol, setCount: completed.count,
                entryId: entry?.id
            )
        }
    }

    private func epley(_ s: SetRecord, bw: Double?, assisted: Bool) -> Double {
        let load = assisted ? max(0, (bw ?? 0) - s.weight) : s.weight
        return s.reps == 1 ? load : load * (1 + Double(s.reps) / 30.0)
    }

    private func nextTierInfo(for rs: RelativeStrengthPoint) -> (label: String, multiplier: Double)? {
        switch rs.tier {
        case .beginner:     return ("Intermediate", rs.thresholds.intermediate)
        case .intermediate: return ("Advanced", rs.thresholds.advanced)
        case .advanced:     return ("Elite", rs.thresholds.advanced * 1.33)
        case .elite:        return nil
        }
    }

    @ViewBuilder
    private var nextMilestoneCard: some View {
        if let rs = relStrength,
           dataPoints.count == 1,
           let bw = store.userProfile.bodyWeightKg,
           let info = nextTierInfo(for: rs) {
            let targetKg = info.multiplier * bw
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(HONTheme.accent)
                    Text("Next Milestone")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                Text("Lift \(targetKg.weightFormatted) kg to reach \(info.label)")
                    .font(.subheadline.bold())
                Text(String(format: "That's %.2f× BW. Log more sessions to track your progress toward this goal.", info.multiplier))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(HONTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let rs = relStrength {
                    tierHeader(rs)
                } else {
                    bodyweightPrompt
                }

                nextMilestoneCard

                if dataPoints.count >= 2 {
                    e1RMChart
                    volumeChart
                }

                if let ea = store.analyticsCache.exerciseAnalytics.first(where: { $0.id == exercise.id }) {
                    analyticsSection(ea)
                }

                sessionLog
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
        .background(HONTheme.background.ignoresSafeArea())
        .sheet(item: $selectedSession) { entry in
            WorkoutDetailView(entry: entry)
        }
    }

    // MARK: Tier Header

    private func tierHeader(_ rs: RelativeStrengthPoint) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Relative Strength")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.2f×", rs.relativeStrength))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(HONTheme.tier(rs.tier))
                        Text("bodyweight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(rs.tier.rawValue.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(HONTheme.tier(rs.tier))
            }
            ExerciseTierBar(relStrength: rs, compact: false)
                .padding(.top, 2)

            if let bw = store.userProfile.bodyWeightKg {
                Text("Based on \(bw.weightFormatted) kg bodyweight")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    private var bodyweightPrompt: some View {
        HStack(spacing: 12) {
            Image(systemName: "scalemass")
                .font(.system(size: 22))
                .foregroundStyle(HONTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Set your bodyweight")
                    .font(.subheadline.bold())
                Text("Strength tier (BEG / INT / ADV / ELITE) requires your bodyweight. Add it in Settings → Profile.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(HONTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: e1RM Chart

    private var e1RMChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Estimated 1-Rep Max")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Chart {
                ForEach(dataPoints) { pt in
                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value("e1RM", pt.e1RM)
                    )
                    .foregroundStyle(HONTheme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", pt.date),
                        yStart: .value("Base", (dataPoints.map(\.e1RM).min() ?? 0) * 0.92),
                        yEnd: .value("e1RM", pt.e1RM)
                    )
                    .foregroundStyle(HONTheme.accent.opacity(0.1))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { val in
                    if let date = val.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(.system(size: 9))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { val in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                    if let v = val.as(Double.self) {
                        AxisValueLabel {
                            Text("\(Int(v))kg").font(.system(size: 9))
                        }
                    }
                }
            }
            .frame(height: 160)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Volume Chart

    private var volumeChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercise.equipment == .dumbbell ? "Volume per Session (kg per hand)" : "Volume per Session (kg)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Chart {
                ForEach(dataPoints) { pt in
                    BarMark(
                        x: .value("Date", pt.date),
                        y: .value("Volume", pt.volume)
                    )
                    .foregroundStyle(HONTheme.accent.opacity(0.65))
                    .cornerRadius(3)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { val in
                    if let date = val.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(.system(size: 9))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { val in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                    if let v = val.as(Double.self) {
                        AxisValueLabel { Text("\(Int(v))kg").font(.system(size: 9)) }
                    }
                }
            }
            .frame(height: 100)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Analytics

    private func analyticsSection(_ ea: ExerciseAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Metrics")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                metricCell(
                    label: "Trend",
                    value: ea.slopePerWeek >= 0
                        ? "+\(String(format: "%.1f", ea.slopePerWeek))kg/wk"
                        : "\(String(format: "%.1f", ea.slopePerWeek))kg/wk",
                    color: ea.slopePerWeek >= 0 ? HONTheme.positive : HONTheme.negative
                )
                Divider().frame(height: 36)
                if let inol = ea.latestINOL {
                    metricCell(label: "INOL", value: String(format: "%.2f", inol),
                               color: INOLZone(inol: inol) == .optimal ? HONTheme.positive : .primary)
                    Divider().frame(height: 36)
                }
                metricCell(label: "Sessions", value: "\(ea.sessions.count)", color: .primary)
            }

            if let inol = ea.latestINOL {
                let zone = INOLZone(inol: inol)
                HStack(spacing: 6) {
                    Image(systemName: zone == .optimal ? "checkmark.circle.fill" : "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(zone == .optimal ? HONTheme.positive : HONTheme.accent)
                    Text("INOL \(zone.rawValue.lowercased()) — \(inolHint(zone))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            if ea.isPlateau {
                HStack(spacing: 6) {
                    Image(systemName: "tortoise.fill").font(.system(size: 12))
                        .foregroundStyle(HONTheme.warning)
                    Text("Plateau detected. Consider varying rep ranges or increasing load.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            if let feel = ea.feelInsight {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "brain.head.profile").font(.system(size: 12))
                        .foregroundStyle(HONTheme.accent)
                    Text(feel).font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    private func metricCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(.subheadline, design: .rounded).bold()).foregroundStyle(color)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func inolHint(_ zone: INOLZone) -> String {
        switch zone {
        case .insufficient: return "volume too low for stimulus"
        case .moderate:     return "light maintenance work"
        case .optimal:      return "ideal training stimulus"
        case .heavy:        return "high demand, manage recovery"
        case .overreaching: return "reduce volume or intensity"
        }
    }

    // MARK: Session Log (tappable)

    private var sessionLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session History")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(Array(dataPoints.reversed().enumerated()), id: \.element.id) { idx, pt in
                Button {
                    if let eid = pt.entryId,
                       let entry = store.workoutLog.first(where: { $0.id == eid }) {
                        selectedSession = entry
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pt.date, format: .dateTime.month(.abbreviated).day().year())
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("\(pt.setCount) set\(pt.setCount == 1 ? "" : "s") · \(Int(pt.volume))kg\(exercise.equipment == .dumbbell ? " per hand" : "") total")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(pt.bestWeight.weightFormatted) × \(pt.bestReps)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("e1RM \(Int(pt.e1RM))kg")
                                .font(.caption).foregroundStyle(HONTheme.accent)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if idx < dataPoints.count - 1 {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}
