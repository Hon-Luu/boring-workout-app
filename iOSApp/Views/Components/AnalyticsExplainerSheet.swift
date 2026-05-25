import SwiftUI

// MARK: - Root

struct AnalyticsExplainerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AEIntroCard()
                    AEProgressDashboardCard()
                    AEE1RMCard()
                    AERollingAvgCard()
                    AETrendCard()
                    AEINOLCard()
                    AERepDecayCard()
                    AESessionCostCard()
                    AEEfficiencyCard()
                    AERelStrengthCard()
                    AERelStrengthTiersCard()
                    AEFiberLoadCard()
                    AECompositeScoreCard()
                    AEBodyCompCard()
                    AEPlateauCard()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 40)
            }
            .background(AppTheme.pageBG)
            .navigationTitle("How It's Calculated")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Card Container

private struct AECard<Content: View>: View {
    let icon: String
    let color: Color
    let title: String
    let content: Content

    init(icon: String, color: Color, title: String, @ViewBuilder content: () -> Content) {
        self.icon   = icon
        self.color  = color
        self.title  = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title).font(.headline)
            }
            content
        }
        .padding(16)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Scenario Box (standalone struct avoids duplicate-id ForEach crashes)

private struct AEScenario: View {
    let emoji: String
    let label: String
    let color: Color
    let context: String
    let lines: [String]
    let verdict: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Text(emoji)
                Text(label).font(.caption.bold()).foregroundStyle(color)
            }
            Text(context)
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    if line.isEmpty {
                        Spacer().frame(height: 3)
                    } else {
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color(.label))
                    }
                }
            }
            if !verdict.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right").font(.caption2)
                    Text(verdict).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(color)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - INOL Zone Table

private struct AEINOLZones: View {
    var body: some View {
        VStack(spacing: 0) {
            zoneRow("< 0.4",      "Insufficient",  .secondary, "Volume too low for meaningful adaptation")
            zoneRow("0.4 – 0.79", "Moderate",      HONTheme.accent,      "Light stimulus; good for deload weeks")
            zoneRow("0.8 – 1.49", "Optimal ✓",     HONTheme.positive,     "Target zone for strength and hypertrophy")
            zoneRow("1.5 – 1.99", "Heavy",         HONTheme.warning,    "High stress; prioritise recovery and sleep")
            zoneRow("≥ 2.0",      "Overreaching",  HONTheme.negative,       "Exceeds safe recovery; reduce volume now")
        }
        .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))
        .padding(.vertical, 4)
    }

    private func zoneRow(_ range: String, _ label: String, _ color: Color, _ note: String) -> some View {
        HStack(spacing: 10) {
            Text(range)
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(label)
                .font(.caption.bold()).foregroundStyle(color)
                .frame(width: 90, alignment: .leading)
            Text(note).font(.caption2).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
    }
}

// MARK: - Shared Helpers (static namespace)

private enum AE {
    static func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.tertiary)
            .padding(.top, 2)
    }

    static func body(_ text: String) -> some View {
        Text(text)
            .font(.subheadline).foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    static func latex(source: String, readable: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LaTeX")
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(HONTheme.textPrimary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color(.systemGray2), in: RoundedRectangle(cornerRadius: 3))
                Spacer()
            }
            Text(source)
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            Text(readable)
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(Color(.label))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 8))
    }

    static func component(symbol: String, name: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(symbol)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(HONTheme.accent)
                .frame(width: 58, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.caption.bold()).foregroundStyle(.primary)
                Text(desc).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    static func step(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption2.bold()).foregroundStyle(HONTheme.textPrimary)
                .frame(width: 16, height: 16)
                .background(HONTheme.accent, in: Circle())
            Text(text)
                .font(.caption).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    static func interpret(_ label: String, _ meaning: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(color)
                .frame(width: 90, alignment: .leading)
            Text(meaning).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Card 1: Intro

private struct AEIntroCard: View {
    var body: some View {
        AECard(icon: "chart.line.uptrend.xyaxis", color: HONTheme.accent, title: "The Analytics Pipeline") {
            AE.body("Every number shown is derived from your raw logged sets — no manual input beyond the optional session feel rating. Each step feeds the next:")
            VStack(alignment: .leading, spacing: 8) {
                AE.step("1", "Raw sets → Estimated 1RM per set (Epley ≤10 reps; Mayhew 11–20 reps; >20 reps excluded)")
                AE.step("2", "Best e1RM per session → 5-session rolling average")
                AE.step("3", "Rolling average → OLS linear regression → kg/wk trend")
                AE.step("4", "INOL measures session load; rep decay measures fatigue gradient")
                AE.step("5", "Session cost + efficiency measure adaptation return on investment")
                AE.step("6", "Relative strength ranks every lift by e1RM ÷ bodyweight against pattern-specific tiers")
                AE.step("7", "Personal Strength Index (PSI) normalizes all exercises to muscle fiber units via EMG × PCSA")
                AE.step("8", "Composite Strength Score (CSS) blends Level + Momentum + Process into one 0–100 grade")
            }
            AE.body("The sections below explain each step: what it is, why it's designed that way, what every variable means, and worked scenarios showing how it behaves under different conditions.")
        }
    }
}

// MARK: - Card 10b: Relative Strength Tiers (new)

private struct AERelStrengthTiersCard: View {
    private struct TierRow: View {
        let pattern: String; let dev: String; let inter: String; let adv: String; let elite: String
        var body: some View {
            HStack(spacing: 0) {
                Text(pattern).font(.system(size: 10)).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
                Text(dev).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).frame(width: 42, alignment: .center)
                Text(inter).font(.system(size: 10, design: .monospaced)).foregroundStyle(HONTheme.accent).frame(width: 42, alignment: .center)
                Text(adv).font(.system(size: 10, design: .monospaced)).foregroundStyle(HONTheme.positive).frame(width: 42, alignment: .center)
                Text(elite).font(.system(size: 10, design: .monospaced)).foregroundStyle(HONTheme.warning).frame(width: 42, alignment: .center)
            }
            .padding(.vertical, 5).padding(.horizontal, 10)
        }
    }

    var body: some View {
        AECard(icon: "trophy.fill", color: HONTheme.chartAmber, title: "Relative Strength Tiers") {
            AE.sectionLabel("What it is")
            AE.body("Every compound lift is benchmarked against pattern-specific thresholds — not a single universal ratio. A 1.5× squat means something very different from a 1.5× overhead press.")

            AE.sectionLabel("Why it matters")
            AE.body("Tier thresholds calibrated to each movement give you honest context. Hip hinges (deadlifts) have higher thresholds than vertical pushes because the movement pattern recruits more total mass. Comparing across patterns with one standard would systematically undervalue or overvalue your efforts.")

            AE.sectionLabel("The formula")
            AE.latex(
                source: "\\text{Rel} = e_{1RM}^{PR} \\div m_{body}\n\n\\text{Tier} = f(\\text{Rel}, \\text{MovementPattern})",
                readable: "rel  =  PR_e1RM  ÷  bodyweight\ntier = lookup(rel, pattern)"
            )

            AE.sectionLabel("Tier thresholds  (e1RM ÷ bodyweight)")
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Pattern").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary).frame(maxWidth: .infinity, alignment: .leading)
                    Text("Dev").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).frame(width: 42, alignment: .center)
                    Text("Inter").font(.system(size: 9, weight: .bold)).foregroundStyle(HONTheme.accent).frame(width: 42, alignment: .center)
                    Text("Adv").font(.system(size: 9, weight: .bold)).foregroundStyle(HONTheme.positive).frame(width: 42, alignment: .center)
                    Text("Elite").font(.system(size: 9, weight: .bold)).foregroundStyle(HONTheme.warning).frame(width: 42, alignment: .center)
                }
                .padding(.vertical, 6).padding(.horizontal, 10)
                Divider().padding(.horizontal, 10)
                TierRow(pattern: "Hip Hinge",       dev: "<1.5×", inter: "1.5×", adv: "2.25×", elite: "3.0×")
                TierRow(pattern: "Knee Flexion",    dev: "<1.25×", inter: "1.25×", adv: "2.0×", elite: "2.75×")
                TierRow(pattern: "Horiz Push",      dev: "<0.75×", inter: "0.75×", adv: "1.25×", elite: "1.75×")
                TierRow(pattern: "Vert Push",       dev: "<0.5×", inter: "0.5×", adv: "0.9×", elite: "1.3×")
                TierRow(pattern: "Horiz Pull",      dev: "<0.75×", inter: "0.75×", adv: "1.25×", elite: "1.75×")
                TierRow(pattern: "Vert Pull",       dev: "<0.6×", inter: "0.6×", adv: "1.0×", elite: "1.5×")
                TierRow(pattern: "Isolation",       dev: "<0.3×", inter: "0.3×", adv: "0.5×", elite: "0.75×")
            }
            .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

            AE.sectionLabel("Scenarios")
            AEScenario(emoji: "🏋️", label: "Deadlift at 2.1× — Advanced", color: HONTheme.positive,
                context: "Lifter BW 80 kg, deadlift PR e1RM 168 kg.",
                lines: ["rel = 168 / 80 = 2.10×",
                        "Hip Hinge: Dev<1.5, Inter≥1.5, Adv≥2.25",
                        "2.10 ≥ 1.5 (Inter) but < 2.25 (Adv)",
                        "→ Intermediate tier"],
                verdict: "Intermediate for Hip Hinge. Target 2.25× for Advanced.")
            AEScenario(emoji: "📊", label: "Same ratio, different meaning", color: HONTheme.accent,
                context: "1.0× bodyweight on two very different movements.",
                lines: ["OHP at 1.0×  →  Elite for Vertical Push",
                        "Squat at 1.0×  →  Below Intermediate (need 1.25×)"],
                verdict: "1.0× is elite for one pattern and developmental for another.")
        }
    }
}

