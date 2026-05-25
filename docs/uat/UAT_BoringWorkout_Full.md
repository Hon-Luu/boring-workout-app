# Boring Workout — Full App UAT
**Version:** 1.0.0 · Build 1  
**Date:** 2026-05-13  
**Coverage:** Every feature surface in the app — Engineering, Architecture, Persistence, Data Validation, Calculations, UI, Navigation, Integrations, Edge Cases, Regression

---

## Severity
| | Meaning |
|---|---|
| **P0** | Blocks shipping. Crash, data loss, wrong number shown, core loop broken. |
| **P1** | Major failure. Feature broken, no data corruption. |
| **P2** | Degraded experience. Workaround exists. |
| **P3** | Cosmetic or edge-case polish. |

---
---

# SECTION 1 — FOUNDATION

---

## TS-01: Engineering & Performance

**TC-01-001** · P0 · Cold launch time  
**Prereq:** 50+ workouts in log  
**Steps:** Kill app → tap icon → start stopwatch  
**Expected:** Home tab visible in ≤1.5s. No blank screen hang.

**TC-01-002** · P0 · Background analytics does not freeze UI  
**Prereq:** 100+ workouts  
**Steps:** Cold launch → immediately tap Workout tab → scroll  
**Expected:** Tab responds instantly. Scroll smooth. Analytics computing in background is fine.

**TC-01-003** · P0 · Memory warning during active workout  
**Steps:** Start workout, log 3 sets → Simulator: Hardware → Simulate Memory Warning  
**Expected:** No crash. Active workout and logged sets intact.

**TC-01-004** · P0 · Rapid background/foreground cycling  
**Steps:** Start workout → background/foreground app 10× in rapid succession  
**Expected:** No crash. Workout state correct each return.

**TC-01-005** · P1 · Analytics refresh non-blocking  
**Steps:** Finish workout → immediately scroll Home tab  
**Expected:** Scroll is smooth. No jank while analytics recompute.

**TC-01-006** · P1 · No retain cycle on workout finish  
**Steps:** Instruments → Leaks → finish 5 workouts in one session  
**Expected:** No leaked objects after each `finishWorkout()` call.

**TC-01-007** · P0 · Clean build succeeds  
**Steps:** `xcodebuild clean build -scheme workout -destination 'platform=iOS Simulator,name=Iphone14p'`  
**Expected:** `BUILD SUCCEEDED`. Zero real compiler errors.

**TC-01-008** · P1 · Timer invalidated on view disappear  
**Steps:** Start rest timer → navigate away from Workout tab before timer ends  
**Expected:** Timer stops. No runaway timer firing after view is gone.

---

## TS-02: Architecture & State Management

**TC-02-001** · P0 · SeedStore singleton consistent across all tabs  
**Steps:** Log a set in Workout tab → immediately check Home "Last Workout" data without finishing  
**Expected:** Active workout reflected in store. No duplicate instances.

**TC-02-002** · P0 · @Observable drives UI update on finish  
**Steps:** Finish workout → observe Home tab  
**Expected:** "Last Workout" card appears immediately. No manual refresh.

**TC-02-003** · P0 · lastPerformanceCache accurate after first workout  
**Steps:** Log Bench Press 100kg × 5 → finish → start new workout → add Bench Press  
**Expected:** Set rows pre-fill 100kg. Cache populated on `finishWorkout()`.

**TC-02-004** · P1 · exerciseHistoryCache capped at 20 sessions  
**Prereq:** Same exercise logged 25 times  
**Steps:** Open exercise detail  
**Expected:** At most 20 sessions displayed. No crash or memory spike.

**TC-02-005** · P0 · analyticsPendingToken prevents stale result overwrite  
**Steps:** Finish workout A → immediately finish workout B (two rapid analytics triggers)  
**Expected:** Only workout B's analytics apply. No race condition where A overwrites B.

**TC-02-006** · P0 · userProfile.didSet suppressed during load  
**Steps:** Cold launch → watch console for `refreshAnalytics` calls  
**Expected:** Not called while `isLoaded == false`. Called exactly once after load completes.

**TC-02-007** · P1 · HomeCache rebuild triggered on workout finish  
**Steps:** Finish workout → check readiness score  
**Expected:** Readiness score reflects new workout (updated recency and frequency).

**TC-02-008** · P1 · ExerciseEquivalenceMap static init runs once  
**Steps:** Open exercise swapper 10× for different exercises → Instruments: Time Profiler  
**Expected:** `reverseIndex` dictionary built once at launch. Not rebuilt per swap open.

---

## TS-03: Persistence & Data Integrity

**TC-03-001** · P0 · Complete workout survives force quit  
**Steps:** Log workout (4 exercises, 3 sets each) → finish → force quit → relaunch  
**Expected:** All 4 exercises, 3 sets each in log. No missing data.

**TC-03-002** · P0 · Decimal weight persists exactly  
**Steps:** Log 102.5 kg → finish → force quit → relaunch → check log  
**Expected:** 102.5, not 102 or 103.

**TC-03-003** · P0 · toFailure flag persists  
**Steps:** Toggle toFailure on a set → finish → force quit → relaunch → check set  
**Expected:** `toFailure = true` preserved.

**TC-03-004** · P0 · RPE value persists  
**Steps:** Set RPE = 8.5 on a set → finish → relaunch → check  
**Expected:** RPE shows 8.5.

**TC-03-005** · P0 · Drop set data persists (dropWeight, dropReps)  
**Steps:** Log drop set 100kg→80kg × 8 → finish → relaunch  
**Expected:** Drop weight and drop reps preserved in log.

**TC-03-006** · P0 · Feel rating persists  
**Steps:** Finish workout with feel = 😊 → relaunch → check workout log entry  
**Expected:** Feel rating stored. Visible in history detail.

**TC-03-007** · P1 · Routines persist across kill cycles  
**Steps:** Create routine (5 exercises, Mon/Wed/Fri) → force quit → relaunch  
**Expected:** Routine intact with same exercises and day assignments.

**TC-03-008** · P0 · Corrupt UserDefaults: silent recovery, no crash  
**Steps:** Write garbage bytes to `workoutLog_v1` via simulator settings → relaunch  
**Expected:** App launches with empty log. No crash. No alert to user.

**TC-03-009** · P1 · UserDefaults keys are versioned  
**Steps:** Read `SeedStore.swift` — inspect `logKey`, `templatesKey`, `userProfileKey` values  
**Expected:** All end in `_v1` (or higher). Schema changes use a new key, not silently corrupt.

**TC-03-010** · P1 · Export contains all field types  
**Steps:** Log workout with RPE, toFailure, drop sets, feel rating → Export → inspect JSON  
**Expected:** All fields present in JSON (`toFailure`, `rpe`, `dropWeight`, `dropReps`, `feelRating`).

**TC-03-011** · P1 · Import merges without duplicates  
**Steps:** Export 10 workouts → import same file → check count  
**Expected:** Still 10. ID-matched, no duplication.

**TC-03-012** · P0 · Import rejects malformed JSON gracefully  
**Steps:** Import a file with `{ "bad": true }` content  
**Expected:** Alert "Import Failed — File format not recognized." No crash. Data untouched.

---

## TS-04: Data Validation & Input Bounds

**TC-04-001** · P0 · Negative weight: not storable  
**Steps:** Type -20 in weight field during workout  
**Expected:** Decimal keyboard has no minus sign. If somehow entered, clamped to 0.

**TC-04-002** · P0 · Weight = 0 on non-barbell exercise: legal  
**Steps:** Log bodyweight exercise with weight field = 0  
**Expected:** Set logs successfully. Analytics uses BW as proxy (not crashes).

**TC-04-003** · P0 · Weight = 0 on barbell exercise: floored to 20 kg in analytics  
**Steps:** Log Barbell Bench with 0 weight  
**Expected:** `Equipment.effectiveWeight(0)` for `.barbell` = `max(0, 20)` = 20. e1RM calculated from 20kg, not 0.

**TC-04-004** · P1 · Extremely large weight (9999 kg) does not crash  
**Steps:** Enter 9999 in weight field → log → finish  
**Expected:** No crash. e1RM computed (large value). Analytics handles without overflow.

**TC-04-005** · P0 · Reps = 0 on non-failure set: e1RM = 0  
**Steps:** Log set with reps = 0, no failure flag  
**Expected:** `e1RM(weight:reps:)` returns 0 (guard `r > 0`). No PR recorded.

**TC-04-006** · P0 · Reps > 20: e1RM = 0  
**Steps:** Log 25 reps at any weight  
**Expected:** e1RM = 0 per `default: return 0`. No PR. Narrative does not claim new best.

**TC-04-007** · P1 · Body weight = 0 or nil: tier scores hidden, no crash  
**Steps:** Leave body weight blank in Settings → check Progress tab  
**Expected:** Tier card shows "Set your body weight in Settings" or equivalent. No division-by-zero crash.

**TC-04-008** · P1 · Body weight decimal accepted and persisted  
**Steps:** Enter 82.3 in body weight → force quit → relaunch  
**Expected:** 82.3 shown. Not truncated to 82.

**TC-04-009** · P1 · Age out of range: app does not crash  
**Steps:** Enter 200 in age field  
**Expected:** Age adjustment uses `60+` scalar (0.75). No crash. Analytics complete.

**TC-04-010** · P1 · Onboarding: blank name blocks Continue  
**Steps:** Onboarding page 1 — leave name empty  
**Expected:** Continue button disabled. Untappable.

**TC-04-011** · P0 · Onboarding: non-numeric body weight ignored  
**Steps:** Type "abc" in body weight field → Continue  
**Expected:** `Double("abc")` = nil → body weight not set → proceeds. No crash, no corruption.

**TC-04-012** · P1 · Circuit duration = 0: handled  
**Steps:** Create AMRAP circuit with duration = 0 minutes → start  
**Expected:** Timer shows 0:00 or immediate completion. No crash.

---
---

# SECTION 2 — ONBOARDING

---

## TS-05: Onboarding Flow

**TC-05-001** · P0 · Appears on first launch only  
**Steps:** Fresh install → launch  
**Expected:** OnboardingView covers entire screen. Not the tab bar.

**TC-05-002** · P0 · Does not re-appear after completion  
**Steps:** Complete onboarding → force quit → relaunch 3×  
**Expected:** Each launch shows main tab bar. `hasCompletedOnboarding = true` in AppStorage.

**TC-05-003** · P1 · Page indicators advance correctly  
**Steps:** Progress through all 3 pages  
**Expected:** 3 dots. Active dot widens and highlights. No skipping.

**TC-05-004** · P1 · Name saves to UserDefaults  
**Steps:** Enter "Jordan" on page 1 → complete onboarding → check Home header  
**Expected:** "Good morning, Jordan 👋"

**TC-05-005** · P1 · Body weight saves to store.userProfile  
**Steps:** Enter 85 on page 2 → complete → Settings → Strength Profile  
**Expected:** Body Weight shows 85 kg.

**TC-05-006** · P2 · Skipping body weight does not break analytics  
**Steps:** Leave page 2 blank → complete onboarding  
**Expected:** App loads normally. Progress tab shows body weight prompt, not crash.

