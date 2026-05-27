# H.O.N. Simulation Findings — 2026-05-26
**Pending sign-off before implementation**

Run against: simulation_guide.html Rev 2  
Data: hon_backup_2026-05-26_07-25.json (18 sessions)  
Method: code reading + data analysis (Protocol 7 regression, SC-04, SC-06, SC-07, SC-02, FC-01–FC-08, Protocol 8)

---

## Summary

| Severity | Count |
|----------|-------|
| High     | 4     |
| Medium   | 12    |
| Low      | 5     |
| Positive (no fix needed) | 6 |

**High findings are ranked first. Nothing in this document is implemented until you sign off.**

---

## High Severity

---

### H-01 · Readiness coaching and HON return message directly contradict each other on gap days

**Scenario:** SC-04 (Gap Return), FINDING-11/12  
**Files:** `ReadinessEngine.swift` ~line 292, `HONMessageLibrary.swift` ~line 199  

**What happens:** When a user returns after a 7–14 day gap, two coaching outputs fire with no integration between them:

- `ReadinessEngine.narrative()` at score ≥ 80: *"Don't hold back today — this is the kind of day you make progress on."*
- `HONMessageLibrary.returnAfterLapse` (< 14 days): *"Start at 70%, not hard. One solid session sets the trajectory."*

A user returning after an 8-day gap can simultaneously see the readiness coaching say "push hard" and the HON message say "ease in." These are not just different in tone — they are actionably contradictory. The user is told to work at full intensity on one part of the screen and told to work at 70% on another. There is no logic that checks whether the user is returning from a gap before selecting the coaching narrative.

Additionally: the readiness Factors list can simultaneously show a red/negative factor "Been a while since your last session" alongside a high score and a "push hard" narrative — the factor says the gap is a problem but the coaching says it isn't.

**Persona impact:** P1 Returner — critical moment. This is the highest-stakes coaching the app delivers.

**Proposed fix:**  
Add a `isReturnAfterGap(daysSinceLast:)` check in `ReadinessEngine.narrative()`. When `daysSinceLast >= 7`, the narrative should override to a return-appropriate register regardless of score. Suggested wording: *"You've had time to recover — ease back in and build momentum. Intensity next session."* The Factors list should also suppress or reframe the "Been a while" factor when a positive return message is active — the same event shouldn't be flagged as negative in one place and celebrated in another.

---

### H-02 · Two different Epley implementations produce different e1RM values for sets with reps > 10

**Scenario:** SC-07 (Cross-Tab Walk), FINDING-13  
**Files:** `ExerciseInsightsView.swift` ~line 358, `Models.swift` ~line 253–260  

**What happens:** Two separate e1RM calculation functions exist in the codebase:

- `SetRecord.e1RM(weight:reps:)` in Models.swift: uses **Epley** for reps 2–10, **Mayhew** for reps 11–20
- `ExerciseInsightsView.epley(_:bw:assisted:)` at line 358–360: uses Epley formula `load * (1 + reps/30)` for ALL rep counts, including reps > 10

For reps ≤ 10 both produce identical values. For reps 11–20 (common: sets of 12, 15) they diverge. Example: 20 kg × 12 reps — Epley gives 28.0 kg, Mayhew gives ~27.0 kg. Progress views use the Mayhew path; ExerciseInsightDetailView's chart uses the local Epley path. The skeptic who spots 28.0 in one chart and 27.0 in another cannot know which is correct.

The ground truth table in SC-07 used reps=10 for all exercises, so this divergence didn't surface during verification — but it affects real sessions with sets of 11–12 reps.

**Persona impact:** P2 Skeptic — trust-breaking. Numbers that don't match each other have no obvious winner.

**Proposed fix:**  
Delete the local `epley()` function in `ExerciseInsightsView.swift` and replace all calls with `SetRecord.e1RM(weight:reps:)` (or `adjustedE1RM` for equipment-aware variant). There should be exactly one e1RM calculation in the codebase. The `ExerciseInsightDetailView` data pipeline that constructs `dataPoints` should use `SetRecord.e1RM()` rather than its local function.

---

### H-03 · e1RM term used in post-session celebration before it is ever explained

**Scenario:** SC-02 (First Workout), SC-01 (Onboarding), FINDING-01  
**Files:** `FirstWorkoutCelebrationSheet.swift` ~line 9, `OnboardingView.swift`  