// MARK: - Card 1b: Progress Dashboard Navigation

private struct AEProgressDashboardCard: View {

    private struct LayerRow: View {
        let badge: String
        let color: Color
        let title: String
        let desc: String

        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(HONTheme.textPrimary)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(color, in: RoundedRectangle(cornerRadius: 5))
                    .fixedSize()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption.bold())
                    Text(desc).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 5).padding(.horizontal, 10)
        }
    }

    var body: some View {
        AECard(icon: "square.grid.2x2.fill", color: HONTheme.chartLavender, title: "Progress Dashboard") {
            AE.sectionLabel("How the Progress tab is structured")
            AE.body("The tab is a 3-layer drill-down. Each layer reveals the sub-components behind the number above it. All scores are computed live from your log — nothing is manually set.")

            VStack(spacing: 0) {
                LayerRow(badge: "L0", color: HONTheme.chartLavender,
                    title: "Command Center  (Progress tab)",
                    desc: "CSS grade + score, tier badge, coaching insight, 3 pillar cards, CSS history chart, pattern breakdown, activity strip, stats, PRs.")
                Divider().padding(.horizontal, 10)
                LayerRow(badge: "L1A", color: HONTheme.accent,
                    title: "Level Detail  (tap Level card)",
                    desc: "Blend formula live, retention trend chart, per-exercise Component A table (PCSA activation weight, Std/Adj/Blended retention), Component B PSI variants, Component C relative-strength anchors, body comp metrics.")
                Divider().padding(.horizontal, 10)
                LayerRow(badge: "L1B", color: HONTheme.positive,
                    title: "Momentum Detail  (tap Momentum card)",
                    desc: "Tier ceiling and live formula, aggregate PSI trend chart with OLS overlay, stalled-exercise callout, per-exercise Std/Adj %/wk and momentum score table.")
                Divider().padding(.horizontal, 10)
                LayerRow(badge: "L1C", color: HONTheme.chartLavender,
                    title: "Process Detail  (tap Process card)",
                    desc: "INOL sub-score with per-exercise bar chart and optimal-zone band, efficiency quartile and session cost, rep decay zone table.")
                Divider().padding(.horizontal, 10)
                LayerRow(badge: "L1D", color: HONTheme.warning,
                    title: "Pattern Detail  (tap Push / Pull / Legs / Isolation row)",
                    desc: "Pattern-only PSI trend chart, PCSA-weighted retention breakdown per exercise (AW, Ret%, Wt%), exercise list with 8-session sparklines.")
                Divider().padding(.horizontal, 10)
                LayerRow(badge: "L2", color: .gray,
                    title: "Exercise Detail  (tap any exercise row in L1A–D)",
                    desc: "Full e1RM history, fatigue-adjusted trend, rolling average, INOL, rep decay, session cost, efficiency history, and feel streak insight for one exercise.")
            }
            .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

            AE.sectionLabel("What each pillar measures")
            AE.component(symbol: "Level (35%)", name: "Where you are", desc: "Current e1RM as % of personal best, PCSA-weighted across all exercises. Drops after deloads, rises as you approach PRs.")
            AE.component(symbol: "Momentum (40%)", name: "How fast you're improving", desc: "OLS %/week trend, tier-calibrated so +ceiling → 100. Uses the better of standard vs fatigue-adjusted trend.")
            AE.component(symbol: "Process (25%)", name: "Training quality", desc: "INOL (stimulus load) + Efficiency (adaptation ROI) + Rep Decay (fatigue control), blended 40/40/20.")

            AE.sectionLabel("Navigation tip")
            AE.body("If your CSS is lower than expected, start with the weakest pillar card (the one with the lowest score). Layer 1 will show exactly which sub-component is the drag. From there, tap the specific exercise to see its raw history in Layer 2.")
        }
    }
}

// MARK: - Card 2: e1RM

