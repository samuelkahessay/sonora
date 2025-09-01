import SwiftUI

// Semantic color tokens backed by Color assets with system fallbacks.
// No hard-coded RGB values; only system semantic colors are used as fallbacks.
enum SemanticColor: String, CaseIterable {
    // Brand
    case brandPrimary = "brand/Primary"
    case brandSecondary = "brand/Secondary"
    case accent = "brand/Accent"

    // Backgrounds
    case bgPrimary = "bg/Primary"
    case bgSecondary = "bg/Secondary"
    case bgTertiary = "bg/Tertiary"

    // Text
    case textPrimary = "text/Primary"
    case textSecondary = "text/Secondary"
    case textInverted = "text/Inverted"
    case textOnColored = "text/OnColored"

    // Fills & Separators
    case fillPrimary = "fill/Primary"
    case fillSecondary = "fill/Secondary"
    case separator = "separator/Primary"

    // States
    case success = "state/Success"
    case warning = "state/Warning"
    case error = "state/Error"
    case info = "state/Info"
}

extension SemanticColor {
    var assetName: String { rawValue }

    // System fallback that adapts to light/dark automatically.
    var fallbackUIColor: UIColor {
        switch self {
        // Brand
        case .brandPrimary: return .systemBlue
        case .brandSecondary: return .systemIndigo
        case .accent: return .systemOrange

        // Backgrounds
        case .bgPrimary: return .systemBackground
        case .bgSecondary: return .secondarySystemBackground
        case .bgTertiary: return .tertiarySystemBackground

        // Text
        case .textPrimary: return .label
        case .textSecondary: return .secondaryLabel
        case .textInverted: return .label // used on tinted/inverted surfaces; assets should provide high-contrast values
        case .textOnColored: return .white // always white for icons/text on colored backgrounds

        // Fills & Separators
        case .fillPrimary: return .systemFill
        case .fillSecondary: return .tertiarySystemFill
        case .separator: return .separator

        // States
        case .success: return .systemGreen
        case .warning: return .systemYellow
        case .error: return .systemRed
        case .info: return .systemBlue
        }
    }
}

extension UIColor {
    /// Attempts to load a color from assets; falls back to the provided system color.
    static func fromAssets(_ name: String, fallback: UIColor) -> UIColor {
        if let found = UIColor(named: name) { return found }
        return fallback
    }
}

extension Color {
    /// Color asset by token with system fallback.
    static func semantic(_ token: SemanticColor) -> Color {
        let uiColor = UIColor.fromAssets(token.assetName, fallback: token.fallbackUIColor)
        return Color(uiColor)
    }

    /// Named Color asset with fallback UIColor.
    static func named(_ name: String, fallback: UIColor) -> Color {
        Color(UIColor.fromAssets(name, fallback: fallback))
    }
}
