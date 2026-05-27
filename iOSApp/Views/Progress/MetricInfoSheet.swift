import SwiftUI

// MARK: - MetricInfo enum

enum MetricInfo {
    case inol, psi, css, repDecay, efficiency, sessionCost, e1RM, tonnage, momentum, level, process, peakRetention, fiberLoad, allometricPSI, relativeStrength, readiness, rpe

    var title: String {
        switch self {
        case .inol:             return "INOL"
        case .psi:              return "PSI"
        case .css:              return "Composite Strength Score"
        case .repDecay:         return "Rep Decay"
        case .efficiency:       return "Efficiency"
        case .sessionCost:      return "Session Cost"
        case .e1RM:             return "e1RM"
        case .tonnage:          return "Tonnage"
        case .momentum:         return "Momentum"
        case .level:            return "Level"
        case .process:          return "Process"
        case .peakRetention:    return "Peak Retention"
        case .fiberLoad:        return "Fiber Load Index"
        case .allometricPSI:    return "Allometric PSI"
        case .relativeStrength: return "Relative Strength"
        case .readiness:        return "Readiness"
        case .rpe:              return "RPE"
        }
    }

    var definition: String {
        switch self {
        case .inol:
            return "Intensity × Volume load — a single number that captures how demanding a session was relative to your maximum."
        case .psi:
            return "Fiber stress weighted by muscle mass, normalised to bodyweight for fair comparison across athletes of different sizes."
        case .css:
            return "A 0–100 composite score combining Level, Momentum, and Process into one overall training quality number."
        case .repDecay:
            return "The average change in reps across consecutive sets, measuring how quickly fatigue accumulates within a session."
        case .efficiency:
            return "Strength gain per unit of fatigue — how much result you are getting from the stress you are imposing."
        case .sessionCost:
            return "The total fatigue load of a session, calibrated to your training experience so that context is built in."
        case .e1RM:
            return "Estimated 1-rep max computed from your working sets using the Epley formula, updated every session."
        case .tonnage:
            return "Total mechanical work performed: sets × reps × weight, measuring the raw volume of loading in a session."
        case .momentum:
            return "Week-over-week strength trend scaled to your experience level, capturing whether you are accelerating or decelerating."
        case .level:
            return "How close your current strength is to your all-time personal best for this exercise."
        case .process:
            return "Training quality score combining INOL, efficiency, and rep decay into a measure of how well-structured your sessions are."
        case .peakRetention:
            return "Your most recent e1RM expressed as a percentage of your all-time best, indicating how well you are retaining peak strength."
        case .fiberLoad:
            return "Per-exercise mechanical stress on recruited muscle fibers, weighted by EMG activation and physiological cross-sectional area."
        case .allometricPSI:
            return "Fiber load normalised to bodyweight^0.67 so that stress can be compared fairly across athletes of different body sizes."
        case .relativeStrength:
            return "Your estimated 1-rep max expressed as a multiple of your bodyweight, used to classify your strength tier."
        case .readiness:
            return "A 0–100 score combining days since last workout, session frequency, and volume trend to estimate training readiness."
        case .rpe:
            return "Rate of Perceived Exertion — a 1–10 scale rating how hard a set felt. 10 is a true maximum (couldn't do another rep), 7–8 is the productive training zone for most people."
        }
    }

    var whyItMatters: String {
        switch self {
        case .inol:
            return "Staying in the optimal INOL band ensures you are accumulating enough stimulus without digging into excessive fatigue."
        case .psi:
            return "Tracking PSI over time reveals whether you are progressively loading muscle fibers or just adding empty volume."
        case .css:
            return "CSS gives you a single number to trend over time so you can see whether your overall training is improving."
        case .repDecay:
            return "Moderate decay confirms productive fatigue; steep decay signals you should reduce load or extend rest periods."
        case .efficiency:
            return "High efficiency means your training economy is good; low efficiency suggests volume may be exceeding your recovery capacity."
        case .sessionCost:
            return "Monitoring session cost alongside recovery helps you avoid stacking too much fatigue before your next workout."
        case .e1RM:
            return "Tracking e1RM over sessions is the clearest signal of whether your absolute strength is trending upward."
        case .tonnage:
            return "Progressive increases in tonnage over weeks are strongly correlated with long-term strength and muscle gain."
        case .momentum:
            return "Positive momentum confirms your current program is working; negative momentum is an early warning to reassess."
        case .level:
            return "Level anchors your CSS score — staying close to your peak means you are maintaining hard-won strength."
        case .process:
            return "A high process score means your training is structured well; a low score points to programming inefficiencies worth fixing."
        case .peakRetention:
            return "Retention below 75% often indicates detraining, poor recovery, or technical regression worth investigating."
        case .fiberLoad:
            return "Understanding fiber load by exercise helps you balance stimulus across muscle groups and avoid chronic overuse."
        case .allometricPSI:
            return "Using allometric scaling makes strength comparisons meaningful regardless of differences in body size."
        case .relativeStrength:
            return "Relative strength is the most meaningful measure of strength for everyday athletes who are not competing by weight class."
        case .readiness:
            return "A high readiness score suggests you are well-recovered and primed for a quality session; low scores counsel restraint."
        case .rpe:
            return "An RPE trend that climbs for the same weight signals accumulated fatigue; a trend that drops signals positive adaptation — you've grown stronger and it now feels easier. That's your cue to add weight."
        }
    }