**TC-05-007** · P1 · Notification permission requested on completion  
**Steps:** Complete onboarding page 3 → tap "Get Started"  
**Expected:** iOS notification permission dialog appears (first time only).

**TC-05-008** · P2 · Transition animation between pages  
**Steps:** Tap Continue on each page  
**Expected:** Smooth slide-in animation (right to left). Not a jump cut.

---
---

# SECTION 3 — HOME TAB

---

## TS-06: Home Tab

**TC-06-001** · P0 · Greeting time-aware  
**Steps:** Open app at 8am, 2pm, 8pm  
**Expected:** "Good morning", "Good afternoon", "Good evening" respectively.

**TC-06-002** · P1 · Weather badge loads  
**Steps:** Allow location permission → open Home tab  
**Expected:** Temperature, H/L, condition shown. No "No location" state with permission granted.

**TC-06-003** · P2 · Weather badge denied state  
**Steps:** Deny location permission  
**Expected:** Location slash icon + "No location" shown. No crash.

**TC-06-004** · P1 · Weekly stats strip: correct session count  
**Steps:** Log 3 workouts this week  
**Expected:** Strip shows "3 sessions · This Week". Volume and set count match logged data.

**TC-06-005** · P1 · WoW delta: positive when this week > last week  
**Steps:** Log 3 workouts this week, 1 last week  
**Expected:** WoW delta shows green "+" value.

**TC-06-006** · P1 · Health snapshot row: all authorized metrics visible  
**Steps:** Authorize HealthKit → open Home  
**Expected:** HRV, Resting HR, Sleep pills visible. Tappable for detail sheet.

**TC-06-007** · P1 · Health metric detail sheet: correct ranges shown  
**Steps:** Tap HRV pill → sheet opens  
**Expected:** Shows "Well recovered ≥60ms / Moderate 40–59ms / Under-recovered <40ms". Correct for HRV.

**TC-06-008** · P0 · Today's Plan card: shows today's scheduled exercises only  
**Prereq:** Routine with Bench/OHP on Monday, Squat/Deadlift on Friday  
**Steps:** Open on Monday  
**Expected:** Today's Plan shows Bench + OHP only. Squat/Deadlift not shown.

**TC-06-009** · P1 · Today's Plan: Start Workout navigates to Workout tab  
**Steps:** Tap "Start Workout" on Today's Plan card  
**Expected:** Tab switches to Workout tab with active workout pre-loaded with today's exercises.

**TC-06-010** · P1 · Today's workout recap: shows if already done today  
**Steps:** Log and finish a workout today → check Home  
**Expected:** "Today's Workout" recap card replaces "Today's Plan". Shows exercise list + stats.

**TC-06-011** · P1 · Upcoming workout card: visible at 8pm+ when workout is tomorrow  
**Steps:** Set up routine for tomorrow → open app after 8pm  
**Expected:** "Next Up" section with tomorrow's exercises visible. Not visible before 8pm.

**TC-06-012** · P0 · Last Workout card: shows correct exercise + best set  
**Steps:** Log Bench 100kg × 5 → finish → check Home  
**Expected:** Last Workout card shows "Barbell Bench Press · 100.0 kg × 5".

**TC-06-013** · P0 · Readiness card: score visible  
**Steps:** Log 3 workouts → check Home readiness card  
**Expected:** Score 0–100 shown. Confidence level shown. Coaching note shown.

**TC-06-014** · P1 · Readiness delta: positive when above baseline  
**Steps:** Log 4 workouts in a week (high frequency)  
**Expected:** Delta is positive (above 30-day baseline). Green arrow.

**TC-06-015** · P2 · Streak badge appears at 2+ consecutive days  
**Steps:** Log workouts on 2 consecutive calendar days  
**Expected:** Flame badge in header: "2d streak". Correct count.

**TC-06-016** · P2 · Progress trend card shows gainers and stalled exercises  
**Steps:** Log consistent improvement on Bench for 6 weeks. Stall on another exercise.  
**Expected:** "Moving in the right direction" section shows Bench. "Worth a closer look" shows stalled exercise.

---
---

# SECTION 4 — WORKOUT TAB (EMPTY STATE)

---

## TS-07: Workout Tab — No Active Workout

**TC-07-001** · P1 · Today's routine card visible if scheduled  
**Prereq:** Routine assigned to today's weekday  
**Steps:** Open Workout tab  
**Expected:** Today's routine card with exercises and "Start Workout" button.

**TC-07-002** · P1 · Start Workout → exercise picker  
**Steps:** Tap "Start Workout" (no routines, or tap "Start Empty Workout")  
**Expected:** Confirmation dialog: "Pick Exercises" / "Load a Routine" / Cancel

**TC-07-003** · P1 · Load a Routine → RoutineSelectorView  
**Steps:** Start Workout → "Load a Routine"  
**Expected:** Sheet showing all routines, each with day-by-day breakdown. Tap a day to start.

**TC-07-004** · P1 · Start a Circuit button visible  
**Steps:** Open Workout tab (no active workout)  
**Expected:** "Start a Circuit" button (orange) visible below main start button.

**TC-07-005** · P1 · My Routines list shows all saved routines  
**Steps:** Create 3 routines → return to Workout tab  
**Expected:** All 3 listed with name, scheduled days, and quick-play button.

**TC-07-006** · P2 · Empty state when no routines exist  
**Steps:** Delete all routines → open Workout tab  
**Expected:** "No routines yet" message + "Create Routine" button. No crash.

---

## TS-08: Active Workout — Core Set Logging

**TC-08-001** · P0 · Weight pre-fills from last session  
**Steps:** Log Bench at 80kg → finish → new workout → add Bench  
**Expected:** Weight column shows 80.0. Not 0.

**TC-08-002** · P0 · Target reps pre-fill from last session or template  
**Steps:** Template has Bench at 5 reps → start from routine  
**Expected:** Target reps column shows 5.

**TC-08-003** · P0 · Complete set: marked and timestamped  
**Steps:** Tap checkmark on a set  
**Expected:** Set row visually marked complete. `completedAt` timestamp set (visible in export).

**TC-08-004** · P1 · Uncomplete set: reverts correctly  
**Steps:** Complete a set → tap again to uncomplete  
**Expected:** Set reverts to uncompleted state. Active set pointer rewinds if needed.

**TC-08-005** · P0 · Add set: clones last set's weight/reps  
**Steps:** Log 100kg × 5 → tap Add Set  
**Expected:** New set appears with 100kg / 5 pre-filled.

**TC-08-006** · P1 · Remove set: row deleted correctly  
**Steps:** Swipe to remove middle set of 3  
**Expected:** 2 sets remain. Correct ones remain, correct one deleted.

**TC-08-007** · P1 · Weight unit toggle: lbs mode  
**Steps:** (If lbs toggle exists in Settings) switch to lbs  
**Expected:** Weight column header changes to "LBS". Entered value shown in lbs. Stored value in kg internally.

**TC-08-008** · P1 · Dumbbell: column label shows "KG/HAND"  
**Steps:** Add a dumbbell exercise to workout  
**Expected:** Weight column header reads "KG/HAND" (or "LBS/HAND" in lbs mode).

**TC-08-009** · P1 · Equipment badge shown for barbell and dumbbell  
**Steps:** Add barbell exercise → observe header  
**Expected:** "min 20 kg (empty bar included)" badge visible for barbell. "× 2 (enter per-hand weight)" for dumbbell.

**TC-08-010** · P0 · Multiple exercises logged independently  
**Steps:** Add Bench, Squat, Row → log different weights/reps for each  
**Expected:** Each exercise retains its own set data. No cross-contamination.

**TC-08-011** · P1 · Exercise removal mid-workout  
**Steps:** Add 3 exercises → remove the middle one  
**Expected:** First and third exercises remain. Middle gone. No crash. Indices correct.

**TC-08-012** · P0 · PR banner shown on new personal record  
**Steps:** Log a weight × reps combination that exceeds previous best e1RM  
**Expected:** PR banner appears. `personalRecords[exerciseId]` updated.

**TC-08-013** · P1 · Weight/reps text field: decimal input accepted  
**Steps:** Type "52.5" in weight field  
**Expected:** 52.5 stored. Not truncated. Set logs 52.5kg.

**TC-08-014** · P2 · Active set indicator advances after complete  
**Steps:** Complete set 1 of 4  
**Expected:** Active set pointer moves to set 2. Visual highlight shifts down.

---

## TS-09: Advanced Set Features — Drop Sets, RPE, To Failure

**TC-09-001** · P0 · To-failure toggle saves to set  
**Steps:** Toggle "to failure" on set 2 → finish workout → check log export  
**Expected:** `toFailure = true` on set 2. Other sets `false`.

**TC-09-002** · P0 · To-failure: narrative shows "on target", not "missed"  
**Steps:** Log OHP to failure (reps may be lower than target) → finish → check narrative  
**Expected:** "on target" phrasing in narrative. Not "missed", "fell short", or "dropped".

**TC-09-003** · P1 · Drop set panel opens  
**Steps:** Long-press or tap drop set button on a completed set  
**Expected:** Drop weight and drop reps fields appear below the main set row.

**TC-09-004** · P0 · Drop set data saved to log  
**Steps:** Log 100kg main, drop to 80kg × 8 → finish → check export  
**Expected:** `dropWeight = 80`, `dropReps = 8` on that set.

**TC-09-005** · P1 · Drop set volume included in total  
**Steps:** Log 100kg × 5 + drop 80kg × 8 → session summary  
**Expected:** Volume for that set = (100×5) + (80×8) = 1,140 kg.

**TC-09-006** · P1 · Drop set completed marker  
**Steps:** Log drop set → tap "complete drop"  
**Expected:** `isDropCompleted = true`. Visual confirmation shown.

**TC-09-007** · P1 · RPE field accepts 6–10 range  
**Steps:** Enter RPE = 7.5 on a set  
**Expected:** 7.5 stored. Visible in export JSON under `rpe`.

**TC-09-008** · P1 · RPE = nil when not entered  
**Steps:** Log a set without entering RPE  
**Expected:** `rpe` field is absent/null in export. Not 0.

**TC-09-009** · P1 · To-failure + lower weight = "Dropped → Completed" narrative  
**Steps:** Log exercise at lower weight than last session, mark to failure  
**Expected:** Narrative reflects the lower weight was intentional (dropped and completed), not a failure regression.

**TC-09-010** · P2 · Multiple drop sets in one session  
**Steps:** Add drop sets to 3 different exercises  
**Expected:** Each exercise independently stores its own drop set data. No mixing.

---

## TS-10: Supersets

**TC-10-001** · P1 · Link two exercises as superset  
**Steps:** Active workout → Exercise A menu → "Link Superset" with Exercise B  
**Expected:** Both show superset badge "A1" / "A2". Orange connector between them.

**TC-10-002** · P1 · Superset: rest fires after completing last exercise in group  
**Steps:** Complete a set for Exercise A (superset A1) → complete Exercise B (A2)  
**Expected:** Rest timer fires after B completes, not after A.

**TC-10-003** · P1 · Superset: no rest between exercises in group  
**Steps:** Complete a set for Exercise A in superset  
**Expected:** No rest banner appears. View scrolls to Exercise B immediately.

