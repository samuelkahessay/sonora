import SwiftUI

// SwiftUI environment for injecting the active AppTheme
private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppTheme = LiquidGlassLightTheme()
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// Inject a custom theme for this view hierarchy.
    func theme(_ theme: AppTheme) -> some View {
        environment(\.theme, theme)
    }
}
