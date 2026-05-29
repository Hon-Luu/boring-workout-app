import SwiftUI
import Charts

// MARK: - Exercise Insights Tab

struct ExerciseInsightsView: View {
    @Environment(SeedStore.self) private var store
    @State private var searchText = ""
    var goToSettings: (() -> Void)? = nil

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
                        Section {
                            NavigationLink {
                                ProgressView()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Full Analytics Dashboard")
                                            .font(.system(.body).weight(.semibold))
                                        Text("Heatmaps · INOL · archetype · emerging signals")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .listRowBackground(AppTheme.cardBG)
                        }

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
                                    bodyweightSet: store.userProfile.bodyWeightKg != nil,
                                    goToSettings: goToSettings
                                )
                                .accessibilityHint("Double-tap to view detailed analytics for this exercise")
                            }
                            .listRowBackground(AppTheme.cardBG)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(HONTheme.background)
                }
            }
            .navigationTitle("Insights")
            .searchable(text: $searchText, prompt: "Search exercises")
            .background(HONTheme.background.ignoresSafeArea())
        }
    }
}

// MARK: - List Row

private struct ExerciseInsightRow: View {
    let exercise: Exercise
    let sessionCount: Int
    let relStrength: RelativeStrengthPoint?
    var bodyweightSet: Bool = false
    var goToSettings: (() -> Void)? = nil

    private var showsBar: Bool { relStrength != nil || bodyweightSet || (!bodyweightSet && sessionCount >= 3) }

    private var accessibilityLabel: String {
        if let rs = relStrength {
            let tierLabel = rs.tier.rawValue
            let e1rmKg = Int(rs.e1RM.rounded())
            let implication: String
            switch rs.tier {
            case .beginner:     implication = "building foundational strength"
            case .intermediate: implication = "developing solid strength base"
            case .advanced:     implication = "strong relative to bodyweight"
            case .elite:        implication = "elite level strength"
            }
            return "\(exercise.name), Tier \(tierLabel), \(e1rmKg) kg estimated one rep max, \(implication)"
        }
        return "\(exercise.name), \(sessionCount) session\(sessionCount == 1 ? "" : "s"), strength tier not yet available"
    }

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
                ExerciseTierGoalBar(sessionCount: sessionCount, bodyWeightMissing: false, goToSettings: goToSettings)
            } else if sessionCount >= 3 {
                ExerciseTierGoalBar(sessionCount: sessionCount, bodyWeightMissing: true, goToSettings: goToSettings)
            }
        }
        .padding(.vertical, showsBar ? 6 : 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct ExerciseTierGoalBar: View {
    let sessionCount: Int
    var bodyWeightMissing: Bool = false
    var goToSettings: (() -> Void)? = nil
    private static let labels = ["BEG", "INT", "ADV", "ELITE"]

    private var progressMessage: String {
        if sessionCount == 1 {
            return "1 of 3 sessions logged — 2 more to unlock your strength tier"
        } else if sessionCount == 2 {
            return "2 of 3 sessions logged — 1 more session unlocks your tier"
        } else {
            return "\(sessionCount) of 3 sessions — unlock tier tomorrow"
        }
    }

    private var progressFraction: Double {
        min(Double(sessionCount) / 3.0, 1.0)
    }

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

            if sessionCount < 3 {
                VStack(alignment: .leading, spacing: 4) {
                    // Mini progress bar showing sessionCount/3
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.12))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(HONTheme.positive.opacity(0.7))
                                .frame(width: geo.size.width * progressFraction)
                        }
                    }
                    .frame(height: 3)

                    Text(progressMessage)
                        .font(.system(size: 8))
                        .foregroundStyle(HONTheme.positive.opacity(0.7))
                }
            } else if bodyWeightMissing {
                HStack(spacing: 4) {
                    Text("Set body weight in Settings → Profile to unlock your tier")
                        .font(.system(size: 8))
                        .foregroundStyle(HONTheme.accent.opacity(0.8))
                    if let go = goToSettings {
                        Button(action: go) {
                            Text("Go →")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(HONTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("Calculating your tier…")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.secondary.opacity(0.4))
            }
        }
    }
}

// MARK: - BEG / INT / ADV / ELITE bar

struct ExerciseTierBar: View {
    let relStrength: RelativeStrengthPoint
    var compact: Bool = false