**What happens:** Onboarding has three pages (goal selection, equipment selection, a brief intro). None of them define e1RM, RPE, INOL, or PSI. After the user's very first session, `FirstWorkoutCelebrationSheet` fires. It tells the user: *"Come back tomorrow to start seeing your e1RM trend."* A P3 beginner reads this and sees a term that has no meaning to them — the celebration moment is diluted because the most forward-looking line contains an unexplained acronym.

RPE compounds this: coaching output from `WorkoutNarrativeEngine` and `EmergentInsightEngine` references RPE in analytics context. The onboarding never surfaces it, so the first time a beginner sees "RPE 7" in an insight card it reads as noise.

**Persona impact:** P3 Beginner — first impression corrupted by jargon. P1 Returner — mildly affected if they never Googled e1RM.

**Proposed fix (two options — pick one for sign-off):**

*Option A — Inline expansion:* Replace "e1RM trend" in FirstWorkoutCelebrationSheet with "strength estimate (e1RM) trend." Add a single parenthetical explanation of RPE the first time it appears in any coaching card — *"RPE 7 means 7 out of 10 effort — 3 more reps left in the tank."* This requires no onboarding changes.

*Option B — Onboarding glossary:* Add a 4th onboarding page titled "Three numbers that matter" covering e1RM ("your estimated max lift"), RPE ("how hard it felt"), and streaks. More upfront investment but users arrive informed. Onboarding page count goes from 3 to 4.

---

### H-04 · RPE never explained before users encounter it in coaching output

**Scenario:** SC-01, SC-02, FINDING-02  
**Files:** `OnboardingView.swift`, `EmergentInsightEngine.swift`, `WorkoutNarrativeEngine.swift`  

**What happens:** RPE (Rate of Perceived Exertion) is used in: the analytics explainer sheet, EmergentInsightEngine program calibration card, the ActiveWorkoutView RPE info tooltip (recently added), and coaching narrative output. A P3 beginner who never opens the RPE tooltip will encounter "RPE" in coaching text with no definition. The tooltip is opt-in (info button) and only visible during an active workout — it doesn't help when RPE appears in EmergentInsights on the Home screen after a session.

This is listed separately from H-03 because the fix path is different: e1RM needs one explanation in the celebration flow, but RPE needs a persistent accessible definition wherever it appears in a non-workout context.

**Persona impact:** P3 Beginner, moderate. P1 Returner, low.

**Proposed fix:**  
Add an inline `(?)` InfoButton next to any instance of "RPE" that appears outside the active workout screen — specifically: EmergentInsightCard, PatternDetailView, ProgressDashboardViews. The tapped sheet should show a 3-line definition: what the scale is (6–10 or 1–10), what "RPE 7" means in practice, and why it matters. This can reuse the `AnalyticsExplainerSheet` pattern already in the codebase.

---

## Medium Severity

---

### M-01 · HON notification fires same morning if workout completed before 8 AM

**Scenario:** Protocol 7 Regression / FC-03, FINDING-34  
**File:** `HONMessageScheduler.swift` ~line 19–23  

**What happens:** The notification trigger is:
```swift
var comps = DateComponents()
comps.hour = 8
comps.minute = 0
let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
```
With no `day` component, `UNCalendarNotificationTrigger` fires at the next occurrence of 08:00. For an early-morning user who finishes a session at 7:45 AM, the HON coaching notification fires 15 minutes later on the same morning — not the intended "next day motivation" behavior.

**Proposed fix:**  
Set `comps.day` to tomorrow's day before creating the trigger, or use a `timeInterval` trigger instead: `UNTimeIntervalNotificationTrigger(timeInterval: 3600 * nextMorningHours, repeats: false)` where `nextMorningHours` is calculated as hours until 8 AM tomorrow from the current time.

---

### M-02 · 4–6 day gap produces no acknowledgement — the threshold is too high

**Scenario:** SC-04 (Gap Return), FINDING-09  
**File:** `HONHabitEngine.swift` ~line 166, `HomeView.swift` WelcomeBackCard ~line 286  

**What happens:** Both the HONHabitEngine gap message threshold and the WelcomeBackCard threshold require 7+ days of inactivity to fire. A user who trains Monday, takes Tuesday–Saturday off (5 days), and returns Sunday sees nothing that acknowledges the gap. This is the most common real-world gap pattern. The app is silent when the user is most likely to feel mild uncertainty about returning.

**Persona impact:** P1 Returner — the gap between 3 days (too short, expected) and 7 days (threshold fires) is where most real gaps live.

