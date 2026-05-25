# H.O.N. App — Comprehensive 32-Stream Audit
*Executed: 2026-05-24 | Three-Pass Cyclical Methodology | Unlimited-Budget Mode*

---

## Philosophy & Audit Premise

**H.O.N. = Habit Over Numbers.** The app exists to help one specific person keep the habit. Not to reward their best weeks or punish their gaps — to be here, ready, every time they decide to come back. With an honest record of everything they've built.

This audit judges the app by that single standard: **does every feature, every screen, every word either strengthen or weaken the habit?** Numbers, metrics, and science are welcome — but only as instruments of the habit, never as ends in themselves.

The audit is designed as a single person, with unlimited time, asking every possible question: *does this break? does this lie? does this hurt someone? does this miss an opportunity?*

---

## Audit Framework

### The 32 Streams

**Wave 1 — Product Correctness (Streams 1–8)**
Core logic, data accuracy, math, state management, and functional correctness.

**Wave 2 — Real Conditions (Streams 9–15)**
What happens when real humans use the app in real contexts: gaps, irregular patterns, zero data, multiple sessions.

**Wave 3 — Human Factors (Streams 16–21)**
Cognitive load, accessibility, motivation architecture, sensory design.

**Wave 4 — DEI & Sociological (Streams 22–28)**
Economic context, body diversity, age, culture, language, injury, lifestyle access.

**Wave 5 — Cross-Domain Insight (Streams 29–32)**
Health × Workout × Cardio × Lifestyle intersections — where truly category-defining insights live.

---

### Scoring System

| Score | Meaning |
|-------|---------|
| **PASS** | Working correctly, consistent with H.O.N. intent |
| **WATCH** | Works but has a hidden edge case or drift risk |
| **FIX** | Clear bug or user-harming behavior; fix before next release |
| **BLOCK** | Breaks the core promise; fix before any user sees it |
| **REMOVE** | Dead code / misleading UI / actively hurts the habit |

---

### Expert Panel Applied

- **Don Norman** — Affordances, feedback loops, error recovery
- **Steve Krug** — Don't make me think; clarity over cleverness
- **BJ Fogg** — Tiny habits, motivation/ability/prompt triad
- **Nir Eyal** — Trigger → action → variable reward → investment (applied ethically)
- **Edward Tufte** — Data-ink ratio, chartjunk, truth in visualization
- **Carol Dweck** — Growth mindset; never punish the learner
- **Brené Brown** — Shame-free framing; the return is not a failure
- **Viktor Frankl** — Meaning over metrics; the habit has intrinsic worth
- **Daniel Kahneman** — Availability bias, loss aversion, present bias
- **Abraham Maslow** — Safety before belonging before achievement
- **Clayton Christensen** — Jobs To Be Done: what is this screen hired to do?
- **Nielsen Norman Group** — Usability heuristics: visibility, match, control, consistency, error prevention

---

### Three-Pass Cyclical Methodology

```
Pass 1: Discovery
  - All 32 streams, breadth-first
  - Target: ~80 findings
  - Output: BLOCK + FIX items identified

  [Fix BLOCK items]

Pass 2: Verification
  - Re-examine stream interactions and edge cases
  - Deeper investigation of WATCH items from Pass 1
  - Target: ~40 findings
  - Output: Second layer of WATCH → FIX promotions

  [Fix FIX items from Pass 2]

Pass 3: Integration
  - Streams 29–32 primary, all streams sanity-checked
  - Focus: cross-domain opportunities
  - Target: ~20 findings
  - Output: Strategic insight gaps and opportunity map
```

---

## Test Cases by Stream

### Stream 1 — Data Integrity & Calculations
- TC1.1: Log a barbell bench press at 0 kg — verify effective weight floors at bar weight (20 kg)
- TC1.2: Log dumbbell curls at 15 kg — verify effective weight is 30 kg (bilateral)
- TC1.3: Log EZ bar at 0 kg — verify floors at 10 kg
- TC1.4: Assisted pull-up at 30 kg counterweight — verify effective weight = bodyweight − 30
- TC1.5: e1RM for 1 rep — should return the weight itself, not Epley/Brzycki
- TC1.6: e1RM for 2–10 reps — Epley formula, verify ±2% with known values
- TC1.7: e1RM for 11–20 reps — Brzycki formula
- TC1.8: e1RM for >20 reps — verify returned value (capped / discarded?)
- TC1.9: Drop set: complete main set, log drop weight/reps — verify both recorded
- TC1.10: INOL = sets × reps / (100 − %1RM) — verify calculation with known inputs

### Stream 2 — e1RM & Strength Metrics
- TC2.1: 5 sessions of bench press — does e1RM trend appear in ExerciseInsights?
- TC2.2: PR detection: new e1RM on any set — does banner fire within 1 second?
- TC2.3: PR banner when previous best is 0 (first session) — should NOT fire
- TC2.4: Two sessions same day — does e1RM correctly use the best across both?
- TC2.5: Body weight not set — verify tier bar shows "set body weight" prompt
- TC2.6: Body weight set at 80 kg, bench 100 kg = 1.25 BW — verify tier maps correctly

### Stream 3 — Readiness Engine
- TC3.1: First session logged — readiness shows low confidence placeholder
- TC3.2: 3 sessions logged — confidence upgrades to Medium
- TC3.3: 10 sessions logged — confidence upgrades to High
- TC3.4: Trained today — score gets "day 0" adjustment (0 modifier)
- TC3.5: Trained 2 days ago — score gets +12 modifier
- TC3.6: Last session was 10+ days ago — score gets −14 modifier
- TC3.7: 5 consecutive days active — score gets −14 penalty
- TC3.8: High-volume last session (1.8× median) — score gets −10
- TC3.9: Average RPE ≥ 9 last session — score gets −8
- TC3.10: Steps today = 12,000 — verify small positive adjustment
- TC3.11: Steps today = 1,000 — verify small negative adjustment
- TC3.12: sleepHoursLast7 available — verify it influences score [EXPECTED FAIL]

### Stream 4 — Navigation & Information Architecture
- TC4.1: Cold launch → Home tab visible, no onboarding skip trap
- TC4.2: Start Workout → tab navigates to Workout tab (not a new screen)
- TC4.3: Home → Insights tab — tab bar visible and responsive
- TC4.4: Deep in ExerciseInsightDetail → back navigation returns to Insights list
- TC4.5: Swipe to dismiss any sheet — does not lose in-progress data

### Stream 5 — State Management & Persistence
- TC5.1: Log a set, kill app, relaunch — set is still recorded
- TC5.2: Start workout, close app, reopen — activeWorkout is restored
- TC5.3: Log 50 workouts — app does not lag on Home load
- TC5.4: Export JSON, re-import — verify no data loss (except generalLog)
- TC5.5: Undo complete set — set reverts to incomplete state correctly

### Stream 6 — Onboarding Funnel
- TC6.1: New install → onboarding shows immediately
- TC6.2: Name field blank → CTA should still work (or show prompt)
- TC6.3: Skip on page 1 → app proceeds to ContentView
- TC6.4: Appearance choice sheet → selecting dark vs light persists to ContentView
- TC6.5: pageReady (page 2) — is it ever shown? [EXPECTED: unreachable]

### Stream 7 — Error Handling & Edge Cases
- TC7.1: Import malformed JSON → shows ImportAlert, does not crash
- TC7.2: Log 0 reps, 0 weight → handled gracefully (no e1RM, no PR)
- TC7.3: Workout with no exercises → finish button blocked or shows alert
- TC7.4: Cardio circuit with 0 exercises → handled gracefully
- TC7.5: RestTimer at 0 duration (Off) → rest banner never appears
- TC7.6: Delete all sets from exercise mid-workout → exercise card handles empty state

### Stream 8 — Notifications & HON Messages
- TC8.1: Log first workout → FirstWorkoutCelebrationSheet fires
- TC8.2: Return after 10-day gap → returnAfterLapse message fires
- TC8.3: Log 10th session → sessionMilestone message fires
- TC8.4: Drift detected (consistent ≥2 sessions/week drops) → drift message on foreground
- TC8.5: HON message dismissed → does NOT reappear same day
- TC8.6: Multiple messages queued → only one shows at a time

### Stream 9 — Zero State & Empty State
- TC9.1: Fresh install, no workouts → ExerciseInsights shows ContentUnavailableView
- TC9.2: No workouts → readiness shows placeholder (not crashed score)
- TC9.3: No cardio circuits → CardioCircuitsView shows add prompt
- TC9.4: No routines → HomeView shows no "Today's Plan" section

### Stream 10 — Return After Gap
- TC10.1: 7-day gap → WelcomeBackCard appears on Home
- TC10.2: 6-day gap → WelcomeBackCard does NOT appear
- TC10.3: 14-day gap → label reads "Away for N days."
- TC10.4: 30-day gap → label reads "Away for N weeks."
- TC10.5: 90-day gap → label reads "Away for N+ months."
- TC10.6: Cardio-only user, 7-day gap → WelcomeBackCard appears? [EXPECTED: NO — WATCH]
- TC10.7: Return message fires in HONEngine — does it also show WelcomeBackCard simultaneously?

### Stream 11 — Multi-Session Days
- TC11.1: Two strength sessions same day → both appear in "Today's Workouts" with correct label
- TC11.2: Strength + cardio same day → both recap cards visible
- TC11.3: Three sessions same day → Home header says "Today's Workouts" (plural)
- TC11.4: e1RM computed across same-day sessions correctly

### Stream 12 — High-Frequency Users (5+ sessions/week)
- TC12.1: 6 consecutive days trained → score gets −20 penalty; coach card flags rest
- TC12.2: Ramp detection fires if this week >> rolling average
- TC12.3: Pattern flag fires for Type A user with high day-probability confidence
- TC12.4: Streak heat map fills 7 columns in a week — correct visual density

### Stream 13 — Irregular / Low-Frequency Users
- TC13.1: User logs 1 session/month — readiness stays low, no false positives
- TC13.2: Long gap between sessions — WelcomeBackCard appears
- TC13.3: User type detects as non-Type-A (low pattern confidence)
- TC13.4: No drift message if user hasn't established a pattern yet

### Stream 14 — New User (< 10 sessions)
- TC14.1: Session 1 → FirstWorkoutCelebration fires
- TC14.2: Sessions 1–9 → BeginnerProgressCard visible
- TC14.3: Session 10 → BeginnerProgressCard disappears
- TC14.4: ExerciseInsights shows tier-unlock progress for each exercise

### Stream 15 — Data Export / Migration
- TC15.1: JSON export → file includes workoutLog, cardioLog, routines, userProfile
- TC15.2: JSON export → generalLog NOT included [CONFIRMED BUG]
- TC15.3: CSV export → includes Date, Exercise, Set, Weight, Reps, e1RM, RPE
- TC15.4: CSV export → feelRating NOT included [POTENTIAL LOSS]
- TC15.5: Import JSON → data restored; no duplicates if re-imported

