import SwiftUI
import Charts

// MARK: - Hero Card Detail Sheet

struct HeroCardDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let composite:         CompositeStrengthResult
    let strengthScore:     CompositeStrengthScore?
    let relativeStrengths: [RelativeStrengthPoint]
    let log:               [WorkoutLogEntry]
    var exerciseAnalytics: [ExerciseAnalytics] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroHeader
                    scoreTrendSection
                    pillarsSection
                    if !relativeStrengths.isEmpty { liftsSection }
                    coverageSection
                    methodologyNote
                }
                .padding(.bottom, 32)
            }
            .background(HONTheme.background)
            .navigationTitle("Strength Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(HONTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var heroHeader: some View {
        VStack(spacing: 20) {
            // Large gauge
            ScoreGauge(score: composite.overallScore, grade: "")
                .frame(width: 160, height: 160)
                .padding(.top, 24)

            VStack(spacing: 6) {
                if let ss = strengthScore {
                    Text(ss.tier.rawValue.uppercased())
                        .font(.custom("CormorantGaramond-Light", size: 34))
                        .foregroundStyle(tierColor(ss.tier))
                    if log.count > 0 && log.count < 10 {
                        Text("Building baseline · \(10 - log.count) sessions to full analysis")
                            .font(.custom("DMSans-Regular", size: 11))
                            .foregroundStyle(HONTheme.textSecondary.opacity(0.5))
                    }
                } else {
                    Text("CALIBRATING")
                        .font(.custom("CormorantGaramond-Light", size: 28))
                        .foregroundStyle(HONTheme.textSecondary)
                    Text("Add body weight in Settings to unlock your tier.")
                        .font(.custom("DMSans-Regular", size: 11))
                        .foregroundStyle(HONTheme.textSecondary.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }

                HStack(spacing: 6) {
                    Text("\(Int(composite.overallScore.rounded()))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(HONTheme.textPrimary)
                    Text("/ 100")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(HONTheme.textSecondary)
                        .padding(.top, 14)
                }
            }

            // Full insight
            Text(composite.insight)
                .font(.custom("CormorantGaramond-LightItalic", size: 17))
                .foregroundStyle(HONTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 28)

            // Stat strip
            HStack(spacing: 0) {
                statChip("\(log.count)", "Sessions")
                Divider().frame(height: 28)
                statChip(thisWeekLabel, "This Week")
                Divider().frame(height: 28)
                statChip(weekDeltaLabel, "WoW Trend")
            }
            .padding(.vertical, 14)
            .background(HONTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Score Trend Chart

    private var scoreTrendSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("SCORE HISTORY")

            Group {
                if composite.history.count >= 2 {
                    scoreTrendChart
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                } else {
                    ghostScoreTrendCard
                }
            }
        }
    }

    private var ghostScoreTrendCard: some View {
        Group {
            if let first = composite.history.first {
                // One data point — show it as a named anchor
                HStack(alignment: .center, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SESSION 1")
                            .font(.custom("DMSans-Medium", size: 10))
                            .kerning(1)
                            .foregroundStyle(HONTheme.accent.opacity(0.7))
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(first.score.rounded()))")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(HONTheme.accent)
                            Text("/ 100")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(HONTheme.textSecondary)
                                .padding(.top, 10)
                        }
                        Text("Your starting point. Log another session to see your trend.")
                            .font(.custom("DMSans-Regular", size: 11))
                            .foregroundStyle(HONTheme.textSecondary.opacity(0.5))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 44))
                        .foregroundStyle(HONTheme.accent.opacity(0.1))
                }
                .padding(16)
                .background(HONTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else {
                // No sessions yet
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 20))
                        .foregroundStyle(HONTheme.textSecondary.opacity(0.25))
                    Text("Your score trend appears after your first session.")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(HONTheme.textSecondary.opacity(0.4))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private var scoreTrendChart: some View {
        let history = composite.history
        let scores  = history.map(\.score)
        let lo = max(0,   (scores.min() ?? 0) - 8)
        let hi = min(100, (scores.max() ?? 100) + 8)

        return VStack(alignment: .leading, spacing: 10) {
            Chart {
                ForEach(history) { pt in
                    AreaMark(
                        x: .value("Date", pt.date),
                        y: .value("Score", pt.score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [HONTheme.accent.opacity(0.18), HONTheme.accent.opacity(0.0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value("Score", pt.score)
                    )
                    .foregroundStyle(HONTheme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }

                if let last = history.last {
                    PointMark(
                        x: .value("Date", last.date),
                        y: .value("Score", last.score)
                    )
                    .foregroundStyle(HONTheme.accent)
                    .symbolSize(36)
                }
            }
            .chartYScale(domain: lo...hi)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 1)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(HONTheme.textSecondary.opacity(0.15))
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(HONTheme.textSecondary.opacity(0.5))
                        .font(.custom("DMSans-Regular", size: 9))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [Int(lo), 50, Int(hi)]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(HONTheme.textSecondary.opacity(0.15))
                    AxisValueLabel()
                        .foregroundStyle(HONTheme.textSecondary.opacity(0.5))
                        .font(.custom("DMSans-Regular", size: 9))
                }
            }
            .frame(height: 130)
            .padding(14)
            .background(HONTheme.surface, in: RoundedRectangle(cornerRadius: 14))

            // Delta annotations
            if let last = history.last {
                VStack(alignment: .leading, spacing: 4) {
                    if let first = history.first, history.count >= 2 {
                        let delta = last.score - first.score
                        let sign  = delta >= 0 ? "+" : ""
                        HStack(spacing: 4) {
                            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(delta >= 0 ? HONTheme.positive : HONTheme.negative)
                            Text("\(sign)\(String(format: "%.0f", delta)) pts since first session")
                                .font(.custom("DMSans-Regular", size: 11))
                                .foregroundStyle(HONTheme.textSecondary.opacity(0.6))
                        }
                    }
                    if let wowDelta = weeklyScoreDelta {
                        let sign = wowDelta >= 0 ? "+" : ""
                        HStack(spacing: 4) {
                            Image(systemName: wowDelta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(wowDelta >= 0 ? HONTheme.positive : HONTheme.negative)
                            Text("\(sign)\(String(format: "%.0f", wowDelta)) pts this week vs last week")
                                .font(.custom("DMSans-Regular", size: 11))
                                .foregroundStyle(HONTheme.textSecondary.opacity(0.6))
                        }
                    }
                }
                .padding(.leading, 2)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Three Pillars

    private var pillarsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("HOW YOUR SCORE IS BUILT")

            VStack(spacing: 12) {
                pillarCard(
                    name: "Level",
                    weight: "35%",
                    score: composite.levelScore,
                    color: HONTheme.chartSlate,
                    description: "How close your current lifts are to your personal best, weighted by muscle activation load.",
                    subScores: [
                        ("Peak Retention", composite.peakRetentionPct.isNaN ? nil : composite.peakRetentionPct, "%"),
                        ("Strength Load", composite.psiLevelScore, "/100"),
                    ],
                    proofRows: levelProofRows
                )

                pillarCard(
                    name: "Momentum",
                    weight: "40%",
                    score: composite.momentumScore,
                    color: HONTheme.chartSage,
                    description: "Rate of e1RM improvement per week, session-weighted across all tracked exercises.",
                    subScores: [],
                    proofRows: momentumProofRows
                )

                pillarCard(
                    name: "Process",
                    weight: "25%",
                    score: composite.processScore,
                    color: HONTheme.chartLavender,
                    description: "Training quality: how close to failure you work, your rep efficiency, and fatigue management.",
                    subScores: [
                        ("Training Load",  composite.inolSubScore,       "/100"),
                        ("Rep Efficiency", composite.efficiencySubScore, "/100"),
                        ("Fatigue Mgmt",   composite.repDecaySubScore,   "/100"),
                    ],
                    proofRows: processProofRows
                )
            }
            .padding(.horizontal, 20)
        }
    }

    private func pillarCard(
        name: String,
        weight: String,
        score: Double,
        color: Color,
        description: String,
        subScores: [(label: String, value: Double?, unit: String)],
        proofRows: [(label: String, detail: String, isPositive: Bool?)] = []
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Name + weight + score
            HStack(alignment: .firstTextBaseline) {
                Text(name)
                    .font(.custom("DMSans-SemiBold", size: 14))
                    .foregroundStyle(HONTheme.textPrimary)
                Text(weight)
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(HONTheme.textSecondary.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(HONTheme.textSecondary.opacity(0.1), in: Capsule())
                Spacer()
                Text("\(Int(score.rounded()))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text("/ 100")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(HONTheme.textSecondary)
                    .padding(.top, 5)
            }

            // Progress bar
            PillarBar(value: score / 100, color: color)

            // Description
            Text(description)
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundStyle(HONTheme.textSecondary.opacity(0.7))
                .lineSpacing(2)

            // Sub-scores
            if !subScores.isEmpty {
                let available = subScores.filter { $0.value != nil }
                if !available.isEmpty {
                    Divider().opacity(0.3)
                    HStack(spacing: 16) {
                        ForEach(available, id: \.label) { sub in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.label)
                                    .font(.custom("DMSans-Regular", size: 10))
                                    .foregroundStyle(HONTheme.textSecondary.opacity(0.6))
                                    .kerning(0.3)
                                Text(subValueText(sub.value!, unit: sub.unit))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(HONTheme.textPrimary)
                            }
                            if sub.label != available.last?.label {
                                Spacer()
                            }
                        }
                    }
                }
            }

            // Proof rows — per-exercise data showing WHY the score is what it is
            if !proofRows.isEmpty {
                Divider().opacity(0.3)
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(proofRows, id: \.label) { row in
                        HStack(spacing: 6) {
                            if let pos = row.isPositive {
                                Image(systemName: pos ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(pos ? HONTheme.positive : HONTheme.negative)
                                    .frame(width: 14)
                            } else {
                                Image(systemName: "minus")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(HONTheme.textSecondary.opacity(0.4))
                                    .frame(width: 14)
                            }
                            Text(row.label)
                                .font(.custom("DMSans-Regular", size: 11))
                                .foregroundStyle(HONTheme.textSecondary.opacity(0.7))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(row.detail)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(
                                    row.isPositive == nil ? HONTheme.textSecondary.opacity(0.7)
                                    : (row.isPositive! ? HONTheme.positive : HONTheme.negative)
                                )
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(HONTheme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Per-Lift

    private var liftsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("YOUR LIFTS")

            VStack(spacing: 10) {
                ForEach(relativeStrengths) { rp in
                    let pct = percentile(for: rp)
                    liftRow(rp: rp, percentile: pct)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func liftRow(rp: RelativeStrengthPoint, percentile: Double) -> some View {
        let tc = relTierColor(rp.tier)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(rp.exercise.name)
                    .font(.custom("DMSans-SemiBold", size: 14))
                    .foregroundStyle(HONTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "%.2f× BW", rp.relativeStrength))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(HONTheme.textSecondary)
            }

            HStack(spacing: 10) {
                // Percentile bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        LinearGradient(
                            colors: [HONTheme.tierBeginner, HONTheme.tierIntermediate,
                                     HONTheme.tierAdvanced, HONTheme.tierElite],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .opacity(0.2)
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                        Rectangle()
                            .fill(tc)
                            .frame(width: max(3, geo.size.width * CGFloat(percentile / 100)), height: 6)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .frame(height: 6)

                Text("\(Int(percentile))th")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(tc)
                    .frame(width: 38, alignment: .trailing)

                Text(rp.tier.rawValue)
                    .font(.custom("DMSans-Medium", size: 10))
                    .foregroundStyle(tc)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(tc.opacity(0.15), in: Capsule())
            }
        }
        .padding(14)
        .background(HONTheme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - PPL Coverage

    private var coverageSection: some View {
        guard let ss = strengthScore else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("CATEGORY COVERAGE")

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        ForEach(PPLCategory.allCases, id: \.self) { cat in
                            let covered = ss.coveredCategories.contains(cat)
                            let catScore = ss.pplScores[cat]
                            coveragePill(cat: cat, covered: covered, score: catScore)
                        }
                    }

                    if ss.isCoverageGated {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(HONTheme.warning)
                                .padding(.top, 1)
                            Text("Your tier is capped because you haven't logged \(ss.missingCategories.map(\.rawValue).joined(separator: " and ")) data. Add compound lifts in those categories to unlock a higher tier.")
                                .font(.custom("DMSans-Regular", size: 12))
                                .foregroundStyle(HONTheme.textSecondary)
                                .lineSpacing(2)
                        }
                        .padding(12)
                        .background(HONTheme.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 20)
            }
        )
    }

    private func coveragePill(cat: PPLCategory, covered: Bool, score: Double?) -> some View {
        let color: Color = covered ? (score.map { tierFromScore($0) }.flatMap { AppTheme.tier($0) } ?? HONTheme.positive) : HONTheme.textSecondary.opacity(0.3)
        return VStack(spacing: 6) {
            Image(systemName: covered ? cat.icon : "questionmark.circle")
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(cat.rawValue)
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundStyle(covered ? HONTheme.textPrimary : HONTheme.textSecondary.opacity(0.5))
            if let s = score {
                Text("\(Int(s.rounded()))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            } else {
                Text("—")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(HONTheme.textSecondary.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(covered ? color.opacity(0.1) : HONTheme.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Methodology note

    private var methodologyNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ABOUT THIS SCORE")
                .font(.custom("DMSans-Medium", size: 10))
                .kerning(1.5)
                .foregroundStyle(HONTheme.textSecondary.opacity(0.5))

            Text("Your score combines three independent signals:")
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundStyle(HONTheme.textSecondary.opacity(0.55))

            VStack(alignment: .leading, spacing: 6) {
                methodologyRow(weight: "40%", pillar: "Momentum", reason: "Consistent week-over-week improvement is the best predictor of long-term progress — it's harder to fake than current strength.")
                methodologyRow(weight: "35%", pillar: "Level", reason: "Anchors your score in absolute strength relative to body weight. If you stop training and lose strength, this reflects it.")
                methodologyRow(weight: "25%", pillar: "Process", reason: "Rewards smart training — optimal session load, rep efficiency, and fatigue management — which compounds over months.")
            }

            Text("Scores update after each logged session.")
                .font(.custom("DMSans-Regular", size: 11))
                .foregroundStyle(HONTheme.textSecondary.opacity(0.4))
                .padding(.top, 2)
        }
        .padding(16)
        .background(HONTheme.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func methodologyRow(weight: String, pillar: String, reason: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(weight)
                .font(.custom("DMSans-SemiBold", size: 11))
                .foregroundStyle(HONTheme.accent)
                .frame(width: 32, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(pillar)
                    .font(.custom("DMSans-SemiBold", size: 11))
                    .foregroundStyle(HONTheme.textSecondary.opacity(0.8))
                Text(reason)
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(HONTheme.textSecondary.opacity(0.5))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - WoW Delta (F-08)

    private var weeklyScoreDelta: Double? {
        let history = composite.history
        guard history.count >= 2 else { return nil }
        let latest = history.last!.score
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        if let prev = history.last(where: { $0.date <= cutoff }) {
            return latest - prev.score
        }
        return nil
    }

    private var weekDeltaLabel: String {
        guard let d = weeklyScoreDelta else { return momentumArrow }
        let sign = d >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.0f", d)) pt WoW"
    }

    // MARK: - Proof Rows (F-09)

    private var momentumProofRows: [(label: String, detail: String, isPositive: Bool?)] {
        let data = exerciseAnalytics
            .filter { $0.hasEnoughData }
            .sorted { abs($0.pctChangePerWeek) > abs($1.pctChangePerWeek) }
            .prefix(4)
        return data.map { ea in
            let pct = ea.pctChangePerWeek
            let sign = pct >= 0 ? "+" : ""
            return (
                label: ea.exercise.name,
                detail: "\(sign)\(String(format: "%.1f", pct))%/wk",
                isPositive: pct >= 0.1 ? true : (pct <= -0.1 ? false : nil)
            )
        }
    }

    private var levelProofRows: [(label: String, detail: String, isPositive: Bool?)] {
        let data = exerciseAnalytics
            .filter { $0.hasEnoughData && !$0.sessions.isEmpty }
            .prefix(4)
        return data.compactMap { ea -> (String, String, Bool?)? in
            guard let latestE1 = ea.sessions.last?.estimated1RM,
                  let peakE1  = ea.sessions.map(\.estimated1RM).max(),
                  peakE1 > 0 else { return nil }
            let pct = min(100, latestE1 / peakE1 * 100)
            let isAtPeak = pct >= 97
            return (
                label: ea.exercise.name,
                detail: "\(String(format: "%.0f", pct))% of peak",
                isPositive: pct >= 90 ? true : false
            )
        }
    }

    private var processProofRows: [(label: String, detail: String, isPositive: Bool?)] {
        var rows: [(String, String, Bool?)] = []
        for ea in exerciseAnalytics.filter({ $0.hasEnoughData }).prefix(4) {
            var parts: [String] = []
            var positive: Bool? = nil
            if let inol = ea.latestINOL {
                let zone = INOLZone(inol: inol)
                parts.append("INOL \(String(format: "%.2f", inol))")
                if positive == nil { positive = zone == .optimal ? true : false }
            }
            if let label = ea.efficiencyLabel {
                parts.append("yield: \(label)")
                if label == "Below avg" { positive = false }
                else if label == "Great" && positive != false { positive = true }
            }
            let slopeStr = ea.slopePerWeek >= 0
                ? String(format: "+%.1f kg/wk", ea.slopePerWeek)
                : String(format: "%.1f kg/wk", ea.slopePerWeek)
            parts.append(slopeStr)
            if !parts.isEmpty {
                rows.append((ea.exercise.name, parts.joined(separator: " · "), positive))
            }
        }
        return rows
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.custom("DMSans-Medium", size: 10))
            .kerning(1.5)
            .foregroundStyle(HONTheme.textSecondary.opacity(0.6))
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statChip(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(HONTheme.textPrimary)
            Text(label)
                .font(.custom("DMSans-Regular", size: 10))
                .foregroundStyle(HONTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func subValueText(_ v: Double, unit: String) -> String {
        if unit == "%" { return String(format: "%.0f%%", v) }
        return "\(Int(v.rounded()))\(unit)"
    }

    private var gradeLabel: String { composite.grade }

    private var momentumArrow: String {
        let m = composite.momentumScore
        if m >= 70 { return "↑" }
        if m >= 45 { return "→" }
        return "↓"
    }

    private var thisWeekLabel: String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let daysFromMon = (cal.component(.weekday, from: today) + 5) % 7
        let weekStart = cal.date(byAdding: .day, value: -daysFromMon, to: today)!
        let count = log.filter { $0.startedAt >= weekStart }.count
        return "\(count)"
    }

    private func percentile(for rp: RelativeStrengthPoint) -> Double {
        let rs = rp.relativeStrength
        let t  = rp.thresholds
        switch rp.tier {
        case .beginner:
            return 20.0 * min(rs / max(t.beginner, 0.01), 1.0)
        case .intermediate:
            let frac = (rs - t.beginner) / max(t.intermediate - t.beginner, 0.01)
            return 20.0 + 30.0 * min(max(frac, 0), 1.0)
        case .advanced:
            let frac = (rs - t.intermediate) / max(t.advanced - t.intermediate, 0.01)
            return 50.0 + 30.0 * min(max(frac, 0), 1.0)
        case .elite:
            let frac = (rs - t.advanced) / max(t.advanced * 0.3, 0.01)
            return 80.0 + 20.0 * min(max(frac, 0), 1.0)
        }
    }

    private func tierColor(_ tier: StrengthTier) -> Color {
        AppTheme.tier(tier)
    }

    private func relTierColor(_ tier: RelativeStrengthTier) -> Color {
        switch tier {
        case .beginner:     return HONTheme.tierBeginner
        case .intermediate: return HONTheme.tierIntermediate
        case .advanced:     return HONTheme.tierAdvanced
        case .elite:        return HONTheme.tierElite
        }
    }

    private func tierFromScore(_ s: Double) -> StrengthTier {
        if s < 20 { return .beginner }
        if s < 50 { return .intermediate }
        if s < 80 { return .advanced }
        return .elite
    }
}

// MARK: - Pillar Bar

private struct PillarBar: View {
    let value: Double  // 0.0–1.0
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.15))

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: max(6, geo.size.width * CGFloat(min(1, max(0, value)))))
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: value)
            }
        }
        .frame(height: 8)
    }
}