private struct AEE1RMCard: View {
    var body: some View {
        AECard(icon: "scalemass.fill", color: HONTheme.warning, title: "Estimated 1RM (Formula by Rep Range)") {
            AE.sectionLabel("What it is")
            AE.body("The estimated 1RM converts any working set into its theoretically equivalent single-rep maximum. It's a common currency — whether you did 5 reps or 10, both translate into one comparable strength number.")

            AE.sectionLabel("Why it matters")
            AE.body("Testing a true 1RM is fatiguing, injury-prone, and impractical every session. These formulas extract a consistent strength signal from normal training sets — a trackable number across weeks and months.")

            AE.sectionLabel("Rep-range formula selection")
            AE.latex(
                source: "e_{1RM} = \\begin{cases} w \\times (1 + r/30) & r \\leq 10 \\quad \\text{(Epley)} \\\\ \\dfrac{100 \\cdot w}{52.2 + 41.9 \\cdot e^{-0.055r}} & 11 \\leq r \\leq 20 \\quad \\text{(Mayhew)} \\\\ 0 & r > 20 \\quad \\text{(excluded)} \\end{cases}",
                readable: "≤ 10 reps:  Epley   →  w × (1 + r/30)\n11–20 reps: Mayhew  →  (100×w) / (52.2 + 41.9×e^(−0.055r))\n> 20 reps:  excluded (too far from 1RM to be reliable)"
            )

            AE.sectionLabel("Why two formulas?")
            AE.body("Epley is accurate and linear for 1–10 rep ranges — it was derived from near-maximal sets. For higher reps (11–20), the Mayhew equation fits empirical data better: its exponential denominator accounts for the fact that endurance starts contributing at longer sets, making pure extrapolation less reliable.")

            AE.sectionLabel("What each variable means")
            AE.component(symbol: "w", name: "Working weight", desc: "The load on the bar (or effective weight for dumbbells: single weight × 2 × 0.92). The absolute foundation of the estimate.")
            AE.component(symbol: "r", name: "Reps completed", desc: "Actual reps performed. Formula switches at r=11. Sets above 20 reps are excluded from e1RM calculations.")
            AE.component(symbol: "30", name: "Epley's constant", desc: "Each additional rep above 1 represents ~3.33% (1/30) of 1RM capacity. So 10 reps implies you're lifting ~75% of your true max.")
            AE.component(symbol: "52.2, 41.9, 0.055", name: "Mayhew constants", desc: "Empirically fitted to powerlifting data for 11–20 rep sets. The denominator approaches 94.1 at very high reps (the theoretical floor for 1RM estimate).")

            AE.sectionLabel("Scenarios")
            AEScenario(emoji: "💪", label: "Standard hypertrophy set (Epley)", color: HONTheme.warning,
                context: "Classic 3×8 at 80 kg — 8 reps uses Epley.",
                lines: ["w = 80 kg,   r = 8 reps  (≤ 10 → Epley)",
                        "e₁ᴿᴹ = 80 × (1 + 8/30)",
                        "     = 80 × 1.267  =  101.3 kg"],
                verdict: "Session best = 101.3 kg")
            AEScenario(emoji: "🏋️", label: "High-rep pump set (Mayhew)", color: HONTheme.accent,
                context: "60 kg × 15 reps — switches to Mayhew formula.",
                lines: ["w = 60 kg,   r = 15 reps  (11–20 → Mayhew)",
                        "denom = 52.2 + 41.9 × e^(−0.055×15)",
                        "      = 52.2 + 41.9 × 0.437  =  70.5",
                        "e₁ᴿᴹ = (100 × 60) / 70.5  =  85.1 kg"],
                verdict: "Mayhew corrects Epley's overestimation at 15 reps (Epley would give 90.0 kg)")
            AEScenario(emoji: "📊", label: "Multiple sets — best wins", color: HONTheme.positive,
                context: "Two sets in one session. App picks the highest e1RM.",
                lines: ["Set A: 80 kg × 8  →  Epley = 101.3 kg",
                        "Set B: 85 kg × 5  →  Epley: 85 × 1.167 = 99.2 kg",
                        "",
                        "Best = max(101.3, 99.2) = 101.3 kg"],
                verdict: "Set A wins. Session e1RM = 101.3 kg")
            AEScenario(emoji: "🚫", label: "Very high rep set — excluded", color: .secondary,
                context: "25 reps at 50 kg. Too far from 1RM to extrapolate reliably.",
                lines: ["r = 25 > 20 → e1RM = 0 (excluded)",
                        "Set still contributes to tonnage (volume),",
                        "but is not used in trend or PR calculations."],
                verdict: "Excluded from e1RM. Still visible in volume charts.")
        }
    }
}

// MARK: - Card 3: Rolling Average

private struct AERollingAvgCard: View {
    var body: some View {
        AECard(icon: "waveform", color: HONTheme.chartSage, title: "5-Session Rolling Average") {
            AE.sectionLabel("What it is")
            AE.body("A moving average of your best e1RM across the last 5 sessions. It's the smooth line on the strength curve — as opposed to the noisy raw session dots underneath it.")

            AE.sectionLabel("Why it matters")
            AE.body("Your session-to-session e1RM swings ±5–10% due to sleep, nutrition, stress, and warm-up quality. None of that represents real strength change. The rolling average filters it out, revealing the actual trajectory.")

            AE.sectionLabel("The formula")
            AE.latex(
                source: "\\bar{e}[i] = \\frac{1}{k} \\sum_{j=\\max(0,i-k+1)}^{i} e_{1RM}[j], \\quad k = \\min(5,\\, i+1)",
                readable: "avg[i]  =  mean of  e₁ᴿᴹ[ max(0, i−4) … i ]\nwindow  =  min(5, sessions so far)"
            )

            AE.sectionLabel("What each variable means")
            AE.component(symbol: "i", name: "Session index", desc: "Sessions numbered from 0. Session 7 is i=6.")
            AE.component(symbol: "k", name: "Window size", desc: "Starts at 1, grows to 5 over first five sessions, then stays at 5. Prevents undefined averages early on.")
            AE.component(symbol: "max(0,i−k+1)", name: "Window start", desc: "Clips lookback so it never goes before session 0. Early sessions use all available history.")

            AE.sectionLabel("Scenarios")
            AEScenario(emoji: "📈", label: "Consistent progress — noise absorbed", color: HONTheme.positive,
                context: "Five sessions trending upward. One bad day barely moves the line.",
                lines: ["Session:   1     2      3      4     5",
                        "e1RM:     88    91     94     80    97  kg",
                        "Roll avg: 88   89.5   91.0   88.3  90.0 kg",
                        "",
                        "Session 4 crashed 14 kg (illness).",
                        "Rolling avg: 91.0 → 88.3 → recovered next session."],
                verdict: "Noise absorbed. True trajectory preserved.")
            AEScenario(emoji: "🆕", label: "New exercise — small window", color: HONTheme.chartSage,
                context: "Just added Romanian Deadlifts. Only 2 sessions of data exist.",
                lines: ["Session 0: e1RM = 70 kg  →  avg = 70.0 kg",
                        "Session 1: e1RM = 76 kg  →  avg = (70+76)/2 = 73.0 kg"],
                verdict: "Window shrinks gracefully. Line appears from session 1.")
            AEScenario(emoji: "🔄", label: "Long gap between sessions", color: HONTheme.warning,
                context: "3 weeks off (travel) then returned. Window uses last 5 sessions regardless of gap.",
                lines: ["Rolling avg = mean of last 5 e1RM values.",
                        "Dates don't affect the mean — only count matters.",
                        "",
                        "But OLS trend will see a big time gap with",
                        "flat e1RM → may trigger plateau flag."],
                verdict: "Rolling avg stable. Check the trend section instead.")
        }
    }
}

// MARK: - Card 4: Trend

private struct AETrendCard: View {
    var body: some View {
        AECard(icon: "arrow.up.right", color: HONTheme.positive, title: "Trend — OLS Linear Regression") {
            AE.sectionLabel("What it is")
            AE.body("Ordinary Least Squares regression fits the best-possible straight line through your e1RM history (x = weeks elapsed, y = e1RM). The slope is your strength gain rate: kg per week and %/week.")

            AE.sectionLabel("Why it matters")
            AE.body("Raw session-to-session deltas are volatile. OLS accounts for all sessions simultaneously, minimizing total squared error. A single bad session barely moves the slope — it's outvoted by the others.")

            AE.sectionLabel("The formula")
            AE.latex(
                source: "\\hat{\\beta} = \\frac{n\\sum x_i y_i - \\sum x_i \\cdot \\sum y_i}{n\\sum x_i^2 - (\\sum x_i)^2}\n\n\\%/wk = (\\hat{\\beta} / \\bar{y}) \\times 100",
                readable: "β  =  ( n·Σxᵢyᵢ  −  Σxᵢ · Σyᵢ )\n   ÷  ( n·Σxᵢ²  −  (Σxᵢ)² )\n\n%/wk  =  β ÷ ȳ × 100"
            )

            AE.sectionLabel("What each variable means")
            AE.component(symbol: "n", name: "Session count", desc: "Sessions in the 6-week window. Minimum 2 needed for a meaningful slope.")
            AE.component(symbol: "xᵢ", name: "Time (weeks)", desc: "Weeks since first session in window. x=0 for first session, x=1.5 for a session 10.5 days later.")
            AE.component(symbol: "yᵢ", name: "e1RM at session i", desc: "Best estimated 1RM from that session.")
            AE.component(symbol: "Σxᵢyᵢ", name: "Cross-product sum", desc: "Captures how strength and time co-vary. Large when both go up → positive slope.")
            AE.component(symbol: "β̂", name: "OLS slope (kg/wk)", desc: "How many kg of e1RM you gain per week on average, accounting for all sessions simultaneously.")
            AE.component(symbol: "ȳ", name: "Mean e1RM", desc: "Average e1RM in window. Converts absolute slope to a percentage rate.")

            AE.sectionLabel("Scenarios")
            AEScenario(emoji: "🚀", label: "Fast novice progress — full derivation", color: HONTheme.positive,
                context: "4 sessions over 3 weeks, each session noticeably heavier.",
                lines: ["Week:   0    1    2    3",
                        "e1RM:  90   93   96   99  kg",
                        "",
                        "n=4, Σx=6, Σy=378",
                        "Σxy = 0·90+1·93+2·96+3·99 = 582",
                        "Σx² = 0+1+4+9 = 14",
                        "",
                        "β = (4·582 − 6·378) / (4·14 − 36)",
                        "  = (2328 − 2268) / 20  =  +3.0 kg/wk",
                        "",
                        "ȳ = 94.5,   %/wk = 3.0/94.5×100 ≈ +3.2%"],
                verdict: "+3.0 kg/wk — exceptional novice rate")
            AEScenario(emoji: "🔄", label: "Plateau scenario", color: HONTheme.warning,
                context: "4 sessions this month, numbers barely moving.",
                lines: ["Week:   0     1     2     3",
                        "e1RM:  95.0  95.5  94.5  95.0  kg",
                        "",
                        "β ≈ −0.10 kg/wk  <  0.5 threshold"],
                verdict: "Plateau flag triggers. Change the stimulus.")
            AEScenario(emoji: "📉", label: "Return from injury — negative slope", color: HONTheme.negative,
                context: "3 weeks off. First month back shows regression.",
                lines: ["Week:   0     1     2     3",
                        "e1RM: 100    98    95    94  kg",
                        "",
                        "β ≈ −2.1 kg/wk  (negative)"],
                verdict: "Shown in red. Slope recovers within 3–4 weeks.")
        }
    }
}

