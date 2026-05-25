import SwiftUI
import Charts

enum E1RMMode: String, CaseIterable {
    case standard = "Standard"
    case adjusted = "Fatigue-Adj"
    case compare  = "Compare"
}

struct ExerciseDetailSheet: View {
    let analytics: ExerciseAnalytics
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitService.self) private var healthKit
    @State private var showVariance = false
    @State private var showExplainer = false
    @State private var e1rmMode: E1RMMode = .standard

    // Active session points / rolling avg depending on mode
    private var activeSessions: [SessionPoint] {
        e1rmMode == .adjusted ? analytics.sessionsFatigue : analytics.sessions
    }
    private var activeRollingAvg: [SessionPoint] {
        e1rmMode == .adjusted ? analytics.rollingAvgFatigue : analytics.rollingAvg
    }
    private var activeSlope: Double {
        e1rmMode == .adjusted ? analytics.slopePerWeekFatigue : analytics.slopePerWeek
    }
    private var activePct: Double {
        e1rmMode == .adjusted ? analytics.pctChangePerWeekFatigue : analytics.pctChangePerWeek
    }

    private var relativeStrength: Double? {
        guard let bw = healthKit.bodyweight, bw > 0,
              let pr = analytics.prProgression.last?.estimated1RM else { return nil }
        return pr / bw
    }

    private var inolZone: INOLZone? {
        analytics.latestINOL.map { INOLZone(inol: $0) }
    }

    private var inolZoneColor: Color {
        switch inolZone {
        case .insufficient: return .secondary
        case .moderate:     return HONTheme.accent
        case .optimal:      return HONTheme.positive
        case .heavy:        return HONTheme.warning
        case .overreaching: return HONTheme.negative
        case nil:           return .secondary
        }
    }

    // Fix 1 — INOL + rep decay → actionable coaching note
    private var coachingNote: String? {
        guard let inol = analytics.latestINOL, let zone = inolZone else { return nil }
        var parts: [String] = []
        switch zone {
        case .insufficient:
            parts.append("INOL \(String(format: "%.2f", inol)) is below the training threshold — add 1–2 sets next session.")
        case .moderate:
            parts.append("INOL \(String(format: "%.2f", inol)) is moderate — one extra set would push you into the optimal zone.")
        case .optimal:
            parts.append("INOL \(String(format: "%.2f", inol)) is in the sweet spot — keep the load and add weight when reps feel comfortable.")
        case .heavy:
            parts.append("INOL \(String(format: "%.2f", inol)) is high — allow 72 h+ recovery before training this pattern again.")
        case .overreaching:
            parts.append("INOL \(String(format: "%.2f", inol)) exceeds safe recovery capacity — drop 2–3 sets next session.")
        }
        if let decay = analytics.latestRepDecay {
            if decay > -0.3 && decay < 0.3 {
                parts.append("Rep decay is near zero — the working weight may be too light to drive adaptation.")
            } else if decay < -3.0 {
                parts.append("Steep rep drop-off — extend rest intervals or reduce the opening set weight.")
            }
        }
        return parts.joined(separator: " ")
    }

    private struct VariancePt: Identifiable {
        let id: Int; let date: Date; let lo: Double; let hi: Double
    }

    private var varianceBand: [VariancePt] {
        let s = analytics.sessions
        return s.indices.map { i in
            let start = max(0, i - 4)
            let vals  = s[start...i].map(\.estimated1RM)
            return VariancePt(id: i, date: s[i].date, lo: vals.min() ?? 0, hi: vals.max() ?? 0)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    patternRow
                    if analytics.hasEnoughData { day1Card }
                    statsRow
                    if analytics.latestINOL != nil || analytics.efficiencyScore != nil || relativeStrength != nil {
                        sessionMetricsCard
                    }
                    if coachingNote != nil || analytics.feelInsight != nil {
                        coachingCard
                    }
                    if analytics.isPlateau { plateauBanner }
                    strengthCard
                    if analytics.prProgression.count >= 2 { prCard }
                    if !analytics.sessions.isEmpty { sessionLogCard }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .background(AppTheme.pageBG)
            .navigationTitle(analytics.exercise.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showExplainer = true
                    } label: {
                        Label("How analytics are calculated", systemImage: "info.circle")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("How analytics are calculated")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showExplainer) {
                AnalyticsExplainerSheet()
            }
        }
    }

    // MARK: - Pattern / Region tags

    private var patternRow: some View {
        HStack(spacing: 8) {
            let ex = analytics.exercise
            tagPill(ex.movementPattern.rawValue, ex.movementPattern.icon, HONTheme.accent)
            tagPill(ex.bodyRegion.rawValue,      ex.bodyRegion.icon,      HONTheme.chartLavender)
            Spacer()
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        let s  = activeSlope
        let p  = activePct
        let pr = analytics.prProgression.last?.estimated1RM
        let bestAdj = analytics.sessionsFatigue.map(\.estimated1RM).max()
        let prDisplay: String = {
            if e1rmMode == .adjusted, let b = bestAdj { return "≈\(Int(b))" }
            return pr.map { "≈\(Int($0))" } ?? "—"
        }()

        return HStack(spacing: 0) {
            dStat("\(analytics.sessions.count)", "Sessions")
            Divider().frame(height: 32)
            dStat(signed("%.1f kg", s), "kg / wk",   color: s >= 0 ? HONTheme.positive : HONTheme.negative)
            Divider().frame(height: 32)
            dStat(signed("%.1f%%", p), "% / wk",    color: p >= 0 ? HONTheme.positive : HONTheme.negative)
            Divider().frame(height: 32)
            dStat(prDisplay, analytics.exercise.equipment == .dumbbell ? "Best 1RM (total)" : "Best 1RM", color: HONTheme.chartAmber)
        }
        .padding(.vertical, 12)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Plateau warning

    private var plateauBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(HONTheme.warning)
            Text("Strength hasn't moved in 4+ weeks. Try varying rep range or adding load.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(HONTheme.warning.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Session Metrics Card (INOL, rep decay, efficiency, relative strength)

    private var sessionMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Session")
                .font(.caption.bold()).foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                // INOL
                if let inol = analytics.latestINOL, let zone = inolZone {
                    metricCell(
                        title: "INOL",
                        value: String(format: "%.2f", inol),
                        badge: zone.rawValue,
                        badgeColor: inolZoneColor
                    )
                }

                // Rep Decay
                if let decay = analytics.latestRepDecay {
                    let isGood = decay < -0.2
                    let label  = decay < -0.1 ? "Fatiguing" : (decay > 0.1 ? "Rising" : "Flat")
                    metricCell(
                        title: "Rep Decay",
                        value: String(format: "%.1f/set", decay),
                        badge: label,
                        badgeColor: isGood ? HONTheme.positive : .secondary
                    )
                }

                // Efficiency Score — fix 4: show quartile label, not just sign
                if let eff = analytics.efficiencyScore {
                    let effBadge  = analytics.efficiencyLabel ?? (eff >= 0 ? "Gaining" : "Declining")
                    let effColor: Color = {
                        switch analytics.efficiencyLabel {
                        case "Great":     return HONTheme.positive
                        case "Average":   return HONTheme.accent
                        case "Below avg": return HONTheme.warning
                        default:          return eff >= 0 ? HONTheme.positive : HONTheme.negative
                        }
                    }()
                    metricCell(
                        title: "Efficiency",
                        value: String(format: "%+.3f", eff),
                        badge: effBadge,
                        badgeColor: effColor
                    )
                }

                // Relative Strength — fix 3: prompt when bodyweight unavailable
                if let rs = relativeStrength {
                    metricCell(
                        title: "Rel. Strength",
                        value: String(format: "%.2f×", rs),
                        badge: "BW",
                        badgeColor: HONTheme.chartLavender
                    )
                } else if analytics.prProgression.last != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rel. Strength")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text("—")
                            .font(.subheadline.bold()).foregroundStyle(.secondary)
                        Label("Log weight in Health", systemImage: "heart.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(HONTheme.chartRose)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(HONTheme.chartRose.opacity(0.10), in: Capsule())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private func metricCell(title: String, value: String, badge: String, badgeColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2).foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(badge)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(badgeColor.opacity(0.12), in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Coaching Card (fixes 1 + 2)

    private var coachingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Recommendations", systemImage: "lightbulb.fill")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let note = coachingNote {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: inolZone == .overreaching || inolZone == .insufficient
                          ? "exclamationmark.circle.fill"
                          : "checkmark.circle.fill")
                        .foregroundStyle(inolZone == .overreaching ? HONTheme.negative :
                                         inolZone == .insufficient ? HONTheme.warning : HONTheme.positive)
                        .font(.subheadline)
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Fix 2 — feel streak insight
            if let feel = analytics.feelInsight {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: feel.contains("primed") || feel.contains("increase")
                          ? "arrow.up.circle.fill" : "moon.zzz.fill")
                        .foregroundStyle(feel.contains("tired") || feel.contains("deload")
                                         ? HONTheme.warning : HONTheme.positive)
                        .font(.subheadline)
                    Text(feel)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Strength chart card

    private var strengthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Estimated 1RM")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                    if analytics.exercise.equipment == .dumbbell {
                        Text("Bilateral total (both dumbbells combined). Enter per-hand weight in the workout.")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if analytics.sessions.count >= 3 {
                    Toggle("Variance", isOn: $showVariance)
                        .toggleStyle(.button)
                        .font(.caption2.bold())
                        .tint(HONTheme.chartSlate.opacity(0.7))
                        .controlSize(.mini)
                }
            }

            Picker("Mode", selection: $e1rmMode) {
                ForEach(E1RMMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if e1rmMode == .compare {
                HStack(spacing: 12) {
                    Label("Standard", systemImage: "circle.fill")
                        .font(.caption2).foregroundStyle(HONTheme.accent)
                    Label("Fatigue-Adj", systemImage: "circle.fill")
                        .font(.caption2).foregroundStyle(HONTheme.warning)
                }
            } else if e1rmMode == .adjusted {
                Text("Each set upscaled by e^(0.08 × set index) to recover estimated fresh capacity.")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            strengthChart

            if !analytics.hasEnoughData {
                let needed = max(0, 3 - analytics.sessions.count)
                Text("Log \(needed) more session\(needed == 1 ? "" : "s") to unlock trend analysis.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private var strengthChart: some View {
        Chart {
            // Variance band — only in standard mode
            if showVariance && varianceBand.count >= 3 && e1rmMode != .compare {
                ForEach(varianceBand) { pt in
                    AreaMark(
                        x: .value("Date", pt.date),
                        yStart: .value("Lo", pt.lo),
                        yEnd:   .value("Hi", pt.hi)
                    )
                    .foregroundStyle(HONTheme.accent.opacity(0.08))
                }
            }

            // Standard Epley dots + line (blue) — shown in Standard and Compare modes
            if e1rmMode != .adjusted {
                ForEach(analytics.sessions) { pt in
                    PointMark(x: .value("Date", pt.date), y: .value("1RM", pt.estimated1RM))
                        .foregroundStyle(HONTheme.accent.opacity(0.30))
                        .symbolSize(24)
                }
                ForEach(analytics.rollingAvg) { pt in
                    LineMark(x: .value("Date", pt.date), y: .value("1RM", pt.estimated1RM))
                        .foregroundStyle(HONTheme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                        .symbol {
                            Circle().fill(HONTheme.accent).frame(width: 7, height: 7)
                                .overlay(Circle().stroke(HONTheme.textPrimary, lineWidth: 1.5))
                        }
                }
            }

            // Fatigue-adjusted dots + line (orange) — shown in Adjusted and Compare modes
            if e1rmMode != .standard {
                ForEach(analytics.sessionsFatigue) { pt in
                    PointMark(x: .value("Date", pt.date), y: .value("Adj", pt.estimated1RM))
                        .foregroundStyle(HONTheme.warning.opacity(0.30))
                        .symbolSize(24)
                }
                ForEach(analytics.rollingAvgFatigue) { pt in
                    LineMark(x: .value("Date", pt.date), y: .value("Adj", pt.estimated1RM))
                        .foregroundStyle(HONTheme.warning)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                        .symbol {
                            Circle().fill(HONTheme.warning).frame(width: 7, height: 7)
                                .overlay(Circle().stroke(HONTheme.textPrimary, lineWidth: 1.5))
                        }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                    .foregroundStyle(Color.secondary.opacity(0.25))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                    .foregroundStyle(Color.secondary.opacity(0.25))
                AxisValueLabel {
                    if let v = val.as(Double.self) {
                        Text("\(Int(v)) kg").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 200)
    }

    // MARK: - PR step chart card

    private var prCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Personal Record Progression")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill").font(.caption2).foregroundStyle(HONTheme.chartAmber)
                    Text("\(analytics.prProgression.count) PRs").font(.caption2).foregroundStyle(.secondary)
                }
            }

            Chart {
                // Area fill under the step
                ForEach(analytics.prProgression) { pt in
                    AreaMark(
                        x: .value("Date", pt.date),
                        y: .value("1RM",  pt.estimated1RM)
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(LinearGradient(
                        colors: [HONTheme.chartAmber.opacity(0.18), HONTheme.chartAmber.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    ))
                }

                // Step line
                ForEach(analytics.prProgression) { pt in
                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value("1RM",  pt.estimated1RM)
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(HONTheme.chartAmber)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                // PR dots with value labels
                ForEach(analytics.prProgression) { pt in
                    PointMark(
                        x: .value("Date", pt.date),
                        y: .value("1RM",  pt.estimated1RM)
                    )
                    .foregroundStyle(HONTheme.chartAmber)
                    .symbolSize(45)
                    .annotation(position: .top, spacing: 4) {
                        Text("\(Int(pt.estimated1RM))")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3]))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            Text("\(Int(v)) kg").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 160)
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Progress Since Day 1

    private var day1Card: some View {
        let sessions = activeSessions
        guard let first = sessions.first, let last = sessions.last,
              first.estimated1RM > 0 else { return AnyView(EmptyView()) }

        let gain    = last.estimated1RM - first.estimated1RM
        let pct     = gain / first.estimated1RM * 100
        let weeks   = last.date.timeIntervalSince(first.date) / (7 * 86400)
        let gainColor: Color = gain > 1 ? HONTheme.positive : (gain < -1 ? HONTheme.negative : .secondary)

        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                Text("Since Day 1")
                    .font(.caption.bold()).foregroundStyle(.secondary)

                // Day 1 → Now comparison bar
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Day 1").font(.caption2).foregroundStyle(.tertiary)
                        Text("≈\(Int(first.estimated1RM)) kg")
                            .font(.subheadline.bold())
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Now").font(.caption2).foregroundStyle(.tertiary)
                        Text("≈\(Int(last.estimated1RM)) kg")
                            .font(.subheadline.bold())
                            .foregroundStyle(gainColor)
                    }
                }

                // Three headline numbers
                HStack(spacing: 0) {
                    bigStat(signed("%.0f kg", gain), "gained", gainColor)
                    Divider().frame(height: 36)
                    bigStat(signed("%.0f%%", pct),   "improvement", gainColor)
                    Divider().frame(height: 36)
                    bigStat("\(Int(weeks.rounded()))wk", "tracked", .primary)
                }
            }
            .padding(14)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
        )
    }

    private func bigStat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Session History Log

    private var sessionLogCard: some View {
        let stdSessions = analytics.sessions.reversed() as [SessionPoint]
        let adjSessions = analytics.sessionsFatigue.reversed() as [SessionPoint]
        let showCompare = e1rmMode == .compare

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Session History")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                if showCompare {
                    HStack(spacing: 8) {
                        Text("Std").font(.system(size: 9, weight: .bold)).foregroundStyle(HONTheme.accent)
                        Text("Adj").font(.system(size: 9, weight: .bold)).foregroundStyle(HONTheme.warning)
                    }
                }
                Text("\(analytics.sessions.count) sessions")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            VStack(spacing: 4) {
                ForEach(Array(stdSessions.enumerated()), id: \.element.id) { idx, pt in
                    let prev      = idx + 1 < stdSessions.count ? stdSessions[idx + 1] : pt
                    let delta     = pt.estimated1RM - prev.estimated1RM
                    let trendIcon = delta > 1 ? "arrow.up" : (delta < -1 ? "arrow.down" : "minus")
                    let trendColor: Color = delta > 1 ? HONTheme.positive : (delta < -1 ? HONTheme.negative : .secondary)
                    let adjPt     = idx < adjSessions.count ? adjSessions[idx] : nil

                    HStack(spacing: 8) {
                        Text(pt.date, format: .dateTime.month(.abbreviated).day().year())
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .frame(width: 76, alignment: .leading)

                        if pt.bestWeight > 0 && pt.bestReps > 0 {
                            Text("\(pt.bestWeight.weightFormatted) × \(pt.bestReps)")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(.primary)
                        }

                        if let feel = pt.feel { Text(feel.icon).font(.system(size: 11)) }

                        Spacer()

                        if showCompare, let adj = adjPt {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("≈\(Int(pt.estimated1RM)) kg")
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(HONTheme.accent)
                                Text("≈\(Int(adj.estimated1RM)) kg")
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(HONTheme.warning)
                            }
                        } else {
                            let display = e1rmMode == .adjusted ? adjPt?.estimated1RM ?? pt.estimated1RM : pt.estimated1RM
                            Text("≈\(Int(display)) kg")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary)
                        }

                        Image(systemName: trendIcon)
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(trendColor)
                            .frame(width: 14)
                    }
                    .padding(.vertical, 7).padding(.horizontal, 10)
                    .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func tagPill(_ label: String, _ icon: String, _ color: Color) -> some View {
        Label(label, systemImage: icon)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func dStat(_ value: String, _ label: String, color: Color = .primary) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // Formats a signed number: +1.2 kg or -0.8%
    private func signed(_ fmt: String, _ v: Double) -> String {
        let s = String(format: fmt, abs(v))
        return v >= 0 ? "+\(s)" : "-\(s)"
    }
}
