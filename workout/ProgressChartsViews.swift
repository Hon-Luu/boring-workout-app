import SwiftUI
import Charts

// MARK: - COMPONENT 1: GradientTierBar

struct GradientTierBar: View {
    let value: Double    // 0–100
    var height: CGFloat = 7

    private let grayColor  = HONTheme.tierBeginner
    private let greenColor = HONTheme.chartSage
    private let blueColor  = HONTheme.chartSlate
    private let goldColor  = HONTheme.chartAmber

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width
                let fillW = w * CGFloat(value / 100.0)
                let markerX = fillW

                ZStack(alignment: .leading) {
                    // Background gradient (low opacity)
                    LinearGradient(
                        stops: [
                            .init(color: grayColor.opacity(0.3),  location: 0.00),
                            .init(color: grayColor.opacity(0.3),  location: 0.20),
                            .init(color: greenColor.opacity(0.3), location: 0.20),
                            .init(color: greenColor.opacity(0.3), location: 0.50),
                            .init(color: blueColor.opacity(0.3),  location: 0.50),
                            .init(color: blueColor.opacity(0.3),  location: 0.80),
                            .init(color: goldColor.opacity(0.3),  location: 0.80),
                            .init(color: goldColor.opacity(0.3),  location: 1.00),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: height / 2))

                    // Fill gradient (full opacity, clipped to value)
                    LinearGradient(
                        stops: [
                            .init(color: grayColor,  location: 0.00),
                            .init(color: grayColor,  location: 0.20),
                            .init(color: greenColor, location: 0.20),
                            .init(color: greenColor, location: 0.50),
                            .init(color: blueColor,  location: 0.50),
                            .init(color: blueColor,  location: 0.80),
                            .init(color: goldColor,  location: 0.80),
                            .init(color: goldColor,  location: 1.00),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: max(0, fillW), height: height)
                    .clipShape(RoundedRectangle(cornerRadius: height / 2))

                    // Tick marks at 20%, 50%, 80%
                    ForEach([0.20, 0.50, 0.80], id: \.self) { pct in
                        Rectangle()
                            .fill(HONTheme.textPrimary)
                            .frame(width: 2, height: height)
                            .offset(x: w * CGFloat(pct) - 1)
                    }

                    // Marker circle at value position
                    Circle()
                        .fill(HONTheme.textPrimary)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .offset(x: max(0, markerX - 7))
                }
                .frame(height: height)
            }
            .frame(height: height)

            // Zone labels
            GeometryReader { geo in
                let w = geo.size.width
                ZStack {
                    Text("Beginner")
                        .font(.system(size: 9))
                        .foregroundColor(grayColor)
                        .position(x: w * 0.10, y: 6)
                    Text("Intermediate")
                        .font(.system(size: 9))
                        .foregroundColor(greenColor)
                        .position(x: w * 0.35, y: 6)
                    Text("Advanced")
                        .font(.system(size: 9))
                        .foregroundColor(blueColor)
                        .position(x: w * 0.65, y: 6)
                    Text("Elite")
                        .font(.system(size: 9))
                        .foregroundColor(goldColor)
                        .position(x: w * 0.90, y: 6)
                }
            }
            .frame(height: 14)
        }
    }
}

// MARK: - COMPONENT 2: PopulationPercentileCard

struct PopulationPercentileCard: View {
    let relativeStrengths: [RelativeStrengthPoint]
    @State private var showDetail = false

    private let goldColor = HONTheme.chartAmber

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

    private func tierColor(_ tier: RelativeStrengthTier) -> Color {
        switch tier {
        case .beginner:     return HONTheme.tierBeginner
        case .intermediate: return HONTheme.tierIntermediate
        case .advanced:     return HONTheme.tierAdvanced
        case .elite:        return goldColor
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Population Rank")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    Text("vs. same body weight")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                if relativeStrengths.isEmpty {
                    Text("Log more sessions to unlock this.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(Array(relativeStrengths.prefix(5))) { rp in
                        let pct = percentile(for: rp)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(rp.exercise.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Spacer()

                                Text("\(Int(pct))th")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(tierColor(rp.tier))

                                Text(rp.tier.rawValue)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(tierColor(rp.tier))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(tierColor(rp.tier).opacity(0.15))
                                    .clipShape(Capsule())
                            }

                            PercentileRankBar(percentile: pct, tierColor: tierColor(rp.tier))
                        }
                    }
                }
            }
            .padding(14)
            .background(AppTheme.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
                .padding(14)
        }
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            PopulationPercentileDetailSheet(
                relativeStrengths: relativeStrengths,
                percentile: percentile,
                tierColor: tierColor
            )
        }
    }
}

// Percentile rank bar — gradient + marker, no tick marks
struct PercentileRankBar: View {
    let percentile: Double
    let tierColor: Color

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                let w = geo.size.width
                let markerX = w * CGFloat(percentile / 100.0)

                ZStack(alignment: .leading) {
                    // Background gradient
                    LinearGradient(
                        colors: [HONTheme.tierBeginner, HONTheme.tierIntermediate,
                                 HONTheme.tierAdvanced, HONTheme.tierElite],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .opacity(0.3)
                    .frame(height: 6)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                    // Marker
                    Rectangle()
                        .fill(HONTheme.textPrimary)
                        .frame(width: 3, height: 10)
                        .clipShape(RoundedRectangle(cornerRadius: 1.5))
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        .offset(x: max(0, markerX - 1.5), y: -2)
                }
            }
            .frame(height: 10)

            GeometryReader { geo in
                let w = geo.size.width
                ZStack {
                    Text("Novice")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                        .position(x: w * 0.10, y: 5)
                    Text("Intermediate")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                        .position(x: w * 0.35, y: 5)
                    Text("Advanced")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                        .position(x: w * 0.65, y: 5)
                    Text("Elite")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                        .position(x: w * 0.90, y: 5)
                }
            }
            .frame(height: 12)
        }
    }
}

// Detail sheet
struct PopulationPercentileDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let relativeStrengths: [RelativeStrengthPoint]
    let percentile: (RelativeStrengthPoint) -> Double
    let tierColor: (RelativeStrengthTier) -> Color

    private let goldColor = HONTheme.chartAmber

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How your lifts compare to people of the same body weight")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Each lift row
                    ForEach(relativeStrengths) { rp in
                        let pct = percentile(rp)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rp.exercise.name)
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(String(format: "%.2f× BW", rp.relativeStrength))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(Int(pct))th percentile")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(tierColor(rp.tier))
                                    Text(tierMeaning(rp.tier))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }

                            PercentileRankBar(percentile: pct, tierColor: tierColor(rp.tier))

                            HStack {
                                Text(rp.tier.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(tierColor(rp.tier))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(tierColor(rp.tier).opacity(0.15))
                                    .clipShape(Capsule())

                                Text(tierDescription(rp.tier))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(14)
                        .background(AppTheme.cardBG)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Explanation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How this is calculated")
                            .font(.system(size: 14, weight: .semibold))

                        Text("Population rank uses body-weight-relative strength thresholds derived from population research. Your lifts are compared to athletes of the same body weight.\n\nPercentile bands:\n• Novice — below 20th percentile\n• Intermediate — 20th to 50th percentile\n• Advanced — 50th to 80th percentile\n• Elite — above 80th percentile")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(AppTheme.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Spacer(minLength: 32)
                }
                .padding(.top, 8)
            }
            .background(AppTheme.pageBG.ignoresSafeArea())
            .navigationTitle("Population Rank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func tierMeaning(_ tier: RelativeStrengthTier) -> String {
        switch tier {
        case .beginner:     return "Building a foundation"
        case .intermediate: return "Above average population"
        case .advanced:     return "Well-trained athlete"
        case .elite:        return "Top-tier strength"
        }
    }

    private func tierDescription(_ tier: RelativeStrengthTier) -> String {
        switch tier {
        case .beginner:     return "Continue progressive overload and consistency."
        case .intermediate: return "Stronger than most gym-goers at your weight."
        case .advanced:     return "Top 50% of serious lifters at your weight."
        case .elite:        return "Top 20% — elite relative strength level."
        }
    }
}

// MARK: - COMPONENT 3: StrengthRetentionRingsCard

struct StrengthRetentionRingsCard: View {
    let exerciseAnalytics: [ExerciseAnalytics]
    @State private var showDetail = false

    private struct RingData {
        let retention: Double
        let peak: Double
        let current: Double
    }

    private func ringData(for ea: ExerciseAnalytics) -> RingData {
        let peak    = ea.sessions.map(\.estimated1RM).max() ?? 0
        let current = ea.sessions.last?.estimated1RM ?? 0
        return RingData(retention: peak > 0 ? min(current / peak, 1.0) : 0, peak: peak, current: current)
    }

    private func ringColor(_ ret: Double) -> Color {
        if ret >= 0.90 { return HONTheme.positive }
        if ret >= 0.75 { return HONTheme.warning }
        return HONTheme.negative
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strength Retention")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Current vs peak e1RM per lift")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                if exerciseAnalytics.isEmpty {
                    Text("Log more sessions to unlock this.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    HStack(spacing: 12) {
                        ForEach(Array(exerciseAnalytics.prefix(4))) { ea in
                            let rd = ringData(for: ea)
                            let color = ringColor(rd.retention)
                            VStack(spacing: 3) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 7)
                                    Circle()
                                        .trim(from: 0, to: CGFloat(rd.retention))
                                        .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                    Text("\(Int(rd.retention * 100))%")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(color)
                                }
                                .frame(width: 68, height: 68)

                                Text(String(ea.exercise.name.prefix(10)))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)

