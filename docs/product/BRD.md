# Business Requirements Document
## Boring Workout — iOS Strength Training App
**Version:** 1.0  
**Date:** April 2026  
**Status:** Draft

---

## 1. Product Overview

Boring Workout is an iOS strength training tracker that eliminates the friction between the gym floor and your data. It combines fast set logging with intelligent session history — showing you exactly what you lifted last time, how it compares to five sessions ago, and whether you're progressing — without requiring a subscription to see your own numbers.

**The core problem it solves:** Existing apps either log sets fast but show no intelligence (Strong), or show intelligence but log slowly (Fitbod). Boring Workout does both.

---

## 2. Business Objectives

| # | Objective | Metric |
|---|-----------|--------|
| B1 | Become the fastest-to-log strength app on iOS | <3 taps to complete a set |
| B2 | Show session-over-session progress without leaving the logging screen | Matrix table visible during active workout |
| B3 | Retain users through visible progress, not social features | 30-day retention via PR streaks and volume charts |
| B4 | Monetise via premium tier without paywalling core logging | Free tier fully functional for basic logging |

---

## 3. User Personas

### P1 — The Consistent Intermediate
- Lifts 3–4x per week, follows a push/pull/legs or upper/lower split
- Tracks weight and reps religiously, cares deeply about progressive overload
- Pain point: has to mentally remember "what did I do last week?" mid-set
- **Needs:** fast logging, instant history, PR tracking

### P2 — The Beginner With a Plan
- 6–18 months lifting, follows a structured program (5/3/1, nSuns, Starting Strength)
- Overwhelmed by complex apps, wants to know what to do today
- Pain point: no guidance on what weight to use or when to increase
- **Needs:** guided workout sessions, target weight suggestions, simple UI

### P3 — The Data-Driven Lifter
- Analyses their training, wants to see volume trends, e1RM curves, and plateaus
- Pain point: most apps bury analytics or require exports to spreadsheets
- **Needs:** per-exercise bar charts, volume comparison, progress dashboard

---

## 4. Functional Requirements

### 4.1 Workout Logging

#### FR-101 — Active Workout Session
- User can start a workout at any time from the Workout tab
- A workout consists of one or more exercises, each with one or more sets
- Session persists if the app is backgrounded or force-closed (auto-save every set)
- User can finish or discard a workout at any time

#### FR-102 — Set Logging Row
Each set row must display, in a single line:

| Column | Content |
|--------|---------|
| Set # | 1, 2, 3… |
| Weight | Editable numeric field (kg or lb) |
| Reps | Fraction display: **actual ÷ target** (see FR-103) |
| Status | Empty circle → tap to mark complete (turns green checkmark) |

- Completing a set starts the rest timer automatically
- Completed sets are visually distinct (green tint, locked from editing)
- Swipe left on a set to delete it

#### FR-103 — Target vs Actual (Numerator / Denominator)
Reps are displayed as a **fraction** throughout the logging screen:

```
  actual
─────────   e.g.   8 / 10
  target
```

- **Denominator (target):** the number of reps prescribed for that set. Source priority:
  1. Reps logged at the same set position in the most recent prior session for that exercise
  2. Programme prescription if a guided plan is active
  3. Blank (user sets it on first-ever log of that exercise)
- **Numerator (actual):** what the user achieved today — editable integer field
- Before a set is logged, the numerator field is empty / zero and the denominator is shown in muted grey
- After completion:
  - Actual = target → fraction shown in green (`10 / 10`)
  - Actual > target → fraction shown in blue + "↑" indicator (`11 / 10 ↑`)
  - Actual < target → fraction shown in orange + "↓" indicator (`8 / 10 ↓`)
- Weight follows the same target/actual pattern: target weight shown in muted text to the left of the editable actual weight field
- Tapping the target (denominator) copies it into the actual (numerator) as a quick-fill

#### FR-104 — Exercise History Matrix (during logging)
When an exercise is expanded during an active workout, a scrollable history panel appears **above** the set rows showing the last 5 sessions as a matrix:

