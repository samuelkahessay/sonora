//
//  SonoraBrandColors.swift
//  Sonora
//
//  Sonora Brand Identity System - Color Foundation
//  Implements the "Clarity through Voice" color palette with semantic mappings
//

import SwiftUI

// MARK: - Sonora Brand Color Palette

extension Color {
    
    // MARK: - Primary Palette
    
    /// Sonora Deep: Rich, contemplative navy that conveys depth and wisdom
    static let sonoraDep = Color(hexString: "#1A2332")
    
    /// Clarity White: Pure, clean white for breathing room and mental clarity
    static let clarityWhite = Color(hexString: "#FDFFFE")
    
    /// Insight Gold: Warm, premium gold for highlighting key insights and achievements
    static let insightGold = Color(hexString: "#D4AF37")
    
    // MARK: - Secondary Palette
    
    /// Reflection Gray: Soft blue-gray for secondary text and subtle elements
    static let reflectionGray = Color(hexString: "#8B9DC3")
    
    /// Whisper Blue: Ultra-light blue for backgrounds and gentle highlights
    static let whisperBlue = Color(hexString: "#E8F0FF")
    
    /// Growth Green: Muted teal for progress indicators and positive actions
    static let growthGreen = Color(hexString: "#4A9B8E")
    
    // MARK: - Accent Colors
    
    /// Spark Orange: Energetic coral for call-to-action elements
    static let sparkOrange = Color(hexString: "#FF6B35")
    
    /// Depth Purple: Rich purple for premium features and depth
    static let depthPurple = Color(hexString: "#6B4C93")
}

// MARK: - Semantic Color Mappings

extension Color {
    
    // MARK: - Recording States
    
    /// Active recording state - uses Insight Gold for premium feel
    static let recordingActive = insightGold
    
    /// Inactive recording state - uses Reflection Gray for subtle presence
    static let recordingInactive = reflectionGray
    
    /// Recording error state - uses Spark Orange for gentle but clear warning
    static let recordingError = sparkOrange
    
    // MARK: - Content & Insights
    
    /// Highlight color for key insights and important content
    static let insightHighlight = growthGreen
    
    /// Background color for insight cards and analysis content
    static let insightBackground = whisperBlue
    
    /// Text color for inspirational quotes and meaningful moments
    static let wisdomText = depthPurple
    
    // MARK: - Interface Elements
    
    /// Primary interactive elements and brand presence
    static let brandPrimary = insightGold
    
    /// Secondary interactive elements
    static let brandSecondary = growthGreen
    
    /// Error states and destructive actions
    static let errorState = sparkOrange
    
    /// Success states and positive feedback
    static let successState = growthGreen
    
    /// Warning states and important notifications
    static let warningState = sparkOrange
    
    /// Information and neutral states
    static let infoState = reflectionGray
    
    // MARK: - Text Hierarchy
    
    /// Primary text on light backgrounds
    static let textPrimary = sonoraDep
    
    /// Secondary text and metadata
    static let textSecondary = reflectionGray
    
    /// Text on dark or colored backgrounds
    static let textOnColored = clarityWhite
    
    /// Subtle text for tertiary information
    static let textTertiary = reflectionGray.opacity(0.7)
    
    // MARK: - Backgrounds
    
    /// Primary background - uses system adaptation with Clarity White preference
    static let backgroundPrimary = Color(UIColor.systemBackground)
    
    /// Secondary background for cards and sections
    static let backgroundSecondary = whisperBlue.opacity(0.3)
    
    /// Elevated content background
    static let backgroundElevated = clarityWhite
    
    /// Glass/frosted background effect
    static let backgroundGlass = reflectionGray.opacity(0.1)
}

// MARK: - Color Utilities

extension Color {
    
    /// Initialize Color from hex string
    /// - Parameter hexString: Hex color string (e.g., "#1A2332")
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Convert Color to hex string
    /// - Returns: Hex string representation (e.g., "#1A2332")
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)

        if components.count >= 4 {
            a = Float(components[3])
        }

        if a != Float(1.0) {
            return String(format: "%02lX%02lX%02lX%02lX",
                         lroundf(a * 255),
                         lroundf(r * 255),
                         lroundf(g * 255),
                         lroundf(b * 255))
        } else {
            return String(format: "#%02lX%02lX%02lX",
                         lroundf(r * 255),
                         lroundf(g * 255),
                         lroundf(b * 255))
        }
    }
}

// MARK: - Brand Color Theme

/// Central theme configuration for Sonora brand colors
struct SonoraBrandTheme {
    // Core brand colors
    let primary: Color
    let secondary: Color
    let accent: Color
    let background: Color
    let surface: Color
    let onPrimary: Color
    let onSurface: Color
    
    // Semantic mappings
    let recordingActive: Color
    let recordingInactive: Color
    let insightHighlight: Color
    let textPrimary: Color
    let textSecondary: Color
    
    /// Whether this theme uses dark appearance
    let isDark: Bool
    
    /// Designated initializer with sensible defaults for the light theme
    init(
        primary: Color = .insightGold,
        secondary: Color = .growthGreen,
        accent: Color = .sparkOrange,
        background: Color = .clarityWhite,
        surface: Color = .whisperBlue,
        onPrimary: Color = .sonoraDep,
        onSurface: Color = .sonoraDep,
        recordingActive: Color = .recordingActive,
        recordingInactive: Color = .recordingInactive,
        insightHighlight: Color = .insightHighlight,
        textPrimary: Color = .textPrimary,
        textSecondary: Color = .textSecondary,
        isDark: Bool = false
    ) {
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.background = background
        self.surface = surface
        self.onPrimary = onPrimary
        self.onSurface = onSurface
        self.recordingActive = recordingActive
        self.recordingInactive = recordingInactive
        self.insightHighlight = insightHighlight
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.isDark = isDark
    }
    
    /// Default Sonora brand theme (light)
    static let `default` = SonoraBrandTheme()
}

// MARK: - Preview Support

#if DEBUG
struct SonoraBrandColors_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                colorSection("Primary Palette", colors: [
                    ("Sonora Deep", Color.sonoraDep),
                    ("Clarity White", Color.clarityWhite),
                    ("Insight Gold", Color.insightGold)
                ])
                
                colorSection("Secondary Palette", colors: [
                    ("Reflection Gray", Color.reflectionGray),
                    ("Whisper Blue", Color.whisperBlue),
                    ("Growth Green", Color.growthGreen)
                ])
                
                colorSection("Accent Colors", colors: [
                    ("Spark Orange", Color.sparkOrange),
                    ("Depth Purple", Color.depthPurple)
                ])
                
                colorSection("Semantic Mappings", colors: [
                    ("Recording Active", Color.recordingActive),
                    ("Insight Highlight", Color.insightHighlight),
                    ("Brand Primary", Color.brandPrimary),
                    ("Success State", Color.successState)
                ])
            }
            .padding()
        }
        .previewDisplayName("Sonora Brand Colors")
    }
    
    static func colorSection(_ title: String, colors: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, colorInfo in
                    HStack {
                        Rectangle()
                            .fill(colorInfo.1)
                            .frame(width: 30, height: 30)
                            .cornerRadius(6)
                        
                        Text(colorInfo.0)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
#endif
