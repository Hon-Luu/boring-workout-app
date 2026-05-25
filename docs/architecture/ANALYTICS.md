# Analytics Architecture

## Engine Map

| Engine | Input | Output | Where Used |
|--------|-------|--------|------------|
| `ReadinessEngine` | WorkoutLog + HealthKit biometrics | `ReadinessState` (score 0–100) | HomeView |
| `StrengthAnalyticsEngine` | Log + exercises + profile | `AnalyticsResult` | ProgressDashboardViews |
| `StrengthScoreEngine` | Per-exercise history + profile | Score vs BW norms | StrengthLabView |
| `CompositeStrengthEngine` | All exercise scores | Single composite score | StrengthLabView |
| `HONHabitEngine` | All 3 log types | `HONMessage?` | HomeView |
| `EmergentInsightEngine` | All 3 log types | Cross-domain insights | Not yet surfaced in UI — see S3 |
| `WorkoutPlanEngine` | Readiness + last performance | `[GuidedWorkoutPlan]` | TrainerTabView |

## ReadinessEngine — Current Inputs (as of Pass 4)

| Input | Signal | Direction |
|-------|--------|-----------|
| Sleep hours (HealthKit) | Recovery volume | Low → score down |
| Resting HR (HealthKit) | Fatigue marker | High → score down |
| Recent session volume + density | Accumulated load | High → score down |
| Feel ratings (avg last 5 sessions) | Subjective state | Low → score down |
| readinessBefore (avg last 5 sessions) | Pre-session energy | Low → score down |
| Days since last session | Freshness | Very long → score down |
| Weekly session count | Frequency load | High → score down |

## Analytics Gaps (not yet wired)

| Signal | Where | Backlog Item |
|--------|-------|--------------|
| HRV | HealthKit available, not used | 29.5 |
| VO2 Max | Displayed in HealthTrendsView, no insights | 29.3 |
| Body weight trend × strength trend | Correlation not built | 31.1 |
| Sleep trend × strength trend | Correlation not built | 31.2 |
| CardioLogEntry feel rating | Field doesn't exist on model | 30.3 (fixed via S1) |

## Strength Decay Model (StrengthLabView)

`peakE1RM × strengthRetentionFactor(daysSince)`
- 0–14 days: no decay
- 14+ days: −0.7%/day
- Floor: 50% of peak

## HONHabitEngine Message Kinds

`sessionMilestone`, `weeklyCount`, `consecutiveWeeks`, `returnAfterLapse`, `patternFlag`,
`rampDetection`, `driftDetection`, `deloadDetection`, `streakMilestone`, `specialMoment`

Deload messaging is `HONUserType`-aware: `.typeA` gets standard deload copy, `.typeB` gets flexible-trainer copy.
