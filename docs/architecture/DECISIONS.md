# Architecture Decisions

## AD-001 — Single Store (SeedStore)

**Decision:** One `@Observable` store, no ViewModels, no service layer.
**Why:** Single-user, offline-first app. Simplicity wins over architecture purity at this scale.
**Trade-off:** Everything in one object — intentional for now. Revisit if modules need isolation.

## AD-002 — Static Exercise Database

**Decision:** `exercises` array built once at init, never mutated at runtime.
**Why:** Exercise definitions are compile-time constants. UUID-stable identity is critical — log entries reference exercise UUIDs; if those change, history becomes unreadable.

## AD-003 — UserDefaults + JSON (no Core Data)

**Decision:** Serialize everything to JSON in UserDefaults.
**Why:** No migration complexity, transparent export format, easy backup/restore.
**Watch:** Large logs could hit UserDefaults size limits (~4MB). Monitor at scale; SQLite migration path exists if needed.

## AD-004 — HealthKit Read-Only

**Decision:** App reads HealthKit but never writes.
**Why:** Avoid polluting the user's health record with app-internal data. User trust.

## AD-005 — Post-Onboarding HealthKit Prompt

**Decision:** No HealthKit permission request during onboarding. A card on Home appears after first session.
**Why:** User needs context (a completed session) to understand why the permission matters.
**Backlog:** 6.5 — revisit if adoption data shows low HealthKit authorization rates.

## AD-006 — HONTheme Color System

**Decision:** All colors go through HONTheme tokens. Zero raw system colors.
**Why:** Consistency, dark mode correctness, semantic meaning (positive=sage, negative=rose, warning=amber).
**Enforced:** Pass 4 sweep confirmed zero violations across all files.

## AD-007 — refreshAnalytics() Token Pattern

**Decision:** Each analytics refresh mints a UUID token; background block only commits if token still matches.
**Why:** Prevents stale analytics from overwriting a newer result if two refreshes overlap.

## AD-008 — FeelSelectorSheet Requires Explicit Action

**Decision:** `.interactiveDismissDisabled(true)` — swipe-down to dismiss is blocked.
**Why:** Silent nil for `feelRating` would exclude the session from EmergentInsightEngine pattern detection. Data integrity over convenience.
