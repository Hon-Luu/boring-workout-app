# Boring Workout — User Manual

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Logging a Workout](#logging-a-workout)
3. [Workout Tab](#workout-tab)
4. [Templates & Routines](#templates--routines)
5. [Progress Tab](#progress-tab)
   - [Stats Row](#stats-row)
   - [Activity Strip](#activity-strip)
   - [Strength Curve](#strength-curve)
   - [Category Breakdown](#category-breakdown)
   - [Strength Score](#strength-score)
   - [Progress Tracker](#progress-tracker)
   - [Personal Records](#personal-records)
6. [Exercise Full Analysis](#exercise-full-analysis)
7. [Settings & Body Profile](#settings--body-profile)
8. [History Tab](#history-tab)
9. [How to Get the Most Out of the App](#how-to-get-the-most-out-of-the-app)

---

## Getting Started

Boring Workout is a strength tracking app built around one principle: **show you what's actually happening to your strength, not just log what you lifted**.

When you first open the app:
- Your exercise database is pre-loaded with 70+ exercises across all major muscle groups and equipment types.
- No account, no sync, no subscription. All data stays on your device.
- Log your first workout using the **Workout** tab at the bottom.

**Recommended first steps:**
1. Go to **Settings** and enter your body weight. This unlocks relative strength rankings and the normalized Personal Strength Index.
2. If you have a smart scale, enter body fat %, muscle mass %, and other body composition values. This unlocks additional strength-per-lean-mass metrics.
3. Log 3+ sessions of any exercise before the analytics section becomes meaningful. The app needs at least 3 data points to run trend analysis.

---

## Logging a Workout

### Starting a session

Tap the **Workout** tab. You'll see:
- A **Start Workout** button if no session is active.
- Your **Today's Plan** if you have a routine with exercises assigned to today's day of the week.

You can start a blank workout or start from a routine.

### Adding exercises

Tap **Add Exercise** to search the database. You can filter by:
- Body region (Chest, Back, Shoulders, Arms, Legs, Core)
- Equipment (Barbell, Dumbbell, Cable, Machine, Bodyweight, Kettlebell)
- Compound vs isolation

Once an exercise is added, the app pre-fills sets with your most recent weight and reps for that exercise as targets.

### Logging sets

Each set row shows:
- **Target weight** (grey, from last session)
- **Target reps** (grey, from last session or template)
- **Actual weight** and **actual reps** fields — tap to enter your numbers
- Tap the checkmark to mark the set complete

The app tracks whether you hit, exceeded, or missed your target reps. This feeds into the progression feedback.

### Supersets

Long-press an exercise row and tap **Link as Superset** to pair it with the next exercise. Paired exercises share a letter label (A, B, C...). Tap **Unlink** to separate them.

### Finishing a workout

Tap **Finish Workout**. You'll be asked to rate how the session felt:
- 😴 **Tired** — body wasn't responding, forced the reps
- 💪 **Normal** — standard session
- 🔥 **Strong** — everything clicked, could have done more

This feel rating adjusts the session cost calculation and influences coaching notes. It takes 5 seconds and meaningfully improves the analytics.

After finishing, the app checks for new Personal Records and shows any PRs set during the session.

---

## Workout Tab

The workout tab shows:

**Today's Plan** — exercises from your active routine that are scheduled for today's day of the week. Tap **Start Today's Plan** to pre-populate a workout with those exercises and your previous performance as targets.

**Active Session** — while a workout is in progress, this tab becomes your logging interface. All exercises, sets, and notes are shown here.

**Rest Timer** — tap any completed set to start an optional rest timer. The timer runs in the background and sends a notification when rest is complete.

---

## Templates & Routines

Go to the **Templates** tab to create and manage routines.

### Creating a routine

1. Tap **New Routine**
2. Name it (e.g. "Push Day", "Full Body A")
3. Add exercises
4. For each exercise, set **target sets** and **target reps**
5. Assign **days of the week** — this controls what appears in Today's Plan

### Using a routine

From the Workout tab, tap **Start Today's Plan** to auto-populate a workout from your routine. You can also tap **Start Full Routine** to start all exercises regardless of day assignment.

### Swapping exercises

During an active workout started from a routine, you can swap any exercise for a different one while keeping the same set/rep structure. Long-press the exercise row and tap **Swap Exercise**.

---

## Progress Tab

The analytical core of the app. The Progress tab is a three-layer dashboard — each layer reveals more detail behind the numbers on the layer above.

---

### Layer 0 — Command Center

The top-level screen answers one question at a glance: **"How am I doing right now?"**

**CSS Hero**

The letter grade (S/A/B/C/D/F) and 0–100 score at the top are your **Composite Strength Score (CSS)**. The coaching insight below identifies the most impactful area to address. Your **tier badge** (Developing / Intermediate / Advanced / Elite) reflects relative strength on compound lifts.

**Three Pillar Cards**

Level, Momentum, and Process — each showing its pillar score. **Tap any card** to drill into Layer 1 for that pillar.

**CSS History Chart**

A time-series chart overlaying CSS, Level, and Momentum scores per session. Use it to spot which pillar is diverging from the overall trend.

**Pattern Breakdown**

Four rows — Push, Pull, Legs, Isolation — showing each movement group's Level score, momentum %/wk trend, and a plateau badge if exercises in that group are stalled. **Tap any row** to drill into the Pattern Detail (Layer 1D).

**Activity Strip, Quick Stats, and PRs**

- **Activity Strip** — 30 tiles, one per calendar day, filled = session logged
- **Quick Stats** — sessions, PRs, streak, total volume
- **Personal Records** — collapsible list of best e1RM by body region

---

### Layer 1A — Level Detail

Reached by tapping the **Level** pillar card.

**Score Overview** — shows the exact blend formula with your real numbers (`Level = 0.50 × A + 0.30 × B + 0.20 × C`, or just A if body weight is not in Settings).

**Retention Trend Chart** — four area lines (Push / Pull / Legs / Isolation) showing how each pattern's PCSA-weighted e1RM retention has moved over time.

**Component A — PCSA-Weighted Retention** — table of every exercise: standard retention %, fatigue-adjusted retention %, blended %, and activation weight (AW in cm²). Sorted by AW so the exercises that drive your Level score appear first.

**Component B — PSI Level** — current session PSI as a % of all-time best, in four normalized variants (raw, ÷ body weight, ÷ lean mass, ÷ muscle mass).

**Component C — Relative Strength Anchor** — each compound lift's tier and the mean tier score feeding into C.

**Body Composition** — PSI per lean/muscle mass and strength-to-fat ratio, if smart-scale data is entered.

---

### Layer 1B — Momentum Detail

Reached by tapping the **Momentum** pillar card.

**Score Overview** — tier ceiling, your PSI trend %, and the resulting score with the live formula.

**PSI Trend Chart** — aggregate fiber-load PSI per session with an OLS dashed trend line.

**Stalled Exercises** — orange callout listing any exercises flagged as plateaued (< 0.5 kg/wk over last 4 weeks). Tap one to open the Exercise Detail sheet.

**Per-Exercise Table** — standard %/wk (Std), fatigue-adjusted %/wk (Adj), and individual momentum score for every exercise. Tap any row to open Exercise Detail.

---

### Layer 1C — Process Detail

Reached by tapping the **Process** pillar card.

**Score Overview** — Process score, all three sub-scores (INOL, Efficiency, Rep Decay), and the live blend formula.

**INOL Detail** — horizontal bar chart with a green band marking the optimal zone for your tier. Your tier's centre and zone boundaries are shown at the top.

**Efficiency Detail** — session cost, delta e1RM, and your quartile position vs your own efficiency history.

**Rep Decay Detail** — zone reference table (all five decay zones with their scores), plus each exercise's decay slope and resulting score.

---

### Layer 1D — Pattern Detail

Reached by tapping a row in the **Pattern Breakdown** card.

**Pattern Overview** — Level score, Momentum score, signed %/wk trend, and exercise count for the movement group.

**Fiber Load Trend Chart** — raw PSI for this pattern only (sum of fiber load from exercises in this group), with an OLS trend overlay.

**PCSA-Weighted Level Breakdown** — per-exercise: activation weight (AW cm²), blended e1RM retention (Ret%), and weighted contribution to the pattern's Level score (Wt%).

**Exercise List** — all exercises in this pattern with %/wk trend, INOL, 8-session sparkline, and latest e1RM. Tap any exercise to open the Exercise Detail sheet.

---

### Strength Score — Exact Formulas

The formulas behind Level, Momentum, and Process. The drill-down views in Layers 1A–1C surface all of these calculations with your actual numbers.

#### Composite Strength Score (CSS)

#### Overall — Composite Strength Score (CSS)

The CSS is a single 0–100 score that answers one question: **"How well am I doing at getting stronger right now?"**

> **Important**: CSS is a *self-relative* score — it measures your consistency and training quality against your own history, not against other people. A Developing lifter scoring 75 and an Elite lifter scoring 68 does not mean the Developing lifter is training better in any absolute sense. Use CSS to track your own trajectory over time, not to compare yourself to others. This property was confirmed by Monte Carlo simulation: CSS distributions overlap heavily across experience tiers by design (see Section 29 of CALCULATIONS_REFERENCE.md).

```
CSS = 0.35 × Level + 0.40 × Momentum + 0.25 × Process
```

| Pillar | Weight | What it captures |
|---|---|---|
| **Level** | 35% | Current strength relative to your personal best |
| **Momentum** | 40% | Rate of improvement right now |
| **Process** | 25% | Training quality: stimulus, recovery, efficiency |

**Grade scale:**

| Grade | Score | Meaning |
|---|---|---|
| S | 90–100 | Peak form — everything firing |
| A | 80–89 | Excellent — strong gains, good process |
| B | 70–79 | Good — solid progress |
| C | 60–69 | Average — progress but inconsistent |
| D | 50–59 | Below par — plateau or poor recovery |
| F | < 50 | Strength declining or no training stimulus |

---

**Level — exact formula**

Three components, blended depending on what profile data is available:

*Component A — PCSA-weighted, fatigue-blended retention (always computed)*

For each exercise, the "blended retention" is:
```
blendedRetention = 0.5 × (latest_e1RM / best_e1RM)
                 + 0.5 × (latest_fatigue_adj_e1RM / best_fatigue_adj_e1RM)
```
This is then weighted by the exercise's activation weight — how much total muscle fiber mass it recruits (`Σ EMG% × PCSA per muscle`). A deadlift has ~7× the activation weight of a lateral raise, so losing ground on deadlift counts ~7× more in your Level score.
```
A = Σ_exercises (activationWeight × blendedRetention) / Σ_exercises activationWeight × 100
```

*Component B — PSI level (requires body weight in Settings)*
```
B = (latest_session_PSI / all_time_best_session_PSI) × 100
```

*Component C — Relative strength anchor (requires body weight)*

Maps your tier on each compound lift to a 0–100 scale:
```
tier_anchor = {Developing: 0, Intermediate: 33, Advanced: 67, Elite: 100}
C = mean(tier_anchor) across compound exercises
```

*Final blend:*
```
With body weight:    Level = 0.50 × A + 0.30 × B + 0.20 × C
Without body weight: Level = A
```

A Level above 80 means you're currently at 80%+ of your physiological and strength ceiling (weighted by muscle mass contributed). Below 70 is a genuine signal of detraining or unresolved recovery debt.

---

**Momentum — exact formula**

For each exercise, the best weekly improvement rate is selected (standard OLS vs. fatigue-adjusted OLS trend, last 6 weeks):
```
pct_i    = max(standard_%/week_i, fatigue_adj_%/week_i)
slope    = 50 / ceiling                  ← tier-calibrated
score_i  = clamp(50 + pct_i × slope,  0, 100)
```

The `ceiling` is the %/week rate that maps to score 100 — calibrated to your experience tier:

| Tier | Ceiling | Meaning |
|---|---|---|
| Developing | 3.0%/wk | Adding weight session-to-session is normal |
| Intermediate | 2.0%/wk | Monthly progression cycles |
| Advanced | 1.0%/wk | Mesocycle-level gains |
| Elite | 0.5%/wk | Macrocycle periodization |

At every tier: 0%/week = 50 (flat), −ceiling = 0 (declining), +ceiling = 100 (peak rate). This means an Advanced lifter making +0.8%/wk scores 90 — correctly reflecting excellent progress at that level — rather than scoring 70 (plateau territory) under a universal ceiling.

Weighted by session count so your most-practiced exercises drive the number:
```
Momentum = Σ(score_i × sessions_i) / Σ sessions_i
```

---

**Process — exact formula**

Built from your most recent session only, three sub-scores:

*INOL score (40% of Process)*
```
INOL = Σ_sets [ reps / (100 − weight/e1RM_ref × 100) ]

INOL_score = max(0,  100 − |INOL − centre| × rate)
```
The `centre` and `rate` are calibrated to your experience tier (derived from your relative strength on compound lifts):

| Tier | Centre | Optimal zone | Rate |
|---|---|---|---|
| Developing | 0.60 | 0.40–0.80 | 100 |
| Intermediate | 0.90 | 0.60–1.20 | 67 |
| Advanced | 1.15 | 0.80–1.50 | 57 |
| Elite | 1.50 | 1.00–2.00 | 40 |

Score peaks at your tier's centre and falls symmetrically as you go under or over. Elite lifters tolerate a wider INOL zone — both the centre and tolerance are higher than Prilepin's original table, which was derived from elite Olympic weightlifters.

*Efficiency score (40% of Process)*
```
efficiency_per_session = Δrolling_avg_e1RM / session_cost

Efficiency_score = 90  if this session's efficiency ≥ top 25% of your history
                   60  if ≥ bottom 25%
                   25  if < bottom 25%
```
Requires 4+ sessions to compute; substitutes 50 (neutral) if not yet available.

*Rep Decay score (20% of Process)*
```
rep_decay = OLS slope of (set_index → reps) within the session

Rep_Decay_score = 100  if slope in [−1.5, −0.5]    ← optimal controlled fatigue
                   70  if slope in [−2.5, −1.5]    ← steep but not collapsed
                   65  if slope in [−0.5,  0.0]    ← too consistent, load may be easy
                   40  if slope ≥ 0                 ← ascending / warm-up effect
                   30  if slope < −2.5              ← severe drop-off
```

*Blend:*
```
Process = 0.40 × INOL_score + 0.40 × Efficiency_score + 0.20 × Rep_Decay_score
```

---

The **coaching insight** below the grade badge identifies the weakest pillar and gives one specific, actionable recommendation — a stalled exercise to address, an INOL zone adjustment, or a recovery note.

The **Score History** chart shows CSS per session over time. The historical chart uses a simplified two-pillar version (`0.47 × Level + 0.53 × Momentum`) because per-session Process data is not stored historically; the weights are the full-model 0.35 and 0.40 re-normalised to sum to 1.

The **Process Detail** row shows the three sub-scores numerically. "—" means that metric needs more data (Efficiency needs 4+ sessions; INOL needs at least one session with completed sets).

#### Fiber Index

Shows your **Personal Strength Index (PSI)** — a measure of total muscle fiber work per session, aggregated across all exercises.

**Core equation:**
```
session_PSI = Σ over all exercises and sets:
                (weight / all_time_best_e1RM)^1.8 × reps × activationWeight

activationWeight = Σ_muscles [ EMG%(muscle) × PCSA(muscle) ]
```

The `^1.8` exponent captures the non-linear relationship between load and motor unit recruitment — heavy sets recruit disproportionately more fibers per rep. `PCSA` (Physiological Cross-Sectional Area, cm², from Ward et al. 2009) weights each exercise by the physical size of the muscles it recruits.

**Display modes:**
```
Raw PSI          = session_PSI
÷ Body Weight    = session_PSI / bodyWeight^0.67
÷ Lean Mass      = session_PSI / leanMass^0.67      [requires body fat %]
÷ Muscle Mass    = session_PSI / muscleMass^0.67    [requires muscle mass %]
```

The `^0.67` divisor is the allometric scaling exponent: muscle force scales with cross-sectional area, which scales with mass^(2/3). This removes body-size advantage from the comparison — the same calculation used by DOTS powerlifting coefficients.

A rising PSI means more total muscle work over time. A flat PSI while e1RM is rising means you're getting more efficient (same fiber work, more strength output).

#### Relative Strength

Ranks every exercise you've logged by **e1RM ÷ body weight**, with tier benchmarks specific to each movement pattern.

```
relative_strength = all_time_best_e1RM / body_weight
```

| Tier | Meaning |
|---|---|
| Developing | Below average for recreational lifters |
| Intermediate | Consistent training for 6–18 months |
| Advanced | 2–4 years of focused strength training |
| Elite | Competitive-level relative strength |

**Tier thresholds (e1RM as a multiple of bodyweight):**

| Pattern | Developing | Intermediate | Advanced | Elite |
|---|---|---|---|---|
| Hip Hinge (Deadlift, RDL) | < 1.5× | 1.5–2.25× | 2.25–3.0× | ≥ 3.0× |
| Knee Flexion (Squat, Leg Press) | < 1.25× | 1.25–1.75× | 1.75–2.5× | ≥ 2.5× |
| Horizontal Push (Bench) | < 0.75× | 0.75–1.25× | 1.25–1.75× | ≥ 1.75× |
| Vertical Push (OHP) | < 0.5× | 0.5–0.85× | 0.85–1.15× | ≥ 1.15× |
| Horizontal Pull (Row) | < 0.75× | 0.75–1.15× | 1.15–1.5× | ≥ 1.5× |
| Vertical Pull (Pull-up, Lat Pulldown) | < 0.5× | 0.5–0.85× | 0.85–1.15× | ≥ 1.15× |
| Isolation (Curl, Extension, Raise) | < 0.15× | 0.15–0.3× | 0.3–0.5× | ≥ 0.5× |

The **overall tier badge** is the mean tier score across compound exercises:
```
tier_score = {Developing: 1, Intermediate: 2, Advanced: 3, Elite: 4}
overall = mean(tier_score) across compound lifts
```

Requires body weight entered in Settings.

#### Body Comp

Shows body composition data entered from your smart scale alongside:
- **PSI ÷ Lean Mass^0.67** — fiber output per unit of lean tissue. Rising = improving neural efficiency or muscle quality.
- **PSI ÷ Muscle Mass^0.67** — how hard your skeletal muscle is actually working per session.
- **Fiber Load ÷ Body Fat%** — output relative to fat mass. Rises when you lose fat while maintaining strength, or gain strength while keeping fat stable.

Requires body fat % and/or muscle mass % entered in Settings.

---

### Personal Records

Every exercise's all-time best estimated 1RM, grouped by body region and sorted strongest first, shown in the collapsible PRs section on the command center.

PRs are detected automatically when you finish a workout. If a set's Epley e1RM exceeds the stored PR for that exercise, the new set becomes the record.

Each card shows the actual weight × reps that established the PR, the date, and the estimated 1RM.

---

## Exercise Full Analysis

Tap **Full Analysis** on the Strength Curve card, or tap any exercise name in the progress tracker, to open the full drill-down sheet.

### e1RM Mode Picker

At the top of the strength chart, you can switch between:
- **Standard** — Epley e1RM, the baseline
- **Fatigue-Adj** — fatigue-adjusted e1RM (upscales later sets in a session to recover estimated "rested" capacity)
- **Compare** — shows both on the same chart in blue (standard) and orange (fatigue-adjusted)

The fatigue-adjusted line will always be higher than standard — the gap tells you how much fatigue was affecting your output in each session.

### Stats Row

Under the chart, four key numbers:
- **Trend** — slope in kg/week and %/week from OLS regression
- **Slope** — raw kg/week
- **Best 1RM** — all-time peak (shows fatigue-adjusted peak in Fatigue-Adj mode)
- **Sessions** — total logged sessions for this exercise

### Last Session Metrics

A 2×2 grid showing analysis of your most recent session:

**INOL** — Intensity Number of Lifts. Measures how demanding the session was relative to your max.
```
INOL = Σ_sets [ reps / (100 − weight/e1RM_ref × 100) ]
```
Zones: Low < 0.4, Moderate 0.4–0.8, Optimal 0.8–1.5, Heavy 1.5–2.0, Overreaching > 2.0

**Rep Decay** — OLS slope of reps across sets within the session. Negative = fatiguing (normal). Optimal range: −1.5 to −0.5 reps/set.

**Efficiency** — strength gain per unit of session cost, ranked against your own history.
```
session_cost = feel_multiplier × Σ [ reps × (weight/e1RM_ref)^1.8 × e^(0.08 × set_index) ]
efficiency   = Δ(rolling_avg_e1RM) / session_cost
```
Ranked as Great (top 25%), Average (middle 50%), or Below avg (bottom 25%) vs. your own past sessions.

**Rel. Strength** — e1RM ÷ body weight, with tier label. Requires body weight in Settings.

### Charts

The chart section shows:
- Rolling 5-session average line (smooths out day-to-day variation)
- Individual session dots (each workout)
- PR step-chart (only sessions that set a new all-time max)

### Session Log

Every session listed chronologically, showing the best set, estimated 1RM, and feel rating. In Compare mode, shows both standard and fatigue-adjusted e1RM per row.

---

## Settings & Body Profile

Access via the **Settings** tab (gear icon).

### Name

Your display name used in narrative session summaries.

### Body Measurements

- **Body Weight (kg)** — used for relative strength rankings, normalized PSI, and allometric scaling. Update this whenever your weight changes significantly.
- **Height (cm)** — stored for future BMI and scaling calculations.

### Body Composition (Smart Scale)

Values from a smart scale (e.g. InBody, Tanita, DEXA scan):
- **Body Fat %** — enables lean mass calculation and PSI ÷ lean mass
- **Muscle Mass %** — enables PSI ÷ muscle mass
- **Body Water %** — stored, shown in Body Comp card
- **Bone Mass (kg)** — stored, shown in Body Comp card

Update these whenever you take a new body composition reading. The app does not automatically pull from any scale — enter values manually.

### Data

- **Export Workouts** — exports your full workout log and routines as a JSON file. Use this for backups.
- **Import Workouts** — imports a previously exported file, merging new workouts into your log without duplicating existing ones.

---

## History Tab

Shows your full workout log in reverse chronological order (most recent first).

Each entry shows:
- Workout name and date
- Duration
- Muscle groups trained
- Total volume (kg lifted)
- Feel rating

Tap any entry to expand the full set-by-set breakdown.

---

## How to Get the Most Out of the App

**Watch your Composite Strength Score (CSS) as your primary weekly signal.** It aggregates every metric — if it's rising, you're doing the right things regardless of which individual metric looks off. If it's falling despite consistent training, the coaching insight will tell you exactly which pillar is dragging it down.

**Log the feel rating every session.** It takes 5 seconds and directly improves the session cost calculation, efficiency score, and coaching notes. Without it, every session is treated identically regardless of how you actually felt.

**Log at least 3 sessions of each exercise** before trusting the trend analysis. Two sessions is not enough for a meaningful regression.

**Enter your body weight in Settings.** Almost all normalized metrics require it. If your weight changes significantly, update it — the PSI trend will shift but that's correct.

**Use the Efficiency Score as your primary long-term signal.** A rising efficiency score means you're getting more strength adaptation per unit of fatigue produced — the best possible outcome in strength training.

**Watch the INOL on your main lifts.** If INOL is consistently below 0.4 (Low zone) for a stalled exercise, you're not providing enough stimulus. If it's above 2.0 (Overreaching) and you're not recovering, pull back.

**Trust the stall flag.** The app flags an exercise as stalled only after 3+ sessions in 4 weeks with slope below 0.5 kg/week. By that point, continuing to do the same thing will not produce different results.

**Update body composition data regularly.** If you're running a cut or bulk, your PSI ÷ lean mass and PSI ÷ muscle mass metrics will tell you whether strength is moving in line with body composition changes.

---

*All data is stored locally on your device. Nothing is sent to any server.*

---

## Appendix: Full Calculation Reference

For every formula, constant, derivation, and calibration methodology, see `docs/CALCULATIONS_REFERENCE.md`.

That document covers:
- Complete derivations with worked examples for every metric
- The full PCSA and EMG activation table (70+ exercises)
- Section 28: Constants inventory — which constants are empirically established, which are design judgments, and four calibration methods (Monte Carlo sensitivity, within-session α fitting, predictive cross-validation, Bayesian updating) with the data requirements and expected outcomes for each.
