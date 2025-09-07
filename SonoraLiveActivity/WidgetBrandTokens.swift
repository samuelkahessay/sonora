import SwiftUI
import UIKit

// Minimal, extension-local brand/semantic color helpers for the Live Activity target.
// Mirrors the app's semantic tokens using dynamic system fallbacks to ensure
// correct light/dark adaptation without requiring asset catalogs.

enum WidgetSemanticColor {
    case bgPrimary
    case bgSecondary
    case textPrimary
    case textSecondary
    case textOnColored
    case fillSecondary
    case separator
    case brandPrimary   // insightGold
    case brandSecondary // growthGreen
}

extension Color {
    static func semantic(_ token: WidgetSemanticColor) -> Color {
        switch token {
        case .bgPrimary:      return Color(UIColor.systemBackground)
        case .bgSecondary:    return Color(UIColor.secondarySystemBackground)
        case .textPrimary:    return Color(UIColor.label)
        case .textSecondary:  return Color(UIColor.secondaryLabel)
        case .textOnColored:  return Color.white
        case .fillSecondary:  return Color(UIColor.tertiarySystemFill)
        case .separator:      return Color(UIColor.separator)
        case .brandPrimary:   return Color(hex: 0xD4AF37) // insightGold
        case .brandSecondary: return Color(hex: 0x4A9B8E) // growthGreen
        }
    }

    // Lightweight hex initializer (RGB, no alpha for simplicity)
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