**TC-10-004** · P1 · Scroll-to next exercise in superset  
**Steps:** Complete Exercise A in superset → observe scroll  
**Expected:** View auto-scrolls to Exercise B's card.

**TC-10-005** · P1 · Unlink superset  
**Steps:** Long-press Exercise A in superset → "Unlink Superset"  
**Expected:** A and B revert to independent exercises. No superset badge.

**TC-10-006** · P1 · Three-exercise superset  
**Steps:** Link A → B → C as one superset group  
**Expected:** All three show "A1/A2/A3". Rest fires only after C completes.

**TC-10-007** · P2 · Superset labels: unique per group  
**Steps:** Create two separate supersets in one workout  
**Expected:** First group = A, second group = B. Labels unique.

**TC-10-008** · P0 · Superset saves correctly to log  
**Steps:** Log superset A+B with 3 rounds each → finish → check export  
**Expected:** Both exercises present in log with 3 completed sets each. Superset group IDs match.

---

## TS-11: Rest Timer

**TC-11-001** · P1 · Default 90s fires on set complete  
**Steps:** Settings → Rest Timer = 90s → complete a set  
**Expected:** Banner counts from 1:30.

**TC-11-002** · P1 · Custom duration respected  
**Steps:** Settings → Rest Timer = 3 min → complete a set  
**Expected:** Banner counts from 3:00.

**TC-11-003** · P1 · Off setting: no banner  
**Steps:** Settings → Rest Timer = Off → complete a set  
**Expected:** No rest timer banner. No countdown.

**TC-11-004** · P2 · Color states: green → orange → red  
**Steps:** Set rest timer to 90s → watch count down  
**Expected:** Green at >30s, orange at 10–30s, red at ≤10s.

**TC-11-005** · P1 · Skip rest: timer stops immediately  
**Steps:** Rest timer counting → tap "Skip Rest"  
**Expected:** Banner disappears. Timer stopped.

**TC-11-006** · P0 · Timer setting persists across app kill  
**Steps:** Set to 2 min → force quit → relaunch → complete set  
**Expected:** Counts from 2:00. Not reverted to 90s.

**TC-11-007** · P1 · Timer in guided session matches setting  
**Steps:** Set timer to 3 min → use guided session → complete a set  
**Expected:** Guided session rest timer counts from 3:00. Same @AppStorage key.

**TC-11-008** · P1 · Timer does not fire in superset mid-group  
**Steps:** Superset A+B → complete A  
**Expected:** No rest timer. Timer only fires after B completes.

---

## TS-12: Exercise Swapper

**TC-12-001** · P0 · Swapper scoped to equivalence group when group exists  
**Steps:** Active workout → tap swap on Barbell Bench Press  
**Expected:** List shows: Dumbbell Bench, Chest Press Machine, Smith Machine Bench, Hammer Strength Chest Press. NOT incline, fly, dip.

**TC-12-002** · P0 · Round-trip returns to exact original  
**Steps:** Swap Barbell Bench → Dumbbell Bench → swap again → select Barbell Bench Press  
**Expected:** Returns "Barbell Bench Press" specifically. Not any other barbell exercise.

**TC-12-003** · P1 · No equivalence group: falls back to body region  
**Steps:** Swap an obscure exercise not in any equivalence group  
**Expected:** List shows all exercises with same `bodyRegion`. Broader list but no crash.

**TC-12-004** · P1 · Equipment filter chip narrows list  
**Steps:** Open swapper → tap "Dumbbell" chip  
**Expected:** List shows only dumbbell variants of the equivalence group (or body region).

**TC-12-005** · P1 · "Any" chip restores full list  
**Steps:** Filter by Dumbbell → tap "Any"  
**Expected:** Full equivalence group list restored.

**TC-12-006** · P1 · Quick swap equipment chips: only valid alternatives shown  
**Steps:** During workout with Barbell Bench → observe chip row  
**Expected:** Only equipment types that have an equivalent exercise in the group are shown. Not all 6 equipment types blindly.

**TC-12-007** · P1 · Quick swap loads correct exercise  
**Steps:** Tap "DB" chip on Barbell Bench row  
**Expected:** Swaps to Dumbbell Bench Press (best history match, or first alphabetically).

**TC-12-008** · P1 · Swap also offered in guided workout plan preview  
**Steps:** Open GuidedWorkoutPlanView → tap swap icon on exercise  
**Expected:** ExerciseSwapperView opens with same equivalence-scoped list.

---

## TS-13: Finish Workout Flow

**TC-13-001** · P0 · "Finish" shows Session Review first  
**Steps:** Active workout → tap "Finish"  
**Expected:** Session Summary sheet appears (duration, sets, volume, exercise list). NOT feel selector directly.

**TC-13-002** · P0 · Session Review: duration is accurate  
**Steps:** Start workout, wait 10 minutes → finish → check review  
**Expected:** Duration shows "10 min" (±1 min). Not 0, not blank.

**TC-13-003** · P0 · Session Review: set count is accurate  
**Steps:** Log 3 exercises × 4 sets each → review  
**Expected:** Shows "12 sets".

**TC-13-004** · P0 · Session Review: volume is accurate  
**Steps:** Log Bench 100kg×5, Squat 120kg×3 → review  
**Expected:** Volume shows 860 kg (100×5 + 120×3 = 500+360).

**TC-13-005** · P1 · Session Review: all exercises listed  
**Steps:** Log 6 exercises → finish → review  
**Expected:** All 6 exercises visible. Sheet is scrollable.

**TC-13-006** · P0 · Session Review "Done" → Feel selector  
**Steps:** Session Summary → tap Done  
**Expected:** Sheet dismisses → Feel selector sheet appears with 4 emoji options + Skip.

**TC-13-007** · P0 · Feel rating saves to log entry  
**Steps:** Select 🙂 (third emoji) → finish  
**Expected:** Workout log entry has `feelRating` set. Visible in history detail.

**TC-13-008** · P1 · Skip feel: workout still saves  
**Steps:** Feel selector → tap Skip  
**Expected:** Workout saved with `feelRating = nil`. No crash. Log entry appears.

**TC-13-009** · P0 · Discard: confirmation dialog appears  
**Steps:** Active workout → tap Discard  
**Expected:** Alert: "Discard Workout? / All logged sets will be lost." Two buttons: Discard (red) + Cancel.

**TC-13-010** · P0 · Discard → Cancel: workout intact  
**Steps:** Discard → Cancel  
**Expected:** Active workout unchanged. All logged sets present.

---
---

# SECTION 5 — ROUTINES & PLANS

---

## TS-14: Routine Management

**TC-14-001** · P0 · Create routine with name and exercises  
**Steps:** Routines → + → name "Push Day" → add Bench, OHP, Dips → assign to Mon/Thu → Save  
**Expected:** Routine appears in list with name, exercise count, Mon/Thu days.

**TC-14-002** · P0 · Edit routine: name change saves  
**Steps:** Tap routine → rename → Save  
**Expected:** New name displayed everywhere (Workout tab, Home tab, log entries).

**TC-14-003** · P0 · Edit routine: add exercise to existing routine  
**Steps:** Edit "Push Day" → add Lateral Raise  
**Expected:** Lateral Raise added. No existing exercises removed.

**TC-14-004** · P1 · Edit routine: remove exercise  
**Steps:** Edit routine → swipe-delete one exercise → Save  
**Expected:** Exercise removed. Others intact.

**TC-14-005** · P0 · Delete routine: swipe delete in list  
**Steps:** Swipe left on routine in list → Delete  
**Expected:** Routine removed. Not shown in Workout tab or Home tab.

**TC-14-006** · P1 · Routine: exercises assignable to multiple days  
**Steps:** Assign Bench to Mon + Thu  
**Expected:** Bench appears in Today's Plan on both Monday and Thursday.

**TC-14-007** · P1 · Routine day selector: starts empty  
**Steps:** Create new routine → add first exercise → check day chips  
**Expected:** No days pre-selected. User must explicitly assign.

**TC-14-008** · P1 · Start from routine: loads correct exercises  
**Steps:** Routine has Bench + Squat + Row on Wednesday → start on Wednesday  
**Expected:** Active workout opens with exactly those 3 exercises.

**TC-14-009** · P1 · Start from routine: specific day selection  
**Steps:** Routine has Mon exercises (Bench) and Wed exercises (Squat) → Load a Routine → select Wednesday  
**Expected:** Only Squat loads. Not Bench.

**TC-14-010** · P1 · Start from routine: Load All Days  
**Steps:** Load a Routine → tap "Load All Days"  
**Expected:** All exercises from all assigned days loaded into one workout.

**TC-14-011** · P1 · Routine superset groups preserved  
**Steps:** Create routine with A+B superset → start from routine  
**Expected:** Workout launches with superset badge on A and B. Superset behavior active.

**TC-14-012** · P1 · Swap in active workout offers to update template  
**Steps:** Start from routine → swap Bench to Dumbbell Bench → confirm "Also update template"  
**Expected:** Routine updated. Next time starting this routine, Dumbbell Bench appears in its place.

**TC-14-013** · P2 · Routine with no name shows "Unnamed Routine"  
**Steps:** Create routine, leave name blank  
**Expected:** Displayed as "Unnamed Routine" everywhere. No crash.

**TC-14-014** · P0 · Routines persist across kill cycles  
**Steps:** Create 3 routines → force quit → relaunch  
**Expected:** All 3 present with all details intact.

---

## TS-15: QR Code Routine Import

**TC-15-001** · P1 · Scanner opens camera  
**Steps:** Routines → QR icon → QRRoutineScannerView opens  
**Expected:** Camera preview visible. Scanning overlay with corners shown.

**TC-15-002** · P0 · Valid QR: routine imports correctly  
**Steps:** Scan a valid QR with `{ "bw_version": 1, "name": "Leg Day", "exercises": [{"name": "Squat", "sets": 4, "reps": 5}] }`  
**Expected:** Success screen shows "Leg Day" with Squat 4×5. Confirm imports routine.

**TC-15-003** · P0 · Imported routine matches QR payload  
**Steps:** After import → check Routines list  
**Expected:** "Leg Day" present with correct exercises, sets, reps.

**TC-15-004** · P0 · Exercise name matching: QR exercise matched to database  
**Steps:** QR contains `"name": "Barbell Bench Press"` → import  
**Expected:** Matched to the actual exercise in the database (same UUID). Not a new unknown exercise.

**TC-15-005** · P1 · Invalid QR code: error state  
**Steps:** Scan a non-workout QR (e.g., a URL)  
**Expected:** Error screen: "This QR code isn't a Boring Workout routine." No crash.

**TC-15-006** · P1 · Wrong version: error or handled  
**Steps:** QR with `"bw_version": 99` → scan  
**Expected:** Either imports gracefully or shows "Unsupported version" error. No crash.

**TC-15-007** · P1 · Cancel: no routine created  
**Steps:** Open scanner → tap Cancel  
**Expected:** No routine added to store. Routine list unchanged.

**TC-15-008** · P2 · Camera permission denied: graceful state  
**Steps:** Deny camera permission → open QR scanner  
**Expected:** Shows "Camera access needed" message or system prompt. Not a blank black screen or crash.

