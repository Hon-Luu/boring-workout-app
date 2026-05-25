# Project Organization

This repository is the canonical home for the Boring Workout app.

## Active Project

- `workout.xcodeproj/` - Xcode project. The app target/product is still named `workout`.
- `iOSApp/` - iOS app source.
- `workoutWidget/` - widget extension source.
- `workoutWatch/` - watchOS app source, placed where the Xcode target expects it.
- `docs/` - project documentation.
- `scripts/` - local project utilities.
- `simulation/` - simulation scripts and generated simulation output.
- `resources/` - non-source working assets such as spreadsheets.

## Documentation Layout

- `docs/product/` - product and business requirements.
- `docs/uat/` - UAT plans and test scenarios.
- `docs/prototypes/` - HTML prototypes and preview artifacts.
- `docs/archive/` - retained historical or top-level files that are not part of the active source tree.
- `docs/project/` - planning, status, and working project notes.
- `docs/research/` - research notes.
- `docs/architecture/` - architecture notes and decisions.
- `docs/design/` - design system and component notes.

## iOS Source Layout

- `iOSApp/App/` - app entry points and top-level navigation.
- `iOSApp/Design/` - theme, shared styling, and common visual systems.
- `iOSApp/Models/` - shared app data models.
- `iOSApp/Services/` - platform services and integrations.
- `iOSApp/Engines/` - calculation, insight, messaging, and coaching engines.
- `iOSApp/Views/` - screen and reusable UI views grouped by area.
- `iOSApp/Features/` - larger feature-specific screens and flows.

The iOS target keeps `Info.plist`, entitlements, and `phrase_bank.json` at the source-root because build settings or runtime code reference those paths directly.

## Quarantine

Original folders and duplicate/obsolete files were moved to:

`/Users/honluu/Desktop/DS/to_delete`

Nothing was deleted during this cleanup. Review that folder before permanently removing anything.