// MARK: - Card 5: INOL

private struct AEINOLCard: View {
    var body: some View {
        AECard(icon: "gauge.with.needle", color: HONTheme.chartLavender, title: "INOL — Intensity × Number of Lifts") {
            AE.sectionLabel("What it is")
            AE.body("INOL is a training load index by Bulgarian powerlifting coach Hristo Hristov. It weights each rep by how close you were to your max — work near failure counts exponentially more than light work.")

            AE.sectionLabel("Why it matters")
            AE.body("Raw volume treats a rep at 60% identically to one at 90%. INOL's shrinking denominator corrects this: at 90% intensity a rep counts 5× more than at 50%. This aligns with RPE research and real fatigue accumulation.")

            AE.sectionLabel("The formula")
            AE.latex(
                source: "\\text{INOL} = \\sum_{i=1}^{n} \\frac{r_i}{100 - \\%1RM_i}\n\n\\%1RM_i = (w_i / e_{1RM}^{ref}) \\times 100 \\quad (\\text{cap: } 97.5\\%)",
                readable: "INOL  =  Σᵢ  rᵢ  ÷  ( 100 − %1RMᵢ )\n%1RM  =  ( weight ÷ ref_e1RM )  ×  100"
            )

            AE.sectionLabel("What each variable means")
            AE.component(symbol: "rᵢ", name: "Reps in set i", desc: "Actual reps completed. Amplified by the denominator at high intensities.")
            AE.component(symbol: "%1RMᵢ", name: "Intensity %", desc: "How heavy the set was relative to your all-time best e1RM. 80 kg when ref is 100 kg → 80%.")
            AE.component(symbol: "100 − %1RM", name: "The denominator", desc: "Room above your max. At 60%: 40. At 80%: 20. At 90%: 10. Denominator halves → each rep costs twice as much.")
            AE.component(symbol: "e₁ᴿᴹᴿᵉᶠ", name: "Reference e1RM", desc: "All-time best estimated 1RM. Stable anchor — doesn't fluctuate with session noise.")
            AE.component(symbol: "97.5% cap", name: "Division guard", desc: "Prevents division by near-zero at maximal loads.")

            AE.sectionLabel("INOL zones")
            AEINOLZones()

            AE.sectionLabel("Scenarios")
            AEScenario(emoji: "😴", label: "Deload — below adaptation threshold", color: .secondary,
                context: "3×5 at 60% of reference e1RM.",
                lines: ["ref=100 kg,  weight=60 kg  →  %1RM=60%",
                        "denominator = 100−60 = 40",
                        "",
                        "INOL = 5/40 + 5/40 + 5/40 = 0.375"],
                verdict: "Insufficient (<0.4). Fine for deloads, not for progress weeks.")
            AEScenario(emoji: "💪", label: "Hypertrophy day — optimal zone", color: HONTheme.positive,
                context: "Classic 4×8 at 75%.",
                lines: ["denominator = 100−75 = 25",
                        "INOL = 8/25 × 4 = 0.32 × 4 = 1.28"],
                verdict: "Optimal ✓ — consistent adaptation expected.")
            AEScenario(emoji: "🏋️", label: "Heavy singles — low reps near-max", color: HONTheme.warning,
                context: "5 singles at 90% — powerlifting approach.",
                lines: ["denominator = 100−90 = 10",
                        "INOL = 1/10 × 5 = 0.50"],
                verdict: "Moderate. Low rep count controls load despite near-max weight.")
            AEScenario(emoji: "🔥", label: "Overreaching — too much volume", color: HONTheme.negative,
                context: "6×10 at 75% — double the normal sets.",
                lines: ["INOL = 10/25 × 6 = 0.40 × 6 = 2.40"],
                verdict: "Overreaching (≥2.0). Expect elevated soreness and poor next session.")
        }
    }
}

// MARK: - Card 6: Rep Decay

private struct AERepDecayCard: View {
    var body: some View {
        AECard(icon: "arrow.down.right", color: HONTheme.chartLavender, title: "Rep Decay Slope") {
            AE.sectionLabel("What it is")
            AE.body("Rep decay is OLS regression within a single session: x = set number, y = reps completed. The slope tells you how many reps you lose per successive set as fatigue accumulates.")

            AE.sectionLabel("Why it matters")
            AE.body("If reps don't decline across sets, the weight is too light or rest too long. A meaningful negative slope means training near failure — the primary driver of hypertrophy and strength adaptation.")

            AE.sectionLabel("The formula")
            AE.latex(
                source: "\\hat{\\beta}_{decay} = \\frac{n\\sum i \\cdot r_i - \\sum i \\cdot \\sum r_i}{n\\sum i^2 - (\\sum i)^2}",
                readable: "slope  =  OLS on  { (set_index, reps) }\nsame OLS formula — x = set#, y = reps"
            )

            AE.sectionLabel("What each variable means")
            AE.component(symbol: "i", name: "Set index (x)", desc: "0 for first set, 1 for second, etc. Independent variable — time within session.")
            AE.component(symbol: "rᵢ", name: "Reps at set i (y)", desc: "Reps completed. Dependent variable — what fatigue acts on.")
            AE.component(symbol: "slope", name: "Reps lost per set", desc: "Negative = healthy fatigue. Zero = no fatigue signal. Positive = ascending ladder sets.")

            AE.sectionLabel("Interpretation guide")
            AE.interpret("< −0.3",  "Working near failure — healthy gradient", HONTheme.positive)
            AE.interpret("−0.3–0",  "Minimal decline — weight may be too light", .secondary)
            AE.interpret("> 0",     "Reps rising — ascending sets or light start", HONTheme.accent)
            AE.interpret("< −3.0",  "Steep drop-off — extend rest or reduce load", HONTheme.negative)

            AE.sectionLabel("Scenarios")
            AEScenario(emoji: "✅", label: "Optimal fatigue — full derivation", color: HONTheme.positive,
                context: "3 working sets. Reps decline naturally as fatigue builds.",
                lines: ["Set 0: 10 reps,  Set 1: 8,  Set 2: 6",
                        "",
                        "n=3, Σi=3, Σr=24",
                        "Σir = 0·10+1·8+2·6 = 20",
                        "Σi² = 0+1+4 = 5",
                        "",
                        "slope = (3·20−3·24) / (3·5−9)",
                        "      = (60−72) / 6  =  −2.0 reps/set"],
                verdict: "−2.0 reps/set — solid fatigue gradient.")
            AEScenario(emoji: "⚠️", label: "Weight too light", color: .secondary,
                context: "Reps barely dropping. Load is well within capacity.",
                lines: ["Set 0: 10,  Set 1: 10,  Set 2: 9",
                        "slope ≈ −0.5 reps/set"],
                verdict: "Near zero. Add 2.5–5 kg.")
            AEScenario(emoji: "🛑", label: "Excessive fatigue — rest more", color: HONTheme.negative,
                context: "Large rep drops signal insufficient recovery between sets.",
                lines: ["Set 0: 10,  Set 1: 6,  Set 2: 3",
                        "slope ≈ −3.5 reps/set"],
                verdict: "Too steep. Increase rest to 3–4 min or reduce load 10%.")
            AEScenario(emoji: "📈", label: "Ascending ladder — positive slope", color: HONTheme.accent,
                context: "Intentional ramp to a top set. Positive slope is expected here.",
                lines: ["Set 0: 6,  Set 1: 8,  Set 2: 10",
                        "slope ≈ +2.0 reps/set  (positive)"],
                verdict: "Expected for pyramid sets — not a warning.")
        }
    }
}