**Proposed fix:**  
Lower the WelcomeBackCard threshold to 4 days and add a separate "short gap" message pool to `HONMessageLibrary` for gaps of 4–6 days. These messages should be lighter in tone than the 7+ day messages — no mention of "break" or "days away," just a forward-looking welcome: *"Ready to pick up where you left off?"* The HONHabitEngine lapse threshold can stay at 7 days since that path produces more substantive coaching.

---

### M-03 · Dumbbell per-hand convention not explained before first dumbbell set is logged

**Scenario:** FC-07, FINDING-22  
**File:** `ActiveWorkoutView.swift` ~line 515–524 (`equipmentBadge`)  

**What happens:** The per-hand badge *("Enter per-hand weight — app doubles for bilateral total")* only renders once a dumbbell exercise is already on screen in an active workout. A user who selects Dumbbell Bench Press for the first time and immediately types "40" (their bilateral total) will log incorrect data before reading the badge. The badge appears after exercise selection, not before.

**Proposed fix:**  
Show the badge text as a subtitle in the ExercisePicker search results for dumbbell exercises — a small *"Enter per-hand weight"* annotation beneath the exercise name. Alternatively, add it to the ExercisePicker detail row for any `equipment == .dumbbell` exercise. This surfaces the convention at the selection moment, not the entry moment.

---

### M-04 · STATE-0 empty state is informational, not inviting

**Scenario:** SC-12 (Empty State Audit), FINDING-05  
**File:** `HomeView.swift` ~line 276–282  

**What happens:** The zero-session Home screen shows:
1. Health tiles (all showing "—")
2. "Start Workout" CTA button
3. Caption text: *"Log your first session to unlock your Readiness score, strength tiers, and weekly insights."*

The caption is a feature list. It tells you what you'll unlock but not what the experience of unlocking it feels like. It doesn't connect to the H.O.N. identity ("Habit Over Numbers"). It reads like a product spec, not an invitation.

**Proposed fix:**  
Replace the caption with two lines that lead with the feeling, not the features: *"Your first session starts the signal. Everything you see here — the score, the tiers, the coach — builds from what you log."* Keep it short. No bullet points.

---

### M-05 · Volume bar chart Y-axis is hidden — no scale reference

**Scenario:** SC-07 (Cross-Tab Walk), FINDING-14  
**File:** `ProgressDashboardViews.swift` ~line 901 (`.chartYAxis(.hidden)`)  

**What happens:** The 8-week volume bar chart uses `.chartYAxis(.hidden)`. Users see relative bar heights but no absolute values. A skeptic who wants to know "did I do 2,000 kg-reps or 5,000?" can't read that from the chart — they'd have to navigate to an individual session to find volume. The X-axis dates are present but set at `font(.system(size: 7))` — functionally unreadable at arm's length.

**Proposed fix:**  
Remove `.chartYAxis(.hidden)` and configure `AxisMarks` with 3–4 tick marks showing kg-rep values (e.g., 1000, 2000, 3000). Format as "2.0k" to keep labels compact. Increase X-axis date font from 7pt to 9pt.

---

### M-06 · PSI metric has no tap-to-explain tooltip; INOL has one but PSI doesn't

**Scenario:** SC-07, Protocol 8, FINDING-15  
**File:** `ExerciseInsightsView.swift` (fiberLoad/PSI section)  

**What happens:** INOL has an `InfoButton` that opens `AnalyticsExplainerSheet` — confirmed in `ProgressDashboardViews.swift`. PSI (Personal Strength Index / Fiber Load) appears in the ExerciseInsightDetailView and PatternDetailView without an equivalent explainer attached to it. PSI is the most opaque metric in the app — it combines intensity, reps, activation weight, and body weight. A P2 skeptic who sees "PSI: 47.3" and taps it expecting an explanation finds nothing.

**Proposed fix:**  
Add an `InfoButton(metric: .psi)` next to the PSI value display in ExerciseInsightDetailView (where `latestFiberLoad` is displayed) and in PatternDetailView's PSI chart header. The `MetricInfoSheet` or `AnalyticsExplainerSheet` should include a PSI entry explaining: what it measures, the formula in plain language, and what a high vs. low value means.

---

### M-07 · Development Tier improvement rate is unlabeled — "% per week" of what?

**Scenario:** SC-07, FINDING-16  
**File:** `ProgressDashboardViews.swift` ~line 544–597  