    var optimalRange: String? {
        switch self {
        case .inol:             return "0.8 – 1.5"
        case .psi:              return nil
        case .css:              return "60 – 100"
        case .repDecay:         return "−0.5 to −1.5 reps/set"
        case .efficiency:       return "Top 25% of your history"
        case .sessionCost:      return nil
        case .e1RM:             return nil
        case .tonnage:          return nil
        case .momentum:         return "Positive (> 0)"
        case .level:            return "≥ 80"
        case .process:          return "≥ 60"
        case .peakRetention:    return "≥ 90%"
        case .fiberLoad:        return nil
        case .allometricPSI:    return nil
        case .relativeStrength: return nil
        case .readiness:        return "≥ 70"
        case .rpe:              return "7 – 8"
        }
    }

    var unit: String? {
        switch self {
        case .inol:             return nil
        case .psi:              return nil
        case .css:              return "/ 100"
        case .repDecay:         return "reps/set"
        case .efficiency:       return nil
        case .sessionCost:      return nil
        case .e1RM:             return "kg"
        case .tonnage:          return "kg·reps"
        case .momentum:         return "kg/wk"
        case .level:            return "/ 100"
        case .process:          return "/ 100"
        case .peakRetention:    return "%"
        case .fiberLoad:        return "a.u."
        case .allometricPSI:    return "/ BW⁰·⁶⁷"
        case .relativeStrength: return "× BW"
        case .readiness:        return "/ 100"
        case .rpe:              return "/ 10"
        }
    }

    var color: Color {
        switch self {
        case .inol:             return HONTheme.accent
        case .psi:              return HONTheme.chartAmber
        case .css:              return HONTheme.accent
        case .repDecay:         return HONTheme.chartSlate
        case .efficiency:       return HONTheme.positive
        case .sessionCost:      return HONTheme.chartClay
        case .e1RM:             return HONTheme.accent
        case .tonnage:          return HONTheme.chartSage
        case .momentum:         return HONTheme.positive
        case .level:            return HONTheme.accent
        case .process:          return HONTheme.chartLavender
        case .peakRetention:    return HONTheme.warning
        case .fiberLoad:        return HONTheme.chartAmber
        case .allometricPSI:    return HONTheme.accent
        case .relativeStrength: return HONTheme.chartSlate
        case .readiness:        return HONTheme.positive
        case .rpe:              return HONTheme.chartClay
        }
    }
}

// MARK: - MetricInfoSheet

struct MetricInfoSheet: View {
    let metric: MetricInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            HONTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Circle()
                                .fill(metric.color)
                                .frame(width: 8, height: 8)
                                .offset(y: -2)
                            Text(metric.title)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            if let unit = metric.unit {
                                Text(unit)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        Rectangle()
                            .fill(metric.color)
                            .frame(height: 2)
                            .cornerRadius(1)
                    }

                    // Definition
                    infoBlock(
                        icon: "text.alignleft",
                        heading: "What it is",
                        body: metric.definition,
                        iconColor: metric.color
                    )

                    // Why it matters
                    infoBlock(
                        icon: "lightbulb.fill",
                        heading: "Why it matters",
                        body: metric.whyItMatters,
                        iconColor: HONTheme.chartSage
                    )

                    // Optimal range (if available)
                    if let range = metric.optimalRange {
                        HStack(spacing: 12) {
                            Image(systemName: "target")
                                .font(.system(size: 14))
                                .foregroundStyle(HONTheme.chartAmber)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Optimal Range")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(range)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(metric.color)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(metric.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer(minLength: 12)

                    // Footer
                    HStack(spacing: 6) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("Learn More in Manual")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func infoBlock(icon: String, heading: String, body: String, iconColor: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 22, alignment: .top)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text(heading)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(body)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - InfoButton

struct InfoButton: View {
    let metric: MetricInfo
    @State private var isPresented = false

    var body: some View {
        Button { if !isPresented { isPresented = true } } label: {
            Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(.secondary.opacity(0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More info about \(metric.title)")
        .disabled(isPresented)
        .sheet(isPresented: $isPresented) {
            MetricInfoSheet(metric: metric).presentationDetents([.medium, .large])
        }
    }
}