    private static let tierLabels: [String] = ["BEG", "INT", "ADV", "ELITE"]
    private static let tierColors: [Color] = [
        HONTheme.tierBeginner, HONTheme.tierIntermediate,
        HONTheme.tierAdvanced,  HONTheme.tierElite
    ]

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

    private static let tierShortLabels: [String] = ["B", "I", "A", "E"]

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    let isFilled = i <= tierIndex
                    let isActive = i == tierIndex
                    ZStack {
                        RoundedRectangle(cornerRadius: isActive ? 3 : 2)
                            .fill(Self.tierColors[i].opacity(isFilled ? (isActive ? 0.85 : 0.35) : 0.08))
                        if isActive {
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(Self.tierColors[i].opacity(0.6), lineWidth: 1)
                        }
                        Text(Self.tierShortLabels[i])
                            .font(.system(size: compact ? 6 : 7, weight: .bold, design: .rounded))
                            .foregroundStyle(isFilled ? Self.tierColors[i] : Color.secondary.opacity(0.2))
                    }
                    .frame(maxWidth: .infinity, minHeight: compact ? 10 : 14)
                }
            }

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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let exercise: Exercise
    let relStrength: RelativeStrengthPoint?

    @AppStorage("insightLevel") private var insightLevel: String = "standard"

    @State private var selectedSession: WorkoutLogEntry? = nil
    @State private var e1rmMode: E1RMMode = .standard

    private var history: [(date: Date, sets: [SetRecord])] {
        (store.exerciseHistoryCache[exercise.id] ?? [])
            .sorted { $0.date < $1.date }
    }

    private var exerciseAnalytics: ExerciseAnalytics? {
        store.analyticsCache.exerciseAnalytics.first(where: { $0.id == exercise.id })
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
            let best = assisted
                ? (completed.min { $0.weight < $1.weight } ?? completed[0])
                : completed.max { SetRecord.e1RM(weight: $0.weight, reps: $0.reps) < SetRecord.e1RM(weight: $1.weight, reps: $1.reps) }!
            let vol = completed.reduce(0.0) {
                let load = assisted ? max(0, (bw ?? 0) - $1.weight) : $1.weight
                return $0 + load * Double($1.reps)
            }
            let entry = store.workoutLog.first {
                abs($0.startedAt.timeIntervalSince(session.date)) < 60
                    && $0.exercises.contains { $0.exercise.id == exercise.id }
            }
            let load = assisted ? max(0, (bw ?? 0) - best.weight) : best.weight
            return E1RMPoint(
                date: session.date, e1RM: SetRecord.e1RM(weight: load, reps: best.reps),
                bestWeight: best.weight, bestReps: best.reps,
                volume: vol, setCount: completed.count,
                entryId: entry?.id
            )
        }
    }

    private func nextTierInfo(for rs: RelativeStrengthPoint) -> (label: String, multiplier: Double)? {
        switch rs.tier {
        case .beginner:     return ("Intermediate", rs.thresholds.intermediate)
        case .intermediate: return ("Advanced", rs.thresholds.advanced)
        case .advanced:     return ("Elite", rs.thresholds.advanced * 1.33)
        case .elite:        return nil
        }
    }

    private var peakRetentionPct: Double? {
        guard let last = dataPoints.last,
              let best = dataPoints.map(\.e1RM).max(), best > 0 else { return nil }
        return last.e1RM / best * 100.0
    }

    // Per-exercise fiber load for latest session
    private struct FiberLoad {
        let rawFiberLoad: Double
        let normalizedPSI: Double?
        let activationWeight: Double
    }

    private var latestFiberLoad: FiberLoad? {
        guard let lastSession = history.last else { return nil }
        let completed = lastSession.sets.filter { $0.isCompleted && $0.reps > 0 && $0.weight > 0 }
        guard !completed.isEmpty else { return nil }
        let profile = StrengthScoreEngine.activationProfile(for: exercise)
        let actWeight = profile.reduce(0.0) { $0 + $1.pctMVC * $1.muscle.pcsa }
        let allSets: [SetRecord] = history.flatMap { $0.sets }
        let qualifiedSets = allSets.filter { $0.isCompleted && $0.weight > 0 && $0.reps >= 1 && $0.reps <= 20 }
        let e1RMValues: [Double] = qualifiedSets.map { SetRecord.e1RM(weight: $0.weight, reps: $0.reps) }
        let bestE1RM = e1RMValues.max() ?? 0
        guard bestE1RM > 0 else { return nil }
        let rawLoad = completed.reduce(0.0) { acc, set in
            let rel = min(set.weight / bestE1RM, 1.0)
            return acc + pow(rel, 1.8) * Double(set.reps) * actWeight
        }
        guard let bw = store.userProfile.bodyWeightKg, bw > 0 else {
            return FiberLoad(rawFiberLoad: rawLoad, normalizedPSI: nil, activationWeight: actWeight)
        }
        return FiberLoad(
            rawFiberLoad: rawLoad,
            normalizedPSI: rawLoad / pow(bw, 0.67),
            activationWeight: actWeight
        )
    }

    @ViewBuilder
    private var nextMilestoneCard: some View {
        if let rs = relStrength,
           rs.tier != .elite,
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

                if dataPoints.count >= 2 {
                    e1RMChart
                    volumeChart
                }

                if let ea = exerciseAnalytics {
                    analyticsSection(ea)
                }

                fiberLoadSection
                cssContext

                sessionLog
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .id(insightLevel)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
        .background(HONTheme.background.ignoresSafeArea())
        .sheet(item: $selectedSession) { entry in
            WorkoutDetailView(entry: entry)
        }
    }

    // MARK: Tier Header helpers

    private func nextTierName(_ tier: RelativeStrengthTier) -> String {
        switch tier {
        case .beginner:     return "Intermediate"
        case .intermediate: return "Advanced"
        case .advanced:     return "Elite"
        case .elite:        return ""
        }
    }

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
                VStack(alignment: .trailing, spacing: 2) {
                    Text(rs.tier.rawValue.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(HONTheme.tier(rs.tier))
                    if rs.tier != .elite {
                        Text("→ \(nextTierName(rs.tier))")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                }
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
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
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

    // MARK: e1RM Chart (with Standard / Fatigue-Adj toggle)

    private var e1RMChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Estimated 1-Rep Max")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                InfoButton(metric: .e1RM)
                Spacer()
                if exerciseAnalytics?.sessionsFatigue.isEmpty == false {
                    Picker("", selection: $e1rmMode) {
                        Text("Standard").tag(E1RMMode.standard)
                        Text("Fatigue-Adj").tag(E1RMMode.adjusted)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                    .scaleEffect(0.85, anchor: .trailing)
                }
            }
            .padding(.horizontal, 4)

            if e1rmMode == .adjusted, let ea = exerciseAnalytics, !ea.sessionsFatigue.isEmpty {
                fatigueAdjE1RMChart(ea: ea)
            } else {
                standardE1RMChart
            }
        }
        .padding(16)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var standardE1RMChart: some View {
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
                .foregroundStyle(HONTheme.accent.opacity(0.10))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis { dateAxis }
        .chartYAxis { kgAxis }
        .frame(height: 160)
    }

    @ViewBuilder
    private func fatigueAdjE1RMChart(ea: ExerciseAnalytics) -> some View {
        let standard  = ea.sessions
        let adjusted  = ea.sessionsFatigue
        let allVals   = standard.map(\.estimated1RM) + adjusted.map(\.estimated1RM)
        let yMin      = (allVals.min() ?? 0) * 0.92
        VStack(alignment: .leading, spacing: 0) {
            Chart {
                ForEach(standard) { pt in
                    LineMark(x: .value("Date", pt.date), y: .value("e1RM", pt.estimated1RM), series: .value("S", "Standard"))
                        .foregroundStyle(HONTheme.chartSlate.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(adjusted) { pt in
                    LineMark(x: .value("Date", pt.date), y: .value("e1RM", pt.estimated1RM), series: .value("S", "Fatigue-Adj"))
                        .foregroundStyle(HONTheme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("Date", pt.date),
                        yStart: .value("Base", yMin),
                        yEnd: .value("e1RM", pt.estimated1RM)
                    )
                    .foregroundStyle(HONTheme.accent.opacity(0.08))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartForegroundStyleScale([
                "Standard":    HONTheme.chartSlate.opacity(0.6),
                "Fatigue-Adj": HONTheme.accent
            ])
            .chartLegend(position: .topTrailing)
            .chartXAxis { dateAxis }
            .chartYAxis { kgAxis }
            .frame(height: 160)
            .overlay(alignment: .bottomLeading) {
                let slope = ea.slopePerWeekFatigue
                let label = slope >= 0
                    ? "+\(String(format: "%.1f", slope)) kg/wk (fresh capacity)"
                    : "\(String(format: "%.1f", slope)) kg/wk (fresh capacity)"
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(slope >= 0 ? HONTheme.positive : HONTheme.negative)
                    .padding(.bottom, 2)
            }

            Text("Shrinking gap between lines = improving inter-session recovery. Widening gap = accumulated fatigue.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary.opacity(0.6))
                .padding(.horizontal, 4)
                .padding(.top, 2)
        }
    }

    private var dateAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 4)) { val in
            if let date = val.as(Date.self) {
                AxisValueLabel {
                    Text(date, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 9))
                }
            }
        }
    }

    private var kgAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 4)) { val in
            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
            if let v = val.as(Double.self) {
                AxisValueLabel { Text("\(Int((v / 5.0).rounded() * 5.0))kg").font(.system(size: 9)) }
            }
        }
    }

    // MARK: Volume Chart

    private var volumeChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text(exercise.equipment == .dumbbell
                     ? "Tonnage per Session (kg·reps, per hand)"
                     : "Tonnage per Session (kg·reps)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                InfoButton(metric: .tonnage)
                Spacer()
            }
            .padding(.horizontal, 4)

            Chart {
                ForEach(dataPoints) { pt in
                    BarMark(
                        x: .value("Date", pt.date),
                        y: .value("Volume", pt.volume)
                    )
                    .foregroundStyle(HONTheme.accent)
                    .cornerRadius(3)
                }
            }
            .chartXAxis { dateAxis }
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
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Analytics Section — trend cards, one per metric

    @ViewBuilder
    private func analyticsSection(_ ea: ExerciseAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            metricTrendCard(
                title: "INOL",
                infoMetric: .inol,
                data: ea.inolHistory,
                dates: ea.sessions.map(\.date),
                current: ea.latestINOL,
                format: { String(format: "%.2f", $0) },
                zonePill: ea.latestINOL.map { INOLZone(inol: $0).rawValue },
                zoneColor: ea.latestINOL.map {
                    INOLZone(inol: $0) == .optimal ? HONTheme.positive
                        : INOLZone(inol: $0) == .overreaching ? HONTheme.negative
                        : HONTheme.accent
                },
                explanation: metricExplanation(.inol, value: ea.latestINOL, ea: ea)
            )

            metricTrendCard(
                title: "Efficiency",
                infoMetric: .efficiency,
                data: ea.efficiencyHistory,
                dates: Array(ea.sessions.map(\.date).dropFirst()),
                current: ea.efficiencyScore,
                format: { String(format: "%.1f", $0) },
                zonePill: ea.efficiencyLabel,
                zoneColor: ea.efficiencyLabel.map {
                    $0 == "Great" ? HONTheme.positive : $0 == "Below avg" ? HONTheme.negative : HONTheme.accent
                },
                explanation: metricExplanation(.efficiency, value: ea.efficiencyScore, ea: ea)
            )

            metricTrendCard(
                title: "Rep Decay",
                infoMetric: .repDecay,
                data: ea.repDecayHistory,
                dates: ea.sessions.map(\.date),
                current: ea.latestRepDecay,
                format: { String(format: "%.1f reps/set", $0) },
                zonePill: ea.latestRepDecay.map { abs($0) < 0.5 ? "Stable" : $0 < -2 ? "High decay" : "Moderate" },
                zoneColor: ea.latestRepDecay.map {
                    abs($0) < 0.5 ? HONTheme.positive : $0 < -2 ? HONTheme.negative : HONTheme.accent
                },
                explanation: metricExplanation(.repDecay, value: ea.latestRepDecay, ea: ea)
            )

            // RPE trend — only if data exists
            if ea.rpeHistory.contains(where: { $0 > 0 }) {
                let rpeData = ea.rpeHistory.enumerated().compactMap { ea.rpeHistory[$0.offset] > 0 ? $0.element : nil as Double? }
                let rpeDates = ea.sessions.enumerated().compactMap { ea.rpeHistory[$0.offset] > 0 ? $0.element.date : nil }
                let latestRPE = ea.rpeHistory.last(where: { $0 > 0 })
                metricTrendCard(
                    title: "Avg RPE",
                    infoMetric: .rpe,
                    data: rpeData,
                    dates: rpeDates,
                    current: latestRPE,
                    format: { String(format: "%.1f / 10", $0) },
                    zonePill: latestRPE.map { $0 >= 9 ? "Max effort" : $0 >= 7 ? "Hard" : "Moderate" },
                    zoneColor: latestRPE.map {
                        $0 >= 9 ? HONTheme.negative : $0 >= 7 ? HONTheme.accent : HONTheme.positive
                    },
                    explanation: metricExplanation(.rpe, value: latestRPE, ea: ea)
                )
            }

            metricTrendCard(
                title: "Session Cost",
                infoMetric: .sessionCost,
                data: ea.sessionCostHistory,
                dates: ea.sessions.map(\.date),
                current: ea.latestSessionCost,
                format: { String(format: "%.1f", $0) },
                zonePill: nil,
                zoneColor: nil,
                explanation: metricExplanation(.sessionCost, value: ea.latestSessionCost, ea: ea)
            )

            // Isolation note if applicable
            if exercise.movementPattern == .isolation {
                coachingNote(
                    icon: "info.circle",
                    color: .secondary,
                    text: "INOL zones are calibrated for compound movements. For isolation exercises, use as directional guidance only."
                )
            }

            // Plateau and feel coaching notes
            if ea.isPlateau {
                coachingNote(
                    icon: "tortoise.fill",
                    color: HONTheme.warning,
                    text: "Plateau detected. Consider varying rep ranges or increasing load."
                )
            }
            if let feel = ea.feelInsight {
                coachingNote(icon: "brain.head.profile", color: HONTheme.accent, text: feel)
            }
        }
    }

    // MARK: Metric Trend Card

    private func metricTrendCard(
        title: String,
        infoMetric: MetricInfo,
        data: [Double],
        dates: [Date],
        current: Double?,
        format: (Double) -> String,
        zonePill: String?,
        zoneColor: Color?,
        explanation: String
    ) -> some View {
        let pillColor = zoneColor ?? HONTheme.accent
        let currentLabel: String = current.map { format($0) } ?? "—"
        return VStack(alignment: .leading, spacing: 10) {
            // Header row — adaptive layout for large Dynamic Type sizes
            if dynamicTypeSize >= .accessibility3 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        InfoButton(metric: infoMetric)
                        Spacer()
                        if let zone = zonePill, let zColor = zoneColor {
                            Text(zone)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(zColor.opacity(0.15), in: Capsule())
                                .foregroundStyle(zColor)
                        }
                    }
                    Text(currentLabel)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(current != nil ? pillColor : .secondary)
                }
            } else {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    InfoButton(metric: infoMetric)
                    Spacer()
                    if let zone = zonePill, let zColor = zoneColor {
                        Text(zone)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(zColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(zColor)
                    }
                    if let current {
                        Text(format(current))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(zoneColor ?? .primary)
                    } else {
                        Text("—")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Mini line chart
            let pairedCount = min(dates.count, data.count)
            if pairedCount >= 2 {
                Chart {
                    ForEach(Array(zip(dates.prefix(pairedCount), data.prefix(pairedCount)).enumerated()), id: \.offset) { _, pair in
                        LineMark(
                            x: .value("Session", pair.0),
                            y: .value(title, pair.1)
                        )
                        .foregroundStyle(zoneColor ?? HONTheme.accent)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Session", pair.0),
                            yStart: .value("base", data.prefix(pairedCount).min() ?? 0),
                            yEnd: .value(title, pair.1)
                        )
                        .foregroundStyle((zoneColor ?? HONTheme.accent).opacity(0.08))
                        .interpolationMethod(.catmullRom)
                    }
                    if let lastDate = dates.prefix(pairedCount).last,
                       let lastVal = data.prefix(pairedCount).last {
                        PointMark(
                            x: .value("Session", lastDate),
                            y: .value(title, lastVal)
                        )
                        .foregroundStyle(zoneColor ?? HONTheme.accent)
                        .symbolSize(30)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 50)
            } else {
                let needed = max(0, 2 - pairedCount)
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.secondary.opacity(0.4))
                    Text("Log \(needed) more session\(needed == 1 ? "" : "s") to see trend")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .frame(height: 30)
            }

            // Explanation text
            Text(explanation)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Metric Explanation

    private enum MetricTrendType { case inol, efficiency, repDecay, rpe, sessionCost }

    private func metricExplanation(_ metric: MetricTrendType, value: Double?, ea: ExerciseAnalytics) -> String {
        switch metric {
        case .inol:
            guard let v = value else { return "INOL measures total training stress per session. More data needed for a trend." }
            switch INOLZone(inol: v) {
            case .insufficient:
                return "Your training stress is low (\(String(format: "%.2f", v))). Increasing sets or reps will drive more adaptation."
            case .moderate:
                return "Moderate training load (\(String(format: "%.2f", v))). You have room to increase volume without overdoing it."
            case .optimal:
                return "Optimal training stress (\(String(format: "%.2f", v))). This is the sweet spot for strength gains — maintain this range."
            case .heavy:
                return "High training load (\(String(format: "%.2f", v))). This is sustainable short-term. Plan a deload if sustained for 3+ weeks."
            case .overreaching:
                return "Overreaching zone (\(String(format: "%.2f", v))). Reduce volume before your next session to avoid accumulated fatigue."
            }
        case .efficiency:
            guard let v = value else { return "Efficiency compares your strength gain to the training cost. More data needed." }
            if let label = ea.efficiencyLabel {
                switch label {
                case "Great":
                    return "Your strength gain per unit of fatigue is excellent (\(String(format: "%.1f", v))). Your current approach is highly productive."
                case "Below avg":
                    return "Low efficiency (\(String(format: "%.1f", v))) — you're fatiguing faster than you're gaining strength. Try reducing volume and increasing intensity."
                default:
                    return "Average efficiency (\(String(format: "%.1f", v))). Small adjustments to intensity or rest periods could improve your output per session."
                }
            }
            return "Efficiency tracks your strength gain relative to session fatigue cost."
        case .repDecay:
            guard let v = value else { return "Rep decay tracks how your rep count changes across sets within a session. More data needed." }
            if abs(v) < 0.5 {
                return "Your rep output is stable across sets (decay: \(String(format: "%.1f", v)) reps/set). Good fatigue management — your rest periods are working."
            }
            if v < -2 {
                return "High rep decay (\(String(format: "%.1f", v)) reps/set). You're losing significant reps by your later sets. Consider more rest time or reducing initial set weight."
            }
            return "Moderate rep decay (\(String(format: "%.1f", v)) reps/set). Some fatigue accumulation is normal. Watch for worsening trends."
        case .rpe:
            guard let v = value else { return "RPE measures how hard each session feels. Log RPE per set to track effort trends." }
            if v >= 9 {
                return "You're training at near-maximal effort (RPE \(String(format: "%.1f", v))). This drives strength but requires adequate recovery. Ensure 48–72h before your next heavy session."
            }
            if v >= 7 {
                return "Working at high intensity (RPE \(String(format: "%.1f", v))). This is productive for hypertrophy and strength. Monitor for signs of accumulated fatigue."
            }
            return "Moderate effort (RPE \(String(format: "%.1f", v))). You have capacity to train harder if your goal is progressive overload."
        case .sessionCost:
            guard let v = value else { return "Session cost estimates the fatigue burden of each workout. More data needed." }
            let trend = ea.sessionCostHistory.count >= 2
                ? ea.sessionCostHistory.last! - ea.sessionCostHistory[ea.sessionCostHistory.count - 2]
                : 0.0
            if trend > 0 {
                return "Your session cost is rising (\(String(format: "%.1f", v))). You're accumulating more fatigue per session — ensure recovery before pushing harder."
            }
            if trend < 0 {
                return "Session cost is decreasing (\(String(format: "%.1f", v))). You're adapting — the same work is becoming less taxing. Good sign for progression."
            }
            return "Session cost (\(String(format: "%.1f", v))) measures the cumulative fatigue from this session. Track this alongside your readiness score."
        }
    }

    private func metricsGrid3(
        _ a: (label: String, value: String, unit: String?, color: Color),
        _ b: (label: String, value: String, unit: String?, color: Color),
        _ c: (label: String, value: String, unit: String?, color: Color)
    ) -> some View {
        HStack(spacing: 0) {
            metricCell(a.label, a.value, a.unit, a.color)
            Divider().frame(height: 40)
            metricCell(b.label, b.value, b.unit, b.color)
            Divider().frame(height: 40)
            metricCell(c.label, c.value, c.unit, c.color)
        }
    }

    private func metricCell(_ label: String, _ value: String, _ unit: String?, _ color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(color)
                if let u = unit {
                    Text(u)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func coachingNote(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Fiber Load (Lab) Section

    @ViewBuilder
    private var fiberLoadSection: some View {
        if let fl = latestFiberLoad {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(HONTheme.chartAmber)
                    Text("Fiber Load Index")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    InfoButton(metric: .fiberLoad)
                    Spacer()
                    Text("LAST SESSION")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.5))
                }

                metricsGrid3(
                    (
                        label: "Raw Fiber Load",
                        value: String(format: "%.1f", fl.rawFiberLoad),
                        unit: "a.u.",
                        color: HONTheme.chartAmber
                    ),
                    (
                        label: "Allometric PSI",
                        value: fl.normalizedPSI.map { String(format: "%.3f", $0) } ?? "—",
                        unit: fl.normalizedPSI != nil ? "/BW⁰·⁶⁷" : nil,
                        color: fl.normalizedPSI != nil ? HONTheme.accent : .secondary
                    ),
                    (
                        label: "Activation Wt.",
                        value: String(format: "%.0f", fl.activationWeight),
                        unit: "cm²",
                        color: HONTheme.chartLavender
                    )
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("How it's computed")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Raw Fiber Load = Σ (relativeIntensity¹·⁸ × reps × activationWeight), where activationWeight = Σ(EMG × PCSA) across muscles recruited. Allometric PSI normalizes by bodyweight⁰·⁶⁷ for cross-athlete comparison (Ward et al., 2009).")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.secondary.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(HONTheme.elevated.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))

                // Top recruited muscles
                let profile = StrengthScoreEngine.activationProfile(for: exercise)
                let topMuscles = profile.sorted { $0.pctMVC * $0.muscle.pcsa > $1.pctMVC * $1.muscle.pcsa }.prefix(4)
                if !topMuscles.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Primary Muscle Contributors")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            ForEach(Array(topMuscles.enumerated()), id: \.offset) { _, ma in
                                VStack(spacing: 2) {
                                    Text(ma.muscle.rawValue)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(HONTheme.chartLavender)
                                    Text(String(format: "%.0f%%", ma.pctMVC * 100))
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(HONTheme.elevated, in: RoundedRectangle(cornerRadius: 6))
                            }
                            Spacer()
                        }
                    }
                }

                // Coaching note based on fiber load level (F-20)
                coachingNote(
                    icon: "figure.strengthtraining.traditional",
                    color: HONTheme.accent,
                    text: fiberLoadActionText(psi: fl.normalizedPSI ?? 0)
                )
            }
            .padding(16)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        } else if exercise.equipment == .bodyweight {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 20))
                    .foregroundStyle(HONTheme.chartLavender)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fiber Load uses your bodyweight as resistance")
                        .font(.caption.bold())
                    Text("For bodyweight exercises like pull-ups and push-ups, your logged body weight is the effective load. Set your body weight in Settings → Profile to unlock fiber load calculations for these exercises.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: CSS Pillar Context

    @ViewBuilder
    private var cssContext: some View {
        let css = store.analyticsCache.compositeScore
        if css.overallScore == 0 || css.grade == "—" {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 11))
                        .foregroundStyle(HONTheme.accent)
                    Text("Composite Strength Score")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    InfoButton(metric: .css)
                }
                Text("CSS = Level (35%) + Momentum (40%) + Process (25%)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.5))
                Text("Complete 3+ sessions with consistent volume to unlock your Composite Strength Score.")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        } else if css.overallScore > 0 {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 11))
                        .foregroundStyle(HONTheme.accent)
                    Text("Composite Strength Score")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    InfoButton(metric: .css)
                    Spacer()
                    Text(String(format: "%.0f", css.overallScore))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(cssGradeColor(css.gradeColor))
                    Text(css.grade)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(cssGradeColor(css.gradeColor))
                }

                Text("CSS = Level (35%) + Momentum (40%) + Process (25%)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.5))

                // Three pillars
                HStack(spacing: 8) {
                    cssGauge(title: "Level", value: css.levelScore,
                             color: HONTheme.accent, icon: "chart.bar.fill",
                             subtitle: String(format: "%.0f%% of peak", css.peakRetentionPct))
                    cssGauge(title: "Momentum", value: css.momentumScore,
                             color: HONTheme.positive, icon: "bolt.fill",
                             subtitle: css.momentumScore >= 60 ? "Progressing" : css.momentumScore >= 40 ? "Steady" : "Slowing")
                    cssGauge(title: "Process", value: css.processScore,
                             color: HONTheme.chartLavender, icon: "gearshape.fill",
                             subtitle: processLabel(css))
                }

                // Sub-scores row
                if css.inolSubScore != nil || css.efficiencySubScore != nil || css.repDecaySubScore != nil {
                    Divider().background(Color.secondary.opacity(0.15))
                    HStack(spacing: 0) {
                        if let s = css.inolSubScore {
                            metricCell("INOL Sub",  String(format: "%.0f", s), nil, HONTheme.chartLavender)
                            Divider().frame(height: 32)
                        }
                        if let s = css.efficiencySubScore {
                            metricCell("Eff. Sub",  String(format: "%.0f", s), nil, HONTheme.positive)
                            Divider().frame(height: 32)
                        }
                        if let s = css.repDecaySubScore {
                            metricCell("Decay Sub", String(format: "%.0f", s), nil, HONTheme.chartSlate)
                        }
                    }
                }

                Text(css.insight)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("CSS reflects your overall training across all exercises. This exercise contributes to the Level pillar via its e1RM retention and to the Process pillar via INOL, efficiency, and rep decay scores.")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.secondary.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func cssGauge(title: String, value: Double, color: Color, icon: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: min(value / 100.0, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
            }
            .frame(width: 44, height: 44)
            Text(String(format: "%.0f", value))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(cssGaugePillarLabel(title))
                .font(.caption2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary.opacity(0.6))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.caption2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func cssGaugePillarLabel(_ title: String) -> String {
        switch title {
        case "Level":    return "accumulated strength"
        case "Momentum": return "recent trajectory"
        case "Process":  return "training quality"
        default:         return ""
        }
    }

    private func fiberLoadActionText(psi: Double) -> String {
        switch psi {
        case ..<100:
            return "Low fiber activation. Increase intensity or add sets to drive more muscle recruitment."
        case 100..<200:
            return "Good activation. You're effectively stimulating target muscles."
        case 200..<350:
            return "High fiber demand. Allow 48–72h before training this muscle group again."
        default:
            return "Very high load. Consider a lighter technique session before your next heavy day."
        }
    }

    private func cssGradeColor(_ gradeColor: String) -> Color {
        switch gradeColor {
        case "purple": return HONTheme.chartLavender
        case "green":  return HONTheme.positive
        case "blue":   return HONTheme.chartSlate
        case "yellow": return HONTheme.chartAmber
        case "orange": return HONTheme.warning
        case "red":    return HONTheme.negative
        default:       return .secondary
        }
    }

    private func processLabel(_ css: CompositeStrengthResult) -> String {
        guard let inol = css.inolSubScore else { return "Insufficient data" }
        if inol >= 70 { return "Optimal load" }
        if inol >= 50 { return "On track" }
        return "Needs work"
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
                            Text("e1RM \(Int((pt.e1RM / 5.0).rounded() * 5.0))kg")
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
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Hint helpers

    private func inolHint(_ zone: INOLZone) -> String {
        switch zone {
        case .insufficient: return "volume too low for stimulus"
        case .moderate:     return "light maintenance work"
        case .optimal:      return "ideal training stimulus"
        case .heavy:        return "high demand, manage recovery"
        case .overreaching: return "reduce volume or intensity"
        }
    }

    private func efficiencyHint(_ label: String) -> String {
        switch label {
        case "Great":     return "high strength gain relative to session cost"
        case "Below avg": return "increase load or reduce junk volume"
        default:          return "consistent with your typical stimulus"
        }
    }

    private func repDecayHint(_ decay: Double) -> String {
        if decay > -0.3 { return "Near-zero rep decay — the weight may be too light to drive adaptation." }
        if decay < -3.0 { return "Steep rep drop-off — extend rest intervals or reduce opening weight." }
        return "Moderate rep decay — healthy fatigue within a session."
    }
}