```
Date        Set 1       Set 2       Set 3       Set 4
Apr 11      100×5       100×5       105×4       —
Apr 4       97.5×5      100×5       100×5       —
Mar 28      95×5        97.5×5      97.5×5      —
Mar 21      92.5×5      95×5        95×5        —
Mar 14      90×5        92.5×5      92.5×5      —
```

- Rows = sessions (newest at top), columns = set number
- Cell format: `weight × reps`
- Empty cells (fewer sets logged) show `—`
- The row matching today highlights in blue
- Matrix scrolls horizontally if sets exceed 4 columns
- Matrix is collapsible to save screen space (collapsed by default, expands on tap)

#### FR-105 — Volume Bar Chart (during logging)
Below the history matrix, a horizontal bar chart shows **total volume per session** for the last 5 completed sessions of that exercise plus the current session:

- X-axis: session number (1–6, left = oldest, right = current)
- Y-axis: total volume in kg (weight × reps × sets)
- Current session bar renders in real-time as sets are completed
- Bar colour: grey for past sessions, blue for current
- Tapping a bar shows a tooltip: date + volume + top set
- If volume is up vs session 5 prior: bar label shows "+X kg ↑" in green
- If volume is down: shows "−X kg ↓" in orange

#### FR-106 — Rest Timer
- Starts automatically when a set is marked complete
- Default duration: 90 seconds (configurable per exercise in Settings)
- Displayed as a bottom banner: countdown + progress bar + Skip button
- Banner colour changes: green → orange (≤30s) → red (≤10s)
- Sends a local notification when timer ends (for backgrounded app)
- Haptic feedback at completion

#### FR-107 — Add / Remove Sets
- "Add Set" button below the last set, copies weight and reps from the set above
- Swipe left on any incomplete set to reveal a Delete option
- Minimum 1 set per exercise; cannot delete the last set

#### FR-108 — Exercise Picker
- Search bar (fuzzy match on name)
- Filter chips: body region (Chest / Back / Shoulders / Arms / Legs / Core)
- Filter chips: equipment (Barbell / Dumbbell / Cable / Machine / Bodyweight / Kettlebell)
- Each exercise row shows: name, equipment, PR if one exists
- Tapping adds exercise to the active workout and dismisses the picker
- Multiple exercises can be added in one picker session before dismissing

#### FR-109 — Finish Workout
- "Finish" button in the toolbar
- Confirmation sheet shows: duration, total sets, total volume, any PRs set
- PR detection uses estimated 1RM (Epley formula): `weight × (1 + reps/30)`
- New PRs shown with a trophy icon per exercise
- On confirm: workout saved to history, widgets updated, active state cleared

---

### 4.2 Exercise Database

#### FR-201 — Bundled Database
- Minimum 45 exercises at launch covering all 6 body regions and all 6 equipment types
- Each exercise has: name, body region, primary equipment, compound/isolation flag

#### FR-202 — Exercise Swap
- Any exercise in an active workout or guided plan can be swapped
- Swap sheet shows alternatives for the same body region, filterable by equipment
- Swapping carries over target sets and reps; target weight resets to last performance on replacement exercise

---

### 4.3 Progress & History

#### FR-301 — Workout History List
- All completed workouts shown in reverse chronological order, grouped by month
- Each row shows: workout name, date, duration, total sets, total volume, muscle groups
- Tap to open workout detail view

#### FR-302 — Workout Detail View
- Full breakdown of every exercise: set number, weight, reps, estimated 1RM per set
- Total volume per exercise
- Duration and timestamp

#### FR-303 — PR Board
- One entry per exercise where a PR has been set
- Shows: exercise name, best weight × reps, estimated 1RM, date achieved
- Grouped by body region
- Sorted by estimated 1RM descending within each group

#### FR-304 — Per-Exercise Progress View
- Accessible from the PR board or exercise picker (long press)
- Shows:
  - e1RM line chart over time (all sessions)
  - Volume bar chart over last 12 sessions
  - History matrix (last 10 sessions, same spec as FR-104)
  - Best set ever (weight × reps × date)

