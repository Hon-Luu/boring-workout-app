# Data Model Reference

> For field definitions, always read `Models.swift`. This doc captures non-obvious decisions and invariants.

## Core Types

### WorkoutLogEntry
One completed session.
- `exercises: [WorkoutExercise]`, `startedAt: Date`, `name: String`
- `feelRating: FeelRating?` — post-session subjective (1–5 scale)
- `readinessBefore: Int?` — pre-session subjective (1–3 scale), captured via FeelSelectorSheet

### SetRecord
One set within a session.
- Drop set: `isDropCompleted` + `dropWeight` + `dropReps`
- `toFailure: Bool` — trained to failure
- `rpe: Int?` — Rate of Perceived Exertion (6–10), enables RPE-adjusted e1RM
- `velocityProfile` — Apple Watch rep-detection data

### e1RM Routing (SetRecord)
| Reps | Formula |
|------|---------|
| 1 | Exact weight |
| 2–10 | Epley |
| 11–15 | Mayhew |
| >15 | Excluded (returns 0) |

### Equipment.effectiveWeight
| Equipment | Calculation |
|-----------|-------------|
| Dumbbell | input × 2 (bilateral) |
| Barbell | max(input, 20) — bar weight floor |
| EZ bar | max(input, 10) |
| Assisted pull-up | bodyWeight − counterweight |

## Persistence

All state serialized to JSON in UserDefaults via `SeedStore`. No Core Data, no SQLite.
- Backup: JSON export (all three log types + exercises + routines)
- CSV export: strength + cardio + general sessions (includes feelRating, readinessBefore)

## Caches (SeedStore)

| Cache | Type | Purpose | Rebuilt |
|-------|------|---------|---------|
| `lastPerformanceCache` | `[UUID: [SetRecord]]` | O(1) last sets per exercise | refreshAnalytics() |
| `exerciseHistoryCache` | `[UUID: [(date, sets)]]` | O(1) history per exercise, newest-first, cap 20 | refreshAnalytics() |
| `homeCache` | `HomeCache` | Pre-computed readiness, progressTrend, todayHints, exerciseNotes | refreshAnalytics() |

## Non-obvious Invariants

- `exercises` is static — built once at init from compiled database, never mutated at runtime
- `exerciseHistoryCache` capped at 20 entries per exercise to bound memory
- `refreshAnalytics()` uses token pattern — stale background results are discarded
- `isLoaded` is set last in init — ContentView renders nothing until then