---

## TS-16: Circuits (AMRAP / EMOM)

**TC-16-001** · P1 · Create AMRAP circuit  
**Steps:** Workout tab → Start a Circuit → + → name "Tabata", AMRAP, 20 min → add Push-Up (15 reps), Burpee (10 reps) → Save  
**Expected:** Circuit saved under AMRAP section.

**TC-16-002** · P1 · Create EMOM circuit  
**Steps:** Create circuit with EMOM format  
**Expected:** Saved under EMOM section in list.

**TC-16-003** · P0 · Start AMRAP circuit: countdown then session begins  
**Steps:** Tap circuit → Start → observe 3-2-1 countdown  
**Expected:** 3-second countdown ring plays → session begins with exercise 1.

**TC-16-004** · P0 · AMRAP: round tracking  
**Steps:** Complete all exercises in circuit once  
**Expected:** Round counter increments. Returns to exercise 1.

**TC-16-005** · P0 · AMRAP: timer counts down  
**Steps:** Start 20-minute AMRAP  
**Expected:** Ring shrinks continuously. Time shown correctly. Ends at 0:00.

**TC-16-006** · P0 · AMRAP: result saved to cardio log  
**Steps:** Complete AMRAP → finish  
**Expected:** `CardioLogEntry` saved. Rounds completed, duration recorded.

**TC-16-007** · P1 · EMOM: each minute advances exercise  
**Steps:** Start EMOM circuit with 3 exercises  
**Expected:** At 0:00 of each minute, next exercise highlighted. User completes reps in remaining time.

**TC-16-008** · P1 · Delete circuit: swipe delete  
**Steps:** Swipe left on circuit → Delete  
**Expected:** Circuit removed from list. No crash.

**TC-16-009** · P1 · Edit circuit: update exercise reps  
**Steps:** Edit circuit → change Push-Up target from 15 to 20 → Save  
**Expected:** Next session target shows 20.

**TC-16-010** · P0 · Empty circuit list: shows ContentUnavailableView  
**Steps:** Delete all circuits  
**Expected:** "No Circuits — Tap + to build your first HIIT circuit." No crash.

**TC-16-011** · P2 · Circuit name empty: shows format + "Circuit" fallback  
**Steps:** Create circuit with no name  
**Expected:** Displays "AMRAP Circuit" or "EMOM Circuit". Not blank.

**TC-16-012** · P1 · Circuit session saved to Health  
**Steps:** Authorize HealthKit → complete AMRAP circuit  
**Expected:** Workout entry saved to Apple Health with correct start time and duration.

---

## TS-17: Guided Trainer Flow

**TC-17-001** · P1 · Trainer tab generates 3 plans  
**Steps:** Open TrainerTabView (accessible from Trainer section or Workout tab)  
**Expected:** 3 swipeable workout plan cards generated: Primary, Alternate, Recovery.

**TC-17-002** · P1 · Plan reflects readiness score  
**Steps:** Readiness score < 50 → check generated plans  
**Expected:** Plans show lower intensity (fewer sets, lighter load recommendation) vs high readiness.

**TC-17-003** · P1 · Plan targets fresh muscle groups  
**Steps:** Log a chest workout → check next day's plans  
**Expected:** Primary plan focuses on back/legs (not chest again).

**TC-17-004** · P1 · Swipe to skip plan card  
**Steps:** Swipe left on a plan card  
**Expected:** Card dismissed. Next card visible.

**TC-17-005** · P0 · Tap Start → plan preview  
**Steps:** Tap Start on a plan card  
**Expected:** GuidedWorkoutPlanView sheet opens with exercise list, coach note, estimated duration.

**TC-17-006** · P1 · Plan preview: swap exercise  
**Steps:** Plan preview → tap swap on an exercise → select alternative  
**Expected:** Exercise replaced in preview. Weight pre-filled from last performance of new exercise.

**TC-17-007** · P0 · Start session from preview  
**Steps:** Plan preview → tap Start  
**Expected:** GuidedWorkoutSessionView opens fullscreen with exercises from plan.

**TC-17-008** · P0 · Guided session: log set → rest timer fires  
**Steps:** Log a set in guided session (not last set of exercise)  
**Expected:** Rest timer starts per Settings preference.

**TC-17-009** · P0 · Guided session: advance to next exercise automatically  
**Steps:** Log all sets for exercise 1  
**Expected:** Progress bar advances. Exercise 2's card becomes active. Previous exercise's card gone.

**TC-17-010** · P0 · Guided session: save to workout log  
**Steps:** Log 3 exercises × 2 sets each → finish → confirm  
**Expected:** Workout log entry created with 3 exercises × 2 completed sets. Correct weights and reps.

**TC-17-011** · P1 · Guided session: partial log (skip exercise)  
**Steps:** Log exercise 1 fully, skip exercise 2, log exercise 3 → finish  
**Expected:** Log entry has exercise 1 (2 sets) + exercise 2 (0 sets) + exercise 3 (2 sets). No crash.

**TC-17-012** · P2 · Mini readiness card visible in Trainer tab  
**Steps:** Open Trainer tab  
**Expected:** Small readiness card at top showing score and coaching note.

---
---

# SECTION 6 — ANALYTICS & PROGRESS

---

## TS-18: Progress Tab

**TC-18-001** · P1 · Loading skeleton while isLoaded = false  
**Steps:** Cold launch → immediately navigate to Progress  
**Expected:** Pulsing skeleton cards visible. Replaced by real content once loaded.

**TC-18-002** · P0 · Standard Lifts card: correct tier for Bench Press  
**Prereq:** BW = 80kg. Log Bench 80kg × 5 (e1RM ≈ 93kg = 1.17× BW)  
**Expected:** Bench tier gauge shows "Beginner" (threshold: 0.80× BW for beginner entry, 1.15× for intermediate). Borderline intermediate.

**TC-18-003** · P0 · Standard Lifts card: all 10 lifts trackable  
**Steps:** Log Bench, Squat, Deadlift, OHP, Row, Incline, Lat Pulldown, Cable Row, Leg Press, Pull-Up  
**Expected:** All appear in Standard Lifts card. Each shows current e1RM and tier gauge.

**TC-18-004** · P1 · Standard Lifts: barbell/dumbbell picker  
**Steps:** Tap "DB" chip on Bench Pair  
**Expected:** Gauge switches to Dumbbell Bench thresholds (per-hand: beg=0.28, int=0.40, adv=0.56× BW).

**TC-18-005** · P0 · Composite score card appears after Push + Pull + Legs data  
**Prereq:** Log all 3 PPL pattern types for 3+ weeks  
**Steps:** Open Progress tab  
**Expected:** CompositeScoreCard visible between Standard Lifts and Weekly Progress.

**TC-18-006** · P0 · Composite score missing when only 1 PPL type logged  
**Prereq:** Log only Bench (Push) for 3 weeks  
**Expected:** Composite score card NOT visible (coverage gate).

**TC-18-007** · P1 · Weekly progress card: volume trend  
**Steps:** Log 3 workouts with increasing volume each week  
**Expected:** Weekly progress card shows upward volume trend.

**TC-18-008** · P1 · Strength portfolio quadrant visible with data  
**Steps:** Log 4+ weeks of workouts  
**Expected:** Portfolio quadrant chart renders. Exercises plotted by level vs momentum.

**TC-18-009** · P1 · Activity strip: correct days highlighted  
**Steps:** Log workouts on days 1, 3, 5, 15, 28 of the month  
**Expected:** Activity strip highlights those 5 days. Other days shown as empty dots.

**TC-18-010** · P1 · Health Trends card shown when HealthKit authorized  
**Steps:** Authorize HealthKit → Progress tab  
**Expected:** "Health Trends" entry card visible. Tap → HealthTrendsView sheet opens.

**TC-18-011** · P1 · Quick Stats row: correct values  
**Steps:** Log 10 workouts, 5 PRs, 3-day streak, total volume = 50,000 kg  
**Expected:** Quick Stats shows "10 sessions / 5 PRs / 3 streak / 50k kg".

**TC-18-012** · P0 · PR section: grouped by body region  
**Steps:** Log PRs across Chest, Back, Legs exercises  
**Expected:** PR section shows 3 groups: Chest / Back / Legs. Each lists exercises with e1RM.

**TC-18-013** · P1 · PR section: collapsible  
**Steps:** Tap "Show PRs" / "Hide PRs" toggle  
**Expected:** PR list expands and collapses smoothly. Not a jump.

**TC-18-014** · P1 · Progress tab: no crash with zero workouts  
**Steps:** Clear all workout data  
**Expected:** Progress tab shows empty states gracefully. No crash on any card.

**TC-18-015** · P2 · Health Trends sheet: charts render  
**Steps:** Authorize HealthKit with data → open Health Trends  
**Expected:** HRV trend, sleep trend, resting HR charts visible with actual data points.

**TC-18-016** · P2 · Analytics insight row on Home: taps to Progress tab  
**Steps:** Home tab → tap analytics insight row (if visible)  
**Expected:** Navigates to Progress tab (selectedTab = 2).

---

## TS-19: Insights Tab (Strength Lab)

**TC-19-001** · P1 · Insights tab shows exercise list grouped by Push/Pull/Legs  
**Steps:** Log Push, Pull, Legs exercises → Insights tab  
**Expected:** Three sections: Push / Pull / Legs. Each contains relevant exercises sorted by activation weight.

**TC-19-002** · P1 · Isolation exercises: grouped by dominant muscle  
**Steps:** Log Bicep Curls (dominant: biceps = Pull) → Insights  
**Expected:** Bicep Curls appears under Pull section.

**TC-19-003** · P0 · Hero score: PCSA-weighted e1RM shown  
**Steps:** Insights tab with 3+ weeks of data  
**Expected:** Hero section shows a single "overall strength score" in kg (or selected unit). Has 90-day trend line.

**TC-19-004** · P1 · Unit switcher: kg → kg/cm² → N/cm²  
**Steps:** Tap unit switcher in Insights tab  
**Expected:** All values update. kg/cm² = score / activation_weight. N/cm² = score × 9.81 / activation_weight.

**TC-19-005** · P1 · Allometric scaling toggle  
**Steps:** Toggle "Allometric Scaling" on  
**Expected:** Scores divided by BW^0.67. Values change. Label reflects scaling.

**TC-19-006** · P1 · Exercise group expand/collapse  
**Steps:** Tap "Push" group header  
**Expected:** Exercise list expands showing per-exercise scores. Taps again to collapse.

**TC-19-007** · P1 · All-time vs recent toggle  
**Steps:** Toggle "All-Time" switch  
**Expected:** Chart x-axis extends to show full history. Not just recent 90 days.

**TC-19-008** · P1 · No data state  
**Steps:** Open Insights tab with zero workouts  
**Expected:** Empty state or "Log workouts to see your insights" message. No crash.

**TC-19-009** · P1 · Exercise with no equivalence group still appears  
**Steps:** Log an unusual exercise not in any PPL group  
**Expected:** Classified by dominant muscle, appears in correct PPL section.

**TC-19-010** · P2 · Mini trend lines render per exercise  
**Steps:** Log one exercise 5+ times  
**Expected:** Mini sparkline chart visible in that exercise's row.

