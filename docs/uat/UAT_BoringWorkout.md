# UAT — Boring Workout
**Version:** Post pre-mortem fix session  
**Date:** 2026-05-12  
**Coverage:** Engineering · Architecture · Persistence · Data Validation · Calculations · UI · Flow · Integration · Regression

---

## Severity Key
| Level | Meaning |
|---|---|
| P0 | Blocks shipping. Data loss, crash, wrong number shown to user. |
| P1 | Major UX failure. Feature broken but no data corruption. |
| P2 | Minor annoyance or visual defect. |
| P3 | Edge case or cosmetic. |

---

## TS-01: Engineering & Performance

### TC-0101 — Cold launch time
**Severity:** P1  
**Prereq:** App installed with 50+ workout log entries  
**Steps:**
1. Kill app from app switcher
2. Tap app icon, start a stopwatch

**Expected:** Main UI visible (isLoaded = true) in under 1.5 seconds. No white-screen hang.

---

### TC-0102 — Background thread analytics does not block UI
**Severity:** P0  
**Prereq:** 100+ workouts in log  
**Steps:**
1. Cold launch app
2. Immediately tap Workout tab

**Expected:** Tab responds instantly. Analytics may still be computing (Progress tab shows stale or empty) but UI is not frozen.

---

### TC-0103 — No crash on memory warning
**Severity:** P0  
**Prereq:** Active workout in progress  
**Steps:**
1. Start a workout, log 3 sets
2. In Simulator: Hardware → Simulate Memory Warning

**Expected:** App does not crash. Active workout state is preserved. Logged sets remain.

---

### TC-0104 — App does not crash on repeated background/foreground cycles
**Severity:** P0  
**Steps:**
1. Start a workout
2. Background and foreground the app 10 times rapidly

**Expected:** No crash. Workout state intact each time.

---

### TC-0105 — Analytics refresh does not block main thread
**Severity:** P1  
**Steps:**
1. Finish a workout
2. Immediately scroll the Home tab

**Expected:** Scroll is smooth. UI remains interactive while analytics recompute in background.

---

### TC-0106 — Build succeeds with no warnings on clean build
**Severity:** P0  
**Steps:**
1. `xcodebuild clean build -scheme workout -destination 'platform=iOS Simulator,name=Iphone14p'`

**Expected:** `BUILD SUCCEEDED`. Zero real compiler errors (SourceKit indexing warnings are excluded).

---

## TS-02: Architecture & State Management

### TC-0201 — SeedStore singleton consistent across views
**Severity:** P0  
**Steps:**
1. Log a set in Workout tab
2. Switch to Home tab without finishing workout
3. Switch back to Workout tab

**Expected:** Active workout is unchanged. Same sets visible.

---

### TC-0202 — @Observable triggers UI update on workout finish
**Severity:** P0  
**Steps:**
1. Start and finish a workout
2. Observe Home tab immediately after

**Expected:** "Last Workout" card appears with the just-completed workout. No manual refresh needed.

---

### TC-0203 — lastPerformanceCache is accurate after log update
**Severity:** P0  
**Steps:**
1. Log Barbell Bench Press at 80kg × 5 reps. Finish workout.
2. Start a new workout, add Barbell Bench Press

**Expected:** Set rows pre-fill with 80kg. Not 0, not a previous session's weight if 80kg is newest.

---

### TC-0204 — exerciseHistoryCache caps at 20 sessions
**Severity:** P2  
**Prereq:** Log the same exercise 25 times across 25 workouts  
**Steps:**
1. Open exercise detail / history for that exercise

**Expected:** At most 20 sessions shown. No crash, no memory spike.

---

### TC-0205 — Analytics token cancels stale computation
**Severity:** P1  
**Steps:**
1. Finish workout A (triggers analytics refresh)
2. Immediately finish workout B (triggers second refresh)

**Expected:** Only the result from workout B's analytics is applied to the cache. No race condition where workout A's stale result overwrites B's.

---

### TC-0206 — userProfile.didSet does not fire during load
**Severity:** P0  
**Steps:**
1. Kill app
2. Cold launch — observe Xcode console for premature `refreshAnalytics` calls

**Expected:** `refreshAnalytics()` is NOT called during the background load phase (while `isLoaded == false`). Called exactly once after `isLoaded = true`.

---

### TC-0207 — ExerciseEquivalenceMap reverse index built once
**Severity:** P1  
**Steps:**
1. Open exercise swapper 10 times across different exercises
2. Profile with Instruments (Time Profiler)

**Expected:** No repeated static initialization. `reverseIndex` computation appears once at cold start.

---

## TS-03: Persistence & Data Integrity

### TC-0301 — Workout log survives force quit
**Severity:** P0  
**Steps:**
1. Log a workout with 4 exercises, 3 sets each. Tap Finish.
2. Force quit app via app switcher
3. Relaunch