// MARK: - Card 7: Session Cost

private struct AESessionCostCard: View {
    var body: some View {
        AECard(icon: "bolt.fill", color: HONTheme.chartAmber, title: "Session Cost") {
            AE.sectionLabel("What it is")
            AE.body("Session cost is a composite fatigue score integrating three realities: heavier sets cost non-linearly more, later sets cost more due to accumulated fatigue, and your perceived readiness adjusts the total.")

            AE.sectionLabel("Why it matters")
            AE.body("Without cost, efficiency is undefined. Two sessions might both show a +2 kg e1RM gain — but one cost 8 units and the other 22. That's a 2.75× difference in adaptation ROI.")

            AE.sectionLabel("The formula")
            AE.latex(
                source: "C = \\varphi \\cdot \\sum_{i=0}^{n-1} r_i \\cdot (w_i / e_{1RM}^{ref})^{1.8} \\cdot e^{0.08 i}",
                readable: "C  =  φ  ×  Σᵢ  [ rᵢ  ×  (wᵢ ÷ ref_e1RM)^1.8  ×  e^(0.08×i) ]"
            )

            AE.sectionLabel("What each variable means")
            AE.component(symbol: "φ", name: "Feel multiplier", desc: "Tired=1.20, Normal=1.00, Strong=0.85. Reflects CNS and recovery state. Same session rated Tired vs Strong differs by 41% in cost.")
            AE.component(symbol: "rᵢ", name: "Reps in set i", desc: "Each rep contributes linearly to the set's sub-cost.")
            AE.component(symbol: "(w/e1RM)^1.8", name: "Superlinear intensity", desc: "At 90% vs 80%: (0.9/0.8)^1.8 ≈ 1.24. So 90% intensity is ~24% more costly per rep — not just 12.5% as linear thinking suggests.")
            AE.component(symbol: "e^(0.08·i)", name: "Fatigue per set", desc: "Each successive set costs ~8.3% more (e^0.08 ≈ 1.083). Set 0: ×1.000. Set 3: e^0.24 = ×1.271. Your 4th squat set costs more than the 1st.")

            AE.sectionLabel("Scenarios")
            AEScenario(emoji: "🟢", label: "Light session, felt strong", color: HONTheme.positive,
                context: "2×8 at 65% intensity. φ = 0.85 (Strong).",
                lines: ["(0.65)^1.8 ≈ 0.460",
                        "Set 0: 8 × 0.460 × 1.000 = 3.68",
                        "Set 1: 8 × 0.460 × 1.083 = 3.99",
                        "Raw = 7.67,   C = 0.85 × 7.67 ≈ 6.5 units"],
                verdict: "Low cost. Efficient for recovery/maintenance days.")
            AEScenario(emoji: "🔴", label: "Heavy session, felt tired", color: HONTheme.negative,
                context: "3×6 at 85% intensity. φ = 1.20 (Tired).",
                lines: ["(0.85)^1.8 ≈ 0.746",
                        "Set 0: 6 × 0.746 × 1.000 = 4.48",
                        "Set 1: 6 × 0.746 × 1.083 = 4.85",
                        "Set 2: 6 × 0.746 × 1.174 = 5.26",
                        "Raw = 14.59,   C = 1.20 × 14.59 ≈ 17.5",
                        "",
                        "Same day felt Strong → C = 0.85 × 14.59 ≈ 12.4"],
                verdict: "Feel rating shifts cost by ~41%.")
            AEScenario(emoji: "🔵", label: "Same reps — different intensity (non-linearity)", color: HONTheme.accent,
                context: "Two sessions: identical sets and reps, but different loads.",
                lines: ["3×8 at 70%:  (0.70)^1.8 ≈ 0.526  →  Cost ≈ 13.7",
                        "3×8 at 85%:  (0.85)^1.8 ≈ 0.746  →  Cost ≈ 19.4"],
                verdict: "15% heavier load → 42% higher cost. Intensity scales non-linearly.")
        }
    }
}

// MARK: - Card 8: Efficiency

private struct AEEfficiencyCard: View {
    var body: some View {
        AECard(icon: "arrow.up.forward.circle", color: HONTheme.chartSlate, title: "Efficiency Score") {
            AE.sectionLabel("What it is")
            AE.body("Efficiency is the ratio of rolling-average strength gain to session cost. It answers: how much adaptation are you generating per unit of training stress? Think of it as your strength ROI per session.")

            AE.sectionLabel("Why it matters")
            AE.body("High cost doesn't guarantee progress. If you're accumulating stress without the rolling average moving, you're in a low-efficiency phase — possibly overtraining, under-recovering, or poorly programmed.")

            AE.sectionLabel("The formula")
            AE.latex(
                source: "\\varepsilon = \\frac{\\Delta\\bar{e}_{1RM}}{C_t} = \\frac{\\bar{e}_{1RM}[t] - \\bar{e}_{1RM}[t-1]}{C_t}",
                readable: "ε  =  ( avg_e1RM[t]  −  avg_e1RM[t−1] )  ÷  cost[t]"
            )

            AE.sectionLabel("Label logic — quartile rank against your own history")
            AE.latex(
                source: "\\text{label} = \\begin{cases} \\text{Great} & \\varepsilon > Q_3 \\\\ \\text{Average} & Q_1 \\leq \\varepsilon \\leq Q_3 \\\\ \\text{Below avg} & \\varepsilon < Q_1 \\end{cases}\n\nQ_1 = history[n/4], \\quad Q_3 = history[3n/4]",
                readable: "Great     →  ε > Q3  (top 25% of your own history)\nAverage   →  Q1 ≤ ε ≤ Q3  (middle 50%)\nBelow avg →  ε < Q1  (bottom 25%)"
            )

            AE.sectionLabel("What each variable means")
            AE.component(symbol: "ε", name: "Efficiency ratio", desc: "Positive = rolling avg climbing. Negative = dipped this session (often noise — one point doesn't alarm).")
            AE.component(symbol: "Δē1RM", name: "Rolling avg delta", desc: "Change in smoothed e1RM. Uses 5-session average — not raw value — to reduce noise.")
            AE.component(symbol: "C_t", name: "Session cost", desc: "Composite cost of this session. Higher cost → harder to maintain high efficiency.")
            AE.component(symbol: "Q1, Q3", name: "Quartile boundaries", desc: "'Great' means top 25% of YOUR history — not a universal standard. Requires ≥4 sessions.")

            AE.sectionLabel("Scenarios")
            AEScenario(emoji: "⭐", label: "Great — top quartile of your history", color: HONTheme.positive,
                context: "Rolling avg jumped after a moderate-cost session.",
                lines: ["Δe1RM = +3.0 kg,   cost = 11.5 units",
                        "ε = 3.0 / 11.5 = +0.261",
                        "",
                        "History Q3 = 0.22  →  0.261 > Q3"],
                verdict: "Great — top 25% of your personal distribution")
            AEScenario(emoji: "📊", label: "Average — middle 50%", color: HONTheme.accent,
                context: "Modest gain, standard cost.",
                lines: ["Δe1RM = +1.5 kg,   cost = 13.1 units",
                        "ε = 1.5 / 13.1 = +0.115",
                        "Q1=0.07, Q3=0.22  →  0.07 ≤ 0.115 ≤ 0.22"],
                verdict: "Average. Solid, sustainable training.")
            AEScenario(emoji: "📉", label: "Below avg — rolling avg dipped", color: HONTheme.warning,
                context: "High-cost session. Rolling avg moved slightly backward (normal noise).",
                lines: ["Δe1RM = −0.8 kg,   cost = 14.0 units",
                        "ε = −0.8 / 14.0 = −0.057",
                        "Q1 = 0.07  →  −0.057 < Q1"],
                verdict: "Below avg for this session. Watch trend over 3–4 sessions.")
            AEScenario(emoji: "🆕", label: "No label yet — insufficient history", color: .secondary,
                context: "Only 3 sessions logged. Quartile split needs at least 4 data points.",
                lines: ["n = 3 efficiency values  →  fewer than 4"],
                verdict: "Shows '—'. Label appears automatically after session 4.")
        }
    }
}