---

## TS-20: Exercise Detail Sheet

**TC-20-001** · P0 · Opens from exercise card in Insights tab  
**Steps:** Insights tab → tap an exercise  
**Expected:** ExerciseDetailSheet opens with e1RM trend chart.

**TC-20-002** · P0 · e1RM trend chart: sessions plotted correctly  
**Steps:** Log Bench 4 sessions with increasing weight  
**Expected:** 4 data points on chart trending upward. Dates on x-axis match session dates.

**TC-20-003** · P1 · Rolling average line visible  
**Steps:** Log 6+ sessions  
**Expected:** 5-session rolling average line overlaid on raw data points.

**TC-20-004** · P1 · Fatigue-adjusted mode  
**Steps:** Tap "Fatigue-Adj" segment  
**Expected:** Chart switches to fatigue-adjusted e1RM (upscaled by set-order decay factor). Values higher than standard for later sets.

**TC-20-005** · P1 · INOL zone badge  
**Steps:** Log high-volume session (many sets near max) → detail  
**Expected:** INOL value shown. Zone badge: Optimal / Heavy / Overreaching with color coding.

**TC-20-006** · P1 · Coaching note from INOL + rep decay  
**Steps:** Log session where reps drop significantly set to set  
**Expected:** Coaching note visible: "Steep rep drop-off — extend rest intervals or reduce opening weight."

**TC-20-007** · P1 · Efficiency score visible  
**Steps:** Log 3+ sessions with feel ratings → detail  
**Expected:** Efficiency score shown (Δe1RM / session_cost). Label: "Great / Average / Below avg".

**TC-20-008** · P1 · PR progression step chart  
**Steps:** Log 5 sessions with new PRs on sessions 1, 3, 5  
**Expected:** Step chart shows 3 steps at those dates. Flat in between.

**TC-20-009** · P1 · Variance bands toggleable  
**Steps:** Tap "Show Variance" toggle  
**Expected:** ±1σ band appears around e1RM trend. Wider = more variable performance.

**TC-20-010** · P1 · Relative strength shown when body weight set  
**Steps:** BW = 80kg → Bench e1RM = 100kg → detail  
**Expected:** Relative strength shows 1.25× BW.

**TC-20-011** · P2 · Feel streak insight visible  
**Steps:** Log 3 consecutive sessions all rated 💪 → detail  
**Expected:** Feel insight: "Three in a row feeling strong — this is your momentum window" or similar.

**TC-20-012** · P1 · Sheet dismisses cleanly  
**Steps:** Open detail → swipe down  
**Expected:** Sheet dismisses. No lingering chart artifacts or state.

---

## TS-21: History

**TC-21-001** · P0 · Workouts grouped by month  
**Steps:** Log workouts in May and June → History tab  
**Expected:** Two sections: "May 2026" and "June 2026". Entries in each.

**TC-21-002** · P1 · Each row shows date badge, name, muscle groups, duration, sets, volume  
**Steps:** Log a named workout → History  
**Expected:** Row shows date number + weekday abbreviation, workout name, muscle groups text, clock icon + duration, "N sets", kg volume.

**TC-21-003** · P1 · Tap row → workout detail sheet  
**Steps:** Tap any history row  
**Expected:** WorkoutDetailView sheet opens. Shows all exercises + sets from that session.

**TC-21-004** · P0 · Detail shows correct data  
**Steps:** Log Bench 80kg × 5, 90kg × 3 → finish → open in History detail  
**Expected:** Both sets visible with correct weights and reps.

**TC-21-005** · P1 · Empty state when no workouts  
**Steps:** Clear all data  
**Expected:** "No Workouts Yet" ContentUnavailableView. No crash.

**TC-21-006** · P2 · Months sorted newest first  
**Steps:** Log workouts in March and May  
**Expected:** May appears first, March below. Not alphabetical.

---
---

# SECTION 7 — SETTINGS & INTEGRATIONS

---

## TS-22: Settings

**TC-22-001** · P0 · Name change updates Home greeting  
**Steps:** Settings → Name → change to "Sam" → Home tab  
**Expected:** "Good morning, Sam 👋"

**TC-22-002** · P0 · Body weight change triggers analytics refresh  
**Steps:** Change body weight 80 → 90 kg → Progress tab  
**Expected:** Tier gauge positions update. Composite score recalculates with new BW.

**TC-22-003** · P1 · Age change updates tier thresholds  
**Steps:** Change age from 30 → 55 → Progress tab  
**Expected:** Tier thresholds shift (0.85 scalar at 55). Same lifts may show higher tier.

**TC-22-004** · P1 · Body Fat % stored and shown  
**Steps:** Enter 18.0 → force quit → relaunch  
**Expected:** Body Fat shows 18.0. Not 0, not blank.

**TC-22-005** · P1 · Sync from Apple Health updates profile  
**Steps:** Authorize Health with body weight data → Settings → "Sync from Apple Health"  
**Expected:** Body weight updates to Health value. "Synced successfully" message shown.

**TC-22-006** · P1 · Rest Timer picker: all 6 options available  
**Steps:** Settings → Workout → Rest Timer picker  
**Expected:** Off / 60s / 90s / 2 min / 3 min / 5 min all selectable.

**TC-22-007** · P1 · Health Metrics toggle: disable HRV  
**Steps:** Settings → Health Metrics → uncheck HRV  
**Expected:** HRV pill disappears from Home health snapshot row.

**TC-22-008** · P1 · Export: share sheet opens  
**Steps:** Settings → Export Workouts  
**Expected:** iOS share sheet appears with JSON file. Can AirDrop, save to Files, etc.

**TC-22-009** · P1 · Export on empty log: valid JSON  
**Steps:** Clear all data → Export  
**Expected:** Exports `{"workoutLog":[],"routines":[],"exportedAt":"..."}`. No crash.

**TC-22-010** · P1 · Help: opens rendered markdown  
**Steps:** Settings → Help  
**Expected:** HelpView opens. Markdown rendered: headers, bullets, code blocks, tables all display correctly.

**TC-22-011** · P2 · Version and build shown  
**Steps:** Settings → About  
**Expected:** "Version 1.0.0" and "Build 1" visible.

**TC-22-012** · P2 · Height stored  
**Steps:** Enter height 178cm → force quit → relaunch  
**Expected:** 178 shown. Not blank.

---

## TS-23: Health Integration

**TC-23-001** · P1 · HealthKit authorization request  
**Steps:** First launch (or after resetting permissions) → open Home tab  
**Expected:** iOS HealthKit permission sheet appears listing requested data types.

**TC-23-002** · P1 · Body weight from Health syncs to profile  
**Steps:** Health app: add body weight 82kg → open Home tab  
**Expected:** `store.userProfile.bodyWeightKg = 82`. Analytics refresh triggered.

**TC-23-003** · P1 · HRV pill shows last night's value  
**Steps:** Health has HRV = 55ms → Home  
**Expected:** HRV pill shows "55 ms" in orange (moderate fatigue range).

**TC-23-004** · P1 · Resting HR pill: color coded  
**Steps:** Resting HR = 48 bpm  
**Expected:** Green (< 55 bpm = "Excellent").

**TC-23-005** · P1 · Sleep pill: color for < 7h  
**Steps:** Sleep = 5h 30m  
**Expected:** Red (< 6h = "Insufficient"). Label shows "5h 30m".

**TC-23-006** · P0 · Workout saved to Health after finish  
**Steps:** Finish workout → open Health → Activity → Workouts  
**Expected:** Workout appears with correct start time, duration, and workout type.

**TC-23-007** · P1 · Avg HR fetched from Health after finish  
**Steps:** Wear Apple Watch during workout → finish → Home Last Workout card  
**Expected:** "Avg HR: X bpm" appears in expanded workout detail (fetched async).

**TC-23-008** · P1 · Active calories fetched from Health  
**Steps:** Wear Watch → finish → expanded last workout card  
**Expected:** "Cal Burned: X kcal" appears.

**TC-23-009** · P1 · Fallback calories: estimated if Watch not available  
**Steps:** No Watch → finish workout (BW set)  
**Expected:** Calories estimated via `5.0 × BW × (duration_hours)`. Shows in Home card.

**TC-23-010** · P2 · Health Trends: VO2 Max pill shown when available  
**Steps:** Health has VO2 Max data → Home  
**Expected:** VO2 Max pill appears in health snapshot row. Color-coded by range.

---

## TS-24: Notifications

**TC-24-001** · P1 · Permission requested once on onboarding complete  
**Steps:** Fresh install → complete onboarding  
**Expected:** iOS notification permission dialog fires. Not before, not twice.

**TC-24-002** · P1 · Re-engagement scheduled after workout finish  
**Steps:** Finish workout → check pending notifications via `UNUserNotificationCenter.getPendingNotificationRequests`  
**Expected:** One pending request with id `re_engagement`, trigger ~3 days from now.

**TC-24-003** · P1 · Re-engagement reset on app foreground  
**Steps:** Finish workout → wait 5 minutes → open app again  
**Expected:** `re_engagement` notification re-scheduled with new trigger 3 days from NOW.

**TC-24-004** · P1 · Previous notification cancelled before rescheduling  
**Steps:** Finish workout → reopen app → check pending count  
**Expected:** Exactly 1 pending `re_engagement` notification. Not accumulating.

**TC-24-005** · P2 · No permission: no crash  
**Steps:** Deny notification permission → finish workout  
**Expected:** `scheduleReEngagement()` exits early (not authorized). No crash.

**TC-24-006** · P2 · Notification content correct  
**Steps:** Inspect pending notification content  
**Expected:** Title: "Time to train". Body contains "3 days" and encouragement. Sound = default.

---

## TS-25: Apple Watch Connectivity

**TC-25-001** · P2 · Workout started notification sent to Watch  
**Steps:** Start workout with paired Watch  
**Expected:** Watch receives "workout started" message. Watch app activates if applicable.

**TC-25-002** · P2 · Active exercise name sent on exercise change  
**Steps:** Active workout → complete all sets of exercise 1 → advance to exercise 2  
**Expected:** Watch displays exercise 2's name.

**TC-25-003** · P2 · Set started notification sent  
**Steps:** Tap a set's active indicator  
**Expected:** Watch receives "set started" with exercise name.

**TC-25-004** · P2 · Workout ended notification sent  
**Steps:** Finish workout  
**Expected:** Watch receives "workout ended" message.

**TC-25-005** · P2 · Velocity profile attached to set when received  
**Steps:** Watch measures bar velocity → sends profile → check set in active workout  
**Expected:** `velocityProfile` attached to the correct set (exercise index + set index match).

**TC-25-006** · P2 · No crash when Watch not connected  
**Steps:** No paired Watch → finish workout  
**Expected:** WatchConnectivityManager calls succeed silently. No crash.

---
---

# SECTION 8 — CALCULATIONS

---

## TS-26: e1RM Formulas

**TC-26-001** · P0 · 1 rep: returns exact weight  
**Manual:** e1RM(140, 1) = 140  
**Steps:** Log Deadlift 140kg × 1 → check PR e1RM  
**Expected:** 140.0. Not Epley(140, 1) = 144.67.

