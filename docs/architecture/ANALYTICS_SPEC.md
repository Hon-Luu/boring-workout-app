# Analytics Engine — Design Specification

## Overview

The analytics system is a pure computation layer (`StrengthAnalyticsEngine`) that transforms raw `WorkoutLogEntry` data into actionable training metrics. All computation is deterministic and side-effect-free; results are cached on `SeedStore.analyticsCache` and refreshed after every finished workout.

---

## Core Model: Session Cost

Every set has a fatigue cost based on intensity and position within the session:

```
set_cost(i) = reps × (weight / ref_e1RM)^1.8 × e^(0.08 × i)
```

- `i` = zero-based set index within the session
- `ref_e1RM` = historical max estimated 1RM across all sessions (stable reference)
- Feel multiplier applied to total: Tired → ×1.20 | Normal → ×1.00 | Strong → ×0.85
- `session_cost = Σ set_cost(i) × feel_multiplier`

## Efficiency Score

```
efficiency = Δe1RM_rolling / session_cost
```

- `Δe1RM_rolling` = last rolling-avg point minus second-to-last
- Positive → gaining strength per cost unit; negative → declining despite effort
- Normalised so units cancel (kg / cost-units)

---

## INOL (Intensity × Number of Lifts)

```
INOL = Σ reps / (100 - intensity%)
```

- `intensity% = weight / ref_e1RM × 100`, capped at 97.5 to prevent division by zero
- Zones:
  | Range | Label | Meaning |
  |-------|-------|---------|
  | < 0.4 | Insufficient | Volume too low for adaptation |
  | 0.4–0.79 | Moderate | Light day / deload territory |
  | 0.8–1.49 | Optimal | Target training stimulus |
  | 1.5–1.99 | Heavy | High-load day; watch recovery |
  | ≥ 2.0 | Overreaching | Reduce before next session |

---

## Rep Decay Slope

Linear regression of `reps ~ set_index` within one session. A negative slope means reps fall as fatigue accumulates — desirable (working close to failure). Near-zero means the sets weren't challenging enough.

```
slope = OLS([(i, reps_i)])   for all completed sets in the last session
```

---

## Relative Strength

```
relative_strength = PR_e1RM / bodyweight_kg
```

Bodyweight sourced from HealthKit (`HKQuantityType(.bodyMass)`, most recent sample). Nil if HealthKit permission not granted or no sample available.

---

## Session Feel (Calibration)

One-tap post-workout rating. Adjusts the perceived session cost:

| Rating | Multiplier | Rationale |
|--------|-----------|-----------|
| Tired  | 1.20 | Body paid more for the same output |
| Normal | 1.00 | Baseline |
| Strong | 0.85 | Body ran more efficiently today |

Stored on `WorkoutLogEntry.feelRating: FeelRating?`. Optional — nil = not rated (treated as Normal in cost model).

---

## Build Order

1. **Rep decay slope** — zero new inputs; surfaces fatigue pattern per exercise
2. **INOL** — zero new inputs; training load gauge per session
3. **Session feel** — one-tap UI; calibrates cost model
4. **Per-set cost + Efficiency Score** — depends on feel; unlocks the core metric
5. **Relative strength** — HealthKit bodyMass; adds normalization across bodyweight changes
6. **Set timer** — deferred; `SetRecord.completedAt` is a partial proxy already

---

## Data Flow

```
WorkoutLogEntry[]
    └─ StrengthAnalyticsEngine.compute(log:exercises:)
            ├─ per-exercise: SessionPoint[], PRPoint[], rolling avg, regression, INOL, rep decay, cost, efficiency
            └─ per-category: volume, improvement rate, efficiency quadrant
                    └─ AnalyticsResult → SeedStore.analyticsCache
                            ├─ ExerciseDetailSheet (drill-down)
                            ├─ CategoryBreakdownView (patterns tab)
                            └─ HomeView (top insight)
```