                                // Current / peak kg
                                Text("\(Int(rd.current))→\(Int(rd.peak)) kg")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(color.opacity(0.85))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(AppTheme.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
                .padding(14)
        }
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            StrengthRetentionDetailSheet(exerciseAnalytics: exerciseAnalytics)
        }
    }
}

struct StrengthRetentionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseAnalytics: [ExerciseAnalytics]

    private struct RetentionData {
        let ea: ExerciseAnalytics
        let retention: Double
        let peak: Double
        let current: Double
        let peakDate: Date?
        let daysSincePeak: Int
        let recentTrend: Double   // slope of last 4 sessions, kg/session
        let color: Color
        let statusLabel: String
        let insight: String
        let repRangeNote: String? // non-nil when peak & current used very different rep ranges
    }

    private func build(_ ea: ExerciseAnalytics) -> RetentionData {
        let vals   = ea.sessions.map(\.estimated1RM)
        let peak   = vals.max() ?? 0
        let curr   = ea.sessions.last?.estimated1RM ?? 0
        let ret    = peak > 0 ? min(curr / peak, 1.0) : 0
        let peakPt = ea.sessions.first(where: { $0.estimated1RM == peak })
        let days   = peakPt.map { Int(Date().timeIntervalSince($0.date) / 86_400) } ?? 0

        // Recent trend: linear slope of last 4 sessions in kg/session
        let recent = ea.sessions.suffix(4)
        let recentTrend: Double = {
            guard recent.count >= 2 else { return 0 }
            let xs = Array(0..<recent.count).map(Double.init)
            let ys = recent.map(\.estimated1RM)
            let n  = Double(xs.count)
            let sx = xs.reduce(0, +); let sy = ys.reduce(0, +)
            let sxy = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
            let sxx = xs.reduce(0) { $0 + $1 * $1 }
            let denom = n * sxx - sx * sx
            return denom == 0 ? 0 : (n * sxy - sx * sy) / denom
        }()

        let color: Color = ret >= 0.90 ? HONTheme.positive : ret >= 0.75 ? HONTheme.warning : HONTheme.negative
        let statusLabel: String = ret >= 0.90 ? "Holding Peak" : ret >= 0.75 ? "Slight Dip" : "Regression"

        let insight: String = {
            let gap = peak - curr
            if ret >= 0.98 { return "At or near your all-time peak. Maintain this stimulus and look for small weekly PRs." }
            if ret >= 0.90 {
                return recentTrend > 0
                    ? "Within \(Int(gap + 0.5)) kg of your peak and trending up — you'll likely set a new high soon."
                    : "Holding strong within \(Int(gap + 0.5)) kg of your peak. One good session can close the gap."
            }
            if ret >= 0.75 {
                return days < 14
                    ? "Peak was \(days) days ago — this drop is normal during a recovery window. Expect to return within 2–3 sessions."
                    : "You're \(Int(gap + 0.5)) kg off your peak from \(days) days ago. Increase stimulus frequency or intensity."
            }
            return recentTrend > 0
                ? "Down significantly from peak but trending up recently (+\(String(format: "%.1f", recentTrend)) kg/session). Stay consistent."
                : "You're \(Int(gap + 0.5)) kg below your \(days)-day-old peak. Consider a technique reset or volume adjustment."
        }()

        // Detect rep-range mismatch: if peak and current sessions used very different rep ranges
        // the e1RM comparison may overstate or understate actual retention.
        let peakReps   = peakPt?.bestReps ?? 0
        let currentReps = ea.sessions.last?.bestReps ?? 0
        let repRangeNote: String? = {
            guard peakReps > 0, currentReps > 0, abs(peakReps - currentReps) > 4 else { return nil }
            let (lowR, highR) = peakReps < currentReps ? (peakReps, currentReps) : (currentReps, peakReps)
            return "Note: your peak was set at \(peakReps) reps; your latest session used \(currentReps) reps. " +
                   "The Epley formula converts both to a theoretical 1RM, but results are most comparable when rep ranges are similar (\(lowR)–\(highR) reps spans different energy systems)."
        }()

        return RetentionData(ea: ea, retention: ret, peak: peak, current: curr,
                             peakDate: peakPt?.date, daysSincePeak: days,
                             recentTrend: recentTrend, color: color,
                             statusLabel: statusLabel, insight: insight,
                             repRangeNote: repRangeNote)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(exerciseAnalytics) { ea in
                        let d = build(ea)
                        exerciseRetentionCard(d)
                    }

                    // What retention means
                    VStack(alignment: .leading, spacing: 10) {
                        Text("HOW TO READ THIS")
                            .font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).kerning(0.5)
                        Text("Retention measures how much of your estimated peak 1-rep max you're currently expressing. 100% means your last session matched your all-time best. Anything above 90% is healthy — strength fluctuates day to day based on fatigue, sleep, and nutrition. A drop below 75% sustained over multiple sessions is worth investigating.")
                            .font(.system(size: 13)).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)

                        Divider()

                        ForEach([
                            (HONTheme.positive, "≥ 90%", "Holding peak — you're expressing close to your best strength."),
                            (HONTheme.warning,  "75–89%", "Normal dip — expected after deloads, travel, or a gap."),
                            (HONTheme.negative,  "< 75%", "Investigate — prolonged regression suggests programming or recovery issues.")
                        ], id: \.1) { color, pct, desc in
                            HStack(alignment: .top, spacing: 10) {
                                Text(pct).font(.system(size: 12, weight: .bold)).foregroundColor(color).frame(width: 48, alignment: .leading)
                                Text(desc).font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(16)
                    .background(AppTheme.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    Spacer(minLength: 32)
                }
                .padding(.top, 12)
            }
            .background(AppTheme.pageBG.ignoresSafeArea())
            .navigationTitle("Strength Retention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func exerciseRetentionCard(_ d: RetentionData) -> some View {
        let sessions = d.ea.sessions
        let dateFmt: DateFormatter = {
            let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
        }()

        VStack(alignment: .leading, spacing: 14) {
            // Header: name + status badge
            HStack {
                Text(d.ea.exercise.name)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text(d.statusLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(d.color)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(d.color.opacity(0.12), in: Capsule())
            }

            // Stats row
            HStack(spacing: 0) {
                retStat("CURRENT", "\(Int(d.current)) kg", d.color)
                Divider().frame(height: 32)
                retStat("PEAK", "\(Int(d.peak)) kg", .secondary)
                Divider().frame(height: 32)
                retStat("GAP", d.peak > d.current ? "-\(Int(d.peak - d.current + 0.5)) kg" : "—", d.color)
                Divider().frame(height: 32)
                retStat("DAYS AGO", d.daysSincePeak > 0 ? "\(d.daysSincePeak)d" : "Today", .secondary)
            }
            .padding(.vertical, 6)
            .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

            // e1RM trend chart — the actual history line
            if sessions.count >= 2 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("e1RM HISTORY")
                        .font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary).kerning(0.5)

                    let minVal = (sessions.map(\.estimated1RM).min() ?? 0) * 0.95
                    let maxVal = (sessions.map(\.estimated1RM).max() ?? 1) * 1.05

                    Chart {
                        // Peak reference line
                        RuleMark(y: .value("Peak", d.peak))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(d.color.opacity(0.4))
                            .annotation(position: .topLeading) {
                                Text("Peak").font(.system(size: 8)).foregroundColor(d.color.opacity(0.6))
                            }

                        ForEach(Array(sessions.enumerated()), id: \.offset) { idx, pt in
                            AreaMark(
                                x: .value("Session", idx),
                                yStart: .value("Base", minVal),
                                yEnd:   .value("e1RM", pt.estimated1RM)
                            )
                            .foregroundStyle(d.color.opacity(0.08))

                            LineMark(
                                x: .value("Session", idx),
                                y: .value("e1RM", pt.estimated1RM)
                            )
                            .foregroundStyle(d.color)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))

                            PointMark(
                                x: .value("Session", idx),
                                y: .value("e1RM", pt.estimated1RM)
                            )
                            .foregroundStyle(idx == sessions.count - 1 ? d.color : d.color.opacity(0.4))
                            .symbolSize(idx == sessions.count - 1 ? 48 : 20)
                        }
                    }
                    .chartYScale(domain: minVal...maxVal)
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) {
                            AxisValueLabel().font(.system(size: 9))
                            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                        }
                    }
                    .frame(height: 120)

                    // x-axis date annotations for first and last
                    HStack {
                        if let first = sessions.first {
                            Text(dateFmt.string(from: first.date))
                                .font(.system(size: 8)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let last = sessions.last {
                            Text(dateFmt.string(from: last.date))
                                .font(.system(size: 8)).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Recent trend direction
            if d.recentTrend != 0 {
                HStack(spacing: 6) {
                    Image(systemName: d.recentTrend > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(d.recentTrend > 0 ? HONTheme.positive : HONTheme.negative)
                    Text(String(format: "%@%.1f kg/session (last 4)", d.recentTrend > 0 ? "+" : "", d.recentTrend))
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background((d.recentTrend > 0 ? HONTheme.positive : HONTheme.negative).opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            }

            // Insight
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 11)).foregroundColor(HONTheme.chartAmber)
                Text(d.insight)
                    .font(.system(size: 12)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true).lineSpacing(2)
            }

            // Rep-range mismatch caveat
            if let note = d.repRangeNote {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11)).foregroundColor(HONTheme.warning)
                    Text(note)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true).lineSpacing(2)
                }
                .padding(10)
                .background(HONTheme.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(AppTheme.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func retStat(_ label: String, _ value: String, _ valueColor: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 14, weight: .bold)).foregroundColor(valueColor)
            Text(label).font(.system(size: 8, weight: .medium)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - COMPONENT 4: MomentumChipsCard

struct MomentumChipsCard: View {
    let exerciseAnalytics: [ExerciseAnalytics]
    @State private var detailAnalytics: ExerciseAnalytics? = nil

    private var qualified: [ExerciseAnalytics] {
        exerciseAnalytics.filter { $0.hasEnoughData }
    }

    private var bestMover: ExerciseAnalytics? {
        qualified.max(by: { $0.slopePerWeek < $1.slopePerWeek })
    }

    private var stale: ExerciseAnalytics? {
        qualified.filter { $0.isPlateau }
                 .min(by: { $0.slopePerWeek > $1.slopePerWeek })
    }

    private var opportunity: ExerciseAnalytics? {
        qualified.filter { $0.isPlateau }
                 .max(by: { $0.sessions.count < $1.sessions.count })
    }

    private func stalledWeeks(_ ea: ExerciseAnalytics) -> Int {
        let cutoff = Date().addingTimeInterval(-4 * 7 * 86400)
        let recent = ea.sessions.filter { $0.date >= cutoff }
        return recent.isEmpty ? 4 : max(1, recent.count)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Momentum")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    Text("What's moving, what's stuck")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                if qualified.isEmpty {
                    Text("Log more sessions to unlock this.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    VStack(spacing: 8) {
                        if let best = bestMover {
                            MomentumChip(
                                emoji: "🔥",
                                iconBG: HONTheme.positive.opacity(0.2),
                                title: "\(best.exercise.name) · Best Mover",
                                subtitle: "+\(String(format: "%.1f", best.slopePerWeek)) kg/wk · \(LiftPhase.classify(best).rawValue)"
                            ) {
                                detailAnalytics = best
                            }
                        }

                        if let st = stale {
                            let weeks = stalledWeeks(st)
                            MomentumChip(
                                emoji: "🧱",
                                iconBG: HONTheme.negative.opacity(0.2),
                                title: "\(st.exercise.name) · Stalled",
                                subtitle: "Flat for \(weeks) sessions · \(LiftPhase.classify(st).rawValue)"
                            ) {
                                detailAnalytics = st
                            }
                        }

                        if let opp = opportunity {
                            MomentumChip(
                                emoji: "🎯",
                                iconBG: HONTheme.chartAmber.opacity(0.2),
                                title: "Biggest Opportunity",
                                subtitle: "\(opp.exercise.name) is dragging your composite down"
                            ) {
                                detailAnalytics = opp
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(AppTheme.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
                .padding(14)
        }
        .sheet(item: $detailAnalytics) { ea in
            MomentumDetailSheet(analytics: ea)
        }
    }
}

private struct MomentumChip: View {
    let emoji: String
    let iconBG: Color
    let title: String
    let subtitle: String
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBG)
                    .frame(width: 36, height: 36)
                Text(emoji)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(10)
        .background(AppTheme.insetBG)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

struct MomentumDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let analytics: ExerciseAnalytics

    private var phase: LiftPhase { LiftPhase.classify(analytics) }

    private func phaseAdvice(_ p: LiftPhase) -> String {
        switch p {
        case .linearProgression:
            return "Keep doing what you're doing. Add weight when you can hit the top of your rep range for 2 sessions in a row."
        case .plateau:
            return "Try changing rep ranges, adding a deload week, or increasing frequency on this pattern."
        case .peaking:
            return "You're near a peak. Plan a PR attempt in the next 1–2 sessions, then follow with a deload."
        case .declining:
            return "Investigate recovery: sleep, nutrition, and total session volume. Consider reducing load by 10–15% for 2 weeks."
        case .deloading:
            return "Not enough data yet. Keep logging sessions to unlock trend insights."
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // e1RM Trend Chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("e1RM Trend")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal)

                        #if DEBUG
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DEBUG — \(analytics.exercise.name) · equip: \(analytics.exercise.equipment.rawValue) · \(analytics.sessions.count) sessions")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.orange)
                            ForEach(Array(analytics.sessions.enumerated()), id: \.offset) { idx, pt in
                                Text("[\(idx)] \(pt.date.formatted(.dateTime.month().day())) · e1RM=\(String(format:"%.1f",pt.estimated1RM))kg · w=\(String(format:"%.1f",pt.bestWeight))kg · r=\(pt.bestReps)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.horizontal)
                        #endif

                        if analytics.sessions.count >= 2 {
                            Chart {
                                ForEach(analytics.sessions) { pt in
                                    LineMark(
                                        x: .value("Date", pt.date),
                                        y: .value("e1RM (kg)", pt.estimated1RM)
                                    )
                                    .foregroundStyle(phase.color)
                                    .interpolationMethod(.catmullRom)

                                    PointMark(
                                        x: .value("Date", pt.date),
                                        y: .value("e1RM (kg)", pt.estimated1RM)
                                    )
                                    .foregroundStyle(phase.color)
                                    .symbolSize(30)
                                }
                            }
                            .chartYAxis {
                                AxisMarks { v in
                                    AxisValueLabel {
                                        if let kg = v.as(Double.self) {
                                            Text("\(Int(kg)) kg")
                                                .font(.system(size: 10))
                                        }
                                    }
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                    AxisValueLabel(format: .dateTime.month().day())
                                }
                            }
                            .frame(height: 180)
                            .padding(.horizontal)
                        } else {
                            Text("Log at least 2 sessions to see the trend.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                    }

                    // Stats row
                    HStack(spacing: 16) {
                        statPill(label: "Slope",
                                 value: analytics.slopePerWeek >= 0
                                     ? "+\(String(format: "%.1f", analytics.slopePerWeek)) kg/wk"
                                     : "\(String(format: "%.1f", analytics.slopePerWeek)) kg/wk")
                        statPill(label: "Phase", value: phase.rawValue)
                        statPill(label: "Sessions", value: "\(analytics.sessions.count)")
                    }
                    .padding(.horizontal)

                    // Phase explanation
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(phase.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(phase.color)
                            Spacer()
                        }
                        Text(phaseAdvice(phase))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(AppTheme.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Spacer(minLength: 32)
                }
                .padding(.top, 8)
            }
            .background(AppTheme.pageBG.ignoresSafeArea())
            .navigationTitle(analytics.exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(AppTheme.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - COMPONENT 5: OverloadScoreboardCard

struct OverloadScoreboardCard: View {
    let exerciseAnalytics: [ExerciseAnalytics]
    @State private var showDetail = false

    private static let sixWeekInterval: TimeInterval = 42 * 86_400

    private struct OverloadRow: Identifiable {
        let id: UUID
        let name: String
        let baselineE1RM: Double
        let currentE1RM: Double
        let gainKg: Double
        let gainPct: Double
    }

    // Returns the session closest to (but not after) 6 weeks ago;
    // falls back to first session when history is shorter than 6 weeks.
    private func sixWeekBaseline(_ ea: ExerciseAnalytics) -> SessionPoint? {
        let cutoff = Date().addingTimeInterval(-Self.sixWeekInterval)
        return ea.sessions.last(where: { $0.date <= cutoff }) ?? ea.sessions.first
    }

    private var rows: [OverloadRow] {
        exerciseAnalytics
            .filter { $0.sessions.count >= 2 }
            .compactMap { ea in
                guard let baseline = sixWeekBaseline(ea),
                      let current  = ea.sessions.last else { return nil }
                let gain = current.estimated1RM - baseline.estimated1RM
                let pct  = baseline.estimated1RM > 0 ? gain / baseline.estimated1RM : 0
                return OverloadRow(
                    id: ea.id,
                    name: ea.exercise.name,
                    baselineE1RM: baseline.estimated1RM,
                    currentE1RM: current.estimated1RM,
                    gainKg: gain,
                    gainPct: pct
                )
            }
            .sorted { $0.gainKg > $1.gainKg }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Progressive Overload")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    Text("e1RM vs 6 weeks ago")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                if rows.isEmpty {
                    Text("Log more sessions to unlock this.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(rows.prefix(5))) { row in
                            overloadRow(row)
                        }
                    }
                }
            }
            .padding(14)
            .background(AppTheme.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
                .padding(14)
        }
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            OverloadScoreboardDetailSheet(exerciseAnalytics: exerciseAnalytics)
        }
    }

    @ViewBuilder
    private func overloadRow(_ row: OverloadRow) -> some View {
        let barFill = min(row.gainPct / 0.30, 1.0)
        let barColor: Color = row.gainKg >= 0 ? HONTheme.positive : HONTheme.negative

        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text("\(Int(row.baselineE1RM)) → \(Int(row.currentE1RM)) kg")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(row.gainKg >= 0 ? "+\(String(format: "%.0f", row.gainKg)) kg" : "\(String(format: "%.0f", row.gainKg)) kg")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(barColor)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(barColor)
                            .frame(width: geo.size.width * CGFloat(max(0, barFill)))
                    }
                }
                .frame(width: 80, height: 5)
            }
        }
    }
}

struct OverloadScoreboardDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseAnalytics: [ExerciseAnalytics]

    private static let sixWeekInterval: TimeInterval = 42 * 86_400

    // MARK: - Data model
    struct OverloadDetail: Identifiable {
        let id: UUID
        let name: String
        let sessions: [SessionPoint]          // full history, oldest first
        let baselineE1RM: Double
        let currentE1RM: Double
        let gainKg: Double
        let gainPerWeek: Double
        let isFullHistory: Bool
        let momentum: MomentumKind
        let firstHalfSlope: Double            // kg/wk in first half of window
        let secondHalfSlope: Double           // kg/wk in second half of window
        let insight: String

        enum MomentumKind {
            case accelerating, steady, slowing, declining
            var label: String {
                switch self {
                case .accelerating: return "Accelerating"
                case .steady:       return "Steady"
                case .slowing:      return "Slowing"
                case .declining:    return "Declining"
                }
            }
            var icon: String {
                switch self {
                case .accelerating: return "arrow.up.right"
                case .steady:       return "arrow.right"
                case .slowing:      return "arrow.down.right"
                case .declining:    return "arrow.down"
                }
            }
            var color: Color {
                switch self {
                case .accelerating: return HONTheme.positive
                case .steady:       return HONTheme.chartSlate
                case .slowing:      return HONTheme.warning
                case .declining:    return HONTheme.negative
                }
            }
        }
    }

    // MARK: - Build helpers
    private func sixWeekBaseline(_ ea: ExerciseAnalytics) -> SessionPoint? {
        let cutoff = Date().addingTimeInterval(-Self.sixWeekInterval)
        return ea.sessions.last(where: { $0.date <= cutoff }) ?? ea.sessions.first
    }

    private func slope(of pts: [SessionPoint]) -> Double {
        guard pts.count >= 2 else { return 0 }
        let n  = Double(pts.count)
        let xs = pts.map { $0.date.timeIntervalSinceReferenceDate / 604_800 }   // weeks
        let ys = pts.map(\.estimated1RM)
        let mx = xs.reduce(0, +) / n
        let my = ys.reduce(0, +) / n
        let num = zip(xs, ys).reduce(0.0) { $0 + ($1.0 - mx) * ($1.1 - my) }
        let den = xs.reduce(0.0) { $0 + ($1 - mx) * ($1 - mx) }
        return den == 0 ? 0 : num / den
    }

    private func buildInsight(name: String, gain: Double, gpw: Double, momentum: OverloadDetail.MomentumKind, sessions: [SessionPoint]) -> String {
        let absGPW = abs(gpw)
        let n      = sessions.count
        switch momentum {
        case .accelerating:
            if absGPW > 2 {
                return "\(name) is surging — \(String(format: "%.1f", gpw)) kg/wk and still picking up speed. Maintain this frequency."
            } else {
                return "\(name) is gaining momentum. Each block is producing more than the last — a great sign of adaptive response."
            }
        case .steady:
            if gain > 0 {
                return "\(name) is progressing at a consistent \(String(format: "%.1f", gpw)) kg/wk. Reliable and sustainable — don't change what's working."
            } else {
                return "\(name) is holding steady. Consider adding a deload, then resuming with a slight load increase to break the plateau."
            }
        case .slowing:
            if n < 6 {
                return "\(name) growth is slowing, but you're still early in the data. More sessions will clarify the trend."
            } else {
                return "\(name) is decelerating. You may be approaching a near-term ceiling — a variation or intensity change could renew adaptation."
            }
        case .declining:
            if gain > 0 {
                return "\(name) gained overall but recently reversed. Check recent recovery — a short deload often restores upward momentum."
            } else {
                return "\(name) is trending down. Evaluate fatigue accumulation and prioritise quality over volume for the next 2–3 sessions."
            }
        }
    }

    private var details: [OverloadDetail] {
        exerciseAnalytics
            .filter { $0.sessions.count >= 2 }
            .compactMap { ea in
                guard let baseline = sixWeekBaseline(ea),
                      let current  = ea.sessions.last else { return nil }
                let cutoff      = Date().addingTimeInterval(-Self.sixWeekInterval)
                let isFullHist  = baseline.date > cutoff
                let windowPts   = ea.sessions.filter { $0.date >= baseline.date }
                let half        = max(1, windowPts.count / 2)
                let firstHalf   = Array(windowPts.prefix(half))
                let secondHalf  = Array(windowPts.suffix(half))
                let s1          = slope(of: firstHalf)
                let s2          = slope(of: secondHalf)
                let gain        = current.estimated1RM - baseline.estimated1RM
                let weeks       = max(1, current.date.timeIntervalSince(baseline.date) / 604_800)
                let gpw         = gain / weeks

                let momentum: OverloadDetail.MomentumKind
                let delta = s2 - s1
                if s2 < 0 {
                    momentum = .declining
                } else if delta > 0.3 {
                    momentum = .accelerating
                } else if delta < -0.3 {
                    momentum = .slowing
                } else {
                    momentum = .steady
                }

                let insight = buildInsight(name: ea.exercise.name, gain: gain, gpw: gpw, momentum: momentum, sessions: ea.sessions)

                return OverloadDetail(
                    id: ea.id,
                    name: ea.exercise.name,
                    sessions: ea.sessions,
                    baselineE1RM: baseline.estimated1RM,
                    currentE1RM: current.estimated1RM,
                    gainKg: gain,
                    gainPerWeek: gpw,
                    isFullHistory: isFullHist,
                    momentum: momentum,
                    firstHalfSlope: s1,
                    secondHalfSlope: s2,
                    insight: insight
                )
            }
            .sorted { $0.gainKg > $1.gainKg }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(details) { d in
                        OverloadDetailCard(detail: d)
                    }

                    // How to read
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Rolling 6-Week Window", systemImage: "info.circle")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Each lift is compared to your e1RM from 6 weeks ago. The chart shows every session so you can see not just how much you gained, but whether the rate is accelerating or slowing.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Divider().padding(.vertical, 4)
                        HStack(spacing: 12) {
                            momentumLegendItem(.accelerating)
                            momentumLegendItem(.steady)
                            momentumLegendItem(.slowing)
                            momentumLegendItem(.declining)
                        }
                    }
                    .padding(14)
                    .background(AppTheme.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Spacer(minLength: 32)
                }
                .padding(.top, 8)
            }
            .background(AppTheme.pageBG.ignoresSafeArea())
            .navigationTitle("Progressive Overload")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func momentumLegendItem(_ kind: OverloadDetail.MomentumKind) -> some View {
        HStack(spacing: 3) {
            Image(systemName: kind.icon).font(.system(size: 9)).foregroundStyle(kind.color)
            Text(kind.label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Per-exercise overload card
private struct OverloadDetailCard: View {
    let detail: OverloadScoreboardDetailSheet.OverloadDetail

    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()

    private var gainColor: Color { detail.gainKg >= 0 ? HONTheme.positive : HONTheme.negative }

    // Chart y-domain padded
    private var yMin: Double {
        let v = detail.sessions.map(\.estimated1RM).min() ?? 0
        return max(0, v - 5)
    }
    private var yMax: Double {
        let v = detail.sessions.map(\.estimated1RM).max() ?? 100
        return v + 5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                Text(detail.name)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                momentumBadge
            }

            // Stat chips row
            HStack(spacing: 0) {
                statChip(label: "BASELINE", value: "\(Int(detail.baselineE1RM)) kg")
                Divider().frame(height: 28)
                statChip(label: "NOW", value: "\(Int(detail.currentE1RM)) kg")
                Divider().frame(height: 28)
                statChip(
                    label: "GAIN",
                    value: detail.gainKg >= 0 ? "+\(String(format: "%.1f", detail.gainKg))" : String(format: "%.1f", detail.gainKg),
                    valueColor: gainColor
                )
                Divider().frame(height: 28)
                statChip(
                    label: "RATE",
                    value: String(format: "%.2f kg/wk", detail.gainPerWeek),
                    valueColor: gainColor
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.systemGray6).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Full trajectory chart
            Chart {
                ForEach(detail.sessions) { pt in
                    AreaMark(
                        x: .value("Date", pt.date),
                        yStart: .value("Base", yMin),
                        yEnd: .value("e1RM", pt.estimated1RM)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [gainColor.opacity(0.25), gainColor.opacity(0.03)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value("e1RM", pt.estimated1RM)
                    )
                    .foregroundStyle(gainColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Date", pt.date),
                        y: .value("e1RM", pt.estimated1RM)
                    )
                    .foregroundStyle(gainColor)
                    .symbolSize(28)
                }

                // Baseline reference line
                RuleMark(y: .value("Baseline", detail.baselineE1RM))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .trailing, alignment: .center) {
                        Text("start")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
            }
            .chartYScale(domain: yMin...yMax)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { val in
                    AxisValueLabel {
                        if let d = val.as(Date.self) {
                            Text(dateFmt.string(from: d))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { val in
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            Text("\(Int(v))")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                }
            }
            .frame(height: 120)

            // Momentum comparison bar
            momentumBar

            // Insight
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(HONTheme.warning)
                Text(detail.insight)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(AppTheme.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Subviews
    private var momentumBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: detail.momentum.icon)
                .font(.system(size: 11, weight: .semibold))
            Text(detail.momentum.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(detail.momentum.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(detail.momentum.color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var momentumBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RATE MOMENTUM")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.5)
            HStack(spacing: 6) {
                rateSegment(label: "First half", slope: detail.firstHalfSlope)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                rateSegment(label: "Second half", slope: detail.secondHalfSlope)
            }
        }
    }

    private func rateSegment(label: String, slope: Double) -> some View {
        let color: Color = slope > 0.2 ? HONTheme.positive : slope < -0.2 ? HONTheme.negative : .secondary
        return VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(String(format: "%+.2f kg/wk", slope))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func statChip(label: String, value: String, valueColor: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.4)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - COMPONENT 6: PlateauRiskCard

struct PlateauRiskCard: View {
    let exerciseAnalytics: [ExerciseAnalytics]
    @State private var showDetail = false

    private func riskScore(_ ea: ExerciseAnalytics) -> Int {
        guard ea.hasEnoughData else { return 0 }
        var score = 0
        if ea.isPlateau { score += 50 }
        if ea.slopePerWeek < 0 { score += 25 }
        else if ea.slopePerWeek < 0.3 { score += 15 }
        let recentSessions = ea.sessions.suffix(4)
        if recentSessions.count >= 4 {
            let e1rms = recentSessions.map(\.estimated1RM)
            let spread = (e1rms.max() ?? 0) - (e1rms.min() ?? 0)
            if spread < 2.5 { score += 25 }
        }
        return min(score, 100)
    }

    private func riskLabel(_ score: Int) -> String {
        if score <= 25 { return "Low" }
        if score <= 55 { return "Moderate" }
        return "High"
    }

    private func riskColor(_ score: Int) -> Color {
        if score <= 25 { return HONTheme.positive }
        if score <= 55 { return HONTheme.warning }
        return HONTheme.negative
    }

    private var qualifiedItems: [ExerciseAnalytics] {
        exerciseAnalytics.filter { $0.hasEnoughData }.prefix(6).map { $0 }
    }

    private func trainingFrequencyCompact(_ ea: ExerciseAnalytics) -> Double {
        let cutoff = Date().addingTimeInterval(-6 * 7 * 86400)
        let count = ea.sessions.filter { $0.date >= cutoff }.count
        return Double(count) / 6.0
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plateau Risk")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Based on velocity & session variance")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                if qualifiedItems.isEmpty {
                    Text("Log more sessions to unlock this.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(qualifiedItems) { ea in
                                let score = riskScore(ea)
                                let color = riskColor(score)
                                let label = riskLabel(score)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(ea.exercise.name.prefix(12).uppercased())
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)

                                    Text("\(score)")
                                        .font(.system(size: 28, weight: .heavy))
                                        .foregroundColor(color)

                                    Text(label)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(color)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(color.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                .padding(12)
                                .frame(width: 90, alignment: .leading)
                                .background(AppTheme.insetBG)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }

                    // Surfaced callout when any lift is high-risk
                    if qualifiedItems.map({ riskScore($0) }).contains(where: { $0 > 55 }) {
                        let stalledLowFreq = qualifiedItems.filter { ea in
                            riskScore(ea) > 55 && trainingFrequencyCompact(ea) < 1.5
                        }
                        HStack(spacing: 8) {
                            Image(systemName: stalledLowFreq.isEmpty ? "lightbulb.fill" : "calendar.badge.exclamationmark")
                                .font(.system(size: 11))
                                .foregroundColor(HONTheme.warning)
                            if stalledLowFreq.isEmpty {
                                Text("One or more lifts are stalled. Tap for deload and variation suggestions.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            } else {
                                let names = stalledLowFreq.prefix(2).map { $0.exercise.name }.joined(separator: ", ")
                                Text("\(names): stalled and trained <1.5×/week. Tap — frequency may be the fix.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(HONTheme.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(14)
            .background(AppTheme.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
                .padding(14)
        }
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            PlateauRiskDetailSheet(exerciseAnalytics: exerciseAnalytics)
        }
    }
}

struct PlateauRiskDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseAnalytics: [ExerciseAnalytics]

    private func riskScore(_ ea: ExerciseAnalytics) -> Int {
        guard ea.hasEnoughData else { return 0 }
        var score = 0
        if ea.isPlateau { score += 50 }
        if ea.slopePerWeek < 0 { score += 25 }
        else if ea.slopePerWeek < 0.3 { score += 15 }
        let recentSessions = ea.sessions.suffix(4)
        if recentSessions.count >= 4 {
            let e1rms = recentSessions.map(\.estimated1RM)
            let spread = (e1rms.max() ?? 0) - (e1rms.min() ?? 0)
            if spread < 2.5 { score += 25 }
        }
        return min(score, 100)
    }

    private func riskLabel(_ score: Int) -> String {
        if score <= 25 { return "Low" }
        if score <= 55 { return "Moderate" }
        return "High"
    }

    private func riskColor(_ score: Int) -> Color {
        if score <= 25 { return HONTheme.positive }
        if score <= 55 { return HONTheme.warning }
        return HONTheme.negative
    }

    // Sessions per week averaged over the last 6 weeks
    private func trainingFrequency(_ ea: ExerciseAnalytics) -> Double {
        let cutoff = Date().addingTimeInterval(-6 * 7 * 86400)
        let count = ea.sessions.filter { $0.date >= cutoff }.count
        return Double(count) / 6.0
    }

    private func frequencyLabel(_ freq: Double) -> String {
        if freq < 0.25 { return "<1×/month" }
        let rounded = (freq * 10).rounded() / 10
        return String(format: "%.1f×/week", rounded)
    }

    // Returns a coaching string when frequency is actionable relative to plateau risk
    private func frequencyInsight(_ ea: ExerciseAnalytics, score: Int, freq: Double) -> String? {
        guard score > 25 else { return nil }
        if freq < 1.5 {
            let label = frequencyLabel(freq)
            return "You train this \(label) on average. Research consistently shows ≥2×/week is the frequency floor for consistent strength gains. Adding one session per week is often the fastest lever when a lift stalls — even a short 2-set top-set counts."
        }
        if freq >= 2.0 && score > 55 {
            let label = frequencyLabel(freq)
            return "You're already hitting this \(label) — frequency isn't the bottleneck. Focus on variation or a deload first (options A–B above)."
        }
        return nil
    }

    private func riskRecommendation(_ score: Int, freq: Double) -> String {
        let lowFreq = freq < 1.5
        if score <= 25 {
            return "Progressing well. Keep doing what you're doing — consistency is the engine of progress."
        }
        if score <= 55 {
            if lowFreq {
                return "Early warning. Best levers in order: (A) add a second session per week on this pattern — even a short top-set counts; (B) shift rep range for 3 weeks (e.g. 3×8 → 4×5 or 3×12); (C) run a planned deload at 50% volume, then restart."
            }
            return "Early warning. Try one of: (A) shift rep range for 3 weeks (e.g. 3×8 → 4×5 or 3×12); (B) run a planned deload at 50% volume, then restart; (C) add a variation (e.g. pause reps, tempo work) for 3–4 weeks."
        }
        if lowFreq {
            return "Adaptation has stalled. Recommended actions in order: (A) Add a second session per week — frequency is your biggest gap; (B) Deload this week — cut volume to 50% and intensity to 80%; (C) After deload, change the rep scheme (e.g. 5×5 instead of 3×8); (D) Check sleep — 3+ consecutive tired sessions is a recovery signal, not a training problem."
        }
        return "Adaptation has stalled. Recommended actions in order: (A) Deload this week — cut volume to 50% and intensity to 80%; (B) After deload, change the rep scheme (e.g. 5×5 instead of 3×8); (C) Check sleep — 3+ consecutive tired sessions is a recovery signal, not a training problem; (D) If stalled >6 weeks, consider a variation swap (e.g. pause squat, close-grip bench) for a 4-week block."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(exerciseAnalytics.filter { $0.hasEnoughData }) { ea in
                        let score = riskScore(ea)
                        let color = riskColor(score)
                        let label = riskLabel(score)
                        let freq  = trainingFrequency(ea)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(ea.exercise.name)
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Text("\(score)")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(color)
                                Text(label)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(color.opacity(0.15))
                                    .clipShape(Capsule())
                            }

                            // Training frequency stat
                            HStack(spacing: 6) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 12))
                                    .foregroundColor(freq < 1.5 && score > 25 ? HONTheme.warning : .secondary)
                                Text("Training frequency:")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text(frequencyLabel(freq))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(freq < 1.5 && score > 25 ? HONTheme.warning : HONTheme.textPrimary)
                                Text("(last 6 wks)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            // Risk factors
                            VStack(alignment: .leading, spacing: 4) {
                                riskFactorRow(
                                    active: ea.isPlateau,
                                    label: "Stalled velocity (slope < 0.5 kg/wk over 4 weeks)",
                                    points: 50
                                )
                                riskFactorRow(
                                    active: ea.slopePerWeek < 0,
                                    label: "Negative slope — currently declining",
                                    points: 25
                                )
                                riskFactorRow(
                                    active: ea.slopePerWeek >= 0 && ea.slopePerWeek < 0.3,
                                    label: "Very slow positive velocity (<0.3 kg/wk)",
                                    points: 15
                                )
                                let recentE1rms = ea.sessions.suffix(4).map(\.estimated1RM)
                                let spread = (recentE1rms.max() ?? 0) - (recentE1rms.min() ?? 0)
                                riskFactorRow(
                                    active: ea.sessions.suffix(4).count >= 4 && spread < 2.5,
                                    label: "Low recent e1RM variance (<2.5 kg spread in last 4 sessions)",
                                    points: 25
                                )
                            }

                            Text(riskRecommendation(score, freq: freq))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            // Frequency coaching callout
                            if let insight = frequencyInsight(ea, score: score, freq: freq) {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 12))
                                        .foregroundColor(freq < 1.5 ? HONTheme.warning : HONTheme.chartSage)
                                        .padding(.top, 1)
                                    Text(insight)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(10)
                                .background(
                                    (freq < 1.5 ? HONTheme.warning : HONTheme.chartSage).opacity(0.07),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                            }
                        }
                        .padding(14)
                        .background(AppTheme.cardBG)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 32)
                }
                .padding(.top, 8)
            }
            .background(AppTheme.pageBG.ignoresSafeArea())
            .navigationTitle("Plateau Risk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func riskFactorRow(active: Bool, label: String, points: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: active ? "exclamationmark.circle.fill" : "checkmark.circle")
                .foregroundColor(active ? HONTheme.warning : .secondary)
                .font(.system(size: 13))
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(active ? HONTheme.textPrimary : .secondary)
            Spacer()
            if active {
                Text("+\(points)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(HONTheme.warning)
            }
        }
    }
}

// MARK: - COMPONENT 7: PRWindowForecastCard

struct PRWindowForecastCard: View {
    let exerciseAnalytics: [ExerciseAnalytics]
    @State private var showDetail = false

    private struct ForecastItem: Identifiable {
        let id: UUID
        let name: String
        let currentPeak: Double
        let currentE1RM: Double
        let targetE1RM: Double
        let weeksToNext: Double?
        let confidence: Double
        let slope: Double
        let isDeclining: Bool
    }

    private func confidence(for ea: ExerciseAnalytics) -> Double {
        let recentE1RMs = ea.sessions.suffix(4).map(\.estimated1RM)
        guard recentE1RMs.count >= 2 else { return 0.6 }
        let mean = recentE1RMs.reduce(0, +) / Double(recentE1RMs.count)
        let variance = recentE1RMs.map { pow($0 - mean, 2) }.reduce(0, +) / Double(recentE1RMs.count)
        let cv = mean > 0 ? sqrt(variance) / mean : 1.0
        return max(0.4, min(0.95, 1.0 - cv * 2))
    }

    private var forecastItems: [ForecastItem] {
        exerciseAnalytics
            .filter { $0.sessions.count >= 3 && ($0.slopePerWeek > 0 || riskScoreHigh($0)) }
            .prefix(4)
            .map { ea in
                let peak      = ea.sessions.map(\.estimated1RM).max() ?? 0
                let current   = ea.sessions.last?.estimated1RM ?? 0
                let target    = peak * 1.01
                let weeks: Double? = ea.slopePerWeek > 0.1
                    ? (target - current) / ea.slopePerWeek
                    : nil
                return ForecastItem(
                    id: ea.id,
                    name: ea.exercise.name,
                    currentPeak: peak,
                    currentE1RM: current,
                    targetE1RM: target,
                    weeksToNext: weeks,
                    confidence: confidence(for: ea),
                    slope: ea.slopePerWeek,
                    isDeclining: ea.slopePerWeek <= 0
                )
            }
    }

    private func riskScoreHigh(_ ea: ExerciseAnalytics) -> Bool {
        guard ea.hasEnoughData else { return false }
        return ea.isPlateau || ea.slopePerWeek < 0
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PR Windows")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    Text("When your next personal records are within reach")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                if forecastItems.isEmpty {
                    Text("Log more sessions to unlock this.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    let columns = [GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(forecastItems) { item in
                            if item.isDeclining {
                                decliningCard(item)
                            } else if let weeks = item.weeksToNext, weeks <= 8 {
                                primedCard(item, weeks: weeks)
                            } else {
                                noWindowCard(item)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(AppTheme.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
                .padding(14)
        }
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            PRWindowForecastDetailSheet(exerciseAnalytics: exerciseAnalytics)
        }
    }

    @ViewBuilder
    private func primedCard(_ item: ForecastItem, weeks: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(HONTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text("PRIMED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(HONTheme.textPrimary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(HONTheme.positive)
                    .clipShape(Capsule())
            }
            Text(String(format: "%.1f kg target", item.targetE1RM))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(HONTheme.textPrimary)
            Text("~\(Int(weeks)) weeks · \(Int(item.confidence * 100))% confidence")
                .font(.system(size: 11))
                .foregroundColor(HONTheme.textPrimary.opacity(0.7))
        }
        .padding(12)
        .background(
            LinearGradient(colors: [HONTheme.chartSlate, HONTheme.chartLavender],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func noWindowCard(_ item: ForecastItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
            }
            Text(String(format: "%.1f kg target", item.targetE1RM))
                .font(.system(size: 13, weight: .bold))
            Text(item.slope > 0 ? "Window > 8 weeks out" : "Slope too slow to forecast")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(AppTheme.insetBG)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func decliningCard(_ item: ForecastItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(HONTheme.negative)
                    .font(.system(size: 11))
                Text(item.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            Text("Lift is declining")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(HONTheme.negative)
            Text("Consider a deload week")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(HONTheme.negative.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PRWindowForecastDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseAnalytics: [ExerciseAnalytics]

    private func confidence(for ea: ExerciseAnalytics) -> Double {
        let recentE1RMs = ea.sessions.suffix(4).map(\.estimated1RM)
        guard recentE1RMs.count >= 2 else { return 0.6 }
        let mean = recentE1RMs.reduce(0, +) / Double(recentE1RMs.count)
        let variance = recentE1RMs.map { pow($0 - mean, 2) }.reduce(0, +) / Double(recentE1RMs.count)
        let cv = mean > 0 ? sqrt(variance) / mean : 1.0
        return max(0.4, min(0.95, 1.0 - cv * 2))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(exerciseAnalytics.filter { $0.sessions.count >= 3 }) { ea in
                        prDetailRow(ea)
                    }

                    // Methodology
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Methodology")
                            .font(.system(size: 14, weight: .semibold))
                        Text("PR windows are forecast using linear extrapolation from your recent e1RM slope (kg/week). The confidence score is derived from the consistency (coefficient of variation) of your recent e1RM values — a smoother trend = higher confidence.\n\nA 1% buffer above your current peak is used as the target to account for daily variance.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(AppTheme.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Spacer(minLength: 32)
                }
                .padding(.top, 8)
            }
            .background(AppTheme.pageBG.ignoresSafeArea())
            .navigationTitle("PR Windows")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func prDetailRow(_ ea: ExerciseAnalytics) -> some View {
        let peak   = ea.sessions.map(\.estimated1RM).max() ?? 0
        let curr   = ea.sessions.last?.estimated1RM ?? 0
        let target = peak * 1.01
        let conf   = confidence(for: ea)
        let weeks: Double? = ea.slopePerWeek > 0.1
            ? (target - curr) / ea.slopePerWeek
            : nil

        VStack(alignment: .leading, spacing: 10) {
            Text(ea.exercise.name)
                .font(.system(size: 15, weight: .semibold))

            if ea.prProgression.count >= 2 {
                prStepChart(ea.prProgression)
            }

            prStatsRow(curr: curr, target: target, weeks: weeks, conf: conf)
        }
        .padding(14)
        .background(AppTheme.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func prStepChart(_ progression: [PRPoint]) -> some View {
        Chart {
            ForEach(progression) { pr in
                LineMark(
                    x: .value("Date", pr.date),
                    y: .value("e1RM", pr.estimated1RM)
                )
                .foregroundStyle(HONTheme.positive)
                .interpolationMethod(.stepEnd)

                PointMark(
                    x: .value("Date", pr.date),
                    y: .value("e1RM", pr.estimated1RM)
                )
                .foregroundStyle(HONTheme.positive)
                .symbolSize(40)
            }
        }
        .chartYAxis {
            AxisMarks { v in
                AxisValueLabel {
                    if let kg = v.as(Double.self) {
                        Text("\(Int(kg)) kg").font(.system(size: 10))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
        .frame(height: 140)
    }

    @ViewBuilder
    private func prStatsRow(curr: Double, target: Double, weeks: Double?, conf: Double) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Current e1RM")
                    .font(.system(size: 10)).foregroundColor(.secondary)
                Text(String(format: "%.1f kg", curr))
                    .font(.system(size: 13, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Target PR")
                    .font(.system(size: 10)).foregroundColor(.secondary)
                Text(String(format: "%.1f kg", target))
                    .font(.system(size: 13, weight: .bold)).foregroundColor(HONTheme.positive)
            }
            if let w = weeks {
                VStack(alignment: .leading, spacing: 1) {
                    Text("ETA")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                    Text("~\(Int(w)) wk")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(HONTheme.accent)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Confidence")
                    .font(.system(size: 10)).foregroundColor(.secondary)
                Text("\(Int(conf * 100))%")
                    .font(.system(size: 13, weight: .bold))
            }
        }
    }
}

// MARK: - COMPONENT 8: VolumeHeatmapCard

struct VolumeHeatmapCard: View {
    let log: [WorkoutLogEntry]
    @State private var showDetail = false

    private let groups = ["Push", "Pull", "Hinge", "Legs", "Arms"]

    private func muscleGroup(for pattern: MovementPattern) -> String? {
        switch pattern {
        case .horizontalPush, .verticalPush: return "Push"
        case .horizontalPull, .verticalPull: return "Pull"
        case .hipHinge:                       return "Hinge"
        case .kneeFlexion:                    return "Legs"
        case .isolation:                      return "Arms"
        }
    }

    private func weeklySetCounts() -> [String: [Int]] {
        let cal = Calendar.current
        let now = Date()
        var counts: [String: [Int]] = [:]
        for g in groups { counts[g] = Array(repeating: 0, count: 6) }
        for entry in log {
            let comps = cal.dateComponents([.weekOfYear], from: entry.startedAt, to: now)
            let weeksAgo = comps.weekOfYear ?? 99
            guard weeksAgo < 6 else { continue }
            let weekIdx = 5 - weeksAgo
            for we in entry.exercises {
                if let g = muscleGroup(for: we.exercise.movementPattern) {
                    counts[g]?[weekIdx] += we.completedSets.count
                }
            }
        }
        return counts
    }

    // Volume zones: rest / undertraining / maintenance / optimal / peak
    private func cellColor(sets: Int) -> Color {
        switch sets {
        case 0:       return Color(.systemGray6).opacity(0.4)
        case 1...4:   return HONTheme.warning.opacity(0.25)
        case 5...9:   return HONTheme.chartSlate.opacity(0.45)
        case 10...19: return HONTheme.chartSage.opacity(0.65)
        default:      return HONTheme.chartSage.opacity(0.9)
        }
    }

    // Amber ring when a group is below hypertrophy threshold (< 5 sets/wk)
    private func showUndertrained(sets: Int) -> Bool { sets >= 1 && sets <= 4 }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Volume Heatmap")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Sets per muscle group per week")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                let counts = weeklySetCounts()

                // Week header
                HStack(spacing: 4) {
                    Text("")
                        .frame(width: 42)
                    ForEach(0..<6, id: \.self) { w in
                        Text("Wk \(w + 1)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                ForEach(groups, id: \.self) { group in
                    HStack(spacing: 4) {
                        Text(group)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 42, alignment: .leading)

                        ForEach(0..<6, id: \.self) { week in
                            let sets = counts[group]?[week] ?? 0
                            GeometryReader { geo in
                                let size = min(geo.size.width, geo.size.height)
                                ZStack {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(cellColor(sets: sets))
                                    if showUndertrained(sets: sets) {
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(HONTheme.warning.opacity(0.6), lineWidth: 1)
                                    }
                                    if sets > 0 {
                                        Text("\(sets)")
                                            .font(.system(size: min(size * 0.45, 9)))
                                            .foregroundColor(HONTheme.textPrimary)
                                    }
                                }
                            }
                            .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
            .padding(14)
            .background(AppTheme.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
                .padding(14)
        }
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            VolumeHeatmapDetailSheet(log: log)
        }
    }
}

struct VolumeHeatmapDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let log: [WorkoutLogEntry]

    private let groups = ["Push", "Pull", "Hinge", "Legs", "Arms"]

    private func muscleGroup(for pattern: MovementPattern) -> String? {
        switch pattern {
        case .horizontalPush, .verticalPush: return "Push"
        case .horizontalPull, .verticalPull: return "Pull"
        case .hipHinge:                       return "Hinge"
        case .kneeFlexion:                    return "Legs"
        case .isolation:                      return "Arms"
        }
    }

    private func weeklySetCounts() -> [String: [Int]] {
        let cal = Calendar.current
        let now = Date()
        var counts: [String: [Int]] = [:]
        for g in groups { counts[g] = Array(repeating: 0, count: 6) }
        for entry in log {
            let comps = cal.dateComponents([.weekOfYear], from: entry.startedAt, to: now)
            let weeksAgo = comps.weekOfYear ?? 99
            guard weeksAgo < 6 else { continue }
            let weekIdx = 5 - weeksAgo
            for we in entry.exercises {
                if let g = muscleGroup(for: we.exercise.movementPattern) {
                    counts[g]?[weekIdx] += we.completedSets.count
                }
            }
        }
        return counts
    }

    private func cellColor(sets: Int) -> Color {
        switch sets {
        case 0:       return Color(.systemGray6).opacity(0.4)
        case 1...4:   return HONTheme.warning.opacity(0.25)
        case 5...9:   return HONTheme.chartSlate.opacity(0.45)
        case 10...19: return HONTheme.chartSage.opacity(0.65)
        default:      return HONTheme.chartSage.opacity(0.9)
        }
    }

    private func showUndertrained(sets: Int) -> Bool { sets >= 1 && sets <= 4 }

    private func currentWeekSets(_ counts: [String: [Int]], group: String) -> Int {
        counts[group]?.last ?? 0
    }

    private func groupCommentary(sets: Int) -> String {
        if sets == 0 { return "No training logged this week." }
        if sets < 5  { return "Below minimum effective volume (10+ sets for hypertrophy)." }
        if sets < 10 { return "Moderate volume. Consider adding a set or two." }
        if sets <= 20 { return "Good working volume. Solid stimulus for adaptation." }
        return "High volume. Monitor for recovery issues."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    let counts = weeklySetCounts()

                    // Full-size heatmap
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("").frame(width: 52)
                            ForEach(0..<6, id: \.self) { w in
                                Text("Wk \(w + 1)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        ForEach(groups, id: \.self) { group in
                            HStack(spacing: 4) {
                                Text(group)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 52, alignment: .leading)

                                ForEach(0..<6, id: \.self) { week in
                                    let sets = counts[group]?[week] ?? 0
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(cellColor(sets: sets))
                                        if showUndertrained(sets: sets) {
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(HONTheme.warning.opacity(0.6), lineWidth: 1)
                                        }
                                        if sets > 0 {
                                            Text("\(sets)")
                                                .font(.system(size: 9))
                                                .foregroundColor(HONTheme.textPrimary)
                                        }
                                    }
                                    .frame(height: 32)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(AppTheme.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Legend")
                            .font(.system(size: 14, weight: .semibold))
                        HStack(spacing: 12) {
                            legendSwatch(color: Color.blue.opacity(0.05), label: "0 sets")
                            legendSwatch(color: Color.blue.opacity(0.2),  label: "1–5")
                            legendSwatch(color: Color.blue.opacity(0.45), label: "6–10")
                            legendSwatch(color: Color.blue.opacity(0.7),  label: "11–15")
                            legendSwatch(color: Color.blue.opacity(0.9),  label: "16+")
                        }
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(HONTheme.accent.opacity(0.1))
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(HONTheme.negative, lineWidth: 1))
                                .frame(width: 20, height: 14)
                            Text("Red border = below minimum effective volume (1–4 sets)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(AppTheme.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Guidance
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minimum Effective Volume")
                            .font(.system(size: 14, weight: .semibold))
                        Text("10+ sets per muscle group per week is the research-backed minimum for meaningful hypertrophy (Schoenfeld et al., 2017). Below this threshold, stimulus is insufficient for consistent muscle growth.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(AppTheme.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Per-group commentary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This Week")
                            .font(.system(size: 14, weight: .semibold))
                        ForEach(groups, id: \.self) { group in
                            let sets = currentWeekSets(counts, group: group)
                            HStack {
                                Text(group)
                                    .font(.system(size: 13, weight: .medium))
                                    .frame(width: 52, alignment: .leading)
                                Text(groupCommentary(sets: sets))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(sets) sets")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(sets >= 10 ? HONTheme.positive : sets > 0 ? HONTheme.warning : .secondary)
                            }
                        }
                    }
                    .padding(14)
                    .background(AppTheme.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Spacer(minLength: 32)
                }
                .padding(.top, 8)
            }
            .background(AppTheme.pageBG.ignoresSafeArea())
            .navigationTitle("Volume Heatmap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func legendSwatch(color: Color, label: String) -> some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 20, height: 14)
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - COMPONENT 9: INOLCalendarCard

struct INOLCalendarCard: View {
    let log: [WorkoutLogEntry]
    @State private var showDetail = false

    private func dailyINOL() -> [Date: Double] {
        var result: [Date: Double] = [:]
        let cal = Calendar.current
        for entry in log {
            let day = cal.startOfDay(for: entry.startedAt)
            var dayINOL = 0.0
            for we in entry.exercises {
                for set in we.completedSets {
                    guard set.reps > 0 else { continue }
                    let intensityPct: Double
                    switch set.reps {
                    case 1...3:   intensityPct = 90.0
                    case 4...5:   intensityPct = 85.0
                    case 6...8:   intensityPct = 75.0
                    case 9...12:  intensityPct = 65.0
                    default:      intensityPct = 55.0
                    }
                    dayINOL += Double(set.reps) / (100.0 - intensityPct)
                }
            }
            result[day, default: 0] += dayINOL
        }
        return result
    }

    private func inolColor(_ inol: Double) -> Color {
        if inol == 0  { return Color(.systemGray6).opacity(0.2)  }
        if inol < 0.4 { return HONTheme.chartSlate.opacity(0.2)  }
        if inol < 0.8 { return HONTheme.chartSlate.opacity(0.5)  }
        if inol < 1.4 { return HONTheme.chartSage.opacity(0.75)  }
        if inol < 2.0 { return HONTheme.warning.opacity(0.75)    }
        return HONTheme.negative.opacity(0.85)
    }

    // Builds a 13-week grid (91 days), oldest first
    private func gridDays() -> [[Date?]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Find Monday of the current week
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        comps.weekday = 2  // Monday
        let thisMonday = cal.date(from: comps) ?? today

        // Start 13 weeks ago (Mon)
        let startMonday = cal.date(byAdding: .weekOfYear, value: -12, to: thisMonday) ?? thisMonday

        var weeks: [[Date?]] = []
        for w in 0..<13 {
            var week: [Date?] = []
            for d in 0..<7 {
                let offset = w * 7 + d
                if let day = cal.date(byAdding: .day, value: offset, to: startMonday) {
                    week.append(day <= today ? day : nil)
                } else {
                    week.append(nil)
                }
            }
            weeks.append(week)
        }
        return weeks
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Training Load (INOL)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Intensity × volume per day")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                let inol  = dailyINOL()
                let grid  = gridDays()
                let days  = ["M", "T", "W", "T", "F", "S", "S"]

                // Day headers
                HStack(spacing: 3) {
                    Text("").frame(width: 28)
                    ForEach(days.indices, id: \.self) { i in
                        Text(days[i])
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                ForEach(grid.indices, id: \.self) { wk in
                    HStack(spacing: 3) {
                        Text("Wk \(wk + 1)")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .frame(width: 28, alignment: .leading)

                        ForEach(0..<7, id: \.self) { d in
                            if let day = grid[wk][d] {
                                let v = inol[day] ?? 0
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(inolColor(v))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 12)
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 12)
                            }
                        }
                    }
                }

                // Inline INOL context
                Text("INOL = Reps ÷ (100 − %1RM). Optimal zone (green) drives best adaptation. Tap for zone guide.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Legend
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        inolLegendItem(color: Color(.systemGray6).opacity(0.2),   label: "Rest")
                        inolLegendItem(color: HONTheme.chartSlate.opacity(0.2),   label: "Low")
                        inolLegendItem(color: HONTheme.chartSlate.opacity(0.5),   label: "Moderate")
                        inolLegendItem(color: HONTheme.chartSage.opacity(0.75),   label: "Optimal")
                        inolLegendItem(color: HONTheme.warning.opacity(0.75),     label: "Heavy")
                        inolLegendItem(color: HONTheme.negative.opacity(0.85),    label: "Overreach")
                    }
                }
            }
            .padding(14)
            .background(AppTheme.cardBG)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
                .padding(14)
        }
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            INOLCalendarDetailSheet(log: log)
        }
    }

    @ViewBuilder
    private func inolLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

struct INOLCalendarDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let log: [WorkoutLogEntry]

    private func dailyINOL() -> [Date: Double] {
        var result: [Date: Double] = [:]
        let cal = Calendar.current
        for entry in log {
            let day = cal.startOfDay(for: entry.startedAt)
            var dayINOL = 0.0
            for we in entry.exercises {
                for set in we.completedSets {
                    guard set.reps > 0 else { continue }
                    let intensityPct: Double
                    switch set.reps {
                    case 1...3:   intensityPct = 90.0
                    case 4...5:   intensityPct = 85.0
                    case 6...8:   intensityPct = 75.0
                    case 9...12:  intensityPct = 65.0
                    default:      intensityPct = 55.0
                    }
                    dayINOL += Double(set.reps) / (100.0 - intensityPct)
                }
            }
            result[day, default: 0] += dayINOL
        }
        return result
    }

    private func inolColor(_ inol: Double) -> Color {
        if inol == 0  { return Color(.systemGray6).opacity(0.2) }
        if inol < 0.4 { return Color.green.opacity(0.2) }
        if inol < 0.8 { return Color.green.opacity(0.5) }
        if inol < 1.4 { return Color.blue.opacity(0.7) }
        if inol < 2.0 { return Color.orange.opacity(0.8) }
        return Color.red.opacity(0.9)
    }

    private func inolZoneLabel(_ inol: Double) -> String {
        if inol == 0  { return "Rest" }
        if inol < 0.4 { return "Low" }
        if inol < 0.8 { return "Moderate" }
        if inol < 1.4 { return "Optimal" }
        if inol < 2.0 { return "Heavy" }
        return "Overreaching"
    }

    private func gridDays() -> [[Date?]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        comps.weekday = 2
        let thisMonday = cal.date(from: comps) ?? today
        let startMonday = cal.date(byAdding: .weekOfYear, value: -12, to: thisMonday) ?? thisMonday

        var weeks: [[Date?]] = []
        for w in 0..<13 {
            var week: [Date?] = []
            for d in 0..<7 {
                let offset = w * 7 + d
                if let day = cal.date(byAdding: .day, value: offset, to: startMonday) {
                    week.append(day <= today ? day : nil)
                } else {
                    week.append(nil)
                }
            }
            weeks.append(week)
        }
        return weeks
    }

    // Count days in each zone over last 4 weeks
    private func zoneCounts(inol: [Date: Double]) -> [String: Int] {
        let cal    = Calendar.current
        let cutoff = cal.date(byAdding: .weekOfYear, value: -4, to: Date()) ?? Date()
        var counts = ["Rest": 0, "Low": 0, "Moderate": 0, "Optimal": 0, "Heavy": 0, "Overreaching": 0]
        for (day, v) in inol where day >= cutoff {
            let label = inolZoneLabel(v)
            counts[label, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    let inol   = dailyINOL()
                    let grid   = gridDays()
                    let days   = ["M", "T", "W", "T", "F", "S", "S"]

                    // Full-size calendar
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 3) {
                            Text("").frame(width: 34)
                            ForEach(days.indices, id: \.self) { i in
                                Text(days[i])
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        ForEach(grid.indices, id: \.self) { wk in
                            HStack(spacing: 3) {
                                Text("Wk \(wk + 1)")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                                    .frame(width: 34, alignment: .leading)

                                ForEach(0..<7, id: \.self) { d in
                                    if let day = grid[wk][d] {
                                        let v = inol[day] ?? 0
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(inolColor(v))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 20)
                                    } else {
                                        Color.clear
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 20)
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(AppTheme.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // INOL explanation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What is INOL?")
                            .font(.system(size: 14, weight: .semibold))
                        Text("INOL (Intensity of Normal Load) is a metric that accounts for both the weight used and the reps performed. It provides a more complete picture of training stress than sets alone.\n\nFormula: Reps ÷ (100 − %1RM)\n\nIntensity is approximated from rep count using validated rep-max curves.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(AppTheme.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Zone guide
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Zone Guide")
                            .font(.system(size: 14, weight: .semibold))
                        VStack(alignment: .leading, spacing: 8) {
                            inolZoneRow(color: Color.green.opacity(0.2),  label: "Low (<0.4)",          desc: "Warm-up / recovery session")
                            inolZoneRow(color: Color.green.opacity(0.5),  label: "Moderate (0.4–0.8)",  desc: "Good working volume — solid stimulus")
                            inolZoneRow(color: Color.blue.opacity(0.7),   label: "Optimal (0.8–1.4)",   desc: "Maximum adaptation zone — hit this regularly")
                            inolZoneRow(color: Color.orange.opacity(0.8), label: "Heavy (1.4–2.0)",     desc: "Use sparingly — high fatigue cost")
                            inolZoneRow(color: Color.red.opacity(0.9),    label: "Overreaching (>2.0)", desc: "Recovery debt — deload soon")
                        }
                    }
                    .padding(14)
                    .background(AppTheme.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Recent pattern analysis
                    let zc = zoneCounts(inol: inol)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last 4 Weeks")
                            .font(.system(size: 14, weight: .semibold))
                        let orderedZones = ["Rest", "Low", "Moderate", "Optimal", "Heavy", "Overreaching"]
                        ForEach(orderedZones, id: \.self) { zone in
                            if let count = zc[zone], count > 0 {
                                HStack {
                                    Text(zone)
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    Text("\(count) day\(count == 1 ? "" : "s")")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(AppTheme.cardBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Spacer(minLength: 32)
                }
                .padding(.top, 8)
            }
            .background(AppTheme.pageBG.ignoresSafeArea())
            .navigationTitle("Training Load (INOL)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func inolZoneRow(color: Color, label: String, desc: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}
