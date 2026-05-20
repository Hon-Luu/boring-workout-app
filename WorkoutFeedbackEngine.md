# Workout Feedback Engine

Documents the scoring and decision logic in `WorkoutFeedbackEngine.swift`.

---

## Session Quality Score (0–100)

Computed per exercise per session from `SessionQuality`. Four components:

### 1. Rep Hit Rate — up to 50 pts
```
repHitRate = sets_where_reps >= targetReps / total_sets_with_a_target
contribution = repHitRate * 50
```
Example: hit 3 of 4 target sets → 0.75 × 50 = **37.5 pts**

### 2. Rep Surplus Bonus — up to 25 pts
```
repSurplusAvg = mean(actual_reps - targetReps) across targeted sets
contribution = min(repSurplusAvg / 2.0, 1.0) * 25
```
Caps at an average of +2 extra reps. Example: averaged +1 extra rep → (1/2) × 25 = **12.5 pts**

### 3. Consistency Bonus — up to 15 pts
```
repDecline = (first_set_reps - last_set_reps) / first_set_reps   [clamped ≥ 0]
contribution = (1.0 - min(repDecline, 1.0)) * 15
```
Measures how much reps drop from the first to last set. Example: dropped 10 → 7 reps → decline = 0.30 → (1 - 0.30) × 15 = **10.5 pts**. No drop = full **15 pts**.

### 4. Set Completion Bonus — 0 or 10 pts
```
if all sets completed → +10 pts, else +0
```

### Total
| Component | Max |
|---|---|
| Rep hit rate | 50 |
| Rep surplus | 25 |
| Consistency | 15 |
| Full completion | 10 |
| **Total** | **100** |

---

## Key Definitions

| Term | Definition |
|---|---|
| **Clean session** | `repHitRate >= 1.0` AND all sets completed |
| **Strong session** | Clean AND `repSurplusAvg >= 1.0` (averaged at least +1 rep beyond target) |
| **Struggling** | `repHitRate < 0.75` |
| **Stuck** | `repHitRate >= 0.75` but `< 1.0` |
| **avgRecentScore** | Mean of current session + last 2 sessions' scores |
| **consecutiveClean** | Streak of clean sessions counting backwards from current |
| **consecutiveStruggle** | Streak of struggling sessions in recent history (not including current) |
| **sessionsAtWeight** | Count of recent sessions where weight matches current (within 0.5 kg) |

---

## Per-Exercise Decision Tree

Evaluated in priority order. First matching rule wins (except rep decline, which is additive).

### 1. Deload
**Triggers if:**
- `consecutiveStruggle >= 2`, OR
- `sessionsAtWeight >= 3` AND `avgRecentScore < 45`

**Action:** Recommend dropping to 90% of current weight for 1 session.
```
deload_weight = round(currentWeight * 0.9 / increment) * increment
```

---

### 2. Add Weight Now (Strong Signal)
**Triggers if:**
- Current session is **strong** (clean + surplus ≥ 1 rep avg), AND
- Previous session was also clean, AND
- All sets completed this session

**Action:** Add weight immediately — athlete has outpaced their program.
```
increment = 2.5 kg (compound) | 1.25 kg (isolation)
```

---

### 3. Standard Progression
**Triggers if:**
- `consecutiveClean >= 2`, AND
- `avgRecentScore >= 72`, AND
- All sets completed this session

**Action:** Add weight next session.

---

### 4. Close But Not Ready
**Triggers if:**
- Current session is clean, AND
- `avgRecentScore >= 60` (but below 72 threshold)

**Action:** Hold weight — one more clean session needed.

---

### 5. Stagnation
**Triggers if:**
- `sessionsAtWeight >= 3`, AND
- Current session is clean, AND
- `avgRecentScore < 72`

**Action:** Focus on rep quality and full set completion before progressing.

---

### 6. Struggling This Session
**Triggers if:**
- `repHitRate < 0.75`

**Action:** Hold weight — don't progress until reps are consistently hit.

---

### 7. Rep Decline (additive flag)
**Triggers if:**
- `repDecline > 0.30` AND no other points were generated

**Action:** Flag possible fatigue or form breakdown. No weight recommendation.

---

### 8. Weight Increase Confirmed (additive flag)
**Triggers if:**
- Current weight > last session weight (by > 0.1 kg), AND
- `repHitRate >= 0.85`, AND
- No recommendation already generated

**Action:** Positive flag — progression confirmed.

---

## Whole-Workout Signals

Run after per-exercise analysis on the session as a whole.

| Signal | Threshold | Type |
|---|---|---|
| Volume up vs recent avg | > +12% vs last 3 sessions | Positive |
| Volume down vs recent avg | > -15% vs last 3 sessions | Warning |
| Skipped sets | Any incomplete sets | Warning |

Volume average uses up to the last 3 sessions.

---

## Increment Sizes

| Exercise type | Weight increment |
|---|---|
| Compound (e.g. squat, deadlift, bench) | 2.5 kg |
| Isolation (e.g. curl, lateral raise) | 1.25 kg |

Determined by `Exercise.isCompound`.

---

## Score Thresholds Summary

| Score | Meaning |
|---|---|
| ≥ 72 | Ready to progress |
| 60–71 | Good, needs one more session |
| 45–59 | Needs quality improvement |
| < 45 | Struggling — deload candidate |
