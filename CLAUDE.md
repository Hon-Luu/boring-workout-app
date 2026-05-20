# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
xcodebuild -scheme workout \
  -destination 'platform=iOS Simulator,arch=arm64,id=3A3A3886-7553-418E-844C-E2DBBE846836' \
  build
```

SourceKit reports false positives for cross-file types (e.g., "Cannot find type X in scope"). Always verify with `xcodebuild` — SourceKit errors alone are not reliable.

---

## Architecture

### Single store: `SeedStore`

`SeedStore` is the sole `@Observable` data store, accessed via `.environment(store)`. It owns all persistent state: `workoutLog`, `exercises`, `routines`, `activeWorkout`, `userProfile`, and several performance caches. `exercises` is a static array built once at init from a compiled exercise database — it never changes at runtime.

### Startup gate: `isLoaded`

On init, SeedStore kicks off a background thread that loads persisted data, builds all caches, and dispatches one batched update to the main thread — then sets `isLoaded = true` last. `ContentView` renders nothing until `isLoaded` is true, preventing mid-state flash.

### Performance caches

Three caches avoid per-render log scans. All are rebuilt together in `refreshAnalytics()` on a background thread:

| Cache | Type | Purpose |
|---|---|---|
| `lastPerformanceCache` | `[UUID: [SetRecord]]` | O(1) lookup of most recent sets per exercise |
| `exerciseHistoryCache` | `[UUID: [(date, sets)]]` | O(1) history per exercise, newest-first, capped at 20 |
| `homeCache` | `HomeCache` | Pre-computed readiness, progressTrend, todayHints, exerciseNotes |

`HomeCache.buildExerciseCaches(log:)` builds both lookup caches in a single O(n_log) pass. `HomeCache.build(log:exercises:routines:)` computes the four HomeView values. Both are called in `refreshAnalytics()` and during background init.

### `refreshAnalytics()` debounce

Uses a token pattern: each call mints a new `UUID` token; the background block only commits its result if the token still matches when it returns to main. This ensures only the last in-flight analytics call is applied.

---

## Key Models (`Models.swift`)

**`Exercise`** — static, immutable. Fields: `id`, `name`, `bodyRegion` (`BodyRegion`), `equipment` (`Equipment`), `isCompound`, `movementPattern` (`MovementPattern`). Exercise identity is UUID-stable.

**`SetRecord`** — mutable per active workout. Key fields beyond weight/reps/target:
- `isDropCompleted` / `dropWeight` / `dropReps` — a drop set appended after the main set
- `toFailure` — set was trained to failure
- `rpe` — Rate of Perceived Exertion (6–10), enables RPE-adjusted e1RM
- `velocityProfile` — Apple Watch rep-detection data

**`WorkoutLogEntry`** — one completed workout session. Contains `exercises: [WorkoutExercise]`, `startedAt`, `name`.

**`WorkoutExercise`** — exercise within a session. Contains `exercise`, `sets: [SetRecord]`, `supersetGroup`, `completedSets` (computed: sets where `isCompleted`).

**`WorkoutTemplate` / `TemplateExercise`** — saved routines. `TemplateExercise` has `assignedDays: [Int]` (weekday indices 1–7).

**e1RM formula routing** in `SetRecord.e1RM(weight:reps:)`: Epley for 2–10 reps, Mayhew for 11–15 reps, exact for 1 rep, 0 (excluded) for >15 reps.

**`Equipment.effectiveWeight(_:)`**: dumbbell entries are per-hand (×2 for bilateral total); barbell floors at bar weight (20 kg).

---

## Tab Structure (`ContentView.swift`)

Six tabs, all mounted at startup (no lazy loading — `@ViewBuilder` closures re-evaluate on every render):

| Tag | View | Role |
|---|---|---|
| 0 | `HomeView` | Dashboard: readiness, today's exercises, progress trend |
| 1 | `TrainerTabView` | AI-generated workout plans, coach notes |
| 2 | `WorkoutTabView` | Active workout logging (`ActiveWorkoutView`) |
| 3 | `ProgressView` | Workout history, streak, PRs |
| 4 | `StrengthLabView` | Strength analytics, decay model, composite score |
| 5 | `SettingsView` | User profile, data management |

---

## Analytics Pipeline

**`StrengthAnalyticsEngine`** — computes `AnalyticsResult` from log + exercises + profile. Handles e1RM progression, volume trends, pattern balance.

**`StrengthScoreEngine`** — per-exercise strength score relative to bodyweight norms.

**`CompositeStrengthEngine`** — aggregates per-exercise scores into a single composite.

**`ReadinessEngine.compute(log:)`** — produces `ReadinessState` (score 0–100, confidence, delta, coachingNote) from recent log. Called once per `refreshAnalytics()` cycle, result stored in `homeCache.readiness`.

**`WorkoutPlanEngine`** — generates `[GuidedWorkoutPlan]` from readiness + last performance. Has a value-type overload (safe for background threads) and a store-based convenience overload that delegates to it.

**Strength decay model** (`StrengthLabView`): `peakE1RM × strengthRetentionFactor(daysSince)` — no decay first 14 days, then −0.7%/day, floor 50%.

---

## Workout Narrative Engine (`WorkoutNarrativeEngine.swift`)

Generates post-set coaching text from `ExerciseAnalysis`. Assembly pulls phrases from `phrase_bank.json` via `pick()`, which rotates through options using UserDefaults to avoid repeats.

**`ExerciseAnalysis`** key fields used for phrase routing:
- `repOutcome` — `RepOutcome` enum (hitAll, missed, exceeded, etc.)
- `weightState` — `WeightState` enum (includes `droppedCompleted`, `droppedStillUnder`)
- `trendKey` — string key into `bank.whats_next`
- `historyKey` — one of `"Normal"`, `"New"`, `"Short Gap"`, `"Long Gap"`, `"Stalled"`
- `hasCompletedDropSet` — true if any set has `isDropCompleted == true`
- `isToFailure` — true if any set has `toFailure == true`

**Phrase bank JSON keys that must stay in sync with engine:**
- `history`: `"Short Gap"`, `"Long Gap"`, `"Stalled"` (engine derives these, JSON must match exactly)
- `weight`: `"Drop Set — Completed"` (10 phrases, IDs 76–85)
- `whats_next`: `"Build From Drop Set|Single"`, `"Use Drop Set Strategy|Single"`
- `connective`: `"To Failure"` (10 phrases, IDs 105–114)

When `historyKey != "Normal"`, `assembleSingle` inserts a history phrase as the first sentence. Drop set modifier replaces the weight slot; to-failure modifier replaces the trend slot.

---

## Equipment Quick-Swap

Two methods on `SeedStore`, split by cost:
- `quickSwapEquipment(for:)` — O(n_exercises), safe to call every render; returns `[Equipment]` variants
- `bestVariant(equipment:matching:)` — O(n_log), called only on tap; returns the best `Exercise` match for the chosen equipment

`EquipmentChipRow` in `ActiveWorkoutView` takes `[Equipment]` (not exercise tuples) and calls `onSelect: (Equipment) -> Void`. The parent resolves the exercise lazily on tap via `bestVariant`.
