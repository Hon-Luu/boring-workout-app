# H.O.N. Backlog

*Last updated: 2026-05-25 — All 26 F-items + P1/P2 items implemented.*

Use `hon-status` in terminal for a quick summary. Use `hon-dashboard-gen` to refresh the HTML dashboard.

---

## Feedback Wave — 2026-05-25 (26 items)

- [x] **F-01** HOME — Remove "Log Activity" quick-action button
- [x] **F-02** HOME — Health tiles (HRV, RHR, steps, cal) above routine; add weekly minutes WTD-WoW + MTD-MoM; all tiles same height/width
- [x] **F-03** HOME — Remove Coach card (ReadinessCoachCard)
- [x] **F-04** HOME — Program calibration: show specific experience that triggered it + success %
- [x] **F-05** HOME — Activity heatmap: full card width, M–S day labels, clear label for what it tracks
- [x] **F-06** HOME — Last session card: fill empty space with more data (sets, volume, feel, top lift)
- [x] **F-07** WORKOUT — Remove circuit routine listing from routine card (attached circuits section removed)
- [x] **F-08** PROGRESS — Strength score: label trend clearly (WoW delta shown explicitly)
- [x] **F-09** PROGRESS — Score 61/100: prove it — cite specific exercises + logging gaps; score history needs Y-axis + insight callout; Level/Momentum/Process pillars each need a data-backed reason, not just a label
- [x] **F-10** HOME — Best Week Blueprint: move card to Home page (remove from Progress)
- [x] **F-11** PROGRESS — Movement Pattern Strength expanded view: add WoW trends, insight text, per-pattern coaching
- [x] **F-12** PROGRESS — Development Tier: FAST/STALLED labels too large, reduce font size
- [x] **F-13** PROGRESS — Momentum detail: pressing shows nothing / only one exercise — fix sheet and broaden to all tracked exercises
- [x] **F-14** PROGRESS — INOL: condense to last-2-weeks only on card; tap into full list; or filter to compound movements only
- [x] **F-15** PROGRESS — Plateau risk: show specific numbers (last weight, sessions since PR, delta %)
- [x] **F-16** PROGRESS — Volume balance: add data-driven insight on tap, not just expansion
- [x] **F-17** PROGRESS — Rep range distribution: box height must match Volume Balance; add insights on tap
- [x] **F-18** PROGRESS — Session density: surface additional metrics (time of day patterns, session gap trend, streak)
- [x] **F-19** PROGRESS — Volume heatmap: show legend on the card itself, not only when tapped
- [x] **F-20** PROGRESS — Training load (INOL): make it actionable — add plain-English recommendation based on zone
- [x] **F-21** PROGRESS — Cardio performance: add VO2 max, HR zones, avg pace trend, cardio INOL
- [x] **F-22** PROGRESS — Recovery signals: tap shows historical trend, not just current value
- [x] **F-23** PROGRESS — Feel × Session: explain purpose + add actionable takeaway (e.g. "you perform best after 7h sleep")
- [x] **F-24** PROGRESS — Emerging insights: prove each claim with specific logged data + quantified evidence, no generic text
- [x] **F-25** INSIGHTS — Remove "Next Milestone" card
- [x] **F-26** INSIGHTS — Show every derived metric (PSI, INOL, rep decay, efficiency score, fatigue-adjusted e1RM, body comp ratios, CSS pillars) — nothing hidden

---

## P1 — High Value (Build Next)