// MARK: - Card 9: Relative Strength

private struct AERelStrengthCard: View {
    var body: some View {
        AECard(icon: "scalemass", color: HONTheme.chartLavender, title: "Relative Strength") {
            AE.sectionLabel("What it is")
            AE.body("Relative strength is your peak estimated 1RM divided by bodyweight. It removes the size advantage — a heavier lifter pressing the same absolute load has lower relative strength.")

            AE.sectionLabel("Why it matters")
            AE.body("Absolute strength during a bulk can be misleading. Adding 8 kg of bodyweight while your bench goes from 100 to 105 kg means relative strength actually fell. Relative strength isolates neural and muscular improvement from mass-driven gains.")

            AE.sectionLabel("The formula")
            AE.latex(
                source: "\\text{Rel. Strength} = e_{1RM}^{PR} / m_{body}",
                readable: "rel_strength  =  PR_e1RM  ÷  bodyweight  (kg)"
            )

            AE.sectionLabel("What each variable means")
            AE.component(symbol: "PR_e1RM", name: "All-time best e1RM", desc: "The highest estimated 1RM ever recorded for this exercise. Your peak strength snapshot.")
            AE.component(symbol: "m_body", name: "Bodyweight (kg)", desc: "Pulled from the most recent bodyMass sample in Apple Health. A prompt appears if unavailable.")

            AE.sectionLabel("Scenarios")
            AEScenario(emoji: "⬆️", label: "Bulk — absolute up, relative down", color: HONTheme.warning,
                context: "3-month bulk. Squat went up but so did bodyweight.",
                lines: ["Before: PR=120 kg, BW=80 kg  →  Rel=1.500×",
                        "After:  PR=128 kg, BW=88 kg  →  Rel=1.455×"],
                verdict: "Absolute +8 kg, relative fell. Mass drove most of the gain.")
            AEScenario(emoji: "💡", label: "Cut — absolute down, relative up", color: HONTheme.positive,
                context: "Lost 5 kg of bodyweight. Strength barely dropped.",
                lines: ["Before: PR=128 kg, BW=88 kg  →  Rel=1.455×",
                        "After:  PR=124 kg, BW=83 kg  →  Rel=1.494×"],
                verdict: "Absolute slightly lower, relative improved. Lean gains confirmed.")
        }
    }
}

// MARK: - Card 11: Fiber Load / PSI

private struct AEFiberLoadCard: View {
    private struct MuscleRow: View {
        let muscle: String; let pcsa: String; let desc: String
        var body: some View {
            HStack(spacing: 8) {
                Text(muscle).font(.system(size: 10, weight: .semibold)).foregroundStyle(.primary).frame(width: 110, alignment: .leading)
                Text(pcsa).font(.system(size: 10, design: .monospaced)).foregroundStyle(HONTheme.accent).frame(width: 40, alignment: .trailing)
                Text(desc).font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 4).padding(.horizontal, 10)
        }
    }

    var body: some View {
        AECard(icon: "fiberchannel", color: HONTheme.chartRose, title: "Personal Strength Index (PSI)") {
            AE.sectionLabel("What it is")
            AE.body("PSI converts every exercise into a universal currency: estimated muscle fiber units. It uses EMG activation data and anatomical PCSA values to weight each exercise by how much real muscle tissue it recruits at what intensity.")

            AE.sectionLabel("Why it matters")
            AE.body("A bench press and a bicep curl cannot be compared by volume alone. PSI normalizes everything to the same denominator — fiber-level work — so your total training stimulus is comparable across different splits, exercises, and phases.")

            AE.sectionLabel("The formula")
            AE.latex(
                source: "\\text{PSI}_{raw} = \\sum_{e} \\sum_{s} \\left( \\frac{w_{s}}{e1RM_{e}}\\right)^{1.8} \\cdot r_{s} \\cdot \\sum_{m} (\\text{EMG}_{e,m} \\cdot \\text{PCSA}_{m})",
                readable: "PSI_raw  =  Σ_exercises  Σ_sets\n  ( w ÷ ref_e1RM )^1.8  ×  reps\n  ×  Σ_muscles ( EMG%  ×  PCSA )"
            )

            AE.sectionLabel("Normalized PSI")
            AE.latex(
                source: "\\text{PSI}_{norm} = \\text{PSI}_{raw} / m_{body}^{0.67}",
                readable: "PSI_norm  =  PSI_raw  ÷  bodyweight^0.67"
            )

            AE.sectionLabel("What each variable means")
            AE.component(symbol: "(w/e1RM)^1.8", name: "Relative intensity load", desc: "Same superlinear intensity term as session cost. Near-maximal sets contribute exponentially more fiber activation.")
            AE.component(symbol: "EMG(e,m)", name: "Activation fraction", desc: "% max voluntary contraction for muscle m during exercise e. From published EMG research on ~70 exercises.")
            AE.component(symbol: "PCSA(m)", name: "Physiological Cross-Section (cm²)", desc: "Anatomical proxy for fiber count. Larger muscles have more fibers and contribute more raw units. From Ward et al. 2009.")
            AE.component(symbol: "BW^0.67", name: "Allometric scaling", desc: "Same exponent used in DOTS scoring. Heavier athletes naturally produce more raw fiber work — dividing by BW^0.67 removes the body mass advantage for fair comparison across your own timeline.")

            AE.sectionLabel("Key PCSA values  (cm²)")
            VStack(spacing: 0) {
                MuscleRow(muscle: "Quadriceps",     pcsa: "148", desc: "Largest muscle group — dominates leg exercises")
                MuscleRow(muscle: "Erector Spinae", pcsa: "90",  desc: "Critical for hip hinges and rows")
                MuscleRow(muscle: "Glute Max",      pcsa: "80",  desc: "Primary driver of hip extension")
                MuscleRow(muscle: "Hamstrings",     pcsa: "75",  desc: "RDLs, leg curls, all hip hinges")
                MuscleRow(muscle: "Latissimus",     pcsa: "45",  desc: "Pulldowns, rows — back width")
                MuscleRow(muscle: "Pec Major",      pcsa: "35",  desc: "All pressing movements")
                MuscleRow(muscle: "Triceps",        pcsa: "22",  desc: "Bench press, OHP, isolation")
                MuscleRow(muscle: "Biceps",         pcsa: "15",  desc: "Curls, rows, pull-up assist")
            }
            .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

            AE.sectionLabel("Scenarios")
            AEScenario(emoji: "🦵", label: "Squat vs Curl — fiber weighting in action", color: HONTheme.chartRose,
                context: "Both at same relative intensity and reps. PSI contribution differs massively.",
                lines: ["Squat: EMG×PCSA ≈ 0.9×148 + 0.7×80 + 0.6×75 = 244 units",
                        "Bicep Curl: EMG×PCSA ≈ 0.95×15 = 14 units",
                        "",
                        "Squat contributes ~17× more PSI per rep than curl."],
                verdict: "PSI correctly weights compound movements as the primary drivers.")
            AEScenario(emoji: "📈", label: "Rising PSI, flat e1RM", color: HONTheme.accent,
                context: "Added training volume. Individual lifts plateaued but total work increased.",
                lines: ["Weekly PSI: 420 → 510 (+21%)",
                        "Bench press e1RM: 100 → 101 kg  (flat)"],
                verdict: "Doing more total muscle work — volume phase confirmed.")
            AEScenario(emoji: "💡", label: "Flat PSI, rising e1RM", color: HONTheme.positive,
                context: "Same training load. Lifts getting stronger.",
                lines: ["Weekly PSI: 480 → 482 (~flat)",
                        "Deadlift e1RM: 140 → 148 kg (+5.7%)"],
                verdict: "Getting stronger per unit of fiber work — neural efficiency rising.")
        }
    }
}