**TC-26-002** · P0 · Epley: 5 reps  
**Manual:** e1RM(100, 5) = 100 × (1 + 5/30) = 116.67  
**Steps:** Log Bench 100kg × 5 → check e1RM  
**Expected:** 116–117 kg.

**TC-26-003** · P0 · Epley: 10 reps  
**Manual:** e1RM(80, 10) = 80 × (1 + 10/30) = 106.67  
**Steps:** Log 80kg × 10  
**Expected:** ≈107 kg.

**TC-26-004** · P0 · Mayhew: 15 reps  
**Manual:** e1RM(60, 15) = 60 / (0.522 + 0.419 × e^(−0.055×15)) ≈ 86.3  
**Steps:** Log 60kg × 15 → check e1RM  
**Expected:** ≈86 kg. NOT Epley (60 × 1.5 = 90).

**TC-26-005** · P0 · Mayhew: 20 reps  
**Manual:** e1RM(50, 20) = 50 / (0.522 + 0.419 × e^(−0.055×20)) ≈ 74.8  
**Steps:** Log 50kg × 20  
**Expected:** ≈75 kg. Mayhew formula used, not 0.

**TC-26-006** · P0 · 21 reps: returns 0  
**Steps:** Log 100kg × 21  
**Expected:** e1RM = 0. No PR recorded. Narrative doesn't show a new best.

**TC-26-007** · P0 · Weight = 0: returns 0  
**Steps:** Log 0kg × 5 (non-barbell)  
**Expected:** e1RM = 0. Guard `w > 0` triggers.

**TC-26-008** · P0 · Barbell weight floor: 0 entered → 20 kg used  
**Steps:** Log barbell exercise with 0 kg, 5 reps  
**Expected:** e1RM computed from 20kg (bar weight). ≈23.3 kg.

**TC-26-009** · P0 · Dumbbell: bilateral doubling before e1RM  
**Manual:** Entered 30 per-hand → effectiveWeight = 60 → e1RM(60, 8) = 60 × (1 + 8/30) ≈ 76  
**Steps:** Log DB Bench 30kg × 8 → check e1RM  
**Expected:** ≈76 kg (calculated from 60kg bilateral, not 30kg).

**TC-26-010** · P1 · Reliable flag correct  
**Steps:** Log 3 reps (reliable), 21 reps (not reliable)  
**Expected:** `e1RMIsReliable` = true for ≤20 reps. False for >20.

---

## TS-27: PSI & Fiber Index

**TC-27-001** · P0 · PSI > 0 after barbell workout  
**Steps:** BW = 80kg → log Bench 100kg × 5, Squat 120kg × 3 → Progress  
**Expected:** PSI chart shows non-zero value on that date.

**TC-27-002** · P0 · PSI uses bodyweight as load for bodyweight exercises  
**Steps:** BW = 80kg → log Pull-Ups (bodyweight) × 10 → check PSI  
**Expected:** PSI contribution from Pull-Ups computed using 80kg as `setWeight`. Not 0.

**TC-27-003** · P1 · PSI = 0 when body weight not set (bodyweight exercises)  
**Steps:** Clear body weight → log Push-Ups only  
**Expected:** PSI = 0 or no data. No crash.

**TC-27-004** · P0 · PSI normalized: normalizedPSI = rawFiberLoad / BW^0.67  
**Manual:** If rawFiberLoad = 500, BW = 80 → BW^0.67 ≈ 18.4 → normalizedPSI ≈ 27.2  
**Steps:** Verify via Insights tab PSI chart (raw vs normalized toggle)  
**Expected:** Normalized PSI significantly lower than raw. Ratio matches BW^0.67 divisor.

**TC-27-005** · P1 · PSI increases after progressive overload  
**Steps:** Log same exercises with 10% more weight 4 weeks later  
**Expected:** PSI trend shows increase (not flat).

**TC-27-006** · P1 · PSI display modes: raw, ÷BW, ÷lean, ÷muscle  
**Steps:** StrengthScoreView → Fiber Index tab → toggle between display modes  
**Expected:** Each mode shows distinct values. Lean/muscle modes require body composition data.

**TC-27-007** · P1 · PSI history: one point per session  
**Steps:** Log 5 workouts over 5 days  
**Expected:** PSI chart shows 5 data points at correct dates.

**TC-27-008** · P1 · leanPSI = nil when lean mass not set  
**Steps:** No lean mass in profile → check PSI detail  
**Expected:** "÷ Lean Mass" mode not shown or shows "Set lean mass in Settings".

---

## TS-28: Composite Score & Tier Thresholds

**TC-28-001** · P0 · Composite score: 0–100 range  
**Steps:** Log sufficient PPL data → check composite score  
**Expected:** Score between 0 and 100 inclusive.

**TC-28-002** · P0 · 3/3 PPL coverage required for Elite  
**Steps:** Log elite-level numbers on all 3 PPL patterns  
**Expected:** Tier can be "Elite". Coverage gate = 3/3 = no cap.

**TC-28-003** · P0 · 2/3 PPL coverage: max Advanced  
**Steps:** Never log a Legs exercise, log high Push + Pull  
**Expected:** Composite tier capped at "Advanced". Not Elite.

**TC-28-004** · P0 · 1/3 PPL coverage: max Intermediate  
**Steps:** Log only Deadlift (Pull pattern) for 3 weeks  
**Expected:** Composite tier capped at "Intermediate".

**TC-28-005** · P0 · 0/3 coverage: composite score absent  
**Steps:** Log only isolation exercises (curls, laterals) for 3 weeks  
**Expected:** No composite score card shown.

**TC-28-006** · P0 · Tier bands: Beginner 0–20, Int 20–50, Adv 50–80, Elite 80–100  
**Steps:** For a known exercise and BW, manually compute expected tier score  
**Expected:** Gauge fills position matches formula band.

**TC-28-007** · P0 · relativeStrength uses peakE1RM (not recentE1RM)  
**Steps:** Log PR 120kg → next session log 100kg → check tier position  
**Expected:** Tier reflects 120kg peak. Does not drop because of 100kg lighter session.

**TC-28-008** · P0 · Elite range = advanced × 0.30 (proportional)  
**Manual:** Bench advanced threshold = 1.60× BW = 128kg (at BW=80). Elite range = 128 × 0.30 = 38.4kg above advanced. Elite max = 166.4kg.  
**Steps:** Log Bench 166kg (above elite ceiling) → check tier  
**Expected:** Score ≈ 100. Not > 100 (clamped). Not uniformly 100 for all elite lifters.

**TC-28-009** · P1 · Age scalar applies to thresholds  
**Steps:** Age = 55 (scalar 0.85). Bench advanced threshold = 1.60 × 0.85 = 1.36× BW.  
**Expected:** Same weight that would be Advanced at 30 may be Elite at 55.

**TC-28-010** · P1 · Coverage gating shown to user  
**Steps:** 2/3 PPL coverage, tier shown as Advanced  
**Expected:** UI indicates "Missing: Legs" or "Tier capped by coverage". Not silently showing wrong tier.

---

## TS-29: Readiness Engine

**TC-29-001** · P0 · Score range: always 20–99  
**Steps:** Various log states: no workouts, every day, very stale  
**Expected:** `score` never below 20 (max penalty) or above 99. Clamped.

**TC-29-002** · P1 · 2-day rest gives highest recovery bonus (+12)  
**Steps:** Log today → simulate 2 days passing (test data) → check readiness  
**Expected:** Score higher than 1-day rest (+8) or 4+ day gap (−4).

**TC-29-003** · P1 · 7+ day gap gives −14 penalty  
**Steps:** No workouts for 7 days  
**Expected:** Score = 68 − 14 = 54 baseline before frequency/volume adjustments.

**TC-29-004** · P1 · 4+ sessions/week: +5 bonus  
**Steps:** Log 4 workouts in past 7 days  
**Expected:** Frequency bonus of +5 applied.

**TC-29-005** · P0 · Baseline grows with session history  
**Steps:** 1 session → note baseline. 15 sessions in 30 days → note baseline  
**Expected:** Baseline increases from ~66 toward ~80. Formula: `65 + min(15, count)`.

**TC-29-006** · P1 · Deload detected: +6 bonus when this-week volume < 70% of last  
**Steps:** High volume last week → low volume this week  
**Expected:** Score gets +6 for apparent deload.

**TC-29-007** · P0 · Trend line deterministic (no jitter)  
**Steps:** Open readiness card 5× without logging any workout  
**Expected:** Trend line identical each view. `Double.random` removed.

**TC-29-008** · P1 · Confidence levels  
**Steps:** 0 sessions → Low. 5 sessions → Medium. 10+ sessions → High.  
**Expected:** Confidence badge color matches: Low=red, Medium=orange, High=green.

---

## TS-30: Analytics Engine (INOL, Rep Decay, Efficiency)

**TC-30-001** · P1 · INOL < 0.4 = "Low" zone  
**Manual:** INOL = Σ reps / (100 − intensity%). 2 sets of 5 at 80% = 2×5/(100-80) = 0.5 (Moderate)  
**Steps:** Log very few sets at low % intensity → check INOL zone  
**Expected:** "Low" badge (blue or grey).

**TC-30-002** · P1 · INOL 0.8–1.5 = "Optimal" zone  
**Steps:** Log moderate volume at moderate intensity → check INOL  
**Expected:** Green "Optimal" badge.

**TC-30-003** · P1 · INOL > 2.0 = "Overreaching" zone  
**Steps:** Log very high volume at high intensity  
**Expected:** Red "Overreaching" badge. Coaching note recommends dropping sets.

**TC-30-004** · P1 · Rep decay: negative means reps drop set-to-set  
**Steps:** Log 4 sets: 10, 8, 6, 5 reps (declining)  
**Expected:** `latestRepDecay` is negative. Detail shows "Steep rep drop-off" coaching note if < −3.

**TC-30-005** · P1 · Rep decay near zero → weight too light  
**Steps:** Log 4 sets: all 12 reps (no drop-off)  
**Expected:** Decay near 0. Coaching note: "working weight may be too light."

**TC-30-006** · P1 · Efficiency score: Δe1RM / session_cost  
**Steps:** Log big e1RM gain with low session cost (short, light) → check efficiency  
**Expected:** High efficiency score. Label = "Great".

**TC-30-007** · P1 · Efficiency history quartile label  
**Steps:** Log 8 sessions with varying efficiency → detail → check label  
**Expected:** "Great / Average / Below avg" based on quartile rank within own history.

**TC-30-008** · P0 · Volume: effectiveVolume uses bilateral doubling for dumbbell  
**Steps:** Log DB Bench 30kg × 5 → check session volume  
**Expected:** Volume contribution = `effectiveWeight(30) × 5 = 60 × 5 = 300 kg`. Not 150.

**TC-30-009** · P1 · Plateau detection: < 0.5 kg/wk slope over 4+ sessions  
**Steps:** Log same exercise at same weight 5 times over 4 weeks  
**Expected:** `isPlateau = true`. Progress Trend card shows exercise under "Worth a closer look".

**TC-30-010** · P1 · Category analytics: volume distribution by movement pattern  
**Steps:** Log 60% Push, 30% Pull, 10% Legs over 4 weeks  
**Expected:** CategoryBreakdown shows proportional distribution. Not all equal.