**What happens:** The Development Tier muscle grid shows values like *"+1.2%/wk"* next to each muscle group. The card header says "Development Tier" and the section header says a movement pattern's grade. But nowhere on the card is it explained that the percentage is the weekly improvement rate of e1RM — not volume, not reps, not some other metric. A skeptic reads "+1.2%/wk" and has to guess whether this is a good or bad number and what it's measuring.

**Proposed fix:**  
Add a subtitle beneath the card header: *"Weekly e1RM improvement rate — how fast each pattern is growing"* (matches the language already used in `ProgressView.swift:3134`). Alternatively, add an `InfoButton` to the card header that explains the metric.

---

### M-08 · PR step chart has no Y-axis tick marks

**Scenario:** SC-07, FINDING-18  
**File:** `ProgressDashboardViews.swift` ~line 1093–1140  

**What happens:** The PR history step chart labels the Y-axis only in the card header text *"e1RM kg"*, not as actual chart axis marks. The chart itself has no `AxisMarks` configuration for the Y-axis. The scale is invisible — the step line is visual but not readable.

**Proposed fix:**  
Add a `chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) { ... } }` block to the PR step chart. Match the format used in other charts in ExerciseInsightDetailView (kg labels, light color, trailing alignment).

---

### M-09 · Zero-rep alert blocks without helping a user who genuinely failed a set

**Scenario:** SC-06 / FC-01, FINDING-19  
**File:** `ActiveWorkoutView.swift` ~line 783–787  

**What happens:** Alert text: *"No Reps Entered — Enter at least 1 rep before completing a set."* This is correct for the most common case (forgot to enter reps). But a user who attempted a set and truly got 0 reps (failed the first rep) has no path: the app blocks the completion and offers no alternative. The `toFailure` flag exists but doesn't help here. A real failed-first-rep set can't be logged.

**Proposed fix:**  
Add a second button to the alert: *"Log as Failed Set"* (alongside "Enter Reps"). Tapping it marks the set as completed with `reps = 0, toFailure = true` — already a known data pattern from the Machine Shoulder Press sessions in the backup. This allows genuine failed attempts to be logged without corrupting the analytics filter (which already excludes `reps == 0` from e1RM calculations).

---

### M-10 · ~88% of HON coaching messages are generic — only two categories reference real user data

**Scenario:** Protocol 8 Coaching Tone Audit, FINDING-25  
**File:** `HONMessageLibrary.swift`  

**What happens:** Auditing all message pools:
- `patternFlag`: References `dayName` and `pct` — specific ✓
- `rampDetection`: References `count` and `avg` — specific ✓
- All other pools (`sessionMilestone`, `weeklyCount`, `returnAfterLapse`, `driftDetection`, `deloadDetection`, `streakMilestone`, `specialMoment`): generic — could apply to any user.

`specialMoment` is the most notable gap: messages like *"Something's different about today's session"* are supposed to fire when the app detects something notable, but none of them state what that something is. They read as placeholders.

The `WorkoutNarrativeEngine` post-set messages ARE specific (reference actual weights, exercise names, target comparisons) — this is the strongest personalization in the codebase. The contrast between narrative quality (specific) and HON messages (generic) will be noticed by P2 and P4.

**Proposed fix:**  
Prioritized by impact:
1. `specialMoment`: Add the specific trigger reason to each message. If the trigger is a PR: *"You just hit a personal record on [exercise]. That's the signal."* If the trigger is a streak milestone: *"[N] days consistent. Your pattern is building."* The `specialMoment` path should receive the trigger context as a parameter.
2. `driftDetection`: Add the exercise or category that drifted: *"[Push] volume is down two weeks running. One session resets it."*
3. `returnAfterLapse`: Add the last exercise logged: *"You're back. Last time you were here: [exercise]."* This makes the return message feel like the app was paying attention.

---

### M-11 · Progress "Where Am I" section opens to 3 dense cards simultaneously

**Scenario:** Protocol 8 Aesthetic, FINDING-28  
**File:** `ProgressView.swift` — Where Am I section  

**What happens:** The default expanded "Where Am I" section shows three cards simultaneously: MovementPatternRadarCard + muscleGridCard (side-by-side HStack), StandardLiftsCard (multiple tier bars), and optionally StrengthRetentionRingsCard. On a standard iPhone (375pt width), the side-by-side HStack produces two compact cards that are difficult to read. Three dense visual units on first open produces the impression of a dashboard designed for a wide screen being compressed into a narrow one.

