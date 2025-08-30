import SwiftUI

struct ColorPalette {
    // Primary colors
    let primary: Color
    let secondary: Color
    let accent: Color
    
    // Background colors with transparency support
    let background: Color
    let backgroundElevated: Color
    let backgroundGlass: Color
    let backgroundGlassSecondary: Color
    
    // Text colors optimized for glass surfaces
    let textPrimary: Color
    let textSecondary: Color
    let textOnGlass: Color
    
    // Glass-specific colors
    let glassTint: Color
    let glassBorder: Color
    let glassHighlight: Color
    let glassShadow: Color
    
    // Semantic colors
    let success: Color
    let warning: Color
    let error: Color
    let info: Color
}

extension ColorPalette {
    // Liquid Glass Light Theme
    static let light = ColorPalette(
        // Primaries for light mode (assets with system fallbacks)
        primary: .semantic(.brandPrimary),
        secondary: .semantic(.brandSecondary),
        accent: .semantic(.accent),

        // Layered backgrounds for depth
        background: .semantic(.bgPrimary),
        backgroundElevated: .semantic(.bgSecondary),
        backgroundGlass: Color(UIColor.systemFill),
        backgroundGlassSecondary: Color(UIColor.tertiarySystemFill),

        // High contrast text
        textPrimary: .semantic(.textPrimary),
        textSecondary: .semantic(.textSecondary),
        textOnGlass: .semantic(.textPrimary),

        // Glass effects - light mode, using system semantic colors
        glassTint: Color(UIColor.systemFill),
        glassBorder: Color(UIColor.separator),
        glassHighlight: Color(UIColor.secondarySystemFill),
        glassShadow: Color(UIColor.separator).opacity(0.25),

        // States
        success: .semantic(.success),
        warning: .semantic(.warning),
        error: .semantic(.error),
        info: .semantic(.info)
    )

    // Liquid Glass Dark Theme
    static let dark = ColorPalette(
        // Primaries for dark mode (assets with system fallbacks)
        primary: .semantic(.brandPrimary),
        secondary: .semantic(.brandSecondary),
        accent: .semantic(.accent),

        // Dark layered backgrounds
        background: .semantic(.bgPrimary),
        backgroundElevated: .semantic(.bgSecondary),
        backgroundGlass: Color(UIColor.systemFill),
        backgroundGlassSecondary: Color(UIColor.tertiarySystemFill),

        // Optimized text for dark glass
        textPrimary: .semantic(.textPrimary),
        textSecondary: .semantic(.textSecondary),
        textOnGlass: .semantic(.textPrimary),

        // Glass effects - dark mode
        glassTint: Color(UIColor.systemFill),
        glassBorder: Color(UIColor.separator),
        glassHighlight: Color(UIColor.secondarySystemFill),
        glassShadow: Color(UIColor.separator).opacity(0.25),

        // States
        success: .semantic(.success),
        warning: .semantic(.warning),
        error: .semantic(.error),
        info: .semantic(.info)
    )
}

// Gradient definitions for glass effects
extension ColorPalette {
    var glassGradient: LinearGradient {
        LinearGradient(
            colors: [glassTint, glassTint.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primary.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