---

## TS-31: Standard Lifts Benchmarks

**TC-31-001** · P0 · Bench tier thresholds (BW-relative)  
**Prereq:** BW = 80kg. Thresholds: Beg=0.80, Int=1.15, Adv=1.60  
**Steps:** Log 88kg × 1 (1.1× BW → just above Beginner, just below Intermediate)  
**Expected:** Tier gauge shows position between Beginner and Intermediate markers.

**TC-31-002** · P0 · Squat threshold: Beg=1.00, Int=1.40, Adv=1.90  
**Steps:** BW=80. Log Squat 120kg × 1 = 1.50× BW  
**Expected:** Gauge shows Intermediate (between 1.40 and 1.90).

**TC-31-003** · P0 · Deadlift threshold: Beg=1.25, Int=1.75, Adv=2.25  
**Steps:** BW=80. Log Deadlift 180kg × 1 = 2.25× BW  
**Expected:** Right at top of Advanced. Elite begins above this.

**TC-31-004** · P0 · OHP threshold: Beg=0.45, Int=0.65, Adv=0.90  
**Steps:** BW=80. Log OHP 55kg × 1 = 0.69× BW  
**Expected:** Intermediate (between 0.65 and 0.90).

**TC-31-005** · P0 · Row threshold: Beg=0.75, Int=1.00, Adv=1.35  
**Steps:** BW=80. Log BB Row 85kg × 1 = 1.06× BW  
**Expected:** Intermediate.

**TC-31-006** · P1 · Dumbbell thresholds differ (per-hand)  
**Steps:** BW=80. Log DB Bench 35kg per-hand × 1. Thresholds: Beg=0.28, Int=0.40, Adv=0.56  
**Expected:** 35/80 = 0.44× BW → Intermediate.

**TC-31-007** · P1 · Lift matching by terms: "Bench Press" matches, "Close Grip Bench" does not  
**Steps:** Log "Close Grip Bench Press" exercise  
**Expected:** Does NOT appear in Standard Lifts Bench tier (rejectTerms includes "close"). Has its own analytics but doesn't pollute benchmark.

**TC-31-008** · P1 · Leg Press threshold: 1.50, 2.25, 3.00  
**Steps:** BW=80. Log Leg Press 200kg × 1 = 2.50× BW  
**Expected:** Advanced (between 2.25 and 3.00).

**TC-31-009** · P1 · Multiple matching sessions: uses peak e1RM  
**Steps:** Log Bench at 100kg (e1RM≈117) then 80kg (e1RM≈93) → check tier  
**Expected:** Tier reflects 117kg peak. Not most recent 93kg.

**TC-31-010** · P2 · "Machine & Cable — varies by machine" note visible  
**Steps:** Progress tab → Standard Lifts → Machine & Cable section  
**Expected:** Note text "Varies by machine — use as a guide" visible below section header.

---
---

# SECTION 9 — UI & VISUAL QUALITY

---

## TS-32: UI & Visual Quality

**TC-32-001** · P1 · Dark mode: all 5 tabs readable  
**Steps:** System → Dark Mode → visit each tab  
**Expected:** No white-on-white or invisible text. All cards have correct backgrounds.

**TC-32-002** · P1 · Light mode: all 5 tabs readable  
**Steps:** Light mode → each tab  
**Expected:** No grey-on-white illegibility.

**TC-32-003** · P0 · Tier gauge labels readable (size 10, primary.opacity(0.75))  
**Steps:** Progress tab → Standard Lifts → gauge → Dark mode  
**Expected:** "Beg / Int / Adv / Elite" labels clearly readable. Not grey blobs.

**TC-32-004** · P1 · Dynamic Type: Accessibility Large  
**Steps:** Settings → Accessibility → Larger Text → max → all tabs  
**Expected:** Text wraps gracefully. No clipping. Cards expand to fit.

**TC-32-005** · P1 · Dynamic Type: Accessibility Small  
**Steps:** Minimum text size → all tabs  
**Expected:** UI remains usable. No layout collapse.

**TC-32-006** · P2 · Exercise card header: name + region + equipment readable  
**Steps:** Active workout with a long exercise name (e.g., "Hammer Strength Incline Chest Press")  
**Expected:** Name wraps or truncates cleanly. Does not overflow card bounds.

**TC-32-007** · P1 · Loading skeleton animates  
**Steps:** Cold launch → Progress tab  
**Expected:** Pulsing opacity animation on placeholder cards.

**TC-32-008** · P1 · Progress bar in guided session advances smoothly  
**Steps:** Guided session: 4 exercises → complete each  
**Expected:** Progress bar transitions from 0→25→50→75→100%. Spring animation.

**TC-32-009** · P2 · Superset connector line visible between linked exercises  
**Steps:** Active workout with A+B superset  
**Expected:** Orange vertical connector line between the two exercise cards.

**TC-32-010** · P2 · PR banner appears and disappears  
**Steps:** Log a new PR  
**Expected:** PR banner slides up from bottom. Disappears after ~3 seconds. Does not block interaction.

**TC-32-011** · P2 · Feel selector emoji: all 4 visible and tappable  
**Steps:** Finish workout → feel selector  
**Expected:** 😫 😐 🙂 💪 all visible at correct sizes. Each tap responds.

**TC-32-012** · P1 · Session Review sheet: scrollable when > 6 exercises  
**Steps:** Log 8 exercises → Finish → Session Review  
**Expected:** Sheet scrolls. All 8 exercises listed. No content cut off.

**TC-32-013** · P2 · Streak badge: flame icon + count visible in header  
**Steps:** 3-day streak → Home  
**Expected:** 🔥 "3d streak" badge with orange background pill. Correctly sized.

**TC-32-014** · P1 · Rest timer banner: transition animation  
**Steps:** Complete set → observe banner appear  
**Expected:** Banner slides up from bottom. `spring(response: 0.4)` animation.

---
---

# SECTION 10 — NAVIGATION & CROSS-TAB

---

## TS-33: Navigation & Cross-Tab Flows

**TC-33-001** · P0 · Tab does not reset to Home on foreground  
**Steps:** Navigate to Insights tab → background → foreground  
**Expected:** Still on Insights tab. No `.onAppear { selectedTab = 0 }`.

**TC-33-002** · P0 · Full new-user journey: onboarding → first workout → progress  
**Steps:** Fresh install → complete onboarding → log full workout → finish → Progress tab  
**Expected:** Workout in log. Home shows Last Workout. Progress begins building.

**TC-33-003** · P1 · Home "Start Workout" → Workout tab  
**Steps:** Today's Plan card → tap Start Workout  
**Expected:** Tab switches to Workout (selectedTab = 1). Active workout starts.

**TC-33-004** · P1 · Analytics insight row → Progress tab  
**Steps:** Home → tap analytics insight row  
**Expected:** Navigates to Progress tab.

**TC-33-005** · P0 · Active workout survives tab switches  
**Steps:** Start workout → switch to Home, Progress, Insights → return to Workout  
**Expected:** Active workout unchanged. All logged sets present.

**TC-33-006** · P1 · Routines sheet: dismiss returns to Workout tab  
**Steps:** Workout tab → Routines → tap Done  
**Expected:** Returns to Workout tab. Not home. Not a blank screen.

**TC-33-007** · P1 · Exercise picker: add exercise → appears in active workout  
**Steps:** Active workout → Add Exercise → pick Pull-Up → dismiss  
**Expected:** Pull-Up card appears at bottom of exercise list.

**TC-33-008** · P1 · Deep navigation: Exercise Detail → dismiss → back to Insights  
**Steps:** Insights → exercise → detail sheet → swipe down  
**Expected:** Returns to Insights list. Scroll position preserved if possible.

**TC-33-009** · P1 · History tap → detail → swipe → history list  
**Steps:** History tab → tap row → detail sheet → swipe dismiss  
**Expected:** Returns to History list. Correct month section still visible.

**TC-33-010** · P2 · Settings changes immediately reflected in Home  
**Steps:** Settings → body weight change → Home  
**Expected:** Any body-weight-dependent content (readiness, if affected) updated.

---
---

# SECTION 11 — EDGE CASES & FAULT TOLERANCE

---

## TS-34: Edge Cases & Fault Tolerance

**TC-34-001** · P0 · Finish workout with zero completed sets  
**Steps:** Start workout → add 2 exercises → complete zero sets → Finish → Review → feel → Save  
**Expected:** Log entry saved. 0 completed sets. No crash. Session Review shows "0 sets / 0 kg".

**TC-34-002** · P0 · Two workouts can't run simultaneously  
**Steps:** Start workout via Routine A → navigate to Home → tap "Start Workout" on Today's Plan  
**Expected:** Either: navigates to existing active workout, or prompts to finish/discard current. No two concurrent `activeWorkout` states.

**TC-34-003** · P1 · Very long exercise name in Active Workout  
**Steps:** Log an exercise with a 60-character name  
**Expected:** Name displays without overflowing card bounds. Truncates with "..." if needed.

**TC-34-004** · P1 · Very long workout name  
**Steps:** Create routine with 80-character name  
**Expected:** Name truncates in tab bar title, history rows, and recap cards. No layout break.

**TC-34-005** · P1 · Progress tab with only isolation exercises  
**Steps:** Log only Bicep Curls and Tricep Pushdowns for 4 weeks  
**Expected:** Standard Lifts card has no entries (or shows "—"). Composite score absent. No crash.

**TC-34-006** · P1 · Exercise added to workout that has no database entry  
**Steps:** Import a workout log containing an exercise UUID not in `store.exercises`  
**Expected:** Exercise loads with stored name. Analytics may be limited but no crash.

**TC-34-007** · P0 · Routine starts on wrong day: no exercises for today  
**Steps:** Routine has exercises only on Friday → start on Tuesday  
**Expected:** Either shows empty set or properly warns "No exercises for today". No crash.

**TC-34-008** · P1 · Log 100 workouts: no performance degradation  
**Steps:** Import or generate 100 workout entries → cold launch  
**Expected:** App launches within 2 seconds. Scrolling smooth. No crash.

**TC-34-009** · P1 · Export → import same data → analytics match  
**Steps:** Export 20 workouts → fresh install → import → wait for analytics → check PSI and tier  
**Expected:** Same tier and PSI as before export. No data loss.

**TC-34-010** · P0 · Body weight changed mid-session: no crash  
**Steps:** Start workout → switch to Settings → change body weight → return to Workout  
**Expected:** No crash. Analytics refresh queued. Workout continues normally.

**TC-34-011** · P1 · Circuit session cancelled mid-way  
**Steps:** Start AMRAP → let it run 2 minutes → tap X to cancel  
**Expected:** Session discarded or saved as partial. No crash. Cardio log not corrupted.

**TC-34-012** · P2 · Scan invalid QR in dark environment  
**Steps:** Try to scan a QR code in low light  
**Expected:** Camera handles low-light gracefully. No crash. Scanning state remains active.

---

## TS-35: Workout Narrative Engine

