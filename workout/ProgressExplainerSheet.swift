import SwiftUI

// MARK: - Topic

enum ProgressExplainerTopic: String, Identifiable {
    case activityHeatmap        = "Activity Heatmap"
    case strengthCurve          = "Strength Curve & Volume"
    case strengthGainByPattern  = "Strength Gain by Pattern"
    case efficiencyMatrix       = "Efficiency Matrix"
    case keyInsights            = "Key Insights"
    case progressTracker        = "Progress Tracker"
    case personalRecords        = "Personal Records"
    var id: String { rawValue }
}

// MARK: - Sheet

struct ProgressExplainerSheet: View {
    let topic: ProgressExplainerTopic
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 40)
            }
            .background(AppTheme.pageBG)
            .navigationTitle(topic.rawValue)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch topic {
        case .activityHeatmap:       activityContent
        case .strengthCurve:         strengthCurveContent
        case .strengthGainByPattern: patternContent
        case .efficiencyMatrix:      matrixContent
        case .keyInsights:           insightsContent
        case .progressTracker:       trackerContent
        case .personalRecords:       prContent
        }
    }

    // MARK: - Activity Heatmap

    private var activityContent: some View {
        Group {
            card(icon: "calendar", color: HONTheme.accent, title: "What Each Tile Represents") {
                body("Each tile is one calendar day over the past 30 days, ordered left-to-right from oldest to most recent. A blue tile means at least one workout was completed and saved on that date.")
                body("Bucketing uses Calendar.current.startOfDay() — two sessions at 6 AM and 11 PM on the same calendar date count as a single active day, not two.")
            }
            card(icon: "waveform.path", color: HONTheme.accent, title: "What Good Looks Like") {
                body("Consistency matters more than raw density. Research on resistance training adaptation shows 3–4 sessions per week, evenly distributed, outperforms cramming sessions or training daily without recovery.")
                VStack(alignment: .leading, spacing: 6) {
                    irow("3–4 blue tiles / wk", "Optimal frequency for most lifters", HONTheme.positive)
                    irow("5+ consecutive grey",  "Compliance gap — worth reviewing", HONTheme.warning)
                    irow("7+ consecutive blue",  "Likely insufficient recovery time", HONTheme.negative)
                }
                body("The strip always reflects the 30 calendar days ending today — it shifts one tile to the left every midnight.")
            }
        }
    }

    // MARK: - Strength Curve & Volume

    private var strengthCurveContent: some View {
        Group {
            card(icon: "chart.line.uptrend.xyaxis", color: HONTheme.accent, title: "Weekly Max e1RM (Top Chart)") {
                body("For each ISO week (Monday–Sunday), the chart finds the highest Epley estimated 1RM across all completed sets of the selected exercise. One point per week regardless of how many sessions you had.")
                formula("weekly_e1RM = max(weight × (1 + reps/30))\n              over all completed sets that week")
                body("The solid blue line uses Catmull-Rom spline interpolation for visual smoothness. The underlying data is the discrete weekly maxima — each faint dot is one actual week. The smooth curve is visual only; the math uses the raw points.")
                example(
                    title: "Example — week with 2 sessions",
                    lines: [
                        "Session 1:  80 kg × 6  →  e1RM = 96.0 kg",
                        "            82 kg × 4  →  e1RM = 92.9 kg",
                        "Session 2:  80 kg × 7  →  e1RM = 98.7 kg",
                        "",
                        "Weekly max = 98.7 kg  (session 2, set 1)",
                        "This single value is plotted for the week.",
                        "",
                        "Effect: lighter technique sessions don't drag",
                        "the chart down — only peak performance counts."
                    ],
                    note: nil
                )
            }
            card(icon: "arrow.up.right.circle", color: HONTheme.chartSlate, title: "4-Week Projection (Dashed Line)") {
                body("The dashed ghost line projects 4 weeks beyond your most recent data point using an observed-rate-with-diminishing-returns model. It is not a guarantee — it shows the expected trajectory if training quality stays consistent.")
                formula(
                    "weeklyRate = (last_e1RM − first_e1RM) / (n_weeks − 1)\n" +
                    "             floored at 1.0 kg/wk if stalled\n\n" +
                    "projected[i] = startValue +\n" +
                    "    Σ_{j=0}^{i−1}  weeklyRate × 0.88^j\n\n" +
                    "No data (compound):   default 2.5 kg/wk\n" +
                    "No data (isolation):  default 1.25 kg/wk"
                )
                body("The 0.88 factor is a diminishing-returns multiplier — each successive projected week gains slightly less than the last. This models the empirical observation that strength gains decelerate as you approach your ceiling. The series Σ 0.88^j converges to 1/(1−0.88) = 8.33, so the maximum theoretical total gain from any rate is rate × 8.33 kg.")
                example(
                    title: "Example — rate = 4.0 kg/wk, start = 118 kg",
                    lines: [
                        "Wk+1: 118 + 4.0 × 0.88⁰ = 118 + 4.00 = 122.0 kg",
                        "Wk+2: 122 + 4.0 × 0.88¹ = 122 + 3.52 = 125.5 kg",
                        "Wk+3: 125.5 + 4.0 × 0.88² = 125.5 + 3.10 = 128.6 kg",
                        "Wk+4: 128.6 + 4.0 × 0.88³ = 128.6 + 2.73 = 131.3 kg",
                        "",
                        "Total projected gain: +13.3 kg over 4 weeks",
                        "vs. linear extrapolation: +16.0 kg",
                        "→ diminishing returns shave off ~3 kg"
                    ],
                    note: "If your rate has stalled (e.g. flat at 100 kg for weeks), the floor of 1.0 kg/wk still shows a slight positive slope — treat it as a lower bound, not a prediction."
                )
            }
            card(icon: "chart.bar.fill", color: HONTheme.positive, title: "Weekly Volume Bars (Bottom Chart)") {
                body("The stacked bars show total training volume per week split by body region. Volume is displayed in tonnes (kg × reps ÷ 1,000) for readability — raw kg values on a weekly basis often exceed 10,000 for compound lifters.")
                formula(
                    "volume = Σ (set.weight × set.reps)\n" +
                    "         for all completed sets in the week\n\n" +
                    "Stacked by body region.\n" +
                    "X-axis is the same ISO-week grid as the\n" +
                    "strength line — the two charts are aligned."
                )
                body("Use this chart alongside the strength line to read the relationship between effort (volume) and output (e1RM gain).")
                example(
                    title: "Patterns to look for",
                    lines: [
                        "Volume ↑, e1RM flat:",
                        "  Body adapting; strength expression lagging.",
                        "  Common in first 4–6 weeks of a new programme.",
                        "",
                        "Volume flat, e1RM ↑:",
                        "  Neural efficiency improving.",
                        "  Typical in intermediate lifters 6–12 wks in.",
                        "",
                        "Volume ↓, e1RM ↑:",
                        "  Deload effect — recovered CNS expressing stored adaptation.",
                        "",
                        "Both flat:",
                        "  Plateau territory — check INOL in Full Analysis."
                    ],
                    note: nil
                )
            }
        }
    }

    // MARK: - Strength Gain by Pattern

    private var patternContent: some View {
        Group {
            card(icon: "list.bullet.rectangle", color: HONTheme.chartLavender, title: "Movement Pattern Classification") {
                body("Every exercise in the database is tagged with one of seven movement patterns. This collapses the exercise space into meaningful training modalities, letting you compare push strength vs. pull, or hip hinge vs. knee flexion.")
                VStack(alignment: .leading, spacing: 5) {
                    prow("Horizontal Push", "Bench press, push-up, cable fly")
                    prow("Vertical Push",   "Overhead press, Arnold press")
                    prow("Horizontal Pull", "Row variations, face pull, cable row")
                    prow("Vertical Pull",   "Pull-up, lat pulldown, straight-arm")
                    prow("Hip Hinge",        "Deadlift, RDL, good morning")
                    prow("Knee Flexion",     "Squat, lunge, leg press, step-up")
                    prow("Isolation",        "Curl, extension, lateral raise, fly")
                }
                .padding(.vertical, 2)
            }
            card(icon: "function", color: HONTheme.chartLavender, title: "How Improvement Rate Is Computed") {
                body("Each exercise gets an OLS slope (kg/wk) over its last 6 weeks of sessions, converted to %/wk by dividing by mean e1RM. The pattern rate is the session-count-weighted mean across all exercises in the pattern.")
                formula(
                    "per-exercise:\n" +
                    "  slope  = OLS(e1RM ~ weeks_from_first)\n" +
                    "  pct/wk = slope / mean(e1RM) × 100\n\n" +
                    "per-pattern:\n" +
                    "  rate = Σᵢ (pct_i × sessions_i)\n" +
                    "         ÷ Σᵢ sessions_i"
                )
                body("Session-count weighting ensures the signal comes from your most-practised exercises. An exercise you've done 12 times should drive the pattern rate far more than one done once or twice.")
                example(
                    title: "Example — Horizontal Push",
                    lines: [
                        "Bench Press:   12 sessions, +1.2%/wk",
                        "Dumbbell Fly:   3 sessions, −0.4%/wk",
                        "",
                        "Weighted rate:",
                        "  = (1.2 × 12 + (−0.4) × 3) / (12 + 3)",
                        "  = (14.4 − 1.2) / 15",
                        "  = 13.2 / 15  =  +0.88%/wk",
                        "",
                        "Simple (unweighted) average:",
                        "  = (1.2 − 0.4) / 2  =  +0.40%/wk",
                        "",
                        "The fly's negative rate inflates the simple avg.",
                        "Weighting suppresses the noise from 3 sessions."
                    ],
                    note: "Bar colour matches the efficiency quadrant: green = Efficient, blue = Opportunity, orange = Inefficient, gray = Low Priority. The colour is consistent between the bar chart and the matrix below it."
                )
            }
        }
    }

    // MARK: - Efficiency Matrix

    private var matrixContent: some View {
        Group {
            card(icon: "square.grid.2x2", color: HONTheme.positive, title: "The Two Axes") {
                body("Each movement pattern lands in one of four quadrants based on two independently computed dimensions:")
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("Volume").font(.caption.bold()).frame(width: 60, alignment: .leading)
                        Text("Average kg lifted per week over the last 6 weeks, summed across all exercises in the pattern.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("Gain").font(.caption.bold()).frame(width: 60, alignment: .leading)
                        Text("Session-count-weighted %/wk improvement rate — the same number shown in the bar chart above.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
                body("Classification uses a median split on each axis, not fixed absolute thresholds. This keeps it self-referential — 'Efficient' always means the best quadrant of your current training mix.")
                formula(
                    "medVol = median(weekly_volume, all patterns)\n" +
                    "medImp = median(improvement_rate, all patterns)\n\n" +
                    "quadrant = f(vol ≥ medVol, imp ≥ medImp)"
                )
            }
            card(icon: "square.grid.2x2.fill", color: HONTheme.positive, title: "Quadrant Meanings & Actions") {
                qrow(icon: "checkmark.circle.fill", color: HONTheme.positive, label: "Efficient",
                     subtitle: "High volume · High gain",
                     meaning: "Volume and intensity are dialled in. Don't break what's working. Consider a small progressive overload — add 1 set or +2.5 kg — to keep the stimulus novel, but don't chase volume for its own sake.")
                Divider().padding(.vertical, 4)
                qrow(icon: "arrow.up.right.circle.fill", color: HONTheme.accent, label: "Opportunity",
                     subtitle: "Low volume · High gain",
                     meaning: "Your body responds strongly to a small stimulus. This is the highest ROI pattern in your training. Adding 1–2 sets/week here should compound quickly. Don't add too much too fast — the response is already good.")
                Divider().padding(.vertical, 4)
                qrow(icon: "exclamationmark.circle.fill", color: HONTheme.warning, label: "Inefficient",
                     subtitle: "High volume · Low gain",
                     meaning: "You're spending significant training budget here without converting it to strength. Two likely causes: (1) volume past the productive maximum — cut 20–30% of sets and raise intensity; (2) insufficient recovery — reduce frequency or add a deload.")
                Divider().padding(.vertical, 4)
                qrow(icon: "minus.circle.fill", color: .gray, label: "Low Priority",
                     subtitle: "Low volume · Low gain",
                     meaning: "Either under-stimulated or deliberately deprioritised. If this pattern matters to your goals, add frequency or load. If it doesn't, leave it and invest elsewhere — not every pattern needs to be maximised simultaneously.")
            }
            card(icon: "ruler", color: .secondary, title: "Edge Cases in the Median Split") {
                body("With an odd number of patterns the median is the middle value. With an even number it's the average of the two middle values. Patterns that land exactly on the boundary are treated as above-median (ties go to the higher quadrant). With only 2 patterns, one will always be above and one below on each axis — producing one of the four quadrants per pattern.")
            }
        }
    }

    // MARK: - Key Insights

    private var insightsContent: some View {
        card(icon: "lightbulb", color: HONTheme.chartAmber, title: "How Insights Are Generated") {
            body("Up to three bullet points are generated from rule-based logic over the computed analytics. Rules fire in priority order; only the first 3 to trigger are shown.")
            VStack(alignment: .leading, spacing: 10) {
                irule("1", "Fastest-improving pattern",
                      "Fires if any pattern has improvement rate > 0.1%/wk. Names the pattern and its rate.")
                irule("2", "Inefficiency warning",
                      "Fires if any pattern is in the Inefficient quadrant. Prompts a volume–intensity rebalance.")
                irule("3", "Stalled exercises",
                      "Fires if any exercise has OLS slope < 0.5 kg/wk with ≥3 sessions in the last 4 weeks. Lists up to 2 exercise names.")
                irule("4", "Opportunity alert",
                      "Fires only if rule 3 did not — names the Opportunity-quadrant pattern. Problems before opportunities.")
            }
            body("If all four rules trigger, only 3 are shown — the stalled-exercise rule takes slot 3 over the opportunity rule.")
        }
    }

    // MARK: - Progress Tracker

    private var trackerContent: some View {
        Group {
            card(icon: "arrow.up.right", color: HONTheme.positive, title: "Getting Stronger") {
                body("An exercise appears here when its OLS e1RM slope is positive over the last 6 weeks AND at least 2 sessions exist in that window. The displayed gain is the raw difference between the most recent and oldest e1RM in the window — not the regression slope.")
                formula(
                    "gain = e1RM[last session in 6-wk window]\n" +
                    "     − e1RM[first session in 6-wk window]\n\n" +
                    "Condition: OLS slope > 0  AND  sessions ≥ 2\n" +
                    "Display:   top 5 by absolute gain"
                )
                body("Showing absolute gain rather than % favours compound lifts, which is intentional — a +5 kg bench improvement is more meaningful than +2 kg on a curl, even if the percentage is the same.")
            }
            card(icon: "exclamationmark.circle", color: HONTheme.warning, title: "Needs Attention (Stalled)") {
                body("An exercise appears here when the OLS slope is below 0.5 kg/wk over the last 6 weeks AND there are at least 3 sessions in that window. The 0.5 kg/wk floor is deliberately conservative — even slow, marginal progress avoids the flag.")
                formula(
                    "stalled = (OLS slope < 0.5 kg/wk)\n" +
                    "        AND (sessions in 6-wk window ≥ 3)"
                )
                body("Common causes and suggested fixes:")
                VStack(alignment: .leading, spacing: 6) {
                    srow("Same weight / reps every session", "Increase load 1.25–2.5 kg next session")
                    srow("Fatigue accumulation",             "Planned deload — cut volume 40% for one week")
                    srow("Volume too low (INOL < 0.4)",      "Add 1–2 sets; check Full Analysis drill-down")
                    srow("Technique ceiling",                "Swap variation (e.g. close-grip → incline bench)")
                    srow("Recovery deficit",                 "Audit sleep quality and protein intake")
                }
            }
        }
    }

    // MARK: - Personal Records

    private var prContent: some View {
        Group {
            card(icon: "trophy.fill", color: HONTheme.chartAmber, title: "How PRs Are Detected") {
                body("On workout finish, every completed set's Epley e1RM is compared to the stored PR for that exercise. If it's higher — or no PR exists yet — the new set becomes the PR. Detection runs at finish, not during an active session.")
                formula(
                    "e1RM = weight × (1 + reps / 30)\n\n" +
                    "PR updated if: e1RM > stored_PR.estimated1RM\n" +
                    "              OR no PR exists for this exercise"
                )
                example(
                    title: "Example",
                    lines: [
                        "Previous PR: 90 kg × 3  →  e1RM = 99.0 kg",
                        "",
                        "Today's sets (all completed):",
                        "  85 kg × 5  →  e1RM = 99.2 kg  ✓ New PR",
                        "  85 kg × 4  →  e1RM = 96.3 kg",
                        "  82.5 kg × 5 → e1RM = 96.3 kg",
                        "",
                        "New PR stored: 85 kg × 5, e1RM ≈ 99.2 kg",
                        "",
                        "A lighter set for more reps legitimately beats",
                        "a heavier set for fewer reps if Epley says so."
                    ],
                    note: "Only the highest e1RM set in a session triggers a PR check — not every set independently. If you're mid-workout and smash a new best, it won't appear here until you tap 'Finish'."
                )
            }
            card(icon: "list.bullet", color: HONTheme.chartAmber, title: "Display & Grouping") {
                body("PRs are grouped by body region (Chest, Back, Shoulders, Arms, Legs, Core) and sorted by estimated 1RM descending within each region. Strongest lift per region is always at the top.")
                body("Each row shows:")
                VStack(alignment: .leading, spacing: 5) {
                    drow("Exercise",    "The movement the PR was set on")
                    drow("Date",        "Calendar date the PR workout was finished")
                    drow("Wt × Reps",   "The actual set that established the PR")
                    drow("≈ X kg 1RM",  "Epley estimate for that set")
                }
                .padding(.vertical, 2)
                body("If the same exercise could plausibly be filed under two regions (e.g. a compound shoulder-and-chest movement), it's filed under its single tagged primary region only. The tagging is set in the exercise database.")
            }
        }
    }

    // MARK: - Reusable helpers

    private func card<C: View>(icon: String, color: Color, title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.subheadline.bold()).foregroundStyle(color).frame(width: 24)
                Text(title).font(.headline)
            }
            content()
        }
        .padding(16)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 14))
    }

    private func body(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
    }

    private func formula(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Color(.label))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.insetBG, in: RoundedRectangle(cornerRadius: 8))
    }

    private func example(title: String, lines: [String], note: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.bold()).foregroundStyle(HONTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(lines, id: \.self) { line in
                    if line.isEmpty { Spacer().frame(height: 4) }
                    else { Text(line).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color(.label)) }
                }
            }
            if let note {
                Divider()
                Text(note).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(HONTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private func irow(_ label: String, _ meaning: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label).font(.system(size: 11, design: .monospaced)).foregroundStyle(color).frame(width: 90, alignment: .leading)
            Text(meaning).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func prow(_ pattern: String, _ examples: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(pattern).font(.caption.bold()).frame(width: 110, alignment: .leading)
            Text(examples).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func qrow(icon: String, color: Color, label: String, subtitle: String, meaning: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(color).font(.subheadline)
                Text(label).font(.caption.bold()).foregroundStyle(color)
                Text("·").foregroundStyle(.secondary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Text(meaning).font(.caption).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func irule(_ n: String, _ title: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(n).font(.caption2.bold()).foregroundStyle(HONTheme.textPrimary)
                .frame(width: 16, height: 16).background(HONTheme.chartAmber, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.bold())
                Text(description).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func srow(_ cause: String, _ fix: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("→").font(.caption).foregroundStyle(HONTheme.warning).frame(width: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(cause).font(.caption.bold())
                Text(fix).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func drow(_ label: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label).font(.caption.bold()).frame(width: 70, alignment: .leading)
            Text(description).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