// MARK: - Card 12: Composite Strength Score

private struct AECompositeScoreCard: View {
    private struct PillarRow: View {
        let name: String; let weight: String; let color: Color; let desc: String
        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                Text(weight).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(color).frame(width: 32, alignment: .trailing)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.caption.bold()).foregroundStyle(.primary)
                    Text(desc).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 5).padding(.horizontal, 10)
        }
    }
    private struct GradeRow: View {
        let grade: String; let range: String; let meaning: String; let color: Color
        var body: some View {
            HStack(spacing: 8) {
                Text(grade).font(.system(size: 11, weight: .bold)).foregroundStyle(color).frame(width: 72, alignment: .leading)
                Text(range).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 54, alignment: .leading)
                Text(meaning).font(.caption).foregroundStyle(.primary)
                Spacer()
            }
            .padding(.vertical, 5).padding(.horizontal, 10)
        }
    }

    var body: some View {
        AECard(icon: "star.circle.fill", color: HONTheme.chartLavender, title: "Composite Strength Score (CSS)") {
            AE.sectionLabel("What it is")
            AE.body("CSS is a single 0–100 number that answers: 'How well am I doing at getting stronger right now?' It combines every analytics metric into three pillars, each weighted by its predictive importance.")

            AE.sectionLabel("The formula")
            AE.latex(
                source: "\\text{CSS} = 0.35 \\cdot \\text{Level} + 0.40 \\cdot \\text{Momentum} + 0.25 \\cdot \\text{Process}",
                readable: "CSS  =  0.35 × Level\n     +  0.40 × Momentum\n     +  0.25 × Process"
            )

            AE.sectionLabel("The three pillars")
            VStack(spacing: 0) {
                PillarRow(name: "Level (35%)", weight: "35%", color: HONTheme.accent,
                    desc: "Current e1RM average as % of personal best. Drops after deloads and illness, rises as you approach PRs.")
                Divider().padding(.horizontal, 10)
                PillarRow(name: "Momentum (40%)", weight: "40%", color: HONTheme.positive,
                    desc: "How fast you are improving right now. OLS %/week trend, clamped: 0 → 50pts, +2%/wk → 100pts. Uses best of standard vs fatigue-adjusted trend.")
                Divider().padding(.horizontal, 10)
                PillarRow(name: "Process (25%)", weight: "25%", color: HONTheme.chartLavender,
                    desc: "Training quality from three sub-scores: INOL (40%) + Efficiency (40%) + Rep Decay (20%).")
            }
            .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

            AE.sectionLabel("Pillar detail — Momentum")
            AE.latex(
                source: "\\text{Momentum} = \\text{clamp}(50 + \\%/wk \\times 25, \\, 0, \\, 100)",
                readable: "Momentum  =  clamp( 50 + (%/wk × 25), 0, 100 )\n0 %/wk → 50pts,  +2%/wk → 100pts"
            )

            AE.sectionLabel("Pillar detail — Process")
            AE.latex(
                source: "\\text{INOL score} = \\max(0, \\, 100 - |INOL - 1.15| \\times 55)\n\\text{Eff score: } \\geq Q3\\to90, \\;\\geq Q1\\to60, \\;<Q1\\to25",
                readable: "INOL: 100 at INOL=1.15, −55pts per unit away\nEff: Great→90, Average→60, Below avg→25\nDecay: −1.5 to −0.5 → 100pts, outside → lower"
            )

            AE.sectionLabel("Score scale")
            VStack(spacing: 0) {
                GradeRow(grade: "Peak",       range: "90–100", meaning: "Peak form — everything firing",          color: HONTheme.chartAmber)
                GradeRow(grade: "Strong",     range: "80–89",  meaning: "Strong gains, good process",             color: HONTheme.positive)
                GradeRow(grade: "Solid",      range: "70–79",  meaning: "Consistent progress",                    color: HONTheme.accent)
                GradeRow(grade: "Building",   range: "60–69",  meaning: "Progress, but inconsistent",             color: HONTheme.warning)
                GradeRow(grade: "Steady",      range: "50–59",  meaning: "Maintaining — base is solid",            color: HONTheme.warning)
                GradeRow(grade: "Developing", range: "35–49",  meaning: "Early progress — keep adding sessions",  color: HONTheme.warning)
                GradeRow(grade: "Starting",   range: "< 35",   meaning: "Low stimulus — more data needed",        color: Color(.systemGray))
            }
            .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 10))

            AE.sectionLabel("The coaching insight")
            AE.body("The CSS insight identifies the weakest pillar and drills into its sub-components. If Process is the drag, it tells you whether INOL, efficiency, or rep decay is the specific problem — and what to do about it.")

            AE.sectionLabel("Scenarios")
            AEScenario(emoji: "🔥", label: "Peak score — full worked example", color: HONTheme.chartAmber,
                context: "Peak week: near PR lifts, optimal INOL, efficient session.",
                lines: ["Level:    ≈95/100  (e1RMs near all-time best)",
                        "Momentum: ≈88/100  (+1.5%/wk  trend)",
                        "Process:  ≈91/100  (INOL=1.1, Eff=Great, Decay=−1.2)",
                        "",
                        "CSS = 0.35×95 + 0.40×88 + 0.25×91",
                        "    = 33.3 + 35.2 + 22.8  =  91.3"],
                verdict: "Peak. Keep the program — don't change what's working.")
            AEScenario(emoji: "📉", label: "Building score — momentum drag", color: HONTheme.warning,
                context: "Level is high but e1RMs have stalled for 6 weeks.",
                lines: ["Level:    85/100  (still near PRs)",
                        "Momentum: 40/100  (slope ≈ −0.2%/wk)",
                        "Process:  70/100  (training quality fine)",
                        "",
                        "CSS = 0.35×85 + 0.40×40 + 0.25×70",
                        "    = 29.8 + 16.0 + 17.5  =  63.3"],
                verdict: "Building. Coaching note: vary stimulus on stalled exercises.")
            AEScenario(emoji: "😴", label: "Deload week — low Level, fine overall", color: HONTheme.accent,
                context: "Intentional light week. Level drops but Momentum still positive.",
                lines: ["Level:    55/100  (volume reduced, e1RMs dipped)",
                        "Momentum: 72/100  (positive trend before deload)",
                        "Process:  80/100  (low INOL = appropriate deload)",
                        "",
                        "CSS = 0.35×55 + 0.40×72 + 0.25×80",
                        "    = 19.3 + 28.8 + 20.0  =  68.1"],
                verdict: "Solid during a planned deload. Expected and healthy.")
        }
    }
}