**Proposed fix:**  
Make the radar + muscle grid a single `ScrollView(.horizontal)` pair rather than a fixed HStack — users can swipe between them. Or: reorder so StandardLiftsCard appears first (it has the clearest signal — tier names are immediately legible) and the radar is secondary. The goal is that opening "Where Am I" for the first time should surface one clear answer, not three competing visualizations.

---

### M-12 · Feel selector sheet drag-to-dismiss is disabled but Skip button is not prominent

**Scenario:** FC-04, FINDING-21  
**File:** `WorkoutTabView.swift` ~line 669  

**What happens:** `FeelSelectorSheet` uses `.interactiveDismissDisabled(true)` — the sheet does not respond to a swipe-down. Users who try the standard iOS dismiss gesture (swipe down) get no response and may think the app is frozen. The "Skip" button exists and functions correctly, but it's positioned as a secondary action (small, below the emoji row) when it is actually the most common path for users who find the feel prompt friction-heavy.

**Proposed fix:**  
Either remove `.interactiveDismissDisabled(true)` and treat swipe-down as equivalent to tapping Skip, OR make the Skip button more visually prominent — move it to the top-right of the sheet header (matching standard iOS sheet dismiss placement) so it's discovered immediately. Disabling an expected iOS gesture without a visible alternative feels like a broken interaction.

---

## Low Severity

---

### L-01 · Short-lapse return messages name the absence explicitly — mild backward pull

**Scenario:** SC-04, FINDING-10  
**File:** `HONMessageLibrary.swift` ~line 199–204  

**What happens:** All three < 14-day return messages anchor on the gap duration: *"You're back. X days off…"*, *"Back after X days…"*, *"X-day break — now closed."* While non-punishing, they lead with the absence. The H.O.N. philosophy favors forward-looking language. One message in the pool should be purely forward-looking with no reference to days away.

**Proposed fix:**  
Add one message to the < 14-day pool that makes no reference to the gap: *"Ready when you are. Pick up where you left off — the work you've done isn't going anywhere."*

---

### L-02 · Dumbbell convention badge uses warning color for a helpful note

**Scenario:** SC-02, FINDING-07  
**File:** `ActiveWorkoutView.swift` ~line 401–407  

**What happens:** The per-hand convention badge is styled in `HONTheme.warning` (amber/orange) color. Warning color on a UI convention note trains users to associate amber with errors. The badge is not a warning — it's a helpful clarification.

**Proposed fix:**  
Change the badge foreground from `HONTheme.warning` to `HONTheme.accent` or `.secondary`. Reserve warning colors for states that actually require corrective action.

---

### L-03 · Drift detection message has mild stakes-framing language

**Scenario:** Protocol 8 Tone, FINDING-30  
**File:** `HONMessageLibrary.swift` ~line 253–261  

**What happens:** *"This is where habits either reset or disappear. One session makes the difference."* The word "disappear" introduces mild pressure framing. The H.O.N. voice is non-punishing. P1 Returner reads this during a stretch where they've been inconsistent — it might add friction rather than invite return.

**Proposed fix:**  
Replace *"This is where habits either reset or disappear."* with *"This is where habits either reset or solidify."* One word change removes the stakes framing while preserving the directness.

---

### L-04 · SetCompletionFlash is a subtle bottom-line sweep — may be under-rewarding

**Scenario:** Protocol 8 Micro-interactions, FINDING-31  
**File:** `CelebrationSystem.swift` ~line 669–689  

**What happens:** Set completion animation: a 1px amber line sweeps across the bottom of the row (0.32s), then fades out (0.38s). Total duration: ~0.7s. This is physically subtle — a single pixel at the bottom of the row during a gym session (low attention, ambient light) may not register as feedback. The row background color change (positive/negative flash at line 853) is the more visible signal.

**Proposed fix:**  
Consider increasing the flash line to 2px height and adding a slight scale pulse on the checkmark icon (scale 1.0 → 1.15 → 1.0, ~0.2s) to reinforce the completion moment. Alternatively, leave as-is — the haptic feedback on set completion is strong and may be sufficient. This is a preference-level decision, not a functional issue.

---

### L-05 · `e1RM` appears as a label without expansion in StandardLiftsCard tier row

**Scenario:** SC-07, FINDING-08  
**File:** `ProgressView.swift` ~line 559  

**What happens:** The StandardLiftsCard LiftPairRow shows a small *"e1RM"* text label directly next to the number. The card header does show *"e1RM ÷ bodyweight vs community benchmarks"* — so context exists at the section level. But if a user taps directly into the tier row without reading the header, the standalone "e1RM" label has no expansion.

