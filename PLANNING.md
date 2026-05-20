# Workout App - Planning & Development Notes

Last Updated: February 15, 2026

---

## Table of Contents
1. [Competitive Analysis](#competitive-analysis)
2. [Implemented Features](#implemented-features)
3. [Planned Features](#planned-features)
4. [User Pain Points Addressed](#user-pain-points-addressed)
5. [Technical Debt](#technical-debt)
6. [Ideas Backlog](#ideas-backlog)

---

## Competitive Analysis

### Top Competitors

| App | Strengths | Weaknesses | Pricing |
|-----|-----------|------------|---------|
| **Hevy** | Free unlimited tracking, social feed, 350+ exercises | Requires internet, no AI guidance | Free / $39/yr |
| **Strong** | Fastest logging, rock-solid reliability | No social, no guidance, limited free tier (3 routines) | $5/mo or $100 lifetime |
| **Fitbod** | AI-powered workout generation, recovery tracking | Buggy algorithm, expensive, poor Android support | $16/mo |
| **JEFIT** | 1,400+ exercise library, video demos | Cluttered UI, buggy updates, ad-heavy | $13/mo |
| **Boostcamp** | Free access to proven programs (nSuns, 5/3/1) | No AI personalization | Free |
| **JuggernautAI** | Elite powerlifting AI coach | Expensive, niche audience | $35/mo |

### Key User Pain Points (Industry-Wide)

1. **Speed & Friction** - Too many taps to log a set
2. **Data Loss & Sync Issues** - Workouts lost, no autosave
3. **Lack of Guidance** - Apps track but don't tell you WHAT to do
4. **Subscription Fatigue** - Core features paywalled
5. **Timer Issues** - Rest timers don't work when backgrounded

### Our Competitive Advantages

| Feature | Hevy | Strong | Fitbod | **Our App** |
|---------|------|--------|--------|-------------|
| PR Celebration | Basic | Basic | No | **Full celebration + shareable cards** |
| Recovery Tracking | No | No | Basic | **Recovery Debt System + Muscle Heatmap** |
| Exercise GIFs | Yes | No | Yes | **Yes (ExerciseDB)** |
| AI Coach | No | No | Limited | **Yes (CoachAI)** |
| Programs | No | No | Yes | **Yes + Race Journey visualization** |
| Gamification | No | No | No | **Race/Journey metaphor** |
| HRV/Readiness | No | No | No | **Yes (HealthKit integration)** |
| Voice Logging | No | No | No | **Yes (Siri Shortcuts)** |
| Micro-Workouts | No | No | No | **Yes (5-min sessions)** |

---

## Implemented Features

### February 2026 Sprint

| Feature | Status | Files | Notes |
|---------|--------|-------|-------|
| One-Tap Set Logging | ✅ Complete | `ExerciseDetailView.swift` | "Repeat All" + per-set quick-fill buttons |
| Shareable PR Cards | ✅ Complete | `PRCelebrationView.swift` | Instagram/TikTok ready graphics |
| Rest Timer Reliability | ✅ Complete | `RestTimerView.swift` | Date-based timing, local notifications, haptics |
| Race Journey Gamification | ✅ Complete | `RaceJourneyView.swift` | Visual race track, milestones, pit stops |
| Muscle Recovery Heatmap | ✅ Complete | `MuscleRecoveryHeatmapView.swift` | Body diagram with color-coded recovery |
| Voice Logging (Siri) | ✅ Complete | `WorkoutIntents.swift` | "Repeat last set", "Start workout", "Check recovery" |
| Micro-Workouts | ✅ Complete | `MicroWorkoutsView.swift` | 6 pre-built 5-min workouts |
| Exercise GIFs | ✅ Complete | `ExerciseMediaService.swift`, `ExerciseMediaView.swift` | Bundled database of 40+ exercises |
| Fatigue Tracking | ✅ Complete | `RecoveryDebtEngine.swift` (merged into Readiness) | 14-day fatigue shown as Readiness factor with warning badge |
| Readiness Waterfall Chart | ✅ Complete | `ReadinessWaterfallView.swift` | "vs Yesterday" + "Breakdown" cascading chart |
| Body Training Analysis | ✅ Complete | `BodyTrainingAnalysisView.swift` | Full body map: Training volume + Recovery status toggle |
| Plate Calculator | ✅ Complete | `PlateCalculatorView.swift` | Visual barbell with colored plates, quick presets |
| Workout History Calendar | ✅ Complete | `WorkoutHistoryCalendarView.swift` | Calendar view with workout indicators, monthly summary |
| Export Data | ✅ Complete | `ExportDataView.swift` | CSV/JSON export with date range filtering |
| Nervous System Waterfall | ✅ Complete | `NervousSystemWaterfallView.swift` | Stress resilience breakdown with HRV factors |
| Volume Waterfall | ✅ Complete | `VolumeWaterfallView.swift` | Volume breakdown by body region or by day |
| Generic Waterfall Component | ✅ Complete | `GenericWaterfallChart.swift` | Reusable cascading waterfall chart component |
| Simple Mode (Strong-style) | ✅ Complete | `SimpleMode.swift` | 3-tab layout (Workout/History/Progress), body part targeting, templates, plate calculator, PRs |
| Undo System | ✅ Complete | `UndoManager.swift` | 8-second undo window for logged workouts |
| RPE Tracking | ✅ Complete | `RPETracker.swift` | RPE 6-10 scale with picker and badge views |
| 1RM Calculator | ✅ Complete | `OneRepMaxCalculator.swift` | Epley formula, percentage charts, training weight suggestions |
| Established Programs | ✅ Complete | `EstablishedPrograms.swift` | 5/3/1, nSuns, Starting Strength, StrongLifts templates |
| Equipment Filtering | ✅ Complete | `EquipmentFilter.swift` | Filter exercises by available equipment |
| Offline Data Manager | ✅ Complete | `OfflineDataManager.swift` | Network monitoring, offline storage, sync queue |

### Previous Implementations

| Feature | Files | Notes |
|---------|-------|-------|
| Apple Watch Integration | `WatchConnectivityManager.swift` | Two-way sync for workout logging |
| Streak System | `StreakSystem.swift`, `StreakCelebrationView.swift` | Daily streak tracking with celebrations |
| Program System | `ProgramModels.swift`, `ProgramManager.swift`, `ProgramTabView.swift` | 4/8/12 week structured programs |
| Progressive Overload | `ProgressionEngine.swift` | Smart weight/rep suggestions |
| Readiness Score | `ReadinessEngine.swift`, `ReadinessScore.swift` | HRV/sleep-based daily readiness |
| AI Coach | `CoachAIManager.swift`, `CoachChatView.swift` | Conversational fitness guidance |
| Templates | `WorkoutTemplatesView.swift` | Save and reuse workout routines |
| Longevity Dashboard | `LongevityDashboardView.swift` | Health span metrics |

---

## Planned Features

### High Priority (Next Sprint)

| Feature | Impact | Effort | Notes |
|---------|--------|--------|-------|
| ~~**Onboarding Revamp**~~ | ✅ Done | Medium | Brief questionnaire (name, goals, equipment, frequency) |
| ~~**Plate Calculator Visual**~~ | ✅ Done | Low | Show which plates to load on barbell |
| ~~**Workout History Calendar**~~ | ✅ Done | Low | Calendar view of past workouts |
| ~~**Export Data**~~ | ✅ Done | Low | CSV/JSON export for data portability |

### Medium Priority

| Feature | Impact | Effort | Notes |
|---------|--------|--------|-------|
| **AI Form Analysis** | Very High | High | Camera-based technique feedback (ML) |
| **Social Challenges** | Medium | Medium | Friend challenges and leaderboards |
| **Nutrition Integration** | Medium | Medium | Macro tracking or MyFitnessPal sync |
| **Custom Exercise Creation** | Medium | Low | Add user-defined exercises |
| **Workout Notes Search** | Low | Low | Search through workout notes |

### Future Considerations

| Feature | Notes |
|---------|-------|
| **3D Body Scanning** | Visual progress tracking (requires ARKit) |
| **Barcode Scanner** | Scan gym equipment QR codes |
| **Gym Check-in** | Location-based workout start |
| **Workout Music Integration** | Apple Music/Spotify controls |
| **Apple Watch Standalone** | Full app on watch without phone |

---

## User Pain Points Addressed

### Speed & Friction
- ✅ One-tap set logging (copy previous)
- ✅ "Repeat All" for entire workout
- ✅ Voice logging via Siri
- ✅ Plate calculator (visual)

### Reliability
- ✅ Date-based rest timer (survives backgrounding)
- ✅ Local notifications for timer
- ✅ Haptic feedback at key moments
- ⏳ Offline-first data storage

### Guidance & Intelligence
- ✅ Progressive overload suggestions
- ✅ Recovery Debt system
- ✅ Muscle recovery heatmap
- ✅ AI Coach chat
- ✅ Readiness score
- ⏳ AI form analysis

### Engagement & Motivation
- ✅ PR celebrations with confetti
- ✅ Shareable PR cards
- ✅ Race Journey gamification
- ✅ Streak system
- ✅ Micro-workouts for busy days

---

## Technical Debt

| Issue | Priority | Notes |
|-------|----------|-------|
| `UIScreen.main` deprecation warnings | Low | Need to use view context instead |
| Swift 6 actor isolation warnings | Medium | `SleepCoaching.swift` line 90 |
| Watch app bundle ID was misconfigured | ✅ Fixed | Changed to `com.honluu.workout` |
| Some views are very large | Low | Consider breaking into smaller components |

---

## Ideas Backlog

### From Competitive Research
- [ ] Zombies Run-style narrative for strength training
- [ ] Live PR detection during workout (not just at save)
- [ ] Workout buddy matching
- [ ] Coach video messages
- [ ] Deload week auto-detection

### From User Feedback
- [ ] Dark mode improvements
- [ ] Widget for home screen
- [ ] Complications for Apple Watch
- [ ] Rest timer sound options
- [ ] Metric/Imperial quick toggle

### From TikTok/Social Trends
- [ ] "Shy girl workout" mode (simpler exercises)
- [ ] Animated muscle highlights during exercise
- [ ] Before/after progress photos with data overlay
- [ ] Workout completion videos for sharing

---

## Beta Feedback (Simulated User Testing - Feb 2026)

### Feedback Summary by Persona

| Persona | Rating | Key Feedback |
|---------|--------|--------------|
| **Jake, 22** - New lifter | ⭐⭐⭐⭐ | Overwhelmed by features; wants "simple mode"; plate calculator is great |
| **Maria, 34** - Strong user | ⭐⭐⭐ | Too many taps to log; no Watch app; can't import data from Strong |
| **Derek, 45** - Powerlifter | ⭐⭐⭐⭐ | Wants percentage-based training (5/3/1, nSuns); PR celebrations feel juvenile |
| **Priya, 28** - Casual | ⭐⭐⭐⭐⭐ | Templates perfect; micro-workouts great; needs equipment filtering |
| **Tom, 58** - Gym owner | ⭐⭐⭐ | Text too small; no trainer/client features; exercise GIFs inconsistent |
| **Aisha, 31** - UX Designer | ⭐⭐⭐ | IA confusion; no undo; no offline mode; duplicate info in multiple places |
| **Chris, 25** - CrossFitter | ⭐⭐ | No WOD timer; no AMRAP/EMOM; missing CrossFit exercises |
| **Emily, 40** - Returning | ⭐⭐⭐⭐ | Wants beginner programs; needs smaller weight increments |
| **Marcus, 29** - Data analyst | ⭐⭐⭐⭐⭐ | Analytics best-in-class; wants API access and correlation analysis |
| **Linda, 52** - Menopause | ⭐⭐⭐ | No women-specific content; no hormone/cycle awareness |
| **Ryan, 19** - D1 Athlete | ⭐⭐⭐ | No RPE tracking; no video recording; no WHOOP integration |
| **Steve, 38** - Tech blogger | ⭐⭐⭐⭐ | Analytics great; logging speed lags Strong; needs "essentials" mode |

### Top Issues by Frequency

| Issue | Mentions | Severity | Status |
|-------|----------|----------|--------|
| Too complex for beginners | 6 | High | ✅ Added Simple Mode (`SimpleMode.swift`) |
| No undo for mistakes | 2 | Medium | ✅ Added Undo Toast (`UndoManager.swift`) |
| No RPE tracking | 2 | Medium | ✅ Added RPE Picker (`RPETracker.swift`) |
| No percentage-based training | 2 | Medium | ✅ Added 1RM Calculator (`OneRepMaxCalculator.swift`) |
| No established programs | 2 | Medium | ✅ Added 5/3/1, nSuns, SS, SL templates (`EstablishedPrograms.swift`) |
| No equipment filtering | 2 | Medium | ✅ Added Equipment Filter (`EquipmentFilter.swift`) |
| Slow logging (too many taps) | 4 | High | 🔄 In Progress - Quick-add partially done |
| No offline mode | 2 | Critical | ✅ Foundation added (`OfflineDataManager.swift`) |
| No Apple Watch standalone | 2 | High | ⏳ Future sprint |
| No data import from competitors | 2 | Medium | ⏳ Future sprint |
| Missing CrossFit/HIIT support | 1 | Low | ❌ Out of scope (different audience) |
| No trainer/client features | 1 | Low | ⏳ Future consideration |

### Most Requested Features (Prioritized)

| Priority | Feature | Implementation |
|----------|---------|----------------|
| P0 | Simple/Essentials mode | ✅ `SimpleModeManager`, `SimpleDashboardView` |
| P0 | Undo functionality | ✅ `WorkoutUndoManager`, `UndoToast` |
| P1 | Quick-add logging | 🔄 `QuickWorkoutPicker` (partial) |
| P1 | RPE tracking | ✅ `RPE` enum, `RPEPicker`, `RPEBadge` |
| P1 | Offline support | ✅ Foundation added: `OfflineDataManager` with NWPathMonitor |
| P2 | Percentage-based training | ✅ `OneRepMaxCalculator`, `PercentageCalculatorView`, `QuickPercentagePicker` |
| P2 | Established programs | ✅ `EstablishedProgramsView`, 5/3/1, nSuns, Starting Strength, StrongLifts |
| P2 | Equipment filtering | ✅ `EquipmentFilter`, `EquipmentSettingsView`, `ExerciseFilterToggle` |
| P3 | Apple Watch standalone | ⏳ Significant effort |
| P3 | Data import | ⏳ Strong/Hevy CSV parsing |

### Quotes Worth Remembering

> "I just want to track my bench press?" - Jake (beginner)

> "No Apple Watch app? Dealbreaker for me honestly." - Maria (Strong user)

> "I'm 45, I don't need confetti." - Derek (experienced lifter)

> "This is exactly what I needed!" - Priya (casual user)

> "No offline mode! I workout in a basement gym with no signal." - Aisha (UX designer)

> "We're a huge market that everyone ignores." - Linda (women 50+)

---

## Feature Wiring Status (Feb 2026)

All features are now connected to the app navigation:

| Feature | Location | Access Point |
|---------|----------|--------------|
| ExportDataView | Settings → Data Management → Export | Sheet |
| WorkoutHistoryCalendarView | Settings → Progress → Workout Calendar | NavigationLink |
| PlateCalculatorView | ExerciseDetailView toolbar (barbell) | Sheet |
| PercentageCalculatorView | ExerciseDetailView toolbar | Sheet |
| MuscleRecoveryHeatmapView | HealthDashboard → Recovery button | Sheet |
| VolumeWaterfallView | HealthDashboard → Volume button | Sheet |
| BodyTrainingAnalysisView | HealthDashboard → Body button | Sheet |
| MicroWorkoutsView | PersonalTrainerView → 5-Min Workouts card | Sheet |
| EstablishedProgramsView | Program tab → Browse Proven Programs | Sheet |
| Simple Mode | Home tab (when enabled) | Full dashboard |

---

## Architecture Notes

### Key Managers (Singletons)
- `SeedStore` - Main data store (exercises, workout log, PRs)
- `ProgramManager` - Active program and history
- `MuscleRecoveryEngine` - Recovery calculations
- `RecoveryDebtEngine` - Stress vs recovery balance
- `ProgressionEngine` - Weight/rep suggestions
- `TimeContextManager` - Time-of-day UI adaptations
- `WatchConnectivityManager` - Apple Watch sync

### Data Flow
```
User Input → SeedStore → HealthKit (optional)
                ↓
         Calculation Engines
                ↓
         UI Views (SwiftUI)
```

### Key Models
- `Exercise` - Exercise definition
- `WorkoutLogEntry` - Logged workout with sets
- `SetRecord` - Individual set data
- `PersonalRecord` - PR tracking
- `Program` / `ProgramWeek` / `ProgramDay` - Structured programs
- `DailyHealthSnapshot` - HealthKit data aggregation

---

## Release Notes Template

### Version X.X.X (Date)

**New Features:**
-

**Improvements:**
-

**Bug Fixes:**
-

---

## Contact & Resources

- GitHub Issues: https://github.com/anthropics/claude-code/issues
- App Store: (pending)
- TestFlight: (pending)

---

*This document is maintained as part of the development process. Update regularly.*
