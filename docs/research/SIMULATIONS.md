# Simulation Scenarios

Run a screenshot: `hon-simulate <scenario-name>`
Screenshots saved to: `docs/screenshots/`

---

## Scenario Library

### New User
| Scenario | Description | What to check |
|----------|-------------|---------------|
| `new-day1` | Day 1, onboarding complete, no sessions | Empty state on Home, onboarding CTA |
| `new-day3` | 2 sessions logged | BeginnerProgressCard visible, no readiness data |
| `new-session10` | Session 10 milestone | Milestone message fires, BeginnerProgressCard graduates |

### Returning After Lapse
| Scenario | Description | What to check |
|----------|-------------|---------------|
| `return-14d` | 14 days gone, first return | returnAfterLapse message, WelcomeBackCard |
| `return-45d` | 45 days gone, first return | "deload return" message, intensity warning |
| `return-90d` | 90+ days gone, first return | "new foundation phase" message |

### Active Trainer
| Scenario | Description | What to check |
|----------|-------------|---------------|
| `active-3x` | 3 sessions/week consistently | Standard Home state, progressTrend positive |
| `active-ramp` | 5 sessions this week (above avg) | rampDetection message fires |
| `active-deload` | 1 session after 4x weeks | deloadDetection fires, userType-aware message |

### Analytics Milestones
| Scenario | Description | What to check |
|----------|-------------|---------------|
| `milestone-10` | Session 10 | Trophy message |
| `milestone-100` | Session 100 | Rosette message |
| `milestone-365` | Session 365 | Crown message |
| `streak-7d` | 7-day consecutive streak | Flame message |
| `streak-30d` | 30-day streak | Flame-fill message |

### Edge Cases
| Scenario | Description | What to check |
|----------|-------------|---------------|
| `edge-zero-bw` | Body weight not set | "Set body weight" prompt, no crash |
| `edge-low-readiness` | Readiness < 40 | Red card, rest recommendation |
| `edge-no-health` | HealthKit not authorized | Graceful fallback, no nil crash |
| `edge-empty-log` | No sessions ever | All empty states correct |

---

## Screenshot Archive

Path: `docs/screenshots/<scenario>_YYYYMMDD_HHmmss.png`

Run `ls docs/screenshots/` to see what's been captured.