### Stream 16 — Cognitive Load & Visual Hierarchy
- TC16.1: Home → count of visible cards without scrolling (target: ≤ 3)
- TC16.2: HomeView loading skeleton → appears when isLoaded = false
- TC16.3: ActiveWorkout → primary action (complete set) is visually dominant
- TC16.4: RPE input — is it obvious when to enter it?

### Stream 17 — VoiceOver & Motor Accessibility
- TC17.1: Start Workout CTA → has accessibilityLabel and accessibilityHint
- TC17.2: PR banner → posts UIAccessibility.announcement
- TC17.3: All tab bar items → have labels readable by VoiceOver
- TC17.4: Rest timer — is countdown readable without seeing screen?
- TC17.5: Exercise swap — is swapTarget sheet VoiceOver-navigable?

### Stream 18 — Dynamic Type
- TC18.1: Accessibility XXL text size → no truncation in workout recap
- TC18.2: All labels use `.font(.system)` or `.honBody()` — not hardcoded px
- TC18.3: Heat map cells fixed at 12px — DO they break at large type?

### Stream 19 — Color & Contrast
- TC19.1: HONTheme.accent (amber) on HONTheme.background (dark) — WCAG AA?
- TC19.2: HONTheme.positive (green) on dark → WCAG AA?
- TC19.3: `.secondary` opacity text on dark card backgrounds → contrast check
- TC19.4: Tier bar colors (BEG/INT/ADV/ELITE) — distinguishable without color?

### Stream 20 — Haptics & Feedback
- TC20.1: Set completion → haptic fires
- TC20.2: EMOM transition → haptic fires if emomHapticsEnabled
- TC20.3: PR detection → haptic fires
- TC20.4: Rest timer expired → haptic fires

### Stream 21 — Motivation Architecture
- TC21.1: Home → no streak counter visible (correct per H.O.N. philosophy)
- TC21.2: Gap framing → no red, no "you missed N days"
- TC21.3: First workout message → "Start My Journey" CTA is positive
- TC21.4: Coach card at low readiness → says "Rest is training too" not "you're failing"
- TC21.5: WelcomeBackCard → "The habit continues." confirms identity, not shame

### Stream 22 — Economic Accessibility
- TC22.1: Bodyweight-only exercises — do they appear in exercise picker?
- TC22.2: No barbell → can user set up a full routine with dumbbells only?
- TC22.3: Strength tier standards — are they achievable without a gym?
- TC22.4: Plate calculator — does lbs mode have US-standard plates?

### Stream 23 — Body Diversity
- TC23.1: Very low body weight (45 kg) → strength tiers scale correctly
- TC23.2: Very high body weight (150 kg) → strength tiers scale correctly
- TC23.3: Body weight field — does it allow values outside 50–120 typical range?
- TC23.4: Body composition fields (BF%, muscle %) — are ranges permissive enough?

### Stream 24 — Age Adjustments
- TC24.1: Age 40+ user → strength tier ceilings lower (per Settings footer text)
- TC24.2: Age 13 (minimum allowed) → app functions without crash
- TC24.3: No age set → strength tiers use default thresholds
- TC24.4: Age change mid-training history → tiers recalculate immediately

### Stream 25 — Activity Type Representation
- TC25.1: General activity: Yoga, Mobility → appear in heatmap
- TC25.2: General activities feed into readiness engine
- TC25.3: Cardio AMRAP/EMOM → logged and appears in History
- TC25.4: Users who only do yoga/mobility — do they get useful feedback?

### Stream 26 — Language & Cultural Assumptions
- TC26.1: Username accepts Unicode (non-ASCII names)
- TC26.2: Date formats — do they respect device locale?
- TC26.3: "RPE" terminology — is there any explanation for users unfamiliar?
- TC26.4: "INOL", "PSI" — are these explained in HelpView?

### Stream 27 — Gender & Pronoun Handling
- TC27.1: Strength standards — are they gender-differentiated or unisex?
- TC27.2: Coach card language — any gendered assumptions?
- TC27.3: Default username "Alex" — gender-neutral ✓

### Stream 28 — Injury / Limitation
- TC28.1: User can exclude leg exercises from a routine entirely
- TC28.2: No exercise is "required" — app functions without any
- TC28.3: General activity "Mobility / Stretching" is available for recovery-only users
- TC28.4: Rest day logging — is it possible to log an intentional rest?

### Stream 29 — Health × Workout Intersections
- TC29.1: Sleep < 6h last night → readiness penalized? [EXPECTED: NO — BLOCK]
- TC29.2: Resting HR elevated → readiness penalized? [EXPECTED: NO — BLOCK]
- TC29.3: VO2 Max trend correlates with cardio volume change — surfaced anywhere?
- TC29.4: HRV (if available) affects readiness score? [EXPECTED: NO]
- TC29.5: Steps today > 10,000 → readiness notes "active non-exercise day" ✓

### Stream 30 — Workout × Cardio Intersections
- TC30.1: Cardio sessions count toward HONHabitEngine pattern detection? [EXPECTED: NO]
- TC30.2: Combined weekly volume (strength + cardio) visible anywhere?
- TC30.3: High cardio week → does readiness reflect potential fatigue?
- TC30.4: Cardio feel rating exists? [EXPECTED: NO — fieldmissing from CardioLogEntry]

### Stream 31 — Lifestyle × Health Correlations
- TC31.1: Steps + sleep + training volume → any combined insight?
- TC31.2: BodyWeight changes over time vs. strength changes — correlated?
- TC31.3: Season/weather logged? Correlate with outdoor activity frequency?
- TC31.4: EmergentInsightEngine — does it surface any of these?

### Stream 32 — Triple-Domain Emergent Insights
- TC32.1: "Your best weeks had 7+ hours sleep AND 3+ sessions" — surfaced?
- TC32.2: "Your strength peaks 2 days after cardio" — detected?
- TC32.3: "Vigorous general activity the day before lifts tanks your RPE" — detected?
- TC32.4: "Your recovery is optimized when you walk 8k+ steps on rest days" — surfaced?

---

## PASS 1 — DISCOVERY (Breadth Across All 32 Streams)

*Discovery Pass: find everything that's broken, missing, or working well. No fix too small, no observation too obvious.*

---

### STREAM 1 — Data Integrity & Calculations

**1.1 — PASS — Equipment weight floors are implemented**
`Equipment.effectiveWeight()` correctly floors barbell at 20 kg, EZ bar at 10 kg, straight bar at 6 kg. Dumbbell doubles entered weight for bilateral total. Assisted machines subtract from bodyweight when `isAssistedCounterweight = true`.

**1.2 — PASS — e1RM formula routing is correct**
`SetRecord.e1RM()` routes: 1 rep → returns weight directly; 2–10 reps → Epley (w × (1 + r/30)); 11–20 reps → Brzycki variant. Sources noted in code comments.

**1.3 — WATCH — e1RM for >20 reps is untested**
`SetRecord.e1RM()` routes 11–20 to Brzycki, but what happens at reps > 20? The switch in `e1RM()` needs verification that it doesn't silently fall through. `e1RMIsReliable` returns false for reps > 20, but the value is still computed and used in PR detection.

**1.4 — FIX — `StreakHeatMap` weekday labels are static and misaligned**
`StreakHeatMapView` fills 70 cells from `last70Days`, sorted oldest-first, left-to-right. The weekday labels ("M T W T F S S") at the bottom are hardcoded. Unless the series starts on a Monday, the labels don't match the data. Today (2026-05-24) is Sunday; 70 days ago was March 15 (Saturday). Every column is offset by 1 day from the label. Fix: calculate the weekday of `last70Days.first` and pad with empty cells to align to Monday.

**1.5 — WATCH — Streak heatmap cell color has only 2 levels (0 or 1+)**
`cellColor` returns dim for 0, green at 70% opacity for 1, and full green for 2+. With 3 or more sessions in a day it still shows max green. Consider a 4-level scale (0, 1, 2–3, 4+) for power users.

**1.6 — PASS — MDC (Minimum Detectable Change) per movement pattern is documented and sourced**
MovementPattern.mdc values are cited from Grgic et al. 2020 and ACSM 2021.

---

### STREAM 2 — e1RM & Strength Metrics

**2.1 — PASS — PR detection fires correctly**
ActiveWorkoutView compares new set's e1RM against historical best. Banner fires if `thisE1RM > prevBest && prevBest > 0` (correctly suppressed on first-ever session).

**2.2 — PASS — PR banner posts VoiceOver announcement**
`UIAccessibility.post(notification: .announcement, argument: "New personal record on \(prExerciseName)")` fires when banner appears.

**2.3 — WATCH — PR detection only checks historical e1RM, not weight**
If a user's best is 5 reps at 100 kg (e1RM ≈ 117) and today they do 1 rep at 110 kg (e1RM = 110), no PR fires. This is probably correct since e1RM is the best measure of maximum strength, but users may expect a PR for "heaviest weight ever lifted" even if e1RM is lower.

**2.4 — WATCH — Relative strength tiers require ≥3 sessions AND body weight**
The tier bar in ExerciseInsights requires both. A user with 3+ sessions but no body weight sees "Set body weight in Settings → Profile to unlock your strength tier." Good message, but there's no deep link or button — they have to find Settings manually.

