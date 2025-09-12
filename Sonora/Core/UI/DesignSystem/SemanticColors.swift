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
    case textTertiary = "text/Tertiary"
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
        case .bgTertiary:
            // Use a truly dark surface in Dark Mode, slightly elevated in Light
            return UIColor { trait in
                // Lighter surface in light mode, truly dark in dark mode
                trait.userInterfaceStyle == .dark ? UIColor.systemGray6 : UIColor.systemGray6
            }

        // Text
        case .textPrimary: return .label
        case .textSecondary: return .secondaryLabel
        case .textTertiary: return .tertiaryLabel
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
}