// MARK: - Card 13: Body Comp Strength

private struct AEBodyCompCard: View {
    var body: some View {
        AECard(icon: "figure.strengthtraining.traditional", color: HONTheme.chartSage, title: "Body Composition Strength") {
            AE.sectionLabel("What it is")
            AE.body("Body Comp strength normalizes PSI by lean mass, muscle mass, and body fat — going beyond bodyweight scaling to reveal how efficiently your lean tissue and skeletal muscle is being trained.")

            AE.sectionLabel("Why it matters")
            AE.body("During a bulk, PSI ÷ bodyweight might stay flat while PSI ÷ lean mass rises — telling you the new mass is productive. During a cut, if strength holds but fat mass drops, PSI ÷ fat% spikes — confirming you're retaining muscle while losing fat. None of this is visible in absolute numbers.")

            AE.sectionLabel("The three metrics")
            AE.latex(
                source: "\\text{PSI}_{lean} = \\text{PSI}_{raw} / m_{lean}^{0.67}\n\\text{PSI}_{muscle} = \\text{PSI}_{raw} / m_{muscle}^{0.67}\n\\text{Fiber/Fat} = \\text{PSI}_{raw} / \\%BF",
                readable: "PSI÷Lean    =  PSI_raw  ÷  leanMass^0.67\nPSI÷Muscle  =  PSI_raw  ÷  muscleMass^0.67\nFiber/Fat   =  PSI_raw  ÷  body_fat_pct"
            )

            AE.sectionLabel("What each variable means")
            AE.component(symbol: "leanMass", name: "Lean body mass (kg)", desc: "Total mass minus fat: BW × (1 − BF%). Includes muscle, bone, water.")
            AE.component(symbol: "muscleMass", name: "Skeletal muscle mass (kg)", desc: "Pure contractile tissue — closer to what matters for strength.")
            AE.component(symbol: "BF%", name: "Body fat percent", desc: "Dividing by fat% creates a ratio that improves both when you lose fat and when you gain strength.")
            AE.component(symbol: "^0.67", name: "Allometric exponent", desc: "Same as PSI normalization. Prevents larger lean mass from automatically looking more efficient.")

            AE.sectionLabel("Data requirements")
            AE.body("Requires body fat % and/or muscle mass % entered in Settings → Body Composition. These values come from smart scales (InBody, Tanita), DEXA scan, or manual entry. Update whenever you take a new reading.")

            AE.sectionLabel("Scenarios")
            AEScenario(emoji: "🔼", label: "Bulk — rising lean mass", color: HONTheme.positive,
                context: "3-month bulk. Added 3 kg lean mass. PSI grew 15%.",
                lines: ["Before: PSI=480, lean=65 kg  →  PSI÷lean^0.67 = 12.1",
                        "After:  PSI=552, lean=68 kg  →  PSI÷lean^0.67 = 13.5",
                        "",
                        "PSI ÷ lean rose despite more lean mass."],
                verdict: "New lean tissue is productive — strength growing faster than mass.")
            AEScenario(emoji: "🔽", label: "Cut — losing fat, retaining muscle", color: HONTheme.chartSage,
                context: "Lost 4 kg, mostly fat. PSI nearly flat.",
                lines: ["Before: PSI=500, lean=65 kg, BF=20%  →  Fiber/Fat=25.0",
                        "After:  PSI=495, lean=64 kg, BF=16%  →  Fiber/Fat=30.9",
                        "",
                        "BF% dropped → Fiber/Fat ratio improved +24%."],
                verdict: "Body fat% fell while strength held — successful recomp confirmed.")
            AEScenario(emoji: "⚠️", label: "Overtraining — PSI÷muscle falling", color: HONTheme.negative,
                context: "Training volume doubled. Muscle mass held but PSI output dropped.",
                lines: ["PSI:    500 → 480  (−4%)",
                        "Muscle: 40 → 40 kg  (flat)",
                        "PSI÷muscle^0.67: 18.8 → 18.0  (−4%)"],
                verdict: "More volume, less output per unit of muscle. Sign of overreaching.")
        }
    }
}

// MARK: - Card 10: Plateau

private struct AEPlateauCard: View {
    var body: some View {
        AECard(icon: "exclamationmark.triangle", color: HONTheme.warning, title: "Plateau Detection") {
            AE.sectionLabel("What it is")
            AE.body("The plateau flag fires when the OLS slope over the last 4 weeks falls below a conservative threshold — meaning your strength trend has effectively flattened, not just had one bad session.")

            AE.sectionLabel("Why it matters")
            AE.body("One regression session is noise. But if the best-fit line through your last 4 weeks is nearly horizontal, the current stimulus is failing to drive adaptation. Something in the program needs to change.")

            AE.sectionLabel("The rule")
            AE.latex(
                source: "\\text{plateau} = \\begin{cases} \\text{true} & \\hat{\\beta}_{4wk} < 0.5\\,\\text{kg/wk AND}\\, n \\geq 3 \\\\ \\text{false} & \\text{otherwise} \\end{cases}",
                readable: "plateau = true  if:\n  slope (last 4 weeks) < 0.5 kg/wk\n  AND  sessions in window ≥ 3"
            )

            AE.sectionLabel("What each variable means")
            AE.component(symbol: "β̂₄wk", name: "4-week OLS slope", desc: "Same OLS formula restricted to the last 28 days. Locally sensitive to recent stagnation without distortion from older sessions.")
            AE.component(symbol: "0.5 kg/wk", name: "Threshold", desc: "Conservative — even 0.6 kg/wk clears the flag. 0.5 kg/wk ≈ +2 kg/month, the lower bound of meaningful intermediate progress.")
            AE.component(symbol: "n ≥ 3", name: "Minimum sessions", desc: "With only 1–2 sessions in the window, there's not enough data to call a plateau. Insufficient data ≠ no progress.")

            AE.sectionLabel("Scenarios")
            AEScenario(emoji: "🟡", label: "Plateau triggered — stagnant month", color: HONTheme.warning,
                context: "Numbers circling the same range for 4 weeks.",
                lines: ["e1RM: 95.0, 95.5, 94.5, 95.0 kg",
                        "OLS slope ≈ −0.10 kg/wk  <  0.5",
                        "n = 4  ≥  3  ✓",
                        "",
                        "Suggested fixes:",
                        "  · Add 2.5–5 kg to working weight",
                        "  · Change rep range (3×5 → 4×8)",
                        "  · Add a second weekly session",
                        "  · Audit sleep, stress, calorie intake"],
                verdict: "Flag triggers. Change the stimulus.")
            AEScenario(emoji: "✅", label: "Flag suppressed — sparse window", color: HONTheme.positive,
                context: "Only trained twice in 4 weeks due to travel.",
                lines: ["Sessions in window: 2  <  3 minimum"],
                verdict: "Not enough data to declare a plateau. Flag stays off.")
            AEScenario(emoji: "📈", label: "Slow but sufficient — no flag", color: HONTheme.accent,
                context: "Intermediate lifter gaining slowly but consistently.",
                lines: ["4-week slope: +0.7 kg/wk",
                        "0.7  ≥  0.5 threshold"],
                verdict: "No plateau. Slow, consistent progress still counts.")
        }
    }
}