---

### 4.4 Health & Readiness Dashboard (Home Tab)

#### FR-401 — Readiness Score
- Computed daily from workout log data (no HealthKit required for base score)
- Score: 0–100 integer
- Inputs: days since last workout, weekly training frequency, volume trend vs prior week
- When HealthKit is authorised: also uses HRV, resting HR, sleep duration, sleep efficiency
- Confidence level: High (≥10 workouts in log + HealthKit data), Medium (≥3 workouts), Low (insufficient data)

#### FR-402 — Dashboard Layout
Matches reference design top-to-bottom:
1. Greeting ("Good morning, [Name]")
2. Headline driven by score ("You're trending upward.")
3. Subtitle ("Your system looks resilient today.")
4. Readiness card: score / 100, confidence badge, "Signals aligned", delta vs 30-day baseline
5. "Today" section: coaching note (2–3 sentences)
6. "Recent Trend" section: 14-day line chart with gradient fill, trend label
7. "What influenced today" section: bullet list of positive/negative factors

#### FR-403 — HealthKit Integration (optional, additive)
- App requests permission on first launch (can be skipped)
- Data read: HRV (SDNN), resting heart rate, sleep duration, sleep efficiency
- Data write: workout duration and active energy (when workout is finished)
- If permission denied: app still works, readiness uses training-log-only model

---

### 4.5 Guided Trainer Tab

#### FR-501 — Workout Plan Generation
- 3 plans generated daily based on readiness score and recent training history
- Plan selection logic:
  - Avoids muscle groups trained in the last 2 sessions
  - Intensity (Light / Moderate / Heavy) maps to readiness score (≥78 = Heavy, 55–77 = Moderate, <55 = Light)
  - Always includes one Active Recovery option regardless of score
- Each plan shows: title, muscle group subtitle, intensity badge, estimated duration, exercise list

#### FR-502 — Swipeable Card Stack
- 3 plan cards visible simultaneously in a Z-stack (card 2 and 3 scaled and offset behind)
- Swipe left to skip (card exits left with rotation)
- Swipe right or tap "Start" to begin (card exits right)
- Background cards animate forward as top card is dragged
- SKIP / START labels fade in on the card edge as drag increases
- Haptic feedback on both actions

#### FR-503 — Plan Preview
- Before starting, a preview sheet shows:
  - Coach note
  - Full exercise list with sets × reps × target weight
  - Swap button per exercise (opens ExerciseSwapper)
  - Cancel or Start buttons

#### FR-504 — Guided Session
- Progress bar: exercise N of total
- Current exercise card: name, set counter, previous performance chip, weight + reps steppers
- "Log Set" CTA
- Completed sets shown as colour-coded chips (weight × reps)
- Rest timer inline (same spec as FR-106)
- "Up Next" list showing remaining exercises
- Finish → saves as a normal WorkoutLogEntry (same history, same PR detection)

---

### 4.6 Apple Watch App

#### FR-601 — Standalone Mode
- Full workout logging without iPhone present
- Exercise list mirrored from last iPhone sync
- Rep counting via accelerometer (motion-based, shows confidence %)
- Saves locally, syncs to iPhone on next connection

#### FR-602 — Paired Mode
- iPhone starts a session → Watch shows current exercise and set
- Watch completion of a set syncs reps + timestamp back to iPhone
- Rest timer shown on both devices
- Skip rest from Watch

---

### 4.7 Widgets

#### FR-701 — Home Screen Widgets (Small / Medium)
| Widget | Content |
|--------|---------|
| Streak | Current day streak + flame icon |
| Last Workout | Workout name + date + top exercise |
| Weekly Volume | Bar chart of volume per day this week |

- Data written to App Group (`group.workout.shared`) on workout finish
- Widgets reload automatically after each workout save

---

### 4.8 Settings

| Setting | Options | Default |
|---------|---------|---------|
| Display name | Text field | "Alex" |
| Weight unit | kg / lb | kg |
| Default rest timer | 60 / 90 / 120 / 180 / Custom | 90s |
| Rest timer sound | Off / Chime / Bell | Chime |
| HealthKit | Authorise / Revoke | Not authorised |
| Data export | CSV / JSON | — |