**Expected:** Workout appears in log with all 4 exercises and 3 sets each. No missing data.

---

### TC-0302 — Partial set data survives force quit
**Severity:** P0  
**Steps:**
1. Log a set with weight = 102.5 kg, reps = 7, toFailure = true
2. Finish workout, force quit, relaunch
3. Check workout log detail

**Expected:** 102.5 kg, 7 reps, toFailure = true all preserved. No rounding to integers, no loss of failure flag.

---

### TC-0303 — UserDefaults keys use versioned names (no silent data loss on schema change)
**Severity:** P1  
**Steps:**
1. Read `SeedStore.swift` keys: `logKey`, `prKey`, `templatesKey`, `userProfileKey`

**Expected:** Keys end in `_v1` (or higher). Changing schema in future will use new key, not silently decode garbage.

---

### TC-0304 — Decoding failure is silent but safe
**Severity:** P0  
**Steps:**
1. Manually corrupt the `workoutLog_v1` key in UserDefaults (via lldb or direct NSUserDefaults edit in Simulator)
2. Relaunch app

**Expected:** App launches with empty log. No crash. No alert. (Silent recovery per `try?` decode pattern.)

---

### TC-0305 — Export JSON contains all fields
**Severity:** P1  
**Steps:**
1. Log a workout with drop sets, RPE, toFailure flags
2. Settings → Export Workouts
3. Open exported JSON in a text editor

**Expected:** JSON contains `dropWeight`, `dropReps`, `toFailure`, `rpe`, `velocityProfile` fields. No fields silently omitted.

---

### TC-0306 — Import merges without duplicating existing workouts
**Severity:** P1  
**Steps:**
1. Export current data (10 workouts)
2. Import the same file
3. Check workout log count

**Expected:** Still 10 workouts. IDs matched — no duplicates created.

---

### TC-0307 — Import rejects malformed JSON gracefully
**Severity:** P0  
**Steps:**
1. Create a `.json` file with content: `{ "broken": true }`
2. Settings → Import Workouts → select that file

**Expected:** Alert "Import Failed — File format not recognized." No crash. Existing data untouched.

---

### TC-0308 — Routines persist across kill cycles
**Severity:** P0  
**Steps:**
1. Create a routine with 5 exercises assigned to Monday/Wednesday
2. Force quit and relaunch

**Expected:** Routine appears unchanged with same exercises and day assignments.

---

### TC-0309 — Body weight persists across kill cycles
**Severity:** P0  
**Steps:**
1. Settings → Body Weight → enter 78.5
2. Force quit and relaunch → check Settings

**Expected:** Shows 78.5. Not nil, not 0.

---

### TC-0310 — Personal records survive force quit
**Severity:** P0  
**Steps:**
1. Log a PR (e.g., Bench Press 100kg × 3 — new all-time best e1RM)
2. Force quit, relaunch, check Progress tab

**Expected:** PR still recorded. Tier thresholds reflect the PR.

---

## TS-04: Data Validation & Input Bounds

### TC-0401 — Weight field: zero is allowed
**Severity:** P1  
**Steps:**
1. During workout, set weight to 0 for a bodyweight exercise
2. Log the set

**Expected:** Set logs successfully. Analytics uses bodyweight as proxy (not 0) for bodyweight equipment.

---

### TC-0402 — Weight field: negative value blocked
**Severity:** P0  
**Steps:**
1. During workout, attempt to type -10 in weight field via text input

**Expected:** Either blocked by keyboard type (no minus key on numpad) or clamped to 0 on confirm. Negative weight never persists to log.

---

### TC-0403 — Weight field: very large value (500+ kg) handled
**Severity:** P1  
**Steps:**
1. Enter 9999 in weight field
2. Log the set and finish workout

