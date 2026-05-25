import SwiftUI

// H.O.N. — Habit Over Numbers
// Single source of truth for brand colors, chart palette, and typography.
// All views should import this file's tokens rather than hardcoding values.

// MARK: - Hex initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - HON Brand System

enum HONTheme {

    // MARK: Core Palette

    /// Onyx — primary background, deepest surface
    static let background   = Color(hex: "1C1C1E")
    /// Carbon — card / modal surface, one step above background
    static let surface      = Color(hex: "2E2E30")
    /// Elevated — input fields, inner chips, one step above surface
    static let elevated     = Color(hex: "3A3A3C")
    /// Amber — brand accent, CTAs, highlights
    static let accent       = Color(hex: "D4943A")
    /// Ivory — primary text on dark backgrounds
    static let textPrimary  = Color(hex: "F0EDE8")
    /// Iron — secondary / supporting text
    static let textSecondary = Color(hex: "5A5A5E")
    /// Muted — placeholder, disabled, micro-labels
    static let textMuted    = Color(hex: "3E3E40")

    // MARK: Semantic Colors (HON-tuned variants)

    /// Positive: muted gold-green — PRs, improvements, success
    static let positive     = Color(hex: "7A9E8E")   // chartSage
    /// Negative: muted rose — regressions, destructive actions
    static let negative     = Color(hex: "B47A80")   // chartRose
    /// Warning: amber — nudges, caution, targets
    static let warning      = accent
    /// Primary action — same as accent
    static let primary      = accent

    // MARK: Tier Colors (muted, works on dark bg)

    static let tierBeginner    = Color(hex: "5A5A5E")   // Iron
    static let tierIntermediate = Color(hex: "6B85A0")  // chartSlate (blue tone)
    static let tierAdvanced    = Color(hex: "7A9E8E")   // chartSage (teal tone)
    static let tierElite       = Color(hex: "D4943A")   // Amber

    // MARK: Pattern Colors (HON-tuned, no clash with tiers)

    static let patternPush      = Color(hex: "6B85A0")   // Slate
    static let patternPull      = Color(hex: "7A9E8E")   // Sage
    static let patternLegs      = Color(hex: "A07060")   // Clay
    static let patternIsolation = Color(hex: "8A80A8")   // Lavender

    // MARK: Muted Spectrum Chart Palette

    static let chartAmber    = Color(hex: "D4943A")
    static let chartSage     = Color(hex: "7A9E8E")
    static let chartSlate    = Color(hex: "6B85A0")
    static let chartRose     = Color(hex: "B47A80")
    static let chartClay     = Color(hex: "A07060")
    static let chartLavender = Color(hex: "8A80A8")

    static let chartSeries: [Color] = [
        chartAmber, chartSage, chartSlate, chartRose, chartClay, chartLavender
    ]

    // MARK: Background Surfaces

    /// Deepest — full-screen background
    static let pageBG  = background
    /// Card — grouped list card background
    static let cardBG  = surface
    /// Inset — inner row / chip background
    static let insetBG = elevated

    // MARK: Separator / Divider

    static let divider = Color(hex: "3A3A3C")

    // MARK: - Tier helpers (matching AppTheme API)

    static func tier(_ t: RelativeStrengthTier) -> Color {
        switch t {
        case .beginner:     return tierBeginner
        case .intermediate: return tierIntermediate
        case .advanced:     return tierAdvanced
        case .elite:        return tierElite
        }
    }

    static func tier(_ t: StrengthTier) -> Color {
        switch t {
        case .beginner:     return tierBeginner
        case .intermediate: return tierIntermediate
        case .advanced:     return tierAdvanced
        case .elite:        return tierElite
        }
    }

    static func pattern(_ g: PatternGroup) -> Color {
        switch g {
        case .push:      return patternPush
        case .pull:      return patternPull
        case .legs:      return patternLegs
        case .isolation: return patternIsolation
        }
    }
}

// MARK: - HON Typography

extension Font {
    /// Brand hero — score callouts, PR weights. Cormorant Garamond Light.
    static func honHero(_ size: CGFloat = 44) -> Font {
        Font.custom("CormorantGaramond-Light", size: size)
    }

    /// Brand display — section titles, archetype name. Cormorant Garamond Light.
    static func honDisplay(_ size: CGFloat = 28) -> Font {
        Font.custom("CormorantGaramond-Light", size: size)
    }

    /// Body / UI — all interface text. DM Sans Regular.
    static func honBody(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold, .semibold, .heavy, .black:
            return Font.custom("DMSans-SemiBold", size: size)
        case .medium:
            return Font.custom("DMSans-Medium", size: size)
        default:
            return Font.custom("DMSans-Regular", size: size)
        }
    }

    /// Card header label. DM Sans SemiBold 13pt.
    static let honCardTitle  = Font.custom("DMSans-SemiBold", size: 13)

    /// Micro / eyebrow label. DM Sans Medium 9pt.
    static let honMicro      = Font.custom("DMSans-Medium", size: 9)

    /// Footnote / explainer. DM Sans Regular 9pt.
    static let honFootnote   = Font.custom("DMSans-Regular", size: 9)

    /// Monospaced number — use system mono for numeric stability.
    static func honMono(_ size: CGFloat = 13, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
