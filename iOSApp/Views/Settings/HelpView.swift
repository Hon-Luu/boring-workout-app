import SwiftUI

// MARK: - Help Data

struct HelpTopic: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let body: String
    let tips: [String]
}

// MARK: - HelpView

struct HelpView: View {
    @State private var searchText = ""
    @State private var expanded: UUID? = nil

    private var topics: [HelpTopic] { HelpContent.all }
    private var filtered: [HelpTopic] {
        guard !searchText.isEmpty else { return topics }
        let q = searchText.lowercased()
        return topics.filter {
            $0.title.lowercased().contains(q) ||
            $0.body.lowercased().contains(q) ||
            $0.subtitle.lowercased().contains(q)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { topic in
                DisclosureGroup(isExpanded: Binding(
                    get: { expanded == topic.id },
                    set: { expanded = $0 ? topic.id : nil }
                )) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(topic.body)
                            .font(.subheadline).foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                        ForEach(topic.tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill").font(.caption2).foregroundStyle(HONTheme.accent)
                                Text(tip).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: topic.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(topic.color)
                            .frame(width: 28, height: 28)
                            .background(topic.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(topic.title).font(.subheadline.bold())
                            Text(topic.subtitle).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search help…")
        .navigationTitle("Help & Manual")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Help Content

enum HelpContent {
    static let all: [HelpTopic] = [

        HelpTopic(
            title: "Getting Started",
            subtitle: "Log your first workout",
            icon: "play.circle.fill",
            color: HONTheme.positive,
            body: "H.O.N is built around five tabs: Home (daily dashboard), Workout (log sessions and circuits), History (full activity log), Insights (analytics), and Settings (profile and preferences). To log your first workout, tap \"Start Workout\" on the Home screen, add an exercise, enter your weight and reps, and tap the checkmark to complete each set. The app saves every change automatically — there is no save button. The philosophy here is boring, consistent tracking: small honest logs every session compound into meaningful data over time.",
            tips: [
                "Start with 3 main exercises per session — you don't need to fill in every field. Weight and reps alone are enough to unlock core analytics.",
                "You don't need a routine to begin. Just tap \"Start Workout\" from the Home screen and build from there."
            ]
        ),

        HelpTopic(
            title: "Logging a Workout",
            subtitle: "Sets, reps, weight & more",
            icon: "dumbbell.fill",
            color: HONTheme.accent,
            body: "Start a free workout from the Home screen or load a planned routine from the Workout tab. Once inside, tap \"Add Exercise\" and search by name or browse by muscle group. For each set, tap the row to enter weight and reps — the previous session's numbers pre-fill as a guide. Tap the circle or checkmark to mark a set complete. You can optionally log RPE (Rate of Perceived Exertion, scale 1–10) to describe how hard the set felt; this feeds the coaching quality score and avg RPE trend. Every change auto-saves instantly so you never lose data if you close the app mid-session.",
            tips: [
                "Complete each set with the checkmark — this is what triggers PR detection and rest timer start.",
                "RPE is optional but unlocks better coaching. An RPE of 7–8 is the productive training zone for most people.",
                "Bilateral exercises (dumbbells): enter the per-hand weight — the app automatically records the combined total."
            ]
        ),

        HelpTopic(
            title: "Rest Timer",
            subtitle: "Auto-starts after each set",
            icon: "timer",
            color: HONTheme.chartSlate,
            body: "Every time you complete a set, the rest timer starts automatically at the top of the workout screen. You can configure the default duration in Settings → Workout → Rest Timer. A countdown runs silently; when it reaches zero, the display turns green and shows \"Tap when ready\" — tapping it dismisses the timer and signals you are ready for your next set. The timer can also be dismissed early at any point.",
            tips: [
                "Default rest is 90 seconds — suitable for accessory lifts. Increase to 3–5 minutes for heavy compound lifts like squats, deadlifts, and bench press.",
                "You can dismiss the timer early and start your next set whenever you feel ready. It will not auto-advance to the next set."
            ]
        ),

        HelpTopic(
            title: "PR Detection",
            subtitle: "Auto-detected on every set",
            icon: "trophy.fill",
            color: HONTheme.accent,
            body: "After completing each set, the app calculates your estimated 1-rep max (e1RM) for that exercise using the Epley formula and compares it to your all-time best for that movement. If your e1RM exceeds the previous record, a gold banner slides in from the top of the screen confirming your new personal record. This process is fully automatic — no setup or flagging required. PRs are stored per-exercise and can be reviewed in the Insights tab.",
            tips: [
                "PRs are based on e1RM, not raw weight lifted. A lighter weight done for more reps can legitimately count as a new PR if the e1RM exceeds your previous best.",
                "The e1RM comparison uses your all-time best across all sessions, not just recent ones — so PRs become genuinely significant over time."
            ]
        ),

        HelpTopic(
            title: "Cardio & Circuits",
            subtitle: "EMOM, AMRAP, custom circuits",
            icon: "figure.run",
            color: HONTheme.positive,
            body: "The Workout tab includes a Circuits section for structured cardio and conditioning work. Three formats are supported: EMOM (Every Minute on the Minute — one exercise block per minute), AMRAP (As Many Rounds As Possible within a fixed time cap), and custom timed circuits. During EMOM sessions, the app uses haptic feedback and optional voice cues to notify you at each minute interval — this can be toggled in Settings → Workout → EMOM Haptics. Circuits count toward your streak and readiness score alongside strength sessions.",
            tips: [
                "Build reusable circuit templates in the Circuits tab and assign them to specific days in your routine.",
                "One-off circuits are also supported — tap \"Start a Circuit\" and build it on the fly without saving a template."
            ]
        ),

        HelpTopic(
            title: "General Activity",
            subtitle: "Yoga, cycling, hiking & more",
            icon: "figure.yoga",
            color: HONTheme.chartSage,
            body: "Not every workout is a barbell session. H.O.N lets you log yoga, cycling, swimming, hiking, martial arts, dance, rowing, or any other activity from the quick-action button on the Home screen, or via History → toolbar icon. When logging, choose the activity type, set a duration, and select an intensity level: Light, Moderate, or Vigorous. Activities lasting at least 10 minutes count toward your Readiness score. Even on rest days, a light walk or stretching session keeps your calendar streak alive and contributes partial recovery credit.",
            tips: [
                "Vigorous activities (cycling, HIIT, rowing) count as a full session equivalent in the readiness calculation.",
                "Light activities (walking, stretching, gentle yoga) contribute partial credit — they still matter and they light up your calendar."
            ]
        ),

        HelpTopic(
            title: "Readiness Score",
            subtitle: "Daily 0–100 recovery metric",
            icon: "heart.fill",
            color: Color(red: 1, green: 0.4, blue: 0.4),
            body: "Your Readiness score (0–100) is a daily estimate of how prepared your body is to train hard. It combines: days since your last session, session frequency over the past two weeks, volume and RPE trends, daily step count (HealthKit), sleep hours (HealthKit), and resting heart rate. A penalty applies for four or more consecutive training days without recovery. The score unlocks after your first session and becomes fully reliable at 10+ sessions. Confidence is labeled Low (≤2 sessions), Medium (3–9), or High (10+). The Home screen coaching note updates automatically after each completed session.",
            tips: [
                "A score of 70–85 is ideal for a hard training day. Below 50 suggests active recovery or an easy session.",
                "The score reflects patterns across your training history — a single outlier day has limited impact."
            ]
        ),

        HelpTopic(
            title: "Estimated 1RM (e1RM)",
            subtitle: "Strength benchmark from any set",
            icon: "chart.line.uptrend.xyaxis",
            color: HONTheme.accent,
            body: "e1RM (estimated 1-rep max) is calculated using the Epley formula: weight × (1 + reps ÷ 30). The result is rounded to the nearest 5 lbs or kg to reflect the realistic accuracy of the formula, which carries a ±10% error margin. Every time you complete a set, e1RM is recalculated and stored, building a trend over time. Use the e1RM chart in Insights to track the direction of your strength — rising, plateau, or declining — rather than treating any single number as your absolute ceiling.",
            tips: [
                "Use sets in the 3–8 rep range for the most accurate e1RM estimates. Very high rep sets (15+) produce less reliable extrapolations.",
                "The 5-unit rounding is intentional. It prevents false precision and helps you focus on the trend, not individual session noise."
            ]
        ),

        HelpTopic(
            title: "INOL — Training Stress",
            subtitle: "Intensity × Number of Lifts",
            icon: "gauge.with.needle",
            color: HONTheme.chartLavender,
            body: "INOL (Intensity × Number of Lifts) measures total training stress per exercise per session using the formula: Σ(reps ÷ (100 − intensity%)). It was developed from Prilepin's weightlifting volume tables. Zones: Low (<0.4) — insufficient stimulus; Moderate (0.4–0.8) — maintenance; Optimal (0.8–1.5) — productive training; Heavy (1.5–2.0) — high stress, use periodically; Overreaching (>2.0) — warrants a deload. INOL is designed for barbell compound lifts; treat it as a directional indicator for isolation work.",
            tips: [
                "Target 0.8–1.5 INOL for compound movements like bench press, squat, and deadlift.",
                "If you are consistently in the Low zone, try adding one more set or a few reps. If you are consistently in Overreaching, consider a planned deload week."
            ]
        ),

        HelpTopic(
            title: "Efficiency Score",
            subtitle: "Strength gain per fatigue unit",
            icon: "bolt.fill",
            color: HONTheme.positive,
            body: "Efficiency compares your rolling e1RM gain over recent sessions to the session cost (fatigue burden) required to produce it. The result is rated as Great, Average, or Below avg — calibrated against your own personal history, not an external benchmark. Rising efficiency means you are gaining strength without accumulating proportionally more fatigue, which is the ideal adaptation signal. Declining efficiency often means you are adding more volume than your current recovery capacity can absorb.",
            tips: [
                "\"Great\" efficiency means your current training structure and load are working — do not change what is not broken.",
                "\"Below avg\" efficiency is an early signal to review rest periods, sleep, nutrition, or overall volume before adding more load."
            ]
        ),

        HelpTopic(
            title: "Rep Decay",
            subtitle: "Fatigue across sets within a session",
            icon: "arrow.down.right",
            color: HONTheme.chartSlate,
            body: "Rep decay measures how your rep count changes from your first set to your last set for a given exercise within a single session. A slope near zero (0 reps per set) indicates strong fatigue management — you maintained performance throughout. A large negative slope (e.g., −3 reps per set) means significant accumulated fatigue by later sets, suggesting you may need longer rest periods, a lower starting weight, or fewer total sets. The metric is displayed as a trend chart in the Insights tab after 3 or more sessions.",
            tips: [
                "Aim for less than −1 rep per set decay on most compound exercises. A small decline is normal and expected.",
                "High rep decay on your final exercise of a session is less concerning than high decay on your first — order effects are real."
            ]
        ),

        HelpTopic(
            title: "Avg RPE Trend",
            subtitle: "Effort level over time",
            icon: "waveform",
            color: HONTheme.accent,
            body: "If you log RPE per set, the Insights tab plots your average RPE for each exercise over time. An increasing RPE trend — the same weight feeling progressively harder — is a signal of accumulated fatigue or inadequate recovery. A decreasing RPE trend for the same weight signals positive adaptation: you have grown stronger and the load now feels easier. This is the ideal cue to add weight or reps at your next session. The RPE trend chart requires consistent RPE logging to be meaningful.",
            tips: [
                "Log RPE every session for a given exercise to build a reliable trend. Even rough estimates (7 vs 8) provide useful signal.",
                "RPE 7–8 is generally the productive training zone for hypertrophy and strength. Sustained RPE 9+ across multiple sessions suggests overreaching."
            ]
        ),

        HelpTopic(
            title: "RPE Scale Reference",
            subtitle: "Rate of Perceived Exertion — what each number means",
            icon: "gauge.with.dots.needle.67percent",
            color: HONTheme.accent,
            body: "RPE measures how hard a set felt on a 1–10 scale. Unlike percentage-based training, RPE auto-regulates to how you feel that day — so a 75% squat might be RPE 6 when fresh, or RPE 8 when fatigued.",
            tips: [
                "RPE 6 — Could do 4+ more reps. Warm-up territory.",
                "RPE 7 — Could do 3 more reps. Moderate effort, good for volume work.",
                "RPE 8 — Could do 2 more reps. Working weight for most top sets.",
                "RPE 9 — Could do 1 more rep. Near-maximal, use for peak sets.",
                "RPE 10 — Maximum effort. True 1RM attempt, no reps left.",
                "Tip: log RPE consistently — trends matter more than single values."
            ]
        ),

        HelpTopic(
            title: "Composite Strength Score (CSS)",
            subtitle: "Your overall strength profile",
            icon: "star.fill",
            color: HONTheme.accent,
            body: "The Composite Strength Score (0–100) aggregates your performance across all tracked exercises into a single score. It has three weighted pillars: Level (35%) — accumulated strength relative to your body weight; Momentum (40%) — direction and rate of your recent e1RM trend; Process (25%) — training quality signals including INOL, efficiency, and rep decay. Score tiers progress from Starting → Developing → Steady → Building → Solid → Strong → Peak. CSS is most meaningful after 10+ sessions across three or more exercises. The Momentum pillar responds fastest to consistent training.",
            tips: [
                "CSS requires data across Push, Pull, and Legs pattern groups to reach the highest tiers. A gap in any category caps the score.",
                "Focus on the Momentum pillar first — it responds within a few weeks of consistent training and provides the fastest feedback."
            ]
        ),

        HelpTopic(
            title: "Strength Tiers (BEG/INT/ADV/ELITE)",
            subtitle: "Relative strength benchmarks",
            icon: "medal.fill",
            color: HONTheme.chartLavender,
            body: "Each exercise is classified into a strength tier — Beginner, Intermediate, Advanced, or Elite — based on your e1RM relative to your body weight (e1RM ÷ body weight ratio). Thresholds differ by movement pattern: an advanced deadlift threshold is a higher ratio than an advanced curl because the movement mechanics allow proportionally more load. Tiers unlock after 3 or more sessions on a given exercise and require body weight to be set in Settings → Profile. The tier bar and your position within it are shown in the Insights tab.",
            tips: [
                "Set your body weight in Settings → Profile to unlock tiers. Without it, relative-strength comparisons remain hidden.",
                "Tiers are set per exercise and per movement pattern — do not compare across different movements."
            ]
        ),

        HelpTopic(
            title: "Fiber Load & PSI",
            subtitle: "Expert metric — muscle activation demand",
            icon: "waveform.path.ecg",
            color: HONTheme.chartRose,
            body: "Fiber Load estimates raw muscle activation demand for a session based on set intensity, rep count, and each exercise's EMG-derived activation profile (pctMVC per muscle). Allometric PSI normalizes Fiber Load by body weight raised to the power of 0.67, allowing fair comparison of your training output across time periods when your body weight changes. PSI is only visible in Expert insight level and requires body weight to be set in Settings → Profile. Because it is allometric, a rising PSI over the same exercise set means you are producing more total muscular work — not just lifting more absolute weight.",
            tips: [
                "Use PSI as a relative week-over-week trend, not an absolute number. The scale is personal to your history.",
                "A rising PSI over the same exercises and loads means you are doing more total work — useful for detecting training density increases."
            ]
        ),

        HelpTopic(
            title: "Insight Levels",
            subtitle: "Essential / Standard / Expert",
            icon: "slider.horizontal.3",
            color: HONTheme.accent,
            body: "Settings → Workout → Insight Level controls the depth of analytics shown in the Insights tab. Essential shows only key e1RM trend charts and your PR history — ideal for beginners who want simple feedback. Standard adds INOL, efficiency score, rep decay, and avg RPE trend — the most useful tier for intermediate and regular trainers. Expert adds all CSS pillars broken out individually, fiber load, allometric PSI, and an adjustable fatigue alpha slider for advanced customization. Switching levels takes effect immediately on all exercise cards.",
            tips: [
                "Start with Standard. It covers the metrics that matter for 95% of training decisions.",
                "Switch to Expert once you have logged 20+ sessions across multiple exercises and want to go deeper into the data."
            ]
        ),

        HelpTopic(
            title: "Body Weight & History",
            subtitle: "Track weight over time",
            icon: "scalemass.fill",
            color: HONTheme.chartSage,
            body: "Set your current body weight in Settings → Profile. Each time you update it, the value is logged with a timestamp, building a body weight history. This history enables meaningful allometric strength comparisons across long time periods: if you got stronger and lighter simultaneously, your PSI captures both changes in a single number. Body weight is also used for relative strength ratios, tier classification, and the Level pillar of the Composite Strength Score. Without a body weight entry, these features remain hidden.",
            tips: [
                "Log your body weight once a week, at the same time of day (e.g., morning, after waking), for consistent and comparable data.",
                "Updating body weight does not retroactively change historical session data — new logs use the most recently entered weight."
            ]
        ),

        HelpTopic(
            title: "Data Export & Backup",
            subtitle: "JSON and CSV formats",
            icon: "square.and.arrow.up",
            color: Color.secondary,
            body: "Settings → Data → Export All Data produces a complete JSON backup of your workouts, cardio sessions, general activities, routines, and profile settings. Export as CSV generates a spreadsheet-compatible file you can open in Excel, Numbers, or share with a trainer. Import replaces all current data after a confirmation prompt — the import validates that no future-dated entries are present and rejects any file containing them. This validation prevents accidental data corruption from test files or corrupted exports.",
            tips: [
                "Export your data before major iOS updates or switching devices. Save the JSON file to iCloud Drive or email it to yourself for off-device backup.",
                "The CSV export is useful for sharing session data with a coach or doing your own analysis in a spreadsheet."
            ]
        ),

        HelpTopic(
            title: "Plate Calculator",
            subtitle: "Exact plate breakdown for any weight",
            icon: "circle.grid.3x3.fill",
            color: HONTheme.accent,
            body: "Found in History → Tools → Plate Calculator. Enter your target barbell weight, select the bar type (10 kg / 15 kg / 20 kg), and the app calculates exactly which plates to load per side to reach that weight. Plates are displayed color-coded by standard international colors: red = 25 kg, blue = 20 kg, yellow = 15 kg, green = 10 kg. A visual bar diagram shows the loaded bar drawn to scale so you can confirm the configuration at a glance before approaching the rack.",
            tips: [
                "Preset weight buttons (60 / 80 / 100 / 120 / 140 / 180 kg) let you jump to common warm-up and working weights instantly.",
                "The calculator accounts for the bar weight — entering 100 kg gives you plates for 100 kg total, not 100 kg plus bar."
            ]
        ),

        HelpTopic(
            title: "1RM Calculator",
            subtitle: "Estimate your 1-rep max from any set",
            icon: "function",
            color: HONTheme.chartLavender,
            body: "Found in History → Tools → 1RM Calculator. Enter any weight and rep count to receive an estimated 1RM averaged across three established formulas: Epley, Brzycki, and Lombardi. Averaging across formulas smooths out individual formula biases at different rep ranges. Below the result, a full rep max table shows recommended working weights for every rep range from 1 to 20, calculated at standard intensity percentages. This is useful for setting up a new percentage-based program when you do not yet have a tested 1RM.",
            tips: [
                "Use this calculator before starting a new program to convert your recent training weights into calibrated percentages.",
                "Sets of 3–8 reps give the most accurate estimates across all three formulas. Avoid using very high rep sets (15+) as inputs."
            ]
        ),

        HelpTopic(
            title: "Activity Heat Map",
            subtitle: "10-week training calendar",
            icon: "calendar",
            color: HONTheme.positive,
            body: "After 3 or more sessions, the Home screen displays a 10-week GitHub-style activity calendar. Each square represents one day; green squares indicate any recorded activity on that date — including strength sessions, cardio, and general activities like yoga or a walk. The calendar is a visual consistency tool: the goal is to build and maintain streaks of green squares. Gaps are visible at a glance, making it easy to spot recovery patterns, deload weeks, or periods of missed training.",
            tips: [
                "Even general activities like a 20-minute yoga session or a brisk walk will light up that day's square.",
                "The calendar spans the most recent 10 weeks. Use it weekly to review your consistency at a glance without digging into individual session logs."
            ]
        ),

        HelpTopic(
            title: "Notifications & Reminders",
            subtitle: "Training reminders and coaching nudges",
            icon: "bell.fill",
            color: HONTheme.accent,
            body: "Settings → Notifications. Training Reminders send a daily push notification at your chosen time to prompt you to log a session. Coaching Nudges deliver brief insight summaries at a configurable frequency: off, weekly, or daily. Weekly is recommended to keep notifications useful without causing fatigue. EMOM Haptic Feedback pulses the device at each minute interval during EMOM circuit sessions — useful when your phone is face-down on a bench. All notification permissions are requested only once; you can adjust them in iOS Settings if needed.",
            tips: [
                "Training reminders are most effective when set to the time you actually train — not a motivational aspiration time.",
                "Use weekly coaching nudges to get a summary without daily notification fatigue. Daily nudges work well during high-frequency training blocks."
            ]
        )
    ]
}

// MARK: - Entry point for Settings row

struct HelpNavigationLink: View {
    @State private var showHelp = false

    var body: some View {
        Button {
            showHelp = true
        } label: {
            Label("Help & Manual", systemImage: "questionmark.circle")
        }
        .foregroundStyle(.primary)
        .sheet(isPresented: $showHelp) {
            NavigationStack {
                HelpView()
            }
        }
    }
}
