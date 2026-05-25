# Side Notes

Ideas and features to revisit later.

---

## Calendar Integration — Smart Workout Nudges

**Idea:** Connect to the user's calendar and nudge them to work out when they have a free slot.

**Why it's interesting:**
- Solves the #1 excuse (no time) passively — no fixed reminder at an arbitrary time
- Could get smarter: "you usually work out Tuesday mornings, you have 90 min free"
- Natural foundation for a future AI coaching tier

**The right version to build:**
Cross-reference two signals before nudging:
1. Calendar has a gap ≥ user's average workout duration
2. Readiness score is above a threshold (don't nudge when overtrained)

This makes the notification feel intelligent, not mechanical — and the readiness engine is already in place to support it.

**Watch out for:**
- Calendar access is a significant permission ask — earn trust before asking
- "Free" on a calendar ≠ actually free (commute buffer, mental load, back-to-back meeting recovery)
- Nudge fatigue — if ignored too often, users disable it permanently
- Make it opt-in deep in settings, not an onboarding prompt

---