- [x] **S3** — EmergentInsightCard on Home: rotate 1 cross-domain insight/day (persisted so it doesn't change mid-session)
- [x] **S4** — Best Week Blueprint: analyze historical data, surface the user's best-performing week pattern as a repeatable target
- [x] **V7** — INOL/PSI tap-to-explain in Expert mode (InfoButton on every metric card)

## P2 — Polish & Correctness

- [x] **18.2** — Hardcoded absolute font sizes: targeted fixes (WelcomeBackCard header → .headline; recommendation text → .caption2)
- [x] **19.1** — HONTheme.accent (#D4943A) on background (#1C1C1E) = 6.25:1 contrast — passes WCAG AA (4.5:1 required)
- [x] **22.4** — Training location selector (Gym / Home / Both) added to onboarding Page 1; stored in AppStorage("trainingLocation")
- [x] **V4** — CSV export now includes per-session Sleep_hrs, HRV_ms, RestingHR_bpm from 90-day HealthKit histories (date-matched)
- [x] **21.5** — HON message library voice tone reviewed and micro-fixes applied (weeklyCount case 2, specialMoment pool expanded)

## P3 — Long-term / Design Decisions (deferred)

- [ ] **S1** — ActivitySession protocol: unified interface for strength/cardio/general — enables EmergentInsightEngine to detect cross-modality feel patterns — ~6h refactor
- [ ] **S2** — Recovery Score card on Home alongside Readiness (separate concept: can-I-perform vs. am-I-recovered)
- [ ] **6.5** — No HealthKit permission request during onboarding (intentional — post-onboarding card is the design decision; revisit if adoption is low)
- [ ] **16.1** — Home can show 8+ cards simultaneously (design decision: intentional scroll; revisit if user research shows overwhelm)

## Analytics Gaps (not yet wired)

- [ ] **29.3** — VO2 Max displayed but generates no training insights
- [ ] **29.5** — HRV available in HealthKit but not used in any calculation
- [ ] **31.1** — Body weight changes vs. strength changes not correlated
- [ ] **31.2** — Sleep trend vs. strength trend not connected

---

## Completed ✓

- [x] BLOCK-1 — Sleep hours influence readiness score
- [x] BLOCK-2 — Resting HR influences readiness score
- [x] BLOCK-3 — HONHabitEngine counts all session modalities (strength + cardio + general)
- [x] BLOCK-4 — ExerciseTierGoalBar edge case message fixed
- [x] FIX-1 — generalLog included in JSON backup
- [x] FIX-2 — CSV export includes feelRating and readinessBefore
- [x] FIX-3 — JSON export filename uses yyyy-MM-dd_HH-mm format
- [x] FIX-4 — SettingsView "Body Weight" label is unit-aware
- [x] FIX-5 — WelcomeBackCard shows for all session types
- [x] FIX-6 — StreakHeatMap weekday labels align correctly
- [x] FIX-7 — Onboarding pageReady screen is reachable
- [x] FIX-8 — Apple Health connect prompt added to HomeView
- [x] FIX-9 — CSV export includes cardio and general activity sessions
- [x] FIX-10 — BeginnerProgressCard graduation moment at session 10
- [x] FIX-11 — Readiness coach card notes when sleep data is unavailable
- [x] FIX-12 — Rest days visible in StreakHeatMap
- [x] FIX-13 — First workout celebration persists across crash/force-quit
- [x] WATCH — isPM hardcoded true in DEBUG (4.2)
- [x] WATCH — WelcomeBackCard border too subtle (19.3)
- [x] WATCH — Readiness score has no scale context (V2)
- [x] WATCH — 14-day readiness trend not labeled as estimated (3.2)
- [x] WATCH — No haptic feedback on set completion (20.1)
- [x] WATCH — feelRating added to GeneralActivityEntry (V11 / 25.3)
- [x] WATCH — No deep link from "Set body weight" message to Settings (2.4)
- [x] WATCH — Blank name shows "Good morning, 👋" (6.2)
- [x] WATCH-17.4 — Rest timer haptics at countdown milestones (10s, 5s, 3s, 2s, 1s)
- [x] WATCH-21.4 — FeelSelectorSheet requires explicit action (.interactiveDismissDisabled)
- [x] WATCH-13.2 — Deload messaging is userType-aware (typeA vs typeB)
- [x] WATCH-3.6 — readinessBefore feeds into readiness score and factors
- [x] Pass 4 — Full raw system color sweep (9 files, zero violations remaining)
- [x] Pass 4 — Chart axis font standardization (8pt dashboard, 9pt standalone)
- [x] Pass 4 — HStack alignment fixes for side-by-side chart cards
- [x] Pass 4 — StreakHeatMap cells tappable with day detail sheet
- [x] BLOCK HM-1 — Heatmap: fill full width + add color legend (Less ●●●●● More)
- [x] BLOCK HM-2 — Momentum chip wired to MomentumDetailView sheet
- [x] BLOCK PR-3 — Volume Balance expanded state now adds tonnage labels + period comparison
- [x] FIX HM-3 — TodayPlanCard "Start Workout" button shows routine name
- [x] FIX HM-4 — BeginnerProgressCard / adjacent card height equalized via .frame(maxHeight:.infinity)
- [x] FIX HM-5 — "Building Momentum" label renamed to "Building Your Baseline"
- [x] FIX TR-2 — SwipeableWorkoutCards: drag tint feedback (green right, gray left)
- [x] FIX PR-1 — DashboardHeroCard: shows locked placeholder when < 3 sessions logged
- [x] FIX PR-4 — Rep Range Distribution bars: percentage labels added
- [x] FIX PR-6 — StrengthScoreView: segmented picker replaced with scrollable pill row
- [x] FIX SL-2 — Allometric toggle: "Add body weight in Settings" tappable annotation
- [x] FIX SL-3 — CSS pillar cards: chevron.right added for tappable affordance
- [x] FIX EI-6 — ExerciseDetailSheet info toolbar button: accessibilityLabel added
- [x] FIX SE-1 — Settings body comp fields: showSavedToast fires on all changes
- [x] FIX DC-1 — Expand icons: arrow.up.left.and.arrow.down.right = fullscreen, chevron = collapse
- [x] FIX DC-2 — Section naming: Progress collapsible sections renamed to Title Case
- [x] WATCH HM-8 — ReadinessCoachCard expanded: inputs breakdown shown inline
- [x] WATCH HM-10 — EmergentInsightCard: minimum data guard (requires ≥ 3 valid insights)
- [x] WATCH HM-11 — BestWeekBlueprintCard: formula subtitle added "Volume · Sessions · Feel"
- [x] WATCH TR-1 — MiniReadinessCard: low-confidence score rendered as "~X" 
- [x] WATCH TR-4 — SwipeableWorkoutCards frame height reduced to 280pt for smaller phones
- [x] WATCH WT-1 — EmptyWorkoutView: CTA hierarchy flips when routines exist
- [x] WATCH WT-3 — RPE first-use inline hint shown once via AppStorage flag
- [x] WATCH PR-2 — CollapsibleDashSection chevron direction fixed (right rotates to down when expanded)
- [x] WATCH PR-5 — InsightsSectionContent: "keep logging" message when < 3 insights
- [x] WATCH PR-9 — CategoryBreakdownView chart minimum height 100pt
- [x] WATCH PR-10 — EfficiencyGrid quadCell: capped at 4 items with "+N more" overflow
- [x] WATCH SL-1 — StrengthLab unit picker: context label below picker for kg/cm² and N/cm²
- [x] WATCH SL-4 — CSS history: placeholder shown at 2 sessions ("1 more to see chart")
- [x] WATCH SL-8 — StrengthConstellationCard: note added if > 8 exercises (filter to top 5 PSI)
- [x] WATCH EI-3 — Next milestone card: shows until tier is achieved (not just at session 1)
- [x] WATCH HI-1 — History Tools section: pinned with section header "Tools"
- [x] WATCH SE-2 — Export button: secondary label describes CSV contents
- [x] WATCH SE-6 — Custom fatigue decay: wrapped in #if DEBUG guard
- [x] WATCH DS-3 — ReadinessCoachCard: "training data only" badge when HealthKit absent
- [x] WATCH DS-4 — EmergentInsightCard: already uses .filter { $0.dataAvailable } (no further cache needed per card)
- [x] WATCH DC-5 — Light mode: prefersDarkMode toggle verified correct at ContentView level