**Proposed fix:**  
This is minor given the header context. Optionally: expand the label to *"Est. 1RM"* which is slightly more self-explanatory. No functional fix required.

---

## Positive Findings (confirmed working, no fix needed)

These passed the simulation without issues and should not be changed.

| Finding | What passed |
|---------|-------------|
| P-01 | Haptic feedback on set completion is correct — medium impact on complete, notification success on PR |
| P-02 | PR banner timing is immediate and contextually correct — fires within the complete tap action, not delayed |
| P-03 | Done keyboard button is correctly placed on ActiveWorkoutView body level only — one button per keyboard instance, regression confirmed fixed |
| P-04 | Both CSV and JSON export correctly route through `exportItem` / `.sheet(item: $exportItem)` — no duplicate sheet modifier, regression confirmed fixed |
| P-05 | Session-1 HON messages are well-calibrated — non-effusive, honest, H.O.N.-aligned ("The habit doesn't exist yet — but the decision does.") |
| P-06 | WorkoutNarrativeEngine post-session coaching is highly specific — references actual exercise names, weights, target comparisons, and performance trajectories. This is the strongest personalization in the codebase. |

---

## Regression Checks (Protocol 7)

| Check | Status |
|-------|--------|
| R-01 | Cannot fully verify without runtime — code path exists |
| R-02 | Code path exists; coaching fires from WorkoutNarrativeEngine after set complete |
| R-03 | ✓ CONFIRMED FIXED — Done toolbar on ActiveWorkoutView body only, not on NumberField |
| R-04 | Cannot fully verify without runtime |
| R-05 | ✓ CONFIRMED FIXED — CSV export routes through `exportItem` in SettingsView |
| R-06 | ✓ CONFIRMED FIXED — JSON export also routes through `exportItem` |
| R-07 | Cannot verify without runtime |

---

## Implementation Priority (proposed order, pending your sign-off)

**Sign off on which of these you want to proceed with, and in what order. Nothing below is implemented until you confirm.**

| Priority | Finding | Effort estimate |
|----------|---------|----------------|
| 1 | H-01 — Readiness/HON coaching contradiction on gap days | Medium — ReadinessEngine.narrative() + new flag check |
| 2 | H-02 — Two epley implementations diverge for reps > 10 | Low — delete local epley(), use SetRecord.e1RM() throughout |
| 3 | H-03 — e1RM not explained in first celebration | Low — one line change in FirstWorkoutCelebrationSheet |
| 4 | H-04 — RPE not explained outside active workout | Low — add InfoButton next to RPE in EmergentInsights/Progress |
| 5 | M-01 — Notification fires same morning before 8 AM | Low — add tomorrow's date to DateComponents |
| 6 | M-09 — Zero-rep alert: add "Log as Failed Set" option | Low — add second alert button |
| 7 | M-02 — 4–6 day gap silence: lower threshold to 4 days | Low — change threshold constant, add short-gap message pool |
| 8 | M-10 — Generic HON messages: prioritize specialMoment + driftDetection | Medium — add parameter passing + new message strings |
| 9 | M-12 — Feel sheet: fix drag-to-dismiss interaction | Low — remove interactiveDismissDisabled OR reposition Skip button |
| 10 | M-05 — Volume chart: show Y-axis | Low — remove .chartYAxis(.hidden), add AxisMarks |
| 11 | M-06 — PSI: add tap-to-explain tooltip | Low — add InfoButton, add PSI entry to MetricInfoSheet |
| 12 | M-07 — Development Tier: label what % measures | Very low — add subtitle text |
| 13 | M-08 — PR step chart: add Y-axis marks | Low — add chartYAxis block |
| 14 | M-03 — Dumbbell convention: surface before first dumbbell selection | Medium — modify ExercisePicker row for dumbbell exercises |
| 15 | M-04 — STATE-0 empty state: replace with inviting copy | Very low — text change |
| 16 | M-11 — Progress "Where Am I": reduce visual density on open | Medium — layout restructure |
| 17 | L-01 — Add one forward-looking return message | Very low — one string addition |
| 18 | L-02 — Dumbbell badge: change from warning to accent color | Very low — color constant swap |
| 19 | L-03 — Drift message: "disappear" → "solidify" | Very low — one word change |
| 20 | L-04 — SetCompletionFlash: consider 2px + checkmark pulse | Low — animation tweak (optional) |
