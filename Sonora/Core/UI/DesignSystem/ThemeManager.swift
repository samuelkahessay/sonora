import SwiftUI
import Combine

final class ThemeManager: ObservableObject {
    // Theme settings
    @Published var mode: ThemeMode { didSet { persist() } }
    @Published var glassIntensity: GlassIntensity { didSet { persist() } }
    @Published var useGlassEffects: Bool { didSet { persist() } }
    @Published var reducedMotion: Bool { didSet { persist() } }
    @Published var accentColor: Color { didSet { persist() } }
    
    // Accessibility
    @Published var reducedTransparency: Bool = false
    
    init(
        mode: ThemeMode? = nil,
        glassIntensity: GlassIntensity? = nil,
        useGlassEffects: Bool? = nil,
        reducedMotion: Bool? = nil,
        accentColor: Color? = nil
    ) {
        let stored = ThemeManager.loadSettings()
        self.mode = mode ?? stored.mode
        self.glassIntensity = glassIntensity ?? stored.glassIntensity
        self.useGlassEffects = useGlassEffects ?? stored.useGlassEffects
        self.reducedMotion = reducedMotion ?? stored.reducedMotion
        self.accentColor = accentColor ?? stored.accentColor
        
        // Subscribe to accessibility changes
        setupAccessibilityObservers()
    }
    
    var activeTheme: AppTheme {
        // When in system mode, we return a theme based on what the system prefers
        // The actual color scheme is determined by SwiftUI based on the device settings
        switch mode {
        case .system:
            // Default to light theme for system mode, actual colors adapt via Color(UIColor.systemBackground)
            return useGlassEffects ? LiquidGlassLightTheme() : LightTheme()
        case .light:
            return useGlassEffects ? LiquidGlassLightTheme() : LightTheme()
        case .dark:
            return useGlassEffects ? LiquidGlassDarkTheme() : DarkTheme()
        }
    }
    
    var effectiveColorPalette: ColorPalette {
        switch mode {
        case .system:
            // This will be determined by the actual device settings
            return .light // Default, but system colors will adapt
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    var effectiveTypography: Typography {
        useGlassEffects ? .glass : .default
    }
    
    var effectiveAnimations: ThemeAnimations {
        reducedMotion ? .reduced : .standard
    }
    
    // Color scheme override for non-system modes
    var colorSchemeOverride: ColorScheme? {
        switch mode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    // MARK: - Actions
    
    func toggle() {
        switch mode {
        case .system: mode = .light
        case .light: mode = .dark
        case .dark: mode = .system
        }
    }
    
    func cycleGlassIntensity() {
        switch glassIntensity {
        case .minimal: glassIntensity = .moderate
        case .moderate: glassIntensity = .intense
        case .intense: glassIntensity = .minimal
        }
    }
    
    func resetToDefaults() {
        mode = .system
        glassIntensity = .moderate
        useGlassEffects = true
        reducedMotion = false
        accentColor = Color.blue
    }
    
    // MARK: - Accessibility
    
    private func setupAccessibilityObservers() {
        NotificationCenter.default.publisher(for: UIAccessibility.reduceTransparencyStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.reducedTransparency = UIAccessibility.isReduceTransparencyEnabled
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.reducedMotion = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)
        
        // Initial values
        reducedTransparency = UIAccessibility.isReduceTransparencyEnabled
        reducedMotion = UIAccessibility.isReduceMotionEnabled
    }
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Persistence
private extension ThemeManager {
    struct StoredSettings: Codable {
        let mode: ThemeMode
        let glassIntensity: GlassIntensity
        let useGlassEffects: Bool
        let reducedMotion: Bool
        let accentColorHex: String
    }
    
    static func loadSettings() -> (mode: ThemeMode, glassIntensity: GlassIntensity, useGlassEffects: Bool, reducedMotion: Bool, accentColor: Color) {
        guard let data = UserDefaults.standard.data(forKey: "app.theme.settings"),
              let settings = try? JSONDecoder().decode(StoredSettings.self, from: data) else {
            return (.system, .moderate, true, false, .blue)
        }
        
        let accentColor = Color(hex: settings.accentColorHex) ?? .blue
        return (settings.mode, settings.glassIntensity, settings.useGlassEffects, settings.reducedMotion, accentColor)
    }
    
    func persist() {
        let settings = StoredSettings(
            mode: mode,
            glassIntensity: glassIntensity,
            useGlassEffects: useGlassEffects,
            reducedMotion: reducedMotion,
            accentColorHex: accentColor.toHex() ?? "#007AFF"
        )
        
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "app.theme.settings")
        }
    }
}

// MARK: - Color Extensions
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
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
            return nil
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
    
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
