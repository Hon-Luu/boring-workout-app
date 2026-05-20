import SwiftUI

// Central design language — now delegates to HONTheme (H.O.N. brand).
// All existing AppTheme references continue to compile; they now resolve
// to HON colors and typography instead of system defaults.

enum AppTheme {

    // MARK: - Tier Colors

    static func tier(_ t: RelativeStrengthTier) -> Color { HONTheme.tier(t) }
    static func tier(_ t: StrengthTier) -> Color { HONTheme.tier(t) }

    // MARK: - Pattern Colors

    static func pattern(_ g: PatternGroup) -> Color { HONTheme.pattern(g) }

    // MARK: - Semantic Colors

    static let positive: Color = HONTheme.positive
    static let negative: Color = HONTheme.negative
    static let warning:  Color = HONTheme.warning
    static let primary:  Color = HONTheme.primary

    // MARK: - Background Surfaces

    static let pageBG  = HONTheme.pageBG
    static let cardBG  = HONTheme.cardBG
    static let insetBG = HONTheme.insetBG
}

// MARK: - Typography (delegates to HON font helpers)

extension Font {
    /// Large hero number — brand moments. Cormorant Garamond Light.
    static func heroRounded(_ size: CGFloat = 44) -> Font {
        Font.honHero(size)
    }

    /// Monospaced numeric value — numbers that change and must stay pixel-stable.
    static func monoValue(_ size: CGFloat = 13, weight: Weight = .bold) -> Font {
        Font.honMono(size, weight: weight)
    }

    /// Card header — exercise names, pattern names, metric labels.
    static let cardTitle: Font = .honCardTitle

    /// Eyebrow / micro label — ALL-CAPS section headers above cards.
    static let microLabel: Font = .honMicro

    /// Small footnote — explainers, units, disclaimers at bottom of cards.
    static let appFootnote: Font = .honFootnote
}
