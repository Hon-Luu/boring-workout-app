# Component Reference

## Chart Infrastructure

### expandingFrame
```swift
.expandingFrame(normal: 260, expanded: 340)
```
Reads `@Environment(\.expandedChart)`. Tap-to-expand is wired in the parent card.

### Side-by-side card pairs
```swift
HStack(alignment: .top, spacing: 12) {
    ChartCardA().expandingFrame(normal: 260, expanded: 340)
    ChartCardB().expandingFrame(normal: 300, expanded: 380)
}
```

## HON Message System

### Flow
1. `HONHabitEngine` — evaluates log, returns `HONMessageKind?`
2. `HONMessageLibrary.pick(kind:phase:userType:context:seed:)` — returns `(message: String, icon: String)?`
3. Displayed in `HONMessageCard` on Home

### Key Enums
- `HONMessageKind`: sessionMilestone, weeklyCount, consecutiveWeeks, returnAfterLapse, patternFlag, rampDetection, driftDetection, deloadDetection, streakMilestone, specialMoment
- `HONUserType`: `.typeA` (consistent/scheduled), `.typeB` (flexible/spontaneous)
- `HONPhase`: onboarding / early / regular / returning

### Deload Messaging
userType-aware — `.typeB` gets "variation is normal" framing, `.typeA` gets standard deload copy.

## Workout Narrative Engine

Source: `WorkoutNarrativeEngine.swift` + `phrase_bank.json`

**Keys that must stay in sync with engine:**
- History: `"Short Gap"`, `"Long Gap"`, `"Stalled"`
- Weight: `"Drop Set — Completed"` (IDs 76–85)
- Whats next: `"Build From Drop Set|Single"`, `"Use Drop Set Strategy|Single"`
- Connective: `"To Failure"` (IDs 105–114)

## Key Sheets

| Sheet | Dismiss behavior | Detents |
|-------|----------------|---------|
| `FeelSelectorSheet` | `.interactiveDismissDisabled(true)` — requires explicit tap | Full |
| `HeatMapDaySheet` | Standard swipe-down | `.fraction(0.45)`, `.medium` |
| `ExerciseDetailSheet` | Standard swipe-down | Full |

## Home Tab Cards (order)

1. Readiness card (always shown once data exists)
2. WelcomeBackCard (return after lapse)
3. HONMessageCard (habit milestone)
4. BeginnerProgressCard (sessions < 10)
5. Apple Health connect (if not authorized)
6. StreakHeatMap
7. Today's exercises / guided plan
8. Progress trend

## StreakHeatMap

- Cells are tappable — opens `HeatMapDaySheet` for that day
- Rest days shown with distinct fill (stored in `store.restDays: [Date]`)
- Identified with `HeatMapDayKey: Identifiable` wrapper (holds date + UUID)

## Readiness Score Thresholds

| Range | Color | Message |
|-------|-------|---------|
| < 40 | negative (rose) | Rest recommendation |
| 40–65 | warning (amber) | Train moderately |
| 66–85 | positive (sage) | Train |
| 86+ | positive (sage) | Peak condition |
