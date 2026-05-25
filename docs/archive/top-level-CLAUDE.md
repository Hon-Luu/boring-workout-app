# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Structure

Multi-target Xcode project at `workout/workout.xcodeproj` with three targets:

| Target | Source Folder | Platform |
|--------|--------------|----------|
| workout (iOS app) | `workout/workout/` | iOS |
| workoutWidgetExtension | `workout/workoutWidget/` | iOS (widget) |
| workoutWatch | `workoutWatch/` | watchOS |

> **Note:** The main iOS app source (`workout/workout/*.swift`) is not currently on disk — only the widget and watch targets have Swift source files present. The planning documents (`workout/PLANNING.md`, `workout/PROJECT_STATUS.md`) describe the full intended feature set and file inventory.

`reference-images/` at the root contains body-part diagram PNGs (two sets: `base-*.png` outlines and `Body-*.png` renders) used as design references, not bundled app assets.

## Build Commands

```bash
# Open in Xcode
open workout/workout.xcodeproj

# Build iOS app (simulator)
xcodebuild -project workout/workout.xcodeproj -scheme workout \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build widget extension
xcodebuild -project workout/workout.xcodeproj -scheme workoutWidgetExtension \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build watch app
xcodebuild -project workout/workout.xcodeproj -scheme workoutWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

No Swift Package Manager dependencies, linter config, or test targets are currently configured.

## Architecture

### State Management
The app uses Swift's `@Observable` macro (Swift 5.9+) throughout — not `ObservableObject`/`@Published`. All singleton managers follow this pattern.

### Key Singletons (iOS app)
- **`SeedStore`** — primary data store for exercises, workout log, and PRs. Central hub for all user data.
- **`ProgramManager`** — active training program and history
- **`MuscleRecoveryEngine`** / **`RecoveryDebtEngine`** — muscle recovery calculations and stress/recovery balance
- **`ProgressionEngine`** — progressive overload weight/rep suggestions
- **`ReadinessEngine`** — HRV/sleep-based daily readiness score
- **`WatchConnectivityManager`** — iPhone side of Watch sync
- **`TimeContextManager`** — time-of-day UI adaptations

### Data Flow
```
User Input → SeedStore → HealthKit (optional write-back)
                ↓
     Calculation Engines (Recovery, Readiness, Progression)
                ↓
          SwiftUI Views
```

Persistence is **UserDefaults only** (no CoreData/SwiftData). `DailyHealthSnapshot` entries are pruned after 180 days.

### Widget Data Sharing
The widget extension reads data via **App Groups** (`group.workout.shared`). `SharedDataManager` (in `workoutWidget/SharedDataManager.swift`) is the read-only interface. The main app writes streak, last workout, and weekly volume data to this shared container; call `WidgetCenter.reloadWorkoutWidgets()` after any write.

### Watch App
`workoutWatch/` operates in two modes toggled by the user:
- **Standalone** — fully independent, uses `StandaloneWorkout.swift` and `RepCountingEngine.swift` for motion-based rep counting
- **Paired** — syncs live with the iPhone via `WatchSessionManager` (WatchConnectivity)

`WatchSyncModels.swift` defines the shared message protocol (`WatchCommand` enum, `WatchWorkoutSession`, `WatchWorkoutUpdate`). This file must stay in sync conceptually with the iOS-side `WatchConnectivityManager`.

### Subscription & Paywalling
`SubscriptionManager` uses **StoreKit 2**. Feature gates use a `PremiumGate` SwiftUI component. A test/sandbox mode exists for development — check `SubscriptionManager` before adding new gated features.

## Known Technical Debt
- `UIScreen.main` deprecation warnings throughout (use view geometry instead)
- Swift 6 actor isolation warning in `SleepCoaching.swift` around line 90
- Several views are large monolithic files — prefer extracting subviews before adding more logic to them

## App Navigation (5 tabs)
`Home → Trainer → Workout → Progress → Settings`

Simple Mode (for beginners) replaces the Home tab with a 3-tab layout when enabled via `SimpleModeManager`.