**TC-35-001** · P0 · Failure set: narrative says "on target"  
**Steps:** Log OHP to failure (few reps, failure flag) → finish → Home Last Workout narrative  
**Expected:** "on target", "pushed to failure", or "solid work" — NOT "missed" or "fell short".

**TC-35-002** · P0 · Bar weight floor: OHP at 0 kg shows 20 kg in narrative  
**Steps:** Log OHP with 0 kg entered → finish → narrative  
**Expected:** Narrative references ≥20 kg. Not "0 kg" or "bar weight".

**TC-35-003** · P1 · Weight increased + hit target: positive narrative  
**Steps:** Previously logged 80kg; this session log 85kg × same reps  
**Expected:** Narrative: "User Increased → Hit Target" tone. Positive phrasing.

**TC-35-004** · P1 · Weight increased + slight miss: acknowledges attempt  
**Steps:** Previously 80kg × 8; this session 85kg × 6 (slight miss on reps)  
**Expected:** Narrative acknowledges heavier weight, slight rep miss. Not purely negative.

**TC-35-005** · P1 · Weight held + reps on target: steady narrative  
**Steps:** Same weight, same reps as last session  
**Expected:** "Held" tone: "consistent execution", "maintaining", etc.

**TC-35-006** · P1 · Weight dropped + completed: "back-off" narrative  
**Steps:** Previous 100kg; this session 90kg, hit all reps  
**Expected:** Narrative reflects intentional back-off or recovery. Not "dropped and failed".

**TC-35-007** · P1 · Weight dropped + still under target reps: honest narrative  
**Steps:** Previous 100kg × 8; this session 90kg × 5 (still short)  
**Expected:** Narrative reflects struggle (droppedStillUnder). Coaching note to re-evaluate.

**TC-35-008** · P1 · Drop set noted in narrative  
**Steps:** Log a set with drop set completed  
**Expected:** Narrative acknowledges intensity technique (drop set). Not omitted.

**TC-35-009** · P1 · First-time exercise: "first session" narrative  
**Steps:** Log an exercise never logged before  
**Expected:** "First Time" history key applied. Narrative says something like "first time logging this".

**TC-35-010** · P2 · Long gap (4+ weeks): narrative notes the return  
**Steps:** Log Bench → skip 5 weeks → log again  
**Expected:** "Long Gap" history key. Narrative: "been a while" or "returning to this".

---
---

# SECTION 12 — REGRESSION

---

## TS-36: Regression — Confirmed Bug Fixes

**TC-36-001** · P0 · Failure sets not called "missed" in narrative  
**Root cause fixed:** `isToFailure` computed before `repOutcome` — overrides to `.onTarget`  
**Steps:** Log any exercise to failure → finish → read narrative  
**Expected:** Never says "missed", "fell short", or negative rep language for failure sets.

**TC-36-002** · P0 · Bar weight shown as minimum 20 kg, not 0  
**Root cause fixed:** `max(rawWeight, Equipment.barbellBarKg)` in WorkoutNarrativeEngine  
**Steps:** Log barbell exercise with weight = 0 → finish → narrative  
**Expected:** Narrative references ≥20 kg weight. Not "0 kg".

**TC-36-003** · P0 · Composite score card visible in Progress tab  
**Root cause fixed:** `CompositeScoreCard` inserted after `StandardLiftsCard` in ProgressView  
**Steps:** 3+ weeks of Push + Pull + Legs data → Progress tab  
**Expected:** Composite score card appears below Standard Lifts. Not invisible.

**TC-36-004** · P0 · Tier gauge labels readable in dark mode  
**Root cause fixed:** Size 8→10, opacity 0.7→primary.opacity(0.75)  
**Steps:** Dark mode → Progress → Standard Lifts gauge  
**Expected:** "Beg / Int / Adv / Elite" clearly readable. Not faint grey.

**TC-36-005** · P0 · Exercise swap round-trips correctly  
**Root cause fixed:** ExerciseEquivalenceMap wired into swapper  
**Steps:** Swap Barbell Bench → Dumbbell Bench → swap again → select Barbell Bench Press  
**Expected:** Returns to exact "Barbell Bench Press". Not a different barbell chest exercise.

**TC-36-006** · P0 · Bodyweight exercises contribute to PSI  
**Root cause fixed:** `effectiveBestE1RM()` uses BW as load proxy  
**Steps:** BW=80kg → log Pull-Ups only for 3 sessions → PSI chart  
**Expected:** PSI shows non-zero values on session dates. Not flat zero.

**TC-36-007** · P0 · Elite tier scores differentiated (not all 100)  
**Root cause fixed:** Elite range = `advanced × 0.30` (proportional) not `adv − int` (uneven)  
**Steps:** Two elite lifters: one at 2× BW bench, one at 2.5× BW bench  
**Expected:** Different tier scores (e.g., 82 vs 95). Not both 100.

**TC-36-008** · P0 · GuidedWorkoutSessionView saves correct completed sets  
**Root cause fixed:** Removed identical ternary — `ge.completedSets` assigned directly  
**Steps:** Guided session: 2 sets for ex1, 3 sets for ex2 → finish → log  
**Expected:** ex1 has exactly 2 sets, ex2 has exactly 3 in the log.

**TC-36-009** · P0 · Session Review appears before Feel Selector  
**Root cause fixed:** "Finish" now shows `SessionReviewSheet` first  
**Steps:** Active workout → Finish  
**Expected:** Session Summary appears. NOT feel emoji selector appearing directly.

**TC-36-010** · P1 · Tab does not reset to Home on app foreground  
**Root cause fixed:** `.onAppear { selectedTab = 0 }` removed from ContentView  
**Steps:** Navigate to Insights → background → foreground  
**Expected:** Returns to Insights tab.

**TC-36-011** · P1 · Readiness trend stable between renders  
**Root cause fixed:** `Double.random(in: -3...3)` removed from `buildTrend()`  
**Steps:** View readiness chart → navigate away → return × 3  
**Expected:** Trend line identical each time. No jitter.

**TC-36-012** · P0 · Onboarding appears exactly once  
**Root cause fixed:** `hasCompletedOnboarding` AppStorage gates OnboardingView  
**Steps:** Fresh install → complete → kill → relaunch × 3  
**Expected:** Onboarding shown exactly once. Never on relaunch.

**TC-36-013** · P1 · "Insights" tab label (was "Lab")  
**Root cause fixed:** `Label("Insights", ...)` in ContentView  
**Steps:** Tab bar  
**Expected:** Fourth tab reads "Insights". Not "Lab".

**TC-36-014** · P1 · Rest timer setting respected in both session types  
**Root cause fixed:** `@AppStorage("restTimerSeconds")` used in both ActiveWorkoutView and GuidedWorkoutSessionView  
**Steps:** Settings → Rest Timer = 2 min → complete set in regular workout → complete set in guided session  
**Expected:** Both count from 2:00. No hardcoded 90 seconds.

---

## Test Execution Matrix

| Suite | TCs | P0 | P1 | P2 | P3 |
|---|---|---|---|---|---|
| TS-01 Engineering | 8 | 5 | 3 | 0 | 0 |
| TS-02 Architecture | 8 | 4 | 4 | 0 | 0 |
| TS-03 Persistence | 12 | 7 | 5 | 0 | 0 |
| TS-04 Data Validation | 12 | 5 | 5 | 2 | 0 |
| TS-05 Onboarding | 8 | 3 | 3 | 2 | 0 |
| TS-06 Home | 16 | 3 | 7 | 6 | 0 |
| TS-07 Workout Empty | 6 | 0 | 4 | 2 | 0 |
| TS-08 Active Workout Core | 14 | 6 | 6 | 2 | 0 |
| TS-09 Drop Sets & Advanced | 10 | 4 | 5 | 1 | 0 |
| TS-10 Supersets | 8 | 2 | 5 | 1 | 0 |
| TS-11 Rest Timer | 8 | 2 | 5 | 1 | 0 |
| TS-12 Exercise Swapper | 8 | 3 | 5 | 0 | 0 |
| TS-13 Finish Workflow | 10 | 6 | 4 | 0 | 0 |
| TS-14 Routine Management | 14 | 5 | 7 | 2 | 0 |
| TS-15 QR Code | 8 | 3 | 4 | 1 | 0 |
| TS-16 Circuits | 12 | 4 | 6 | 2 | 0 |
| TS-17 Guided Trainer | 12 | 5 | 6 | 1 | 0 |
| TS-18 Progress Tab | 16 | 4 | 8 | 4 | 0 |
| TS-19 Insights Tab | 10 | 1 | 6 | 3 | 0 |
| TS-20 Exercise Detail | 12 | 1 | 8 | 3 | 0 |
| TS-21 History | 6 | 2 | 3 | 1 | 0 |
| TS-22 Settings | 12 | 2 | 7 | 3 | 0 |
| TS-23 Health Integration | 10 | 2 | 6 | 2 | 0 |
| TS-24 Notifications | 6 | 0 | 4 | 2 | 0 |
| TS-25 Apple Watch | 6 | 0 | 1 | 5 | 0 |
| TS-26 e1RM Formulas | 10 | 9 | 1 | 0 | 0 |
| TS-27 PSI & Fiber Index | 8 | 4 | 4 | 0 | 0 |
| TS-28 Composite & Tier | 10 | 7 | 3 | 0 | 0 |
| TS-29 Readiness Engine | 8 | 3 | 5 | 0 | 0 |
| TS-30 Analytics Engine | 10 | 2 | 7 | 1 | 0 |
| TS-31 Standard Lifts | 10 | 5 | 4 | 1 | 0 |
| TS-32 UI & Visual | 14 | 0 | 6 | 8 | 0 |
| TS-33 Navigation | 10 | 3 | 6 | 1 | 0 |
| TS-34 Edge Cases | 12 | 4 | 6 | 2 | 0 |
| TS-35 Narrative Engine | 10 | 3 | 6 | 1 | 0 |
| TS-36 Regression | 14 | 9 | 5 | 0 | 0 |
| **TOTAL** | **337** | **138** | **191** | **57** | **0** |

---

## Ship Gate

1. **All 138 P0 cases must pass.** Zero P0 failures acceptable for any build distributed externally.
2. **All TS-36 regression cases must pass.** These are confirmed previous bugs — a regression on any is an automatic block.
3. **P1 failures must have a documented workaround or be scheduled for the next build.** No open P1s without a ticket.
4. **P2 failures may ship with a filed issue** and milestone assignment.

---

## Execution Order (Recommended)

1. TS-36 (Regression) — run first. If any fail, stop and fix before continuing.
2. TS-01, TS-02, TS-03 (Foundation) — blocks everything else if broken.
3. TS-08, TS-13 (Core logging + finish flow) — primary user loop.
4. TS-26, TS-27, TS-28, TS-29 (Calculations) — correctness of numbers shown to users.
5. TS-05, TS-06 (Onboarding, Home) — first-run experience.
6. TS-14, TS-16, TS-17 (Routines, Circuits, Trainer) — secondary flows.
7. TS-18, TS-19, TS-20 (Analytics UI) — analytics correctness end-to-end.
8. TS-32, TS-33, TS-04 (UI, Navigation, Validation) — polish and edge cases.
9. TS-23, TS-24, TS-25 (Integrations) — device/platform dependent.
