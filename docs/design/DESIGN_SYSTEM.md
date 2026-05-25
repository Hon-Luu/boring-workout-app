# H.O.N. Design System

## Color Tokens

All colors use `HONTheme`. Never use raw system colors (`Color.blue`, `.green`, `.red`, `.pink`, `.orange`, `.purple`, `.yellow`).

| Token | Role | Semantic Use |
|-------|------|-------------|
| `HONTheme.positive` | Success, light load, progress | Sage green |
| `HONTheme.negative` | Warning, vigorous, concerning | Rose |
| `HONTheme.warning` | Moderate intensity, caution | Amber |
| `HONTheme.accent` | Highlights, PRs, primary actions | Amber (same as warning) |
| `HONTheme.chartLavender` | Strength/score chart series | #9B8EC4 |
| `HONTheme.chartSlate` | Neutral chart series | #6B85A0 |
| `HONTheme.chartSage` | Volume / frequency series | Sage variant |
| `HONTheme.chartRose` | Recovery / cardio series | Rose variant |
| `HONTheme.chartClay` | Warm neutral series | Clay |
| `HONTheme.chartAmber` | PR / best performance | Amber variant |

### Intensity Color Mapping
```swift
case .light:    HONTheme.positive
case .moderate: HONTheme.warning
case .vigorous: HONTheme.negative
```

### INOL Calendar Mapping
```swift
inol == 0:      Color(.systemGray6).opacity(0.2)  // rest
inol < 0.4:     HONTheme.positive.opacity(0.2)    // easy
inol < 0.8:     HONTheme.positive.opacity(0.5)    // moderate
inol < 1.4:     HONTheme.chartSlate.opacity(0.7)  // hard
inol < 2.0:     HONTheme.warning.opacity(0.8)     // very hard
inol >= 2.0:    HONTheme.negative.opacity(0.9)    // overreaching
```

## Typography

| Context | Size | Where |
|---------|------|-------|
| Dashboard card axis labels | `size: 8` | Cards 100–140px tall |
| Standalone chart axis labels | `size: 9` | Full-screen charts 160–220px |
| Section headers | `sectionHeader()` modifier | All section headers |

## Layout

### Side-by-Side Chart Cards
```swift
HStack(alignment: .top, spacing: 12) { ... }
```
`alignment: .top` required — cards have different heights and must share a top edge.

### Chart Card Heights
Via `expandingFrame(normal:expanded:)` which reads `@Environment(\.expandedChart)`:
- Donut / bar charts: 260pt normal
- Line / scatter charts: 300pt normal

### Card Style
Use `.cardStyle()` modifier for consistent background, corner radius, shadow.

## Voice & Tone

- Direct, not cheerleader
- Dry, not corporate
- Specific, not generic ("Session 50. Half a hundred." not "Great job!")
- Shame-free return framing always
- Science earns its place — never jargon for jargon's sake
