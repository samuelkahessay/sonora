import SwiftUI

protocol AppTheme {
    var palette: ColorPalette { get }
    var typography: Typography { get }
    var glassIntensity: GlassIntensity { get }
    var animations: ThemeAnimations { get }
}

// MARK: - Theme Mode
enum ThemeMode: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

// MARK: - Glass Intensity Settings
enum GlassIntensity: String, CaseIterable, Codable {
    case minimal = "minimal"
    case moderate = "moderate"
    case intense = "intense"
    
    var blurRadius: CGFloat {
        switch self {
        case .minimal: return 8
        case .moderate: return 14
        case .intense: return 20
        }
    }
    
    var materialOpacity: Double {
        switch self {
        case .minimal: return 0.65
        case .moderate: return 0.75
        case .intense: return 0.85
        }
    }
    
    var displayName: String {
        switch self {
        case .minimal: return "Subtle"
        case .moderate: return "Balanced"
        case .intense: return "Prominent"
        }
    }
}

// MARK: - Theme Animations
struct ThemeAnimations {
    let defaultAnimation: Animation
    let springAnimation: Animation
    let interactiveAnimation: Animation
    let shimmering: Bool
    let floating: Bool
    
    static let standard = ThemeAnimations(
        defaultAnimation: .easeInOut(duration: 0.3),
        springAnimation: .spring(response: 0.4, dampingFraction: 0.75),
        interactiveAnimation: .spring(response: 0.3, dampingFraction: 0.7),
        shimmering: true,
        floating: true
    )
    
    static let reduced = ThemeAnimations(
        defaultAnimation: .linear(duration: 0.1),
        springAnimation: .linear(duration: 0.1),
        interactiveAnimation: .linear(duration: 0.1),
        shimmering: false,
        floating: false
    )
}

// MARK: - Liquid Glass Light Theme
struct LiquidGlassLightTheme: AppTheme {
    let palette: ColorPalette = .light
    let typography: Typography = .glass
    let glassIntensity: GlassIntensity = .moderate
    let animations: ThemeAnimations = .standard
}

// MARK: - Liquid Glass Dark Theme
struct LiquidGlassDarkTheme: AppTheme {
    let palette: ColorPalette = .dark
    let typography: Typography = .glass
    let glassIntensity: GlassIntensity = .moderate
    let animations: ThemeAnimations = .standard
}

// MARK: - Legacy Support
struct LightTheme: AppTheme {
    let palette: ColorPalette = .light
    let typography: Typography = .default
    let glassIntensity: GlassIntensity = .minimal
    let animations: ThemeAnimations = .standard
}

struct DarkTheme: AppTheme {
    let palette: ColorPalette = .dark
    let typography: Typography = .default
    let glassIntensity: GlassIntensity = .minimal
    let animations: ThemeAnimations = .standard
}

// Theme environment is defined in ThemeEnvironment.swift