**Expected:** No crash. e1RM calculated (will be large but won't cause overflow). Analytics processes without crash.

---

### TC-0404 — Reps field: zero reps prevented in non-failure sets
**Severity:** P1  
**Steps:**
1. During workout, set reps = 0 (no failure toggle)
2. Attempt to complete the set

**Expected:** Set with 0 reps produces e1RM = 0 (guard `r > 0` in `e1RM(weight:reps:)`). Does not crash. Does not contribute to PR.

---

### TC-0405 — Reps field: > 20 reps returns e1RM = 0
**Severity:** P0 (calculation correctness)  
**Steps:**
1. Log a set with 25 reps at any weight
2. Check if a PR is recorded for that exercise

**Expected:** No PR recorded. e1RM = 0 for 25+ reps per `default: return 0` case. Narrative does not claim a new best.

---

### TC-0406 — Body weight field: 0 blocks analytics
**Severity:** P1  
**Steps:**
1. Clear body weight in Settings (set to blank)
2. Check Progress tab

**Expected:** Composite score and tier scores show "Set body weight in Settings" prompt or are hidden. No division-by-zero crash.

---

### TC-0407 — Body weight field: decimal values accepted
**Severity:** P2  
**Steps:**
1. Settings → Body Weight → type 82.3
2. Force quit, relaunch

**Expected:** Shows 82.3, not 82 (not truncated to integer).

---

### TC-0408 — Age field: out of range values do not crash analytics
**Severity:** P1  
**Steps:**
1. Settings → Age → enter 150

**Expected:** Age adjustment factor uses the `60+` tier (0.75 scalar). No crash. Analytics complete.

---

### TC-0409 — Name field: empty name gets default in UI
**Severity:** P2  
**Steps:**
1. Settings → Name → clear to blank

**Expected:** Home tab shows "Good morning,  👋" or falls back to default ("Alex"). Does not show "Good morning, nil 👋" or crash.

---

### TC-0410 — Onboarding: blank name disables Continue
**Severity:** P1  
**Steps:**
1. Fresh install, onboarding page 1
2. Leave name field empty

**Expected:** Continue button is visually disabled and non-tappable.

---

### TC-0411 — Onboarding: non-numeric body weight is ignored, not crash
**Severity:** P0  
**Steps:**
1. Onboarding page 2, type "abc" in body weight field
2. Tap Continue

**Expected:** `Double("abc")` returns nil → body weight not set → proceeds to page 3 with no crash. No corrupted data.

---

## TS-05: Calculations & Analytics

### TC-0501 — e1RM: Epley formula correct (1–10 reps)
**Severity:** P0  
**Manual Calculation:** 100kg × 5 reps → Epley = 100 × (1 + 5/30) = 116.67  
**Steps:**
1. Log Barbell Bench Press: 100 kg × 5 reps
2. Check Progress tab → Standard Lifts → Bench Press e1RM

**Expected:** Shows approximately 116–117 kg. Not 100, not 150.

---

### TC-0502 — e1RM: Mayhew formula used for 11–20 reps
**Severity:** P0  
**Manual Calculation:** 60kg × 15 reps → Mayhew = 60 / (0.522 + 0.419 × e^(−0.055 × 15)) ≈ 60 / 0.695 ≈ 86.3  
**Steps:**
1. Log any exercise: 60 kg × 15 reps
2. Check e1RM shown

**Expected:** ≈ 86 kg. NOT the Epley result (60 × (1 + 15/30) = 90).

---

### TC-0503 — e1RM: zero for > 20 reps
**Severity:** P0  
**Steps:**
1. Log 100 kg × 21 reps
2. Check PR for that exercise

**Expected:** No PR recorded. No e1RM shown. Raw volume (100 × 21 = 2100 kg) may show but not as 1RM.

---

### TC-0504 — e1RM: exact weight for 1 rep
**Severity:** P0  
**Steps:**
1. Log 140 kg × 1 rep on Deadlift

**Expected:** e1RM = 140.0. Not 140 × (1 + 1/30) = 144.67 (would be Epley for 1 rep, but the code uses `case 1: return w`).

---

### TC-0505 — Barbell bar weight floor: 20 kg minimum
**Severity:** P0  
**Steps:**
1. Log Barbell Bench Press with weight = 0 (or leave blank)
2. Complete set with 5 reps

**Expected:** Effective weight = 20 kg (bar weight). `Equipment.effectiveWeight(0)` for `.barbell` = `max(0, 20)` = 20. e1RM ≈ 23.3.

---

### TC-0506 — Dumbbell weight doubles in analytics
**Severity:** P0  
**Manual:** Dumbbell entered as per-hand (e.g., 30kg per hand = 60kg bilateral)  
**Steps:**
1. Log Dumbbell Bench Press: 30 kg (per hand) × 8 reps
2. Check e1RM vs Barbell Bench Press logged at 60kg × 8 reps

**Expected:** Both show approximately same e1RM (~75 kg). Dumbbell's `effectiveWeight(30)` returns 60.

---

### TC-0507 — PSI: bodyweight exercises use body weight as load
**Severity:** P0  
**Steps:**
1. Enter body weight = 80 kg in Settings
2. Log Push-Ups (bodyweight equipment), 3 sets of 15 reps
3. Check PSI chart on Progress tab

**Expected:** PSI moves upward. Not flat/zero as it would be if bodyweight sets were excluded. Pull-Ups, Dips also contribute.

---

### TC-0508 — PSI: zero body weight excludes bodyweight exercises
**Severity:** P1  
**Steps:**
1. Clear body weight (leave blank)
2. Log only Push-Ups

**Expected:** PSI chart shows 0 or no data (cannot compute relative intensity without BW). No crash.

---

### TC-0509 — Composite score: requires Push + Pull + Legs data
**Severity:** P0  
**Steps:**
1. Log only Bench Press and OHP (both Push) for 3 weeks

**Expected:** Composite score card NOT visible in Progress tab (or shows "missing Pull and Legs" message). Coverage gate enforced.

---

### TC-0510 — Composite score: 2/3 PPL coverage caps at Advanced
**Severity:** P0  
**Steps:**
1. Log Push and Pull compound lifts for 3+ weeks. Never log a Legs exercise.

**Expected:** Composite tier shows maximum "Advanced". Never shows "Elite" with 2/3 coverage.

---

### TC-0511 — Composite score: 1/3 PPL coverage caps at Intermediate
**Severity:** P0  
**Steps:**
1. Log only Deadlift (Pull) for 3+ weeks.

**Expected:** Composite tier maximum "Intermediate". Not Advanced or Elite.

---

### TC-0512 — Tier thresholds: Beginner band correct
**Severity:** P0  
**Reference:** tierScore() band: 0–20 = Beginner  
**Steps:**
1. New user, log Bench Press 40 kg × 5 reps, body weight 80 kg
2. Relative strength = e1RM / BW ≈ 46.7 / 80 = 0.58× BW

**Expected:** Shown as Beginner (threshold for Beginner/Intermediate is ~1.0× BW for bench). Gauge fills in lower 0–20 range.

---

### TC-0513 — Tier score: Elite requires all 3 PPL categories
**Severity:** P0  
**Steps:**
1. Log elite-level numbers on Push and Pull. Never log Legs.

**Expected:** Overall tier capped at Advanced. "Elite" only possible with 3/3 PPL coverage.

---

### TC-0514 — relativeStrength uses peakE1RM (not recentE1RM)
**Severity:** P0  
**Steps:**
1. Log Bench Press 100kg × 5 = ~117 e1RM (peak)
2. Next session: log 80kg × 5 = ~93 e1RM (recent, lower)
3. Check tier position

**Expected:** Tier is calculated from the 117 peak, not the 93 recent. User does not appear to drop a tier after a lighter session.

---

### TC-0515 — Readiness score: 2-day rest gives highest recovery bonus
**Severity:** P1  
**Reference:** `case 2: score += 12` in ReadinessEngine  
**Steps:**
1. Log a workout today
2. Simulate 2 days passing (advance system date or use test data)

**Expected:** Readiness score is higher than after 1 day rest (+8) or 4+ days (+−4 penalty).

---

### TC-0516 — Readiness baseline: grows with log history
**Severity:** P1  
**Reference:** `65 + min(15, last30.count)` — max baseline = 80 at 15+ sessions/month  
**Steps:**
1. Log 1 workout → note baseline
2. Log 15 workouts in 30 days → note baseline

**Expected:** Baseline increases from ~66 (1 session) toward ~80 (15+ sessions). Delta displayed reflects this.

---

### TC-0517 — Readiness trend is deterministic (no jitter)
**Severity:** P1  
**Steps:**
1. Open Home tab, view Readiness chart
2. Navigate away and back 5 times

**Expected:** Trend line is identical each time. No random variation (Double.random removed).

---

### TC-0518 — Volume calculation: weight × reps summed across exercises
**Severity:** P0  
**Steps:**
1. Log: Bench 100kg × 5 = 500, Squat 120kg × 3 = 360, Row 80kg × 8 = 640
2. Check "Session Summary" volume on finish sheet

**Expected:** Total = 1,500 kg. Tolerance ±1 due to display rounding.

---

### TC-0519 — Drop set volume included in total
**Severity:** P1  
**Steps:**
1. Log a set: 100kg × 5 + drop to 80kg × 8
2. Check session volume

**Expected:** Volume includes both: 100×5 + 80×8 = 1,140 kg for that set.

---

### TC-0520 — PSI trend: OLS slope direction matches training reality
**Severity:** P1  
**Steps:**
1. Log progressively heavier workouts over 6 weeks
2. Check PSI trend % per week

**Expected:** Positive %. Not negative or zero when weights clearly increased.

---

### TC-0521 — Age adjustment applied to tier thresholds
**Severity:** P1  
**Reference:** <40→1.0, 40s→0.93, 50s→0.85, 60+→0.75  
**Steps:**
1. Set age = 55, body weight = 80 kg, log Bench 80kg × 5 (e1RM ≈ 93kg, 1.16× BW)
2. Note tier
3. Change age to 30, check tier

**Expected:** At age 55 (0.85 scalar), thresholds are lower → user is a higher tier than at age 30. Same lifts, different tier classification.

---

## TS-06: UI & Visual Quality

### TC-0601 — Dark mode: all screens readable
**Severity:** P1  
**Steps:**
1. Settings → Display & Brightness → Dark
2. Visit every tab: Home, Workout, Progress, Insights, Settings

**Expected:** No white text on white background. No invisible cards. Tier gauge labels visible.

---

### TC-0602 — Light mode: all screens readable
**Severity:** P1  
**Steps:** Same as TC-0601 in Light mode

**Expected:** No grey-on-white illegibility. No invisible elements.

---

### TC-0603 — Tier gauge labels: readable at size 10 font
**Severity:** P1  
**Reference:** Labels set to `.system(size: 10, weight: .semibold)` and `.primary.opacity(0.75)`  
**Steps:**
1. Progress tab, Standard Lifts card, view tier gauge

**Expected:** "Beg", "Int", "Adv", "Elite" labels are readable in both light and dark mode. Not grey blobs.

---

### TC-0604 — Dynamic Type: Large Accessibility size does not break layout
**Severity:** P2  
**Steps:**
1. Settings → Accessibility → Display & Text Size → Larger Text → max
2. Visit Home, Workout, Progress tabs

**Expected:** Text wraps gracefully. No text clipped. No overlapping elements. Scrollable where needed.

---

### TC-0605 — Empty state: no workouts logged
**Severity:** P1  
**Steps:**
1. Fresh install or clear all data
2. Visit Progress tab, Home tab

**Expected:** 
- Home: shows "Readiness" card, no "Last Workout" section, no crash
- Progress: shows empty state or "Log workouts to see your progress" message. No crash.

---

### TC-0606 — Empty state: no routines
**Severity:** P1  
**Steps:**
1. Delete all routines
2. Visit Workout tab

**Expected:** Shows "No routines yet" with "Create Routine" button. No crash. "My Routines" section hidden.

---

### TC-0607 — Streak badge: appears at 2+ consecutive days
**Severity:** P2  
**Steps:**
1. Log workouts on 2 consecutive calendar days

**Expected:** Flame badge appears in Home header with "2d streak". Not shown after only 1 workout.

---

### TC-0608 — Streak badge: hidden at exactly 1 session
**Severity:** P2  
**Steps:**
1. Only one workout ever logged (1-day streak)

**Expected:** No flame badge. `currentStreak > 1` guard hides it.

---

### TC-0609 — Composite score card visible after PPL coverage achieved
**Severity:** P0  
**Steps:**
1. Log Push, Pull, and Legs compound exercises over 3+ weeks
2. Open Progress tab

**Expected:** Composite score card visible between Standard Lifts and next section. Shows score 0–100 and tier.

---

### TC-0610 — Session Review sheet layout: all exercises visible
**Severity:** P1  
**Steps:**
1. Log 8 exercises in one workout
2. Tap Finish → view Session Summary

**Expected:** All 8 exercises listed. Sheet is scrollable. No exercises missing.

---

### TC-0611 — Feel selector: 4 emoji options all tappable
**Severity:** P1  
**Steps:**
1. Finish workout → Session Summary → Done → Feel selector
2. Tap each emoji option (😫😐🙂💪)

**Expected:** Each tap dismisses sheet and saves feel rating. No option is invisible or clipped.

---

### TC-0612 — Rest timer: color states correct
**Severity:** P2  
**Reference:** green >30s, orange >10s, red ≤10s  
**Steps:**
1. Complete a set. Watch rest timer count down.

**Expected:**
- 90s–31s: green text
- 30s–11s: orange text  
- 10s–0s: red text

---

### TC-0613 — Progress bar in guided session advances by exercise
**Severity:** P2  
**Steps:**
1. Start guided session with 4 exercises
2. Complete all sets for exercise 1

**Expected:** Progress bar advances to 1/4. Does not jump to 2/4 until exercise 2 starts.

---

## TS-07: Navigation & Flow

### TC-0701 — Onboarding → first workout → Progress: full new-user journey
**Severity:** P0  
**Steps:**
1. Fresh install
2. Complete onboarding (enter name + body weight)
3. Workout tab → Start Workout → add Bench, Squat, Row → log 3 sets each → Finish → Review → Feel → Save
4. Progress tab

**Expected:** Workout appears in log. Home shows Last Workout. Progress tab begins showing data.

---

### TC-0702 — Tab does not reset to Home on background/foreground
**Severity:** P1  
**Steps:**
1. Navigate to Insights tab
2. Background the app (press Home or swipe up)
3. Return to app

**Expected:** Still on Insights tab. `.onAppear { selectedTab = 0 }` is removed.

---

### TC-0703 — Session Review → Feel → Save: full finish flow
**Severity:** P0  
**Steps:**
1. Active workout with 3 exercises logged
2. Toolbar: Finish
3. Session Summary sheet appears → tap Done
4. Feel selector appears → tap 🙂
5. Check workout log

**Expected:** Workout saved with feel = .good. Review showed correct summary before feel.

---

### TC-0704 — Session Review → Skip Feel
**Severity:** P1  
**Steps:**
1. Finish workout → Session Summary → Done → Feel selector → Skip

**Expected:** Workout saved with feel = nil. No crash.

---

### TC-0705 — Discard confirmation prevents accidental loss
**Severity:** P0  
**Steps:**
1. Active workout with 5 logged sets
2. Toolbar: Discard
3. Alert appears → tap Cancel

**Expected:** Workout still active. All 5 sets intact.

---

### TC-0706 — Discard confirmed: workout gone
**Severity:** P0  
**Steps:**
1. Active workout
2. Toolbar: Discard → tap Discard in alert

**Expected:** Active workout cleared. Workout tab shows empty state. Nothing saved to log.

---

### TC-0707 — Exercise swap flow: equivalence group scoped
**Severity:** P0  
**Steps:**
1. During workout, tap swap on Barbell Bench Press
2. Review exercise list

**Expected:** Only: Dumbbell Bench Press, Chest Press Machine, Smith Machine Bench Press, Hammer Strength Chest Press. NOT: Incline Press, Cable Fly, Dips, etc.

---

### TC-0708 — Exercise swap: round-trip returns to original
**Severity:** P0  
**Steps:**
1. Swap Barbell Bench → Dumbbell Bench
2. Swap again from within workout

**Expected:** "Barbell Bench Press" is visible and selectable. Selecting it returns to exact original exercise.

---

### TC-0709 — Routine creation: exercises assigned to specific days
**Severity:** P1  
**Steps:**
1. Manage Routines → New Routine → Add exercises → assign Bench/OHP to Monday/Wednesday, Squat/Deadlift to Friday
2. Save. Return to Workout tab on a Monday.

**Expected:** "Today" section shows Bench and OHP only. Squat/Deadlift not shown.

---

### TC-0710 — Start workout from routine: correct exercises loaded
**Severity:** P0  
**Steps:**
1. Routine with 5 exercises on Tuesday
2. Tap "Start Workout" from Today's Plan card

**Expected:** Active workout contains exactly those 5 exercises with weights pre-filled from last performance.

---

### TC-0711 — Guided session: sets save correctly to log
**Severity:** P0  
**Steps:**
1. Guided session (Trainer tab): 3 exercises, log 2 of 3 planned sets each
2. Tap Finish → Save

**Expected:** Log entry shows 3 exercises × 2 completed sets each (6 total). Not 0. Not 3 (planned) sets.

---

### TC-0712 — Rest timer setting: guided + regular session both respect it
**Severity:** P1  
**Steps:**
1. Settings → Workout → Rest Timer → 3 min
2. Complete a set in regular workout (ActiveWorkoutView) → confirm 3:00 timer
3. Complete a set in guided session (GuidedWorkoutSessionView) → confirm 3:00 timer

**Expected:** Both use 3 minutes. Consistent across both flows.

---

### TC-0713 — Rest timer OFF: no banner appears
**Severity:** P1  
**Steps:**
1. Settings → Rest Timer → Off
2. Complete a set in workout

**Expected:** No rest timer banner appears. No countdown shown.

---

### TC-0714 — Import → merge → no duplicates: full import flow
**Severity:** P1  
**Steps:**
1. Export current data (note workout count)
2. Import the same file via Settings
3. Check workout log count

**Expected:** Count unchanged. IDs matched, no duplication.

---

## TS-08: Integration (HealthKit, Notifications, Watch)

### TC-0801 — HealthKit: body weight syncs to profile
**Severity:** P1  
**Prereq:** HealthKit authorized, body weight logged in Health app  
**Steps:**
1. Open Home tab (triggers `health.requestAndFetch()`)

**Expected:** `store.userProfile.bodyWeightKg` updated to match Health body weight value. Analytics recalculate.

---

### TC-0802 — HealthKit: workout saved after finish
**Severity:** P1  
**Steps:**
1. Finish a workout
2. Open Apple Health app → Browse → Activity → Workouts

**Expected:** Workout appears in Health with correct start time and duration.

---

### TC-0803 — Notification permission: requested on onboarding completion
**Severity:** P1  
**Steps:**
1. Fresh install, complete onboarding page 3, tap "Get Started"

**Expected:** iOS system notification permission alert appears (once only). If user denies, app still functions normally.

---

### TC-0804 — Re-engagement notification: scheduled after workout finish
**Severity:** P2  
**Steps:**
1. Finish a workout
2. In Xcode: Debug → Simulate Background Fetch or check pending notifications via `UNUserNotificationCenter.current().getPendingNotificationRequests`

**Expected:** One pending notification with identifier `re_engagement`, trigger 3 days in future.

---

### TC-0805 — Re-engagement notification: reset on app foreground
**Severity:** P2  
**Steps:**
1. Background app for 10 seconds
2. Return to foreground
3. Check pending notifications

**Expected:** `re_engagement` notification re-scheduled with trigger 3 days from NOW (new timestamp, not original).

---

### TC-0806 — Re-engagement notification: not delivered if app opened within 3 days
**Severity:** P2  
**Steps:**
1. Finish workout (notification scheduled T+3 days)
2. Open app the next day (notification re-scheduled to T+3 from now)
3. Never open app for 3+ days

**Expected:** Notification fires on day 3. (Verify with a 30-second test trigger in DEBUG.)

---

## TS-09: Edge Cases & Error States

### TC-0901 — Two workouts started without finishing first
**Severity:** P0  
**Steps:**
1. Start a workout but do not finish
2. Attempt to start a second workout via a different entry point (e.g., HomeView plan card)

**Expected:** Either: active workout is shown (no second workout started), OR: user prompted to finish/discard current before starting new. No state corruption with two concurrent `activeWorkout` values.

---

### TC-0902 — Finish workout with zero logged sets
**Severity:** P1  
**Steps:**
1. Start workout, add 2 exercises, do NOT log any sets
2. Tap Finish → Session Summary → Done → feel → Save

**Expected:** Workout saved with 0 completed sets. No crash. Log entry shows exercises with no sets marked complete.

---

### TC-0903 — Progress tab with only isolation exercises (no PPL compound lifts)
**Severity:** P1  
**Steps:**
1. Log only Bicep Curls and Tricep Pushdowns for 4 weeks

**Expected:** Standard Lifts card shows no entries (or isolation-only note). Composite score not shown (no PPL compound coverage). No crash.

---

### TC-0904 — Very long exercise name does not break UI
**Severity:** P2  
**Steps:**
1. Create a custom exercise with a 60-character name
2. Log it, view in Home recap and Progress tab

**Expected:** Name truncates with ellipsis or wraps gracefully. No layout breakage, no overflow off screen.

---

### TC-0905 — Log 0 kg bodyweight exercise — PSI uses body weight
**Severity:** P0  
**Steps:**
1. Log Pull-Ups with weight = 0 (pure bodyweight), body weight = 80 kg
2. Check PSI contribution

**Expected:** PSI computed using 80 kg (BW) as load proxy. Not 0. Bodyweight equipment detected.

---

### TC-0906 — Superset: all sets in group complete before rest
**Severity:** P1  
**Steps:**
1. Link Bench Press + Row as superset
2. Complete one set of each

**Expected:** Rest timer fires AFTER both exercises in the pair are done. Not after Bench alone.

---

### TC-0907 — Routine with no exercises assigned to today
**Severity:** P2  
**Steps:**
1. Create routine, assign exercises only to Sunday
2. Open app on a Tuesday

**Expected:** "Today's Plan" section on Home does not show that routine. "My Routines" list still shows it. No crash.

---

### TC-0908 — Export on empty log
**Severity:** P2  
**Steps:**
1. Clear all workouts (or fresh install)
2. Settings → Export Workouts

**Expected:** Exports valid JSON with `"workoutLog": []`. No crash. Share sheet opens.

---

## TS-10: Regression (Specific Bugs Fixed This Session)

### TC-1001 — [REGRESSION] Failure sets not called "missed" in narrative
**Severity:** P0  
**Steps:**
1. Log Overhead Press to failure (no rep count entered, toFailure = true)
2. Finish workout, view narrative on Home "Last Workout" card

**Expected:** Narrative does NOT say "missed" or "fell short". Says something like "solid session" or "on target". `isToFailure` overrides `repOutcome` to `.onTarget`.

---

### TC-1002 — [REGRESSION] Bar weight shown as 20 kg minimum, not 0
**Severity:** P0  
**Steps:**
1. Log Barbell Bench Press with weight = 0 kg (just the bar)
2. Finish, view Home narrative

**Expected:** Narrative mentions approximately 20 kg weight (bar weight), not "0 kg". `max(rawWeight, Equipment.barbellBarKg)` applied.

---

### TC-1003 — [REGRESSION] Composite score card visible in Progress tab
**Severity:** P0  
**Prereq:** 3+ weeks of Push + Pull + Legs compound data  
**Steps:**
1. Open Progress tab

**Expected:** Composite score card visible with 0–100 score and tier. Was previously invisible due to UI wiring bug.

---

### TC-1004 — [REGRESSION] Tier gauge labels readable in dark mode
**Severity:** P0  
**Steps:**
1. Dark mode. Progress tab. Standard Lifts section.

**Expected:** "Beg", "Int", "Adv", "Elite" labels visible. Were previously size-8 grey-on-grey. Now size 10 `.primary.opacity(0.75)`.

---

### TC-1005 — [REGRESSION] Exercise swap returns correct exercise
**Severity:** P0  
**Steps:**
1. Log Barbell Bench Press
2. Swap → Dumbbell Bench Press
3. Swap again → should show Barbell Bench Press as option

**Expected:** "Barbell Bench Press" available. Selecting it returns exactly that exercise. Was previously returning a wrong/different barbell exercise because equivalence map was not used.

---

### TC-1006 — [REGRESSION] Bodyweight exercises contribute to PSI
**Severity:** P0  
**Steps:**
1. Body weight = 80 kg
2. Log only Pull-Ups for 3 sessions

**Expected:** PSI chart shows non-zero values. Was previously 0 because bodyweight exercises were excluded from PSI calculation.

---

### TC-1007 — [REGRESSION] Elite score not uniformly 100
**Severity:** P0  
**Steps:**
1. Log elite-level lifts (e.g., 2× BW bench, 3× BW deadlift)
2. Check Progress → Standard Lifts → tier gauge positions

**Expected:** Scores vary between 80–100 based on actual performance. Were previously all clustering at exactly 100.0 due to elite range calculation error.

---

### TC-1008 — [REGRESSION] GuidedWorkoutSessionView saves correct sets
**Severity:** P0  
**Steps:**
1. Guided session: log 2 sets for exercise 1, 3 sets for exercise 2
2. Finish → save → check workout log

**Expected:** Exercise 1 has 2 completed sets, exercise 2 has 3. Previous bug: identical ternary branches meant the intent to use placeholder sets was never applied (happened to work but was logically wrong — confirmed correct now).

---

### TC-1009 — [REGRESSION] Session review appears before feel selector
**Severity:** P0  
**Steps:**
1. Active workout with logged sets. Tap Finish.

**Expected:** Session Summary sheet appears FIRST (showing duration, sets, volume, exercise list). Tapping Done on that sheet THEN shows feel selector. Previously: feel selector appeared with no session review.

---

### TC-1010 — [REGRESSION] Tab does not reset to Home on foreground
**Severity:** P1  
**Steps:**
1. Navigate to Progress tab
2. Lock screen and unlock (or background and return)

**Expected:** App opens on Progress tab. Previously `.onAppear { selectedTab = 0 }` reset to Home every time.

---

### TC-1011 — [REGRESSION] Readiness trend does not jitter between views
**Severity:** P1  
**Steps:**
1. Home tab → Readiness card → note trend line shape
2. Navigate away and back 3 times

**Expected:** Trend is identical every time. `Double.random(in: -3...3)` removed from `buildTrend()`.

---

### TC-1012 — [REGRESSION] Onboarding appears exactly once
**Severity:** P0  
**Steps:**
1. Fresh install → complete onboarding
2. Kill app, relaunch 3 times

**Expected:** Onboarding never shown again. `hasCompletedOnboarding = true` persists in `@AppStorage`.

---

### TC-1013 — [REGRESSION] "Lab" tab renamed to "Insights"
**Severity:** P2  
**Steps:**
1. Look at tab bar

**Expected:** Fourth tab label reads "Insights". Not "Lab".

---

### TC-1014 — [REGRESSION] Rest timer respects user setting in both session types
**Severity:** P1  
**Steps:**
1. Settings → Rest Timer → 2 min
2. Complete set in regular workout → confirm 2:00 timer
3. Complete set in guided session → confirm 2:00 timer

**Expected:** Both use the same @AppStorage value. No hardcoded 90 seconds.

---

## Test Execution Matrix

| Suite | TC Count | P0 | P1 | P2 | P3 |
|---|---|---|---|---|---|
| TS-01 Engineering | 6 | 3 | 3 | 0 | 0 |
| TS-02 Architecture | 7 | 3 | 4 | 0 | 0 |
| TS-03 Persistence | 10 | 6 | 4 | 0 | 0 |
| TS-04 Data Validation | 11 | 4 | 5 | 2 | 0 |
| TS-05 Calculations | 21 | 9 | 10 | 2 | 0 |
| TS-06 UI & Visual | 13 | 2 | 7 | 4 | 0 |
| TS-07 Navigation & Flow | 14 | 7 | 6 | 1 | 0 |
| TS-08 Integration | 6 | 0 | 3 | 3 | 0 |
| TS-09 Edge Cases | 8 | 2 | 3 | 3 | 0 |
| TS-10 Regression | 14 | 9 | 4 | 1 | 0 |
| **Total** | **110** | **45** | **49** | **16** | **0** |

---

## Ship Gate
App should not ship with any open P0. All TC-10xx regression cases must pass before any build is distributed.
