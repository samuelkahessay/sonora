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
        // Vibrant primaries for light mode
        primary: Color(red: 0.0, green: 0.478, blue: 1.0), // Bright blue
        secondary: Color(red: 0.0, green: 0.78, blue: 0.82), // Cyan
        accent: Color(red: 1.0, green: 0.231, blue: 0.188), // Coral red
        
        // Layered backgrounds for depth
        background: Color(UIColor.systemBackground),
        backgroundElevated: Color(UIColor.secondarySystemBackground),
        backgroundGlass: Color.white.opacity(0.72),
        backgroundGlassSecondary: Color.white.opacity(0.55),
        
        // High contrast text for glass readability
        textPrimary: Color(UIColor.label),
        textSecondary: Color(UIColor.secondaryLabel),
        textOnGlass: Color.black.opacity(0.85),
        
        // Glass effects - light mode
        glassTint: Color.white.opacity(0.3),
        glassBorder: Color.white.opacity(0.65),
        glassHighlight: Color.white.opacity(0.8),
        glassShadow: Color.black.opacity(0.08),
        
        // Semantic colors
        success: Color(red: 0.20, green: 0.78, blue: 0.35),
        warning: Color(red: 1.0, green: 0.58, blue: 0.0),
        error: Color(red: 1.0, green: 0.23, blue: 0.19),
        info: Color(red: 0.0, green: 0.48, blue: 1.0)
    )
    
    // Liquid Glass Dark Theme
    static let dark = ColorPalette(
        // Luminous primaries for dark mode
        primary: Color(red: 0.04, green: 0.52, blue: 1.0), // Electric blue
        secondary: Color(red: 0.39, green: 0.82, blue: 1.0), // Light cyan
        accent: Color(red: 1.0, green: 0.45, blue: 0.42), // Soft coral
        
        // Dark layered backgrounds
        background: Color(UIColor.systemBackground),
        backgroundElevated: Color(UIColor.secondarySystemBackground),
        backgroundGlass: Color.black.opacity(0.65),
        backgroundGlassSecondary: Color(white: 0.15, opacity: 0.7),
        
        // Optimized text for dark glass
        textPrimary: Color(UIColor.label),
        textSecondary: Color(UIColor.secondaryLabel),
        textOnGlass: Color.white.opacity(0.92),
        
        // Glass effects - dark mode
        glassTint: Color.white.opacity(0.1),
        glassBorder: Color.white.opacity(0.2),
        glassHighlight: Color.white.opacity(0.25),
        glassShadow: Color.black.opacity(0.3),
        
        // Semantic colors (adjusted for dark)
        success: Color(red: 0.24, green: 0.84, blue: 0.39),
        warning: Color(red: 1.0, green: 0.68, blue: 0.0),
        error: Color(red: 1.0, green: 0.34, blue: 0.34),
        info: Color(red: 0.19, green: 0.58, blue: 1.0)
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