---

## 5. Non-Functional Requirements

| ID | Requirement |
|----|-------------|
| NF-01 | A set must be loggable in ≤3 taps from an active workout screen |
| NF-02 | History matrix must render in <200ms for 5 sessions |
| NF-03 | App must launch to active workout screen in <1.5s |
| NF-04 | All core features (logging, history, PRs) work fully offline |
| NF-05 | Data persisted to UserDefaults after every set completion (no data loss on crash) |
| NF-06 | Supports iOS 17+ (required for `@Observable` macro and Swift Charts) |
| NF-07 | Supports Dynamic Type (text scales with system font size setting) |

---

## 6. Out of Scope (v1.0)

- Social / friend features, leaderboards, referral codes
- AI form analysis via camera
- Nutrition / macro tracking
- Barcode scanner
- Android
- Gym check-in / location features
- Custom exercise creation by the user
- Data import from Strong / Hevy CSV
- Trainer–client multi-user accounts

---

## 7. Screen Inventory

| Screen | Tab | Trigger |
|--------|-----|---------|
| Home Dashboard | Home | Default |
| Trainer Tab | Trainer | Tab tap |
| Plan Preview Sheet | Trainer | Tap "Start" on card |
| Guided Session | Trainer | Confirm in Plan Preview |
| Workout Tab (empty) | Workout | Tab tap, no active workout |
| Active Workout | Workout | Tap "Start Workout" |
| Exercise Picker Sheet | Workout | Tap "Add Exercise" |
| Exercise Swapper Sheet | Workout / Trainer | Tap swap icon |
| History List | Progress | Tab tap |
| Workout Detail Sheet | Progress | Tap history row |
| PR Board | Progress | Scroll down in Progress tab |
| Per-Exercise Progress | Progress | Long press exercise in PR board |
| Settings | Settings | Tab tap |

---

## 8. Data Model Summary

```
Exercise
  id, name, bodyRegion, equipment, isCompound

SetRecord
  id, weight, reps, isCompleted, completedAt
  → computed: volume, estimated1RM

WorkoutExercise
  id, exercise, sets[], notes
  → computed: totalVolume, completedSets, bestSet

WorkoutLogEntry
  id, startedAt, finishedAt, name, exercises[], notes
  → computed: duration, totalVolume, totalSets, muscleGroups

PersonalRecord
  id, exerciseId, exerciseName, weight, reps, estimated1RM, date

GuidedWorkoutPlan
  id, title, subtitle, bodyRegions[], exercises[], estimatedMinutes, intensity, coachNote

GuidedExercise
  id, exercise, targetSets, targetReps, targetWeight, completedSets[]
```

---

## 9. Open Questions

| # | Question | Owner | Status |
|---|----------|-------|--------|
| Q1 | Weight unit — default kg or lb? Can user change mid-session? | Product | Open |
| Q2 | Should "Target" be user-editable, or always auto-filled from last session? | Product | Open |
| Q3 | Monetisation: which features are premium? | Product | Open |
| Q4 | Is the "5 sessions prior" comparison count fixed or user-configurable? | Product | Open |
| Q5 | Does the matrix table appear inline in the active workout, or as a separate expandable panel? | Product | Open |
| Q6 | Should the guided trainer session log to a separate history category or merge with manual workouts? | Product | Open |
| Q7 | App name: "Boring Workout" confirmed or placeholder? | Product | Open |

---

## 10. Assumptions

- A1: Weight stored internally in kg; display converted to lb if user prefers
- A2: "5 sessions prior" is fixed at 5 for v1.0
- A3: The history matrix column count is capped at the maximum sets logged in any of the 5 sessions shown
- A4: Guided sessions and manual workouts are stored in the same history log and are indistinguishable after saving
- A5: HealthKit is always optional; the app never requires it
- A6: No server or cloud sync in v1.0; data is local only