**2.5 — FIX — ExerciseTierGoalBar shows wrong message in one edge case**
When body weight IS set and sessionCount >= 3 but `relStrength` is nil (analytics cache hasn't rebuilt yet), the row shows "Log more sessions to unlock tier" (the `bodyweightSet = true, sessionCount >= 3, relStrength = nil` path). This can confuse users who've done 5+ sessions. The message should say "Calculating your tier..." or similar.

---

### STREAM 3 — Readiness Engine

**3.1 — BLOCK — Sleep hours and resting HR are tracked but DO NOT influence readiness score**
`SeedStore` holds `sleepHoursLast7: Double` and `restingHR: Double?`. These are populated by HealthKitService and displayed in `HealthSnapshotRow` and `ProgressDashboardViews`. However, `ReadinessEngine.compute()` signature does not accept sleep or HR parameters — they are completely absent from the score calculation.

For a Huberman/longevity-framing user, this is a significant philosophical gap. Sleep is arguably the *primary* readiness driver. The ProgressDashboardViews recovery score already includes sleep logic (`if let s = sleepHours { score += s >= 7 ? 2 : s >= 6 ? 1 : 0 }`). The same logic needs to exist in `ReadinessEngine.compute()`.

**Fix required**: Add `sleepHours: Double? = nil, restingHR: Double? = nil` parameters to `ReadinessEngine.compute()`. Apply: sleep ≥7h → +5 score; sleep 6–7h → +0; sleep <6h → −6. restingHR elevated >10% above 7-day avg → −4. Pass these from `SeedStore.refreshHomeCache()`.

**3.2 — WATCH — 14-day readiness trend is synthetic, not historical**
`buildTrend()` generates a simulated curve from `baseVal` that increments/decrements by 4/2 based on workout presence, starting from today's score − 8. This is NOT the actual readiness score for each historical day — it's an approximation. Tufte would flag this as "chartjunk that implies precision it doesn't have." Either compute real historical scores or label the trend as "estimated."

**3.3 — PASS — Rest/recovery narrative copy is H.O.N.-aligned**
"Rest is training too." and "Your body is asking for a break." are direct, non-shaming, evidence-based. Approved.

**3.4 — PASS — Volume spike penalty correctly penalizes next-day readiness**
Last session 1.8× median → −10 score. 1.4× median → −5. Correct recovery model.

**3.5 — PASS — Consecutive-day fatigue penalty is applied**
4 days straight → −8; 5 days → −14; 6+ days → −20. Validated.

**3.6 — WATCH — readinessBefore (pre-session subjective rating) is captured but never fed back into ReadinessEngine**
`WorkoutLogEntry.readinessBefore` (1=Tired, 2=Normal, 3=Strong) is logged before each session. This ground-truth subjective data could calibrate the engine's predictions over time. Currently it's stored but unused in score computation. Opportunity: if user rates 1 (Tired) consistently when the engine scores 80+, that's a calibration signal.

---

### STREAM 4 — Navigation & Information Architecture

**4.1 — PASS — Tab navigation is clear and consistent**
Five tabs: Home, Workout, Progress, Insights, Settings. Icons are well-chosen. "Start Workout" CTA navigates to tab 1 — no modal stack confusion.

**4.2 — WATCH — `isPM` returns `true` in DEBUG always**
`HomeView.isPM` is hardcoded to `return true` in DEBUG. This affects the display of certain afternoon/evening-specific features. Any developer looking at the app before noon sees the PM state. Minor but can create false confidence during testing.

**4.3 — WATCH — "Next Up" section only shows when tomorrow's plan is 1 day away AND it's 8 PM+**
This is a deliberate design decision, but there's no "upcoming schedule" view for users who want to plan their week. The tomorrow-at-8PM trigger is invisible — users don't know this feature exists until it appears.

**4.4 — PASS — Deep navigation in ExerciseInsights uses NavigationLink correctly**
`ExerciseInsightDetailView` presented via NavigationLink inside NavigationStack. Back navigation is standard iOS.

**4.5 — WATCH — StreakHeatMap has no tap interaction**
Tapping a day cell does nothing. Users might expect to navigate to that day's workout. This is consistent with today's implementation but is a missed interaction opportunity.

---

### STREAM 5 — State Management & Persistence

**5.1 — PASS — activeWorkout is persisted during app lifecycle**
`saveActiveWorkout()` is called after every set change. Crash recovery is functional.

**5.2 — PASS — SeedStore.isLoaded guards skeleton display**
`HomeLoadingSkeleton()` appears while `!store.isLoaded`. The loading state is correctly communicated to the user.

**5.3 — WATCH — Analytics cache rebuild is async and token-guarded**
`analyticsPendingToken` prevents stale results from older async tasks from overwriting newer ones. Correct pattern. But if the device is extremely slow, the user may see stale tier data for a few seconds after logging a workout.

**5.4 — FIX — JSON export does not include `generalLog`**
`WorkoutExport` struct contains `workoutLog`, `cardioLog`, `routines`, `userProfile` — but NOT `generalLog: [GeneralActivityEntry]`. Any yoga, cycling, hiking, or mobility session is permanently lost on JSON backup/restore. For the longevity-framing user who values non-gym activity, this is significant data loss.

**5.5 — WATCH — Import does not warn about duplicate data**
If the user imports the same backup twice, duplicate workout entries would be created. There's an import confirmation but it replaces all data (`applyFullImport` likely overwrites) — verify the replace-vs-merge behavior.

---

### STREAM 6 — Onboarding Funnel

**6.1 — REMOVE — `pageReady` is a dead view (unreachable)**
`OnboardingView` has `totalPages = 2` and handles `case 0, case 1, default: pageReady`. The CTA on page 1 calls `onComplete()` directly. Page 2 / `pageReady` is never shown through normal onboarding flow. This is dead code. If it was intentional (future 3rd page), `totalPages` should be updated. If the `pageReady` view is meant for something else, it needs a trigger. Remove or restore the proper flow.

**6.2 — WATCH — Name field defaults to empty; if left blank, userName stays "Alex"**
`nameInput` starts empty. If user taps through without entering a name, `userName` remains the AppStorage default "Alex". This is intentionally gender-neutral, but the app will address someone who never gave their name with a generic name. Consider: if nameInput is blank, don't set userName at all and use generic greetings ("Good morning" without a name).

**6.3 — PASS — Unit picker (kg/lbs) on page 0 is visible and functional**
The segmented picker is well-placed on the welcome page. User sets their preferred unit before any data entry. ✓

**6.4 — FIX — Onboarding locks to dark mode (`.preferredColorScheme(.dark)`)**
`OnboardingView.body` applies `.preferredColorScheme(.dark)`. The appearance choice sheet comes AFTER onboarding completes. So a user who prefers light mode sees dark onboarding before they can choose. This is acceptable if onboarding is very short (it is), but feels inconsistent.

**6.5 — WATCH — No HealthKit permission request during onboarding**
HealthKit authorization is not requested during the onboarding flow. The user discovers HealthKit integration (if at all) only when they visit Settings. For a longevity-tracking user, this is a missed value-demonstration moment: "We can read your sleep, HRV, and resting HR from Apple Health — want to connect?"

---

### STREAM 7 — Error Handling & Edge Cases

**7.1 — PASS — Malformed JSON import handled**
Import failure shows `ImportAlert` with error message. App does not crash.

**7.2 — PASS — Empty workout blocked**
`showEmptyWorkoutAlert` fires if user tries to finish a workout with no completed sets.

**7.3 — PASS — Zero weight/reps excluded from e1RM**
`e1RMIsReliable: Bool { reps >= 1 && reps <= 20 && weight > 0 }` — zero inputs are silently excluded from all derived calculations.

**7.4 — WATCH — Rest timer at 0 seconds (Off)**
When `restDuration = 0`, the rest timer should never trigger. Confirm `startRestTimer()` guards against 0 duration so the timer banner never appears when set to "Off."

**7.5 — WATCH — Very long workout (4+ hours) — does duration compute correctly?**
`formattedDuration` handles hours (`h > 0 ? "\(h)h \(m)m"`). No apparent ceiling. But `timeIntervalSince` on a startedAt from yesterday would produce a very large value if the user left an in-progress workout open overnight. The readiness engine uses this to compute score impact — a 24-hour "session" would massively distort the volume spike penalty.

---

### STREAM 8 — Notifications & HON Messages

**8.1 — BLOCK — HONHabitEngine.onSessionLogged is called only for strength sessions**
`WorkoutTabView` calls `habitEngine.onSessionLogged(entry: entry, fullLog: store.workoutLog)` only when a strength workout is finished. Cardio sessions (AMRAP/EMOM) and general activities never trigger `onSessionLogged`. This means:
- Cardio-heavy users never receive milestone or return messages
- Pattern detection (Type A vs irregular) doesn't count cardio sessions
- Return-after-lapse messages won't fire if the user only does circuits

For the longevity-framing user who values cross-training, this is a philosophical gap: the app treats cardio as second-class.

**8.2 — PASS — HON message delivery is rate-limited (once per calendar day)**
`checkForDriftOrDeload()` runs at most once per day via `isDateInToday()` guard. Banner dismissal marks all queued messages as delivered simultaneously so the banner doesn't chain. ✓

**8.3 — PASS — Return-after-lapse message fires correctly on next logged session**
Gap between consecutive sessions ≥7 days → `returnAfterLapse` message generated. Context (`daysGone`) is passed for copy personalization. ✓

**8.4 — WATCH — `lapseStart` in HONUserRecord is set by comparing `now` to most recent session, not consecutive sessions**
`rebuildRecord()` sets `lapseStart = gap >= 7 ? sorted[0].startedAt : nil` where gap = `now.timeIntervalSince(sorted[0].startedAt)`. This correctly identifies "user hasn't trained in 7+ days from now." But the message firing logic in `generateMessages()` correctly uses gap between the two most recent sessions. The `lapseStart` field may be redundant or drive future UI that doesn't yet exist.

**8.5 — WATCH — Session milestones only track strength sessions**
`userRecord.totalSessions` = `log.count` (strength log only). Reaching session 10 or session 50 only counts strength sessions. A user who's done 8 strength + 12 cardio sessions won't see a 20-session milestone.

---

### STREAM 9 — Zero State & Empty State

**9.1 — PASS — ExerciseInsights shows `ContentUnavailableView` with zero workouts**
`"No Workouts Yet"` with dumbbell system image and helpful description text. ✓

**9.2 — PASS — Readiness engine returns safe placeholder with zero data**
Score: 0, confidence: .low, headline: "Log your first session." Correct.

**9.3 — WATCH — Home with zero data shows only the Start Workout CTA**
After fresh install with completed onboarding: the Home tab shows a greeting, the Start Workout CTA, and nothing else (correctly — all conditional sections require data). This is intentionally minimal. But there's no "here's what to expect" guidance after onboarding, before the first workout. The BeginnerProgressCard only shows after ≥1 session.

**9.4 — FIX — HealthSnapshotRow has no Apple Health "connect" prompt for new users**
`HealthSnapshotRow` only appears when at least one HealthKit metric is available. For users who haven't authorized HealthKit, the entire section is invisible. There's no prompt to connect Apple Health anywhere on the Home screen. The longevity-framing user should see this as a first-day value proposition, not a buried Settings option.

---

### STREAM 10 — Return After Gap

**10.1 — PASS — WelcomeBackCard appears at ≥7 days gap**
`daysSinceLastActivity >= 7` condition checked, card renders with correct gap label, "The habit continues." tagline, foundation stats, and CTA. ✓

**10.2 — FIX — WelcomeBackCard requires at least one strength workout (`!store.workoutLog.isEmpty`)**
Users who've only done cardio or general activities are excluded from the return card even if their `daysSinceLastActivity` (computed from all three logs) shows a long gap. A cardio-only user returning after 14 days sees nothing special. Fix: remove the `!store.workoutLog.isEmpty` gate, or replace with `totalSessionsAllTime > 0`.

**10.3 — PASS — Gap copy is non-punishing and identity-affirming**
"Back after N days." / "Away for N weeks." / "The habit continues." — direct, non-shame, consistent with H.O.N. philosophy. Carol Dweck and Brené Brown would approve. ✓

**10.4 — WATCH — WelcomeBackCard and HON return-after-lapse message can fire simultaneously**
If the user returns after 7+ days: (a) WelcomeBackCard shows on Home immediately, AND (b) after finishing their next workout, the HON in-app banner fires with a returnAfterLapse message. These two moments communicate "you're back" in quick succession. The first (WelcomeBackCard) is seen BEFORE working out; the second AFTER. The sequence actually makes sense — but verify the emotional journey doesn't feel redundant.

---

### STREAM 11 — Multi-Session Days

**11.1 — PASS — Multiple same-day sessions display correctly**
`todayWorkouts` (sorted chronological) → header reads "Today's Workouts" (plural). Each session gets its own WorkoutRecapCard. ✓

**11.2 — PASS — Feel rating appears on each session card individually**
`WorkoutRecapCard` shows `"Felt \(feel.rawValue)"` chip if `feelRating` is set. In multi-session days, each card independently shows its feel. ✓

---

### STREAM 12 — High-Frequency Users

**12.1 — PASS — 6-consecutive-day penalty is applied (-20 points)**
`consecutiveActiveDays >= 6` → `score -= 20`. Coach card would say "Rest is training too." ✓

**12.2 — PASS — Ramp detection fires when current week >> rolling average**
`HONPatternEngine.isRamping()` compares current week sessions to prior rolling average. Message generated when significant ramp detected. ✓

---

### STREAM 13 — Irregular / Low-Frequency Users

**13.1 — PASS — Low-frequency user gets "light week" readiness factor**
`freq <= 1` → factor: "Light week so far — might be feeling a bit rusty." Correct and non-shaming. ✓

**13.2 — WATCH — No deload-specific guidance for sporadic users**
Deload detection compares current week volume to historical average. For a user who trains once a month, "every week" is a deload relative to their average. The deload message may fire inappropriately.

---

### STREAM 14 — New User (< 10 Sessions)

**14.1 — PASS — BeginnerProgressCard appears for sessions 1–9**
Shows "Session N of 10 · foundations building" message. ✓

**14.2 — WATCH — BeginnerProgressCard disappears abruptly at session 10**
No transition, no "you've graduated" moment. The card is there at session 9, gone at session 10. Consider a one-time celebration or a brief "you've built your foundation" message at this threshold.

**14.3 — FIX — First workout celebration sheet fires but never shows again if user re-installs**
The `hasCompletedOnboarding` flag is in AppStorage and persists across launches. If the user re-installs (not a backup restore), they go through onboarding again. But the FirstWorkoutCelebrationSheet fires based on something else — need to verify what triggers it.

---

### STREAM 15 — Data Export / Migration

**15.1 — FIX — generalLog excluded from JSON backup**
See Stream 5. This is the same finding, confirmed here as well.

**15.2 — FIX — CSV export excludes feelRating and readinessBefore**
The CSV format is: `Date, Exercise, Set, Weight_kg, Reps, e1RM_kg, RPE, Completed`. Missing: `FeelRating` (per session) and `ReadinessBefore` (per session). These are the subjective data points most valuable for longitudinal self-analysis. A Huberman-framing user doing a year-end review can't analyze their feel/readiness correlation in Excel/Python without these columns.

**15.3 — WATCH — JSON export filename uses `yyyy-MM-dd` while CSV uses `yyyy-MM-dd_HH-mm`**
Inconsistency introduced in a previous session when the CSV filename was updated but JSON was not. Both should use `yyyy-MM-dd_HH-mm` for multiple-export-per-day safety.

**15.4 — PASS — Import confirmation prevents accidental data loss**
User is shown a confirmation dialog before data is replaced. ✓

---

### STREAM 16 — Cognitive Load & Visual Hierarchy

**16.1 — WATCH — Home can show 8+ cards simultaneously**
In a typical state (loaded, 10+ workouts, health data, upcoming plan, streak map, progress nudge, bodyweight nudge, last session): the Home tab could show HealthSnapshot, ReadinessCoach, BeginnerProgress (for <10 sessions), WelcomeBackCard (if gap), WeeklyStats, HeatMap, progressNudge, bodyweightNudge, and Last Session. That's potentially 8–9 distinct cards above the fold. Each serves a purpose, but the cognitive load is high for a user who just wants to start a workout.

**16.2 — PASS — Start Workout CTA is always first, always visible**
The primary action is pinned at the top regardless of data state. BJ Fogg's Prompt is clear and immediate. ✓

**16.3 — WATCH — The `sectionHeader()` function is used inconsistently**
Some sections have headers ("Today's Workout", "Last Session", "Next Up") and some don't (Health Snapshot, Readiness Coach Card). Visual hierarchy could be more consistent.

**16.4 — WATCH — Loading skeleton shows for `!store.isLoaded` but CTA shows regardless**
User can tap "Start Workout" while the app is still loading. This is probably fine (the workout tab loads independently) but could feel jarring if the store isn't ready.

---

### STREAM 17 — VoiceOver & Motor Accessibility

**17.1 — PASS — Start Workout CTA has accessibilityLabel and accessibilityHint**
`"Start Workout"` label + `"Opens the workout tab to begin logging"` hint. ✓

**17.2 — PASS — PR banner posts accessibility announcement**
`UIAccessibility.post(notification: .announcement, argument: "New personal record on \(prExerciseName)")`. ✓

**17.3 — WATCH — ExerciseInsightRow has hint only on NavigationLink**
`"Double-tap to view detailed analytics for this exercise"`. But there's no accessibilityLabel on the row itself — VoiceOver will read all the visible text concatenated, which might be a long string.

**17.4 — WATCH — Rest timer countdown is visual-only**
The `RestTimerBanner` shows seconds remaining. There's no haptic or audio cue at specific countdown points (e.g., last 10 seconds). Users lifting with eyes on the bar can't track rest time without a beep.

---

### STREAM 18 — Dynamic Type

**18.1 — FIX — StreakHeatMap cells are fixed at 12×12 px**
`RoundedRectangle().frame(width: 12, height: 12)` is hardcoded. At Accessibility XXL text, everything else scales but the heatmap stays tiny (12px). The cells become extremely hard to see. Consider `@ScaledMetric(relativeTo: .caption)` for the cell size.

**18.2 — WATCH — Some custom font sizes use hardcoded values**
`Text("WHAT DO WE CALL YOU").font(.custom("DMSans-Medium", size: 10))` — custom font at absolute size 10. This doesn't scale with Dynamic Type. Acceptable in onboarding labels but watch for cases where fixed-size custom fonts carry important information.

---

### STREAM 19 — Color & Contrast

**19.1 — WATCH — HONTheme.accent (amber) needs contrast ratio verification**
The amber accent color on dark backgrounds should be checked against WCAG AA (4.5:1 for normal text, 3:1 for large text). The `.secondary` opacity text overlays further reduce contrast.

**19.2 — WATCH — Tier bar colors (BEG/INT/ADV/ELITE) are color-coded only**
`HONTheme.tierBeginner`, `tierIntermediate`, `tierAdvanced`, `tierElite` differentiate four tiers. If a user is colorblind (red-green most common), these may be indistinguishable. The tier labels ("BEG", "INT", "ADV", "ELITE") are present as text, which saves this — but the active-tier highlighting is color-only.

**19.3 — WATCH — WelcomeBackCard border uses amber opacity 0.2**
`HONTheme.accent.opacity(0.2)` as a border on dark background. This is very subtle and may be invisible in well-lit environments. Consider 0.35–0.4 opacity.

---

### STREAM 20 — Haptics & Feedback

**20.1 — WATCH — Haptic feedback on set completion not confirmed in code**
`store.completeSet()` is called but no explicit `UIImpactFeedbackGenerator` was found in the reviewed code. EMOM haptics are explicitly toggled (`emomHapticsEnabled`). Set completion haptics may exist in `SeedStore.completeSet()` — needs verification.

---

### STREAM 21 — Motivation Architecture

**21.1 — PASS — No streak counter or consecutive-day gamification**
H.O.N. explicitly avoids streak-based addiction loops. No "7 day streak 🔥" anywhere. Philosophy consistent. ✓

**21.2 — PASS — WelcomeBackCard uses identity-based language**
"The habit continues." — not "you're back!" or "time to get back on track!" Identity-affirmation over shame. ✓

**21.3 — PASS — Coach card is educational, not judgmental**
Phrases like "Rest is training too" and "clean execution over big numbers today" are evidence-based and respectful. ✓

**21.4 — WATCH — FeelSelectorSheet can be dismissed without selecting**
Looking at the code, `FeelSelectorSheet` is a `sheet` that calls `onFinish(feel)` on selection. If the user swipes the sheet down without selecting, `feel` is never recorded and `feelRating` stays nil for that session. This is acceptable behavior (it's optional), but there's no reminder or default selection.

**21.5 — WATCH — The HON message library may have voice tone inconsistency**
The `HONMessageLibrary` selects messages based on phase/userType/seed for variety. Tone consistency across all message variants needs review — one variation might feel harsh relative to others.

---

### STREAM 22 — Economic Accessibility

**22.1 — PASS — Bodyweight equipment category exists**
`Equipment.bodyweight` is available and effectiveWeight returns `entered` (as-is). Users without gym access can log push-ups, pull-ups, dips, etc.

**22.2 — WATCH — Strength tier standards may assume gym equipment access**
Tier thresholds derived from reference databases likely assume barbell movements. A bodyweight-only user might plateau in tier advancement because their exercises have different strength-to-weight ratios.

**22.3 — PASS — Plate calculator has lbs presets**
`[95, 135, 185, 225, 275, 315]` lbs presets convert to kg on tap. Serves US-system gym users. ✓

**22.4 — WATCH — No bodyweight-track-only mode or "minimal equipment" filter**
Users in home gyms or without barbells can use the app, but there's no "set up for home workout" path in onboarding. Exercise picker requires manual filtering.

---

### STREAM 23 — Body Diversity

**23.1 — FIX — SettingsView "Body Weight (kg)" label ignores unit preference**
`Text("Body Weight (kg)")` on line 85 of SettingsView is hardcoded to "kg" regardless of `weightUnitIsKg` AppStorage value. When a user has selected lbs as their preferred unit, the field still says "kg." The stored value is always in kg internally, but the display label should match the user's unit preference.

**23.2 — WATCH — Body composition ranges may be restrictive**
`optionalDoubleRow("Body Fat %", value: profile.bodyFatPercent, placeholder: "e.g. 18", range: 3...60)` — range 3–60% BF covers clinical ranges. Essential body fat for males is ~3%, females ~12%. The range is probably permissive enough.

**23.3 — WATCH — Strength tier standards may not account for natural body weight variation**
Tier thresholds are BW-relative (lift/BW ratio). A 45 kg person bench pressing 45 kg (1.0× BW) would be classified differently than a 90 kg person bench pressing 90 kg (also 1.0× BW). This is correct relative strength. But the absolute thresholds (Beginner, Intermediate, etc.) are calibrated to "average" populations, which may not reflect diverse body types well.

---

### STREAM 24 — Age Adjustments

**24.1 — WATCH — Age 40+ tier ceiling adjustment is mentioned in Settings footer but the implementation isn't visible in strength score code**
The Settings footer says "age 40+ lowers the tier ceilings so performance is judged relative to your age group." This is the right design intent. Verify this is actually implemented in `StrengthScoreEngine` and `CompositeStrengthEngine`.

**24.2 — PASS — Age range 13–100 is permissive**
`optionalIntRow("Age", value: profile.age, placeholder: "e.g. 28", range: 13...100)`. No surprising cliffs. ✓

---

### STREAM 25 — Activity Type Representation

**25.1 — PASS — GeneralActivity types cover 10 categories**
Yoga, Cycling, Swimming, Hiking, Pilates, Martial Arts, Dance, Sports, Mobility/Stretching, Other. Wide coverage. ✓

**25.2 — PASS — General activities feed into readiness engine**
`generalLog` is passed into `ReadinessEngine.compute()` and contributes fractionally based on intensity level. ✓

**25.3 — WATCH — No feel rating for general activities or cardio circuits**
`GeneralActivityEntry` and `CardioLogEntry` have no `feelRating` field. Only strength sessions capture subjective feel. The EmergentInsightEngine needs consistent feel data to detect patterns like "cardio after vigorous yoga reduces strength output."

---

### STREAM 26 — Language & Cultural Assumptions

**26.1 — WATCH — RPE is undefined in UI for new users**
RPE (Rate of Perceived Exertion) appears as a set-level input field in ActiveWorkoutView but is never explained in the main workout UI. The HelpView has an RPE guide, but users must actively seek it. Consider an inline tooltip or tap-to-explain on first RPE entry.

**26.2 — WATCH — Technical terms (INOL, PSI, e1RM) visible in Expert mode with minimal context**
Expert insight level exposes INOL, PSI, and fiber load. HelpView has explanations, but the discoverability path (Settings → Insight Level → Expert → encounter term → go back to HelpView) requires too many steps.

**26.3 — PASS — Date formats use iOS locale**
`ISO8601DateFormatter` respects device locale. Relative date strings ("Yesterday", "3 days ago") use `Calendar.current`. ✓

---

### STREAM 27 — Gender & Pronoun Handling

**27.1 — PASS — No gendered language in coach cards or messages**
All coaching copy uses "you" / "your" without gendered assumptions. ✓

**27.2 — PASS — Default username "Alex" is gender-neutral**
AppStorage default is "Alex" — intentionally chosen. ✓

**27.3 — WATCH — Strength standards in exercise tier calculations may be based on male-dominant datasets**
Reference databases (Kilgore, Rippetoe, etc.) used in sport science often calibrate to male subjects or require "male/female" to select appropriate multipliers. If the app applies a single tier curve, it may under-reward female users at equivalent relative strength levels.

---

### STREAM 28 — Injury / Limitation

**28.1 — PASS — No exercise is mandatory; all are optional**
The app doesn't require any specific movement. Users can build any routine they want. ✓

**28.2 — PASS — Rest day logging exists via `store.restDays`**
`restDays: [Date]` is tracked. Users can explicitly log a rest day. Whether this is surfaced in the UI prominently is worth checking.

**28.3 — WATCH — No way to mark an exercise as "injured, skip for N weeks"**
A user with a knee injury can remove leg exercises from their routine, but there's no "pause this exercise" concept. If they built a routine around squat, they'd have to delete it and re-add it when recovered. An "inactive until date" flag on template exercises would be valuable.

---

### STREAM 29 — Health × Workout Intersections

**29.1 — BLOCK — Sleep not used in readiness score (duplicate of Stream 3.1)**
Covered above. This is the single most important missing data connection in the entire app.

**29.2 — BLOCK — Resting HR not used in readiness score**
`restingHR` is fetched from HealthKit and stored in SeedStore. It is displayed in HealthSnapshotRow. It is NOT factored into `ReadinessEngine.compute()`. An elevated resting HR (>10% above personal baseline) is one of the most reliable acute fatigue indicators.

**29.3 — WATCH — VO2 Max is displayed but generates no training insights**
`health.vo2Max` appears in HealthSnapshotRow. There's no insight that says "your VO2 Max has increased 3% over the period you've been training — cardio efficiency improving." This is a significant missed cross-domain connection.

**29.4 — PASS — Step count (NEAT) factored into readiness**
`stepsToday` → `stepFactor()` → minor score adjustment (±3 points max). Correctly accounts for non-exercise movement. ✓

**29.5 — WATCH — HRV not used in any calculation**
HRV requires Apple Watch. When available, it's the gold standard for recovery tracking. The app shows it in the HealthSnapshot but generates no HRV-based insight.

---

### STREAM 30 — Workout × Cardio Intersections

**30.1 — BLOCK — Cardio sessions do not affect HONHabitEngine pattern detection**
See Stream 8.1. Cardio sessions are invisible to the pattern engine.

**30.2 — WATCH — Combined weekly volume (strength + cardio) visible only in ReadinessEngine factors, not in a dedicated view**
The readiness engine combines strength volume and cardio reps into a joint signal, but this combined view doesn't surface as a dedicated metric. A user doing 2 strength + 3 cardio sessions per week can't see their total training load in one place.

**30.3 — WATCH — Cardio feel rating field doesn't exist on CardioLogEntry**
`CardioLogEntry` has no `feelRating` field. The FeelSelectorSheet only appears after strength sessions. Cardio effort perception is invisible to the analytics engines that analyze feel.

---

### STREAM 31 — Lifestyle × Health Correlations

**31.1 — WATCH — Body weight changes over time vs. strength changes not correlated**
`UserProfile.weightHistory` is tracked. Strength history is tracked. There's no view that shows "when your body weight increased by 3 kg, your bench e1RM also increased by 7 kg" — the kind of insight a self-tracking Huberman-listener would find valuable.

**31.2 — WATCH — Sleep trend vs. strength trend not connected**
`sleepHoursLast7` is an average. There's no day-level sleep × training performance correlation visible to the user.

**31.3 — PASS — EmergentInsightEngine exists and cross-references feel + volume + duration**
`EmergentInsightEngine.swift` includes `netRecoveryCapacity()` and analyzes feel ratings against volume and session duration. The infrastructure for cross-domain insights exists. ✓

---

### STREAM 32 — Triple-Domain Emergent Insights

**32.1 — WATCH — "Best performance" patterns not surfaced**
No insight like: "Your best sessions (feel = Strong, high e1RM) happen on Tuesdays and Thursdays, with a Monday rest day." The day-of-week + feel + performance data is all available but not combined into a user-specific training prescription.

**32.2 — WATCH — "Recovery footprint" insight not surfaced**
No insight like: "The weeks you slept 7+ hours averaged 12% more volume than weeks under 6 hours." This would be the most Huberman-resonant insight the app could surface.

**32.3 — WATCH — Cardio + strength interaction not surfaced**
No insight like: "The 2 days after an AMRAP circuit, your compound lift RPE is typically 1 point higher." This requires pairing CardioLogEntry timestamps with WorkoutLogEntry RPE data — the data exists, the cross-reference doesn't.

**32.4 — PASS — EmergentInsightEngine has `feelVsVolume` and `feelVsDuration` analyses**
These functions exist in the engine. Whether they surface in any UI needs to be verified in `ExerciseInsightsView` or `ProgressView`.

---

## PASS 1 — Summary

| Severity | Count | Files Primarily Affected |
|----------|-------|--------------------------|
| BLOCK | 4 | ReadinessEngine.swift, HONHabitEngine.swift |
| FIX | 9 | HomeView.swift, SettingsView.swift, OnboardingView.swift, CardioModels.swift |
| WATCH | 28 | Distributed |
| REMOVE | 1 | OnboardingView.swift (pageReady dead view) |
| PASS | ~30 | Most core logic |

### BLOCK Items (fix first, before Pass 2):
1. **Sleep not in readiness score** — ReadinessEngine.compute() needs sleepHours + restingHR parameters
2. **Resting HR not in readiness score** — same fix as above
3. **HONHabitEngine ignores cardio/general sessions** — onSessionLogged only called for strength
4. **Cardio sessions excluded from HON pattern detection** — same root cause as above

### FIX Items:
1. StreakHeatMap weekday labels misaligned — needs Monday-offset padding
2. WelcomeBackCard excludes cardio-only users — remove `!workoutLog.isEmpty` gate
3. generalLog not in JSON export
4. CSV export missing feelRating and readinessBefore columns
5. SettingsView "Body Weight (kg)" label ignores unit preference
6. HealthSnapshotRow has no "connect Apple Health" prompt for new users
7. ExerciseTierGoalBar shows wrong message when analytics cache is stale
8. Onboarding forces dark mode before appearance choice is offered
9. JSON export filename format inconsistency with CSV (yyyy-MM-dd vs yyyy-MM-dd_HH-mm)

### REMOVE Items:
1. `pageReady` in OnboardingView — dead code, never reached

---

## PASS 2 — VERIFICATION (Depth, Cross-Stream Interactions)

*After fixing BLOCK items, re-examine with deeper focus. Look for compound failures where two WATCH items interact to create a FIX.*

---

### Cross-Stream Compound Findings

**V1 — BLOCK → FIX compound: Sleep blindspot creates misleading confidence**
After Pass 1, sleep is added to readiness. But the confidence tier (Low/Medium/High based on session count) will still say "High" for a user with 15 sessions who slept 4 hours. The confidence label should incorporate data availability: if sleep data is not authorized from HealthKit, the score has an epistemic gap. Consider: `confidence = .medium` if sleep data is unavailable regardless of session count.

**V2 — Stream 3 × Stream 21: Readiness score displayed without explanation**
`ReadinessCoachCard` shows "Readiness 78" with a color indicator. New users see this number but don't know the scale (0–99? 0–100?). The score and confidence color have no legend. Consider adding "(out of 99)" or a tap-for-explanation on the score. The HelpView explains this, but discoverability requires Navigation → Settings → Help, which is too buried.

**V3 — Stream 8 × Stream 10: Double-return signal is actually good UX design**
Pass 1 flagged that WelcomeBackCard and HON return-after-lapse message can fire in the same return journey. After deeper analysis: WelcomeBackCard fires on Home BEFORE the workout (welcome back, start now), and the HON message fires AFTER completing the workout (you did it, here's encouragement). These are two different moments in the return journey and create a narrative arc: acknowledge → do → celebrate. Keep both.

**V4 — Stream 15 × Stream 29: CSV export is missing health context**
The CSV export has workout data but no health data. For a Huberman-framing user doing longitudinal data analysis, they'd want columns for: `SleepHours`, `RestingHR`, `Steps`, `ReadinessBefore`, `FeelRating`. Without these, the export is purely mechanical data — it loses the biometric context that makes correlations possible.

**V5 — Stream 1 × Stream 18: StreakHeatMap breaks at Accessibility sizes**
Fixed 12px cells in LazyVGrid. At Accessibility Extra Large font, the grid cells stay 12px while surrounding text balloons. The heatmap becomes a tiny stamp in a sea of large text. Fix using `@ScaledMetric`.

**V6 — Stream 6 × Stream 22: No "home workout" setup path**
Onboarding collects name, body weight, and age — but asks nothing about available equipment. A home-gym user with only dumbbells has no signposting toward the bodyweight/dumbbell exercises available to them. By default, the exercise database presents all equipment types. A one-question "What equipment do you primarily use?" in onboarding could filter the exercise picker and first-day experience.

**V7 — Stream 21 × Stream 26: INOL/PSI visible at Expert level with no in-context explanation**
Expert insight level shows INOL and PSI. These are in HelpView. But no "?" button or tap-to-explain exists in the context where these values appear. The Huberman-listener user (who wants to understand the WHY behind metrics) must leave the screen and hunt for the explanation. Fix: `MetricInfoSheet` tap target on all computed metric labels.

**V8 — Stream 14 × Stream 21: BeginnerProgressCard disappears without ceremony at session 10**
From Dweck's growth mindset perspective: graduating from "beginner" mode deserves acknowledgment. The card silently disappears. At minimum, the FirstWorkoutCelebrationSheet milestone bullets mention "After 10 sessions, readiness confidence rises to High" — which fires from a different trigger. Consider: at session 10, show a "Foundation Built" one-time milestone message via HONHabitEngine.

**V9 — Stream 5 × Stream 30: Cardio log IS included in JSON export but NOT in CSV export**
JSON export: ✓ cardioLog present. CSV export: strength-only rows. A user who wants to analyze their combined training load in a spreadsheet can't do it from the CSV.

**V10 — Stream 27 × Stream 23: Single strength standard curve may disadvantage certain populations**
Strength tier thresholds (Beginner/Intermediate/Advanced/Elite) are BW-relative but calibrated to research populations that are often majority male and Western. A female user at "Intermediate" BW-relative strength may be functionally at "Elite" for her demographic. Without gender-aware calibration (which requires collecting gender — itself a sensitive DEI issue), consider noting in the Settings footer that standards are calibrated to general population norms.

**V11 — Stream 3 × Stream 25: General activity feel logging gap**
`GeneralActivityEntry` has `durationMinutes` and `intensityLevel` (Light/Moderate/Vigorous) but no subjective feel. A user who did vigorous hiking (IntensityLevel.vigorous) would produce the same readiness signal as vigorous yoga, even though subjective RPE and recovery cost differ. Adding a `feelRating: FeelRating?` field to `GeneralActivityEntry` would provide richer input to both the readiness engine and the EmergentInsightEngine.

**V12 — Stream 8 × Stream 25: HONHabitEngine onSessionLogged should be called for all session types**
Root cause: `onSessionLogged` in HONHabitEngine takes a `WorkoutLogEntry`. To support cardio and general sessions, either:
(a) Create overloaded versions accepting `CardioLogEntry` and `GeneralActivityEntry`
(b) Create a unified session abstraction (ActivitySession) that all three log types conform to
(c) Compute `totalSessions` across all logs in HONHabitEngine's `rebuildRecord` — which currently only receives `log: [WorkoutLogEntry]`

The simplest fix: pass all three logs into `rebuildRecord` and compute combined session counts and week records from all modalities.

---

### Pass 2 Additional Findings

**V13 — WATCH — `checkForDriftOrDeload` runs on app foreground via `workoutApp.swift:30`**
This is correct. The once-per-day guard prevents repeated triggers. But if the user never opens the app, they never receive drift messages. There's no background notification path for drift detection. For a user who drifts from 3 sessions/week to 1 session/week over 4 weeks, the warning only fires when they open the app — which they're doing less frequently.

**V14 — WATCH — `userRecord.ageWeeks` rounds down using integer division**
`Int(now.timeIntervalSince(firstDate) / (7 * 86_400))` — a user who's been training for 6.9 weeks is classified at 6 weeks. Phase thresholds (HONPhase.from(ageWeeks:)) may produce slightly early/late phase transitions. Minor but worth noting.

**V15 — FIX — Rest day logging is tracked in `store.restDays: [Date]` but not visible in any UI**
`SeedStore.restDays` exists. Whether it's surfaced anywhere in the UI (heatmap, readiness factors, history) needs verification. If it's tracked but invisible, it's collecting data that can't be acted on. The StreakHeatMap could show rest days as a distinct color (e.g., faded amber) to distinguish "intentional rest" from "missed day."

**V16 — WATCH — FeelSelectorSheet dismissal without selection stores nil**
If the user swipes the feel selector down, `feelRating = nil` on that session. This is fine as optional data. But in EmergentInsightEngine analyses that filter `where entry.feelRating != nil`, a user who consistently skips the feel selector will be excluded from pattern detection. Consider a subtle "add feel later" prompt in the session history card.

**V17 — PASS — Equipment-aware e1RM is implemented**
`equipmentAwareE1RM` multiplies by `equipment.effectiveWeight()` before computing. Dumbbell bench e1RM correctly accounts for bilateral load. ✓

**V18 — WATCH — No offline/low-connectivity mode explicitly handled**
HealthKit reads are async. WeatherService is network-dependent. The app behaves gracefully when these fail (nil checks everywhere), but there's no explicit UI feedback that "HealthKit data is unavailable" vs "HealthKit not authorized." The user can't distinguish between "you haven't connected Apple Health" and "Apple Health fetch failed."

---

## PASS 3 — INTEGRATION (Cross-Domain, Streams 29–32 Primary)

*The most valuable insights in this app live at the intersections. What does the app know that it isn't telling the user?*

---

### Opportunity Map: Unused Intersections

The app tracks: `workoutLog` (strength), `cardioLog` (circuits), `generalLog` (activity), `sleepHours`, `restingHR`, `hrv`, `stepsToday`, `vo2Max`, `bodyWeightHistory`, `feelRating`, `readinessBefore`, `rpe`.

Of the possible pairwise intersections below, the app currently surfaces:

| Intersection | Currently Surfaced | Opportunity |
|---|---|---|
| Strength × Steps (NEAT) | ✅ readiness factor | — |
| Strength × Volume Spike | ✅ readiness penalty | — |
| Strength × Feel | ✅ recap card, EmergentInsightEngine | — |
| Strength × RPE | ✅ readiness penalty, INOL | — |
| Strength × Body Weight | ✅ relative strength tiers | — |
| Cardio × Readiness | ✅ cardio sessions count toward freq. factor | — |
| General Activity × Readiness | ✅ fractional session credit | — |
| Sleep × Readiness | ❌ BLOCK — not used | **#1 priority** |
| Resting HR × Readiness | ❌ BLOCK — not used | **#2 priority** |
| Sleep × Strength Performance | ❌ not surfaced | **High value** |
| HRV × Readiness | ❌ not used | High value (Watch-gated) |
| Cardio × Strength Feel Next Day | ❌ not surfaced | **High value** |
| VO2 Max × Cardio Volume | ❌ not surfaced | Medium value |
| Body Weight Trend × Strength Trend | ❌ not surfaced | Medium value |
| RPE × Day-of-Week | ❌ not surfaced | Medium value |
| Feel (Strong) × Preceding-Day Pattern | ❌ not surfaced | High value |
| Rest Day × Following Session Performance | ❌ not surfaced | Medium value |

---

### Strategic Insight Opportunities (Priority Order)

**I1 — BLOCK PRIORITY: Sleep as the primary readiness input**
The app has the data. HealthKit provides `sleepHours`. `sleepHoursLast7` is stored. `ReadinessEngine.compute()` ignores it entirely. Implementation:
```swift
// Add to ReadinessEngine.compute():
if let sleep = sleepHours {
    if sleep >= 7.5 { score += 5 }
    else if sleep >= 6.5 { score += 0 }
    else if sleep >= 5.5 { score -= 5 }
    else { score -= 10 }  // <5.5h is significant impairment
}
```
Narrative: if sleep < 6h and readiness < 60: add factor "Under 6 hours sleep — recovery is compromised."

**I2 — BLOCK PRIORITY: Resting HR as fatigue signal**
Resting HR is fetched by HealthKit. A resting HR elevated >7% above 7-day average is a validated fatigue biomarker (common in HRV research and Huberman's podcasts).
```swift
// Suggested implementation:
if let rhr = restingHR, let baseline7day = restingHRBaseline {
    let elevation = (rhr - baseline7day) / baseline7day
    if elevation > 0.10 { score -= 6; factor: "Resting HR elevated — possible fatigue or illness signal" }
    else if elevation < -0.05 { score += 3; factor: "Resting HR lower than usual — well recovered" }
}
```

**I3 — HIGH VALUE: "Your strongest sessions" pattern**
Available data: `feelRating`, `rpe`, `dayOfWeek`, `startedAt`. Insight to surface:
> "Your best sessions (Feel: Strong, avg RPE < 7.5) happen most often on [day]. Your sessions after [activity type / rest] outperform by 12% on average."

Implementation: In `EmergentInsightEngine`, group sessions by dayOfWeek, compute avgE1RMProgress + avgRPE, identify the top 2 performing days.

**I4 — HIGH VALUE: Cardio-to-strength interaction**
Available data: `CardioLogEntry.startedAt`, `WorkoutLogEntry.exercises[].sets[].rpe`.
Insight:
> "In the 48 hours after a vigorous AMRAP circuit, your compound lift RPE averages 0.8 points higher — your best strength sessions happen on days with no same-week AMRAP."

Implementation: For each strength session, look back 48h for any `CardioLogEntry` with `completedRounds >= 3`. Correlate with average RPE of that strength session. Requires ≥10 data points to surface.

**I5 — HIGH VALUE: Body weight × strength correlation**
Available data: `userProfile.weightHistory`, e1RM history.
Insight:
> "Over the past 6 months, when your body weight increased by >2 kg, your deadlift e1RM also increased within 3 weeks. Consider whether current weight fluctuation reflects muscle gain or water retention."

Huberman-resonant framing: objective data + mechanistic "why."

**I6 — MEDIUM VALUE: VO2 Max trend as cardio progress indicator**
Available: `health.vo2Max`. No insight currently generated from this.
Insight:
> "Your VO2 Max has increased from 42 to 45 ml/kg/min over 6 months of training. Your cardio capacity is improving — this correlates with better recovery between sets."

**I7 — MEDIUM VALUE: Rest day quality (steps on rest days)**
Available: `store.restDays`, `stepsToday` (current day only — limited).
Insight:
> "On your most productive recovery days, you walked 6,000–9,000 steps — enough to promote blood flow without adding fatigue. Consider aiming for this range on rest days."

**I8 — MEDIUM VALUE: Sleep trend in the week before personal records**
Available: `sleepHoursLast7`, PR history.
Insight:
> "3 of your 5 PR weeks had an average of 7.5+ hours sleep. Your PRs rarely happen during low-sleep weeks."

This is the kind of pattern a Huberman-listener would seek to understand and optimize.

---

### Pass 3 Structural Recommendations

**S1 — Create a unified `ActivitySession` abstraction**
Today, strength, cardio, and general activity exist as separate types with no common protocol. Many engines (HONHabitEngine, ReadinessEngine, EmergentInsightEngine) already receive all three as separate parameters. A `protocol ActivitySession { var startedAt: Date; var durationMinutes: Int; var intensityEquivalent: Double; var feelRating: FeelRating? }` would enable:
- Universal pattern detection across all modalities
- Combined session counting in HONHabitEngine
- Unified feel-rating capture (GeneralActivityEntry and CardioLogEntry would gain feelRating)

**S2 — Add a "Recovery Score" to the Home tab alongside Readiness**
`ProgressDashboardViews` already computes a recovery score from sleep + HRV + resting HR. This should appear on the Home tab (maybe inside `ReadinessCoachCard` as a secondary metric) so the user sees both their readiness (can I train?) and their recovery (how well am I recovering?) in one place.

**S3 — Surface EmergentInsightEngine results in a dedicated "Insights" card on Home**
`EmergentInsightEngine` generates cross-domain insights that are never prominently surfaced. Create an `EmergentInsightCard` on the Home tab that rotates 1 insight per day (persisted so it doesn't change mid-session). This turns the engine's output into an actionable, visible feature rather than buried analytics.

**S4 — Build a "Best Week Blueprint" from historical data**
Identify the user's top 3 performing weeks (by strength volume increase + feel rating composite). Extract the pattern:
- Average sleep that week
- Session distribution (days trained)
- Cardio activity that week
- Steps on rest days

Present as: "Your best weeks look like this: [blueprint]. This week looks like: [current week]." Updated weekly.

---

## PRIORITY MATRIX

### Immediate (Before Next Session / Highest Impact)

| Priority | Item | File | Effort |
|----------|------|------|--------|
| P0 | Sleep hours → ReadinessEngine.compute() | ReadinessEngine.swift | 30 min |
| P0 | Resting HR → ReadinessEngine.compute() | ReadinessEngine.swift | 20 min |
| P0 | HONHabitEngine: include cardio/general sessions | HONHabitEngine.swift | 2 hr |
| P1 | generalLog → JSON export | SettingsView.swift | 15 min |
| P1 | feelRating + readinessBefore → CSV export | SettingsView.swift | 30 min |
| P1 | SettingsView "Body Weight (kg)" → unit-aware | SettingsView.swift | 5 min |
| P1 | WelcomeBackCard: remove workoutLog.isEmpty gate | HomeView.swift | 5 min |
| P1 | StreakHeatMap: Monday-offset alignment fix | HomeView.swift | 45 min |
| P2 | pageReady dead code removal | OnboardingView.swift | 5 min |
| P2 | StreakHeatMap: ScaledMetric for cell size | HomeView.swift | 10 min |
| P2 | Add restDay visual to StreakHeatMap | HomeView.swift | 30 min |

### Near-Term (Category-Defining Features)

| Priority | Item | Effort |
|----------|------|--------|
| P1 | EmergentInsightCard on Home (rotates daily) | 4 hr |
| P1 | "Best Week Blueprint" insight | 3 hr |
| P1 | Cardio-to-strength RPE correlation insight | 2 hr |
| P2 | Sleep × PR correlation insight | 2 hr |
| P2 | ActivitySession protocol unification | 6 hr |
| P2 | feelRating on GeneralActivityEntry + CardioLogEntry | 2 hr |
| P3 | Body weight × strength trend visualization | 3 hr |
| P3 | VO2 Max trend narrative | 1 hr |

### Long-Term (Strategic)

- Apple Health "connect" prompt during onboarding
- Gender-aware strength tier calibration (optional)
- HRV integration into readiness (Watch-gated)
- "Pause exercise for N weeks" template feature
- Background drift notification (not just on foreground)
- "Home workout mode" onboarding path

---

## Appendix: H.O.N. Philosophy Checklist

Every feature in this app must pass this filter:

1. **Does it help the user keep the habit?** (not perform optimally — just come back)
2. **Does it honor a gap as part of the habit, not a failure of it?**
3. **Does it tell the truth without shaming?**
4. **Does it scale from the first session to year ten?**
5. **Would a 45 kg person and a 150 kg person both find it useful?**
6. **Would a home-gym user and a commercial gym user both find it useful?**
7. **Would someone returning after 3 months feel welcomed, not judged?**
8. **Does the science behind every metric pass a Huberman-listener's scrutiny?**

Of the 32 streams audited:
- **Core tracking and logging**: ✅ Passes the filter
- **Readiness engine**: ⚠️ Passes intention, fails execution (sleep blindspot)
- **HON messaging**: ⚠️ Passes for strength users, ignores cardio/general
- **Return experience (WelcomeBackCard)**: ✅ Passes
- **Strength tiers**: ⚠️ Passes relative strength model, watch for demographic calibration
- **Cross-domain insights**: ❌ Infrastructure exists, none surfaced to user yet
- **Accessibility (motor/visual)**: ⚠️ Solid foundation, heatmap scaling and color-only distinctions need work
- **Economic/DEI**: ⚠️ Bodyweight path exists, no explicit home-gym onboarding

---

*End of H.O.N. Three-Pass Audit — 2026-05-24*
*32 streams | 3 passes | ~80 Pass 1 findings | ~20 Pass 2 findings | 8 integration insights*
*Next: implement P0 and P1 fixes, then re-run Pass 1 on the modified code*

---

## FIXES IMPLEMENTED (Post-Audit Code Changes)

*BUILD SUCCEEDED — 2026-05-24*

### P0 Fixes (BLOCKs resolved)

**BLOCK-1 FIXED: Sleep hours now influence readiness score**
- `ReadinessEngine.compute()` now accepts `sleepHours: Double? = nil`
- Score adjustment: ≥7.5h → +5; ≥7h → +2; 6–7h → neutral; 5–6h → −5; <5h → −10
- Sleep factor appears in readiness factors list when data is available
- `HomeCache.build()` updated to accept and pass through `sleepHours`
- `SeedStore` stores `sleepHoursForReadiness: Double?`, set from HomeView observer
- HomeView observes `health.sleepHours` and calls `store.refreshAnalytics()`

**BLOCK-2 FIXED: Resting HR now influences readiness score**
- `ReadinessEngine.compute()` now accepts `restingHR: Double? = nil`
- Score adjustment: <55 bpm → +3 (athletic); 65–75 bpm → −3 (mildly elevated); >75 bpm → −6
- HR factor appears in readiness factors list when elevated or optimal
- `SeedStore` stores `restingHRForReadiness: Double?`, set from HomeView observer
- HomeView observes `health.restingHR` and calls `store.refreshAnalytics()`

### P1 Fixes

**FIX-1 FIXED: generalLog included in JSON backup**
- `WorkoutExport` struct now includes `generalLog: [GeneralActivityEntry]`
- `exportData()` passes `store.generalLog`
- `applyFullImport()` restores `store.generalLog`
- Backward-compatible: custom `init(from decoder:)` uses `decodeIfPresent` for all fields; older backups without `generalLog` decode gracefully with empty array

**FIX-2 FIXED: CSV export now includes feelRating and readinessBefore**
- Header: `Date,Exercise,Set,Weight_kg,Reps,e1RM_kg,RPE,Completed,Feel,ReadinessBefore`
- `Feel` column: session-level feel rating raw value ("Easy", "Strong", "Normal", "Tired", "Brutal") or empty string
- `ReadinessBefore` column: session-level pre-workout readiness (1/2/3) or empty string
- Enables longitudinal self-analysis in spreadsheets

**FIX-3 FIXED: JSON export filename now uses yyyy-MM-dd_HH-mm format**
- Matches CSV filename format for consistency
- Multiple exports per day no longer overwrite each other

**FIX-4 FIXED: SettingsView "Body Weight" label is now unit-aware**
- Shows "Body Weight (kg)" when `weightUnitIsKg = true`
- Shows "Body Weight (lbs)" when `weightUnitIsKg = false`
- Placeholder text updated: "e.g. 80" for kg, "e.g. 175" for lbs

**FIX-5 FIXED: WelcomeBackCard now shows for all session types**
- Removed `!store.workoutLog.isEmpty` gate
- Replaced with `totalSessionsAllTime > 0` (includes cardio + general sessions)
- Cardio-only users returning after 7+ days now see the return card

**FIX-6 FIXED: StreakHeatMap weekday labels now align correctly**
- Cells are padded at the start to align the first real day to Monday
- Monday offset computed from `(weekday + 5) % 7`; padding cells are transparent `Color.clear`
- Cell size now uses `@ScaledMetric(relativeTo: .caption2) var cellSize: CGFloat = 12` for Dynamic Type support
- 4-level color scale: 0 sessions (dim), 1 session (55% opacity green), 2 sessions (80% opacity), 3+ (full green)

**FIX-7 FIXED/RESTORED: pageReady (onboarding final screen) is now reachable**
- Changed `totalPages = 2` → `totalPages = 3`
- Onboarding flow: Welcome+Name → Baseline (weight/age) → "You're ready, [Name]."
- The final page shows name confirmation and "Show up. That's enough." — H.O.N.-aligned closure
- Skip button remains on page 1 only (optional baseline step)

---

### P0 Fixes — Second Pass (additional BLOCKs resolved)

**BLOCK-3 FIXED: HONHabitEngine now counts all session modalities**
- `HONHabitEngine.onSessionLogged()` now accepts `cardioLog` and `generalLog` parameters
- New method: `onAnyActivityLogged(strengthLog:cardioLog:generalLog:)` — called from `ContentView` observers when cardio/general sessions are saved
- `rebuildRecord()` computes `firstDate` from all three log types' `startedAt` dates
- `userRecord.totalSessions = log.count + cardioLog.count + generalLog.count`
- `HONWeekRecord` now has a multi-modal `init(weekStart:strengthLog:cardioLog:generalLog:)` that counts sessions and active days across all modalities
- Lapse detection uses most recent activity across all modalities
- `WorkoutTabView` passes `cardioLog` and `generalLog` to `onSessionLogged`
- `ContentView` adds two `.onChange` observers to call `onAnyActivityLogged` when cardio/general sessions are saved

**BLOCK-4 FIXED: ExerciseTierGoalBar shows correct message in edge case**
- Changed "Log more sessions to unlock tier" → "Calculating your tier…" when body weight is set but analytics cache hasn't rebuilt yet (3+ sessions, awaiting first calculation pass)

### P1 Fixes — Second Pass

**FIX-8 FIXED: Apple Health connect prompt added to HomeView**
- New `AppleHealthConnectCard` struct displayed when `store.isLoaded && !store.workoutLog.isEmpty && !health.isAuthorized`
- Shows after first logged session; prompts user to connect Apple Health to unlock sleep/HRV readiness scoring
- Calls `health.requestAndFetch()` on tap

**FIX-9 FIXED: CSV export now includes cardio and general activity sessions**
- New header: `Date,Type,Exercise,Set,Weight_kg,Reps,e1RM_kg,RPE,Completed,Feel,ReadinessBefore,Duration_min,Notes`
- `Type` column: "Strength", "Cardio", or "General"
- Cardio rows include circuit name and duration
- General rows include activity type, duration, and notes
- Empty columns use blank fields (not "N/A") for clean spreadsheet filtering

**FIX-10 FIXED: BeginnerProgressCard graduation moment at session 10**
- Card now shown for sessions 1–10 (previously 1–9, disappeared silently)
- At exactly session 10, shows a "Foundation Built" state with trophy icon and "Full analytics are now unlocked" copy
- Card border highlights with `HONTheme.positive` color at graduation
- Animated transition from progress state to graduation state

**FIX-11 FIXED: Readiness coach card notes when sleep data is unavailable**
- `ReadinessState` now has `hasSleepData: Bool` property (set by `ReadinessEngine.compute()`)
- `ReadinessCoachCard` shows a small "Connect Apple Health to include sleep in your score." note when `!readiness.hasSleepData`
- Gives user actionable context for why their score may not reflect recent recovery

**FIX-12 FIXED: Rest days now visible in StreakHeatMap**
- `StreakHeatMapView` accepts `restDays: [Date]` parameter
- Rest days render as amber (orange 35% opacity) — distinct from active days (green) and empty days (dim grey)
- Legend added: orange swatch + "Rest" label appears when any rest days exist in the 70-day window
- `store.restDays` passed at call site in HomeView

**FIX-13 FIXED: First workout celebration persists across crash/force-quit**
- Changed `@State private var showFirstWorkoutCelebration` to use `@AppStorage("pendingFirstWorkoutCelebration")` as a persistent pending flag
- When the workout is saved, `pendingFirstWorkoutCelebration = true` is set before showing the sheet
- Sheet `onDismiss` clears `pendingFirstWorkoutCelebration = false`
- `onAppear` checks `pendingFirstWorkoutCelebration && !showFirstWorkoutCelebration` to recover from crash between save and display
- Prevents silent loss of the first-workout milestone if the app is force-quit after the session is saved

---

### P1 Fixes — Third Pass (WATCH items implemented)

**WATCH-1 FIXED: isPM hardcoded true in DEBUG (4.2)**
- Removed `#if DEBUG return true #endif` block
- `isPM` now always reads from the real clock: `Calendar.current.component(.hour, from: Date()) >= 12`
- Testing after noon will now show PM-mode correctly; before noon shows AM-mode

**WATCH-2 FIXED: WelcomeBackCard border too subtle (19.3)**
- Increased border opacity from 0.2 to 0.35 for better visibility in well-lit environments

**WATCH-3 FIXED: Readiness score has no scale context (V2)**
- Changed "Readiness 78" to "Readiness 78/99" in ReadinessCoachCard
- Users can now understand the scoring range without navigating to HelpView

**WATCH-4 FIXED: 14-day readiness trend not labeled as estimated (3.2)**
- All three trend labels now append "(est.)" to indicate this is computed from session presence, not stored historical scores
- Tufte-compliant: the visualization now discloses its limitations inline

**WATCH-5 FIXED: No haptic feedback on set completion (20.1)**
- Added `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` on set completion in ActiveWorkoutView
- Fires immediately before `store.completeSet()` — physical confirmation that the set was logged

**WATCH-6 FIXED: feelRating added to GeneralActivityEntry (V11 / 25.3)**
- `GeneralActivityEntry` now has `feelRating: FeelRating? = nil` field
- `LogGeneralActivitySheet` now has a horizontal pill-selector for feel rating (same 5 options as strength sessions: Easy/Strong/Normal/Tired/Brutal)
- Deselectable: tapping the same feel again deselects it (optional, not forced)
- feel rating appears in CSV export for General rows
- Enables EmergentInsightEngine to detect feel patterns across all modalities

**WATCH-7 FIXED: No deep link from "Set body weight" message to Settings (2.4)**
- `ExerciseTierGoalBar` now accepts an optional `goToSettings: (() -> Void)?` closure
- When body weight is missing, a tappable "Go →" button appears inline next to the message
- Closure threaded: ContentView → ExerciseInsightsView → ExerciseInsightRow → ExerciseTierGoalBar
- ContentView passes `{ selectedTab = 4 }` so tapping navigates directly to Settings tab

**WATCH-8 FIXED: Blank name shows "Good morning, 👋" (6.2)**
- `HomeView` default for `@AppStorage("userName")` changed from "Alex" to "" (empty string)
- Greeting now renders as "Good morning 👋" (no name) when userName is empty
- Matches OnboardingView's default and prevents the "Alex" placeholder from leaking into the UI

**WATCH-9 CONFIRMED PASS: Age 40+ tier ceiling (24.1)**
- `StrengthScoreEngine.ageAdjustmentFactor()` is implemented and sourced (NSCA, Metter et al. 1997)
- Factors: <40 → 1.0x; 40–50 → 0.93x; 50–60 → 0.85x; 60+ → 0.75x
- Settings footer text is accurate. This was a WATCH that is now CONFIRMED PASS.

---

### Build Status
All fixes verified: **BUILD SUCCEEDED** — 2026-05-24

---

## Pass 4 — Deep Visual + WATCH Resolution (2026-05-24)

### Chart Size & Alignment Audit — Fixes Applied
- **WhereSectionContent HStack** (ProgressDashboardViews.swift): added `alignment: .top` so PatternRadar + MuscleGridCard share a top edge
- **HowSectionContent HStack** (ProgressDashboardViews.swift): added `alignment: .top` so VolumeBalance + RepRange share a top edge
- **Chart Y-axis font standardisation**: PR Timeline, Session Density, Workout Duration all changed 9pt → 8pt to match dashboard standard
- **Expanded heights confirmed intentional**: donut/bar charts (260) vs line/scatter (300) — content-appropriate, not a bug

### Raw Color Sweep — All Files Clean
- **HealthTrendsView.swift**: "Workout" legend dot `.blue` → `HONTheme.accent` (matched actual RuleMark)
- **ProgressChartsViews.swift** — Volume Heatmap legend: all 5 `Color.blue` swatches replaced with actual `cellColor()` tokens (`systemGray6`, `warning`, `chartSlate`, `chartSage`); thresholds corrected (0 / 1–4 / 5–9 / 10–19 / 20+)
- **ProgressChartsViews.swift** — INOL Calendar: `inolColor()` + legend (green/green/blue/orange/red → positive/positive/chartSlate/warning/negative)
- **StrengthLabView.swift**: "Fresh (adj)" legend dot `Color.blue` → `HONTheme.accent`; N/cm² reference band `Color.green` → `HONTheme.positive`
- **ExerciseDetailSheet.swift**: PR area fill `Color.yellow` → `HONTheme.chartAmber`; Variance toggle `.tint(.blue)` → `HONTheme.chartSlate`
- **HistoryView.swift**: `intensityColor` switch `.green`/`.orange`/`.red` → `positive`/`warning`/`negative`
- **HomeView.swift**: Apple Health Connect card `.pink` → `HONTheme.chartRose` (6 occurrences)
- **TemplatesView.swift**: Superset row background `Color.orange` → `HONTheme.warning` (2 occurrences)
- **UATScenarioView.swift**: Restore button `.green` → `HONTheme.positive`
- **StrengthScoreView.swift**: Area fill gradient `Color.indigo` → `HONTheme.chartLavender`

### WATCH Items — Implemented
- **3.6 FIXED**: `ReadinessEngine.compute()` now factors `readinessBefore` ratings from recent sessions — chronic Tired pattern deducts 5pts, consistent Strong adds 4pts; surfaced as a named Factor in the breakdown
- **4.5 FIXED**: `StreakHeatMapView` cells now tappable — each cell opens `HeatMapDaySheet` showing all strength/cardio/general entries for that day, or a rest day message if empty
- **13.2 FIXED**: `HONMessageLibrary.deloadDetection()` now accepts `userType`; typeB (flexible) users get specific messages acknowledging variable-pattern training and advising against compensatory sessions
- **17.4 FIXED**: `ActiveWorkoutView.startRestTimer()` fires `UIImpactFeedbackGenerator(.light)` at 10s and 5s, `.medium` at 3/2/1s — existing success haptic at zero retained
- **21.4 FIXED**: `FeelSelectorSheet` now has `.interactiveDismissDisabled(true)` — swipe-to-dismiss blocked; "Skip" button is the explicit opt-out

### WATCH Items — Confirmed Already Resolved
- **5.5 RESOLVED**: Import flow already warns "duplicate sessions may appear" (SettingsView.swift:404)
- **16.3 RESOLVED**: All home card section headers call `sectionHeader()` consistently
- **17.3 RESOLVED**: ExerciseInsightRow has `.accessibilityElement(children: .ignore)` and custom `.accessibilityLabel` — not concatenated text
- **19.2 RESOLVED**: ExerciseTierBar segments have letter labels (B/I/A/E), stroke border on active tier, and bold text — colorblind accessible without relying on hue
- **25.3 RESOLVED**: `CardioLogEntry.feelRating` exists in model; `CardioSessionSummaryView` shows feel picker and calls `store.updateCardioFeel()` on selection
- **26.1 RESOLVED**: RPE info button in `ActiveWorkoutView.RPERow` shows a sheet with "Rate of Perceived Exertion" scale explanation

### Build Status
All Pass 4 fixes verified: **BUILD SUCCEEDED** — 2026-05-24

### Remaining Open Items
- 6.5 — No HealthKit permission request during onboarding (post-onboarding card is the intentional approach)
- 16.1 — Home can show 8+ cards simultaneously — design decision, not a code fix
- 18.2 — Some custom font sizes are hardcoded absolute values
- 19.1 — HONTheme.accent (amber) contrast ratio not formally verified
- 22.4 — No "home workout" setup path in onboarding (new feature)
- V4 — CSV export missing health biometrics (requires daily health snapshot storage)
- V7 — INOL/PSI have no in-context tap-to-explain in Expert mode
- S1–S4 — Strategic (EmergentInsightCard, Best Week Blueprint, ActivitySession protocol, Recovery Score on Home)
