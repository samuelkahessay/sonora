import Combine
import SwiftUI

enum ThemeMode: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }
}

@MainActor
final class ThemeManager: ObservableObject {
    // Minimal theme settings
    @Published var mode: ThemeMode { didSet { persist() } }
    @Published var useGlassEffects: Bool { didSet { persist() } }
    @Published var reducedMotion: Bool { didSet { persist() } }
    @Published var accentColor: Color { didSet { persist() } }

    init(
        mode: ThemeMode? = nil,
        useGlassEffects: Bool? = nil,
        reducedMotion: Bool? = nil,
        accentColor: Color? = nil
    ) {
        let stored = Self.loadSettings()
        self.mode = mode ?? stored.mode
        self.useGlassEffects = useGlassEffects ?? stored.useGlassEffects
        self.reducedMotion = reducedMotion ?? stored.reducedMotion
        self.accentColor = accentColor ?? stored.accentColor

        // Subscribe to accessibility changes
        setupAccessibilityObservers()
    }

    // MARK: - Accessibility

    private func setupAccessibilityObservers() {
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reducedMotion = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)

        // Initial value
        reducedMotion = UIAccessibility.isReduceMotionEnabled
    }

    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Persistence
private extension ThemeManager {
    struct StoredSettings: Codable {
        let mode: ThemeMode
        let useGlassEffects: Bool
        let reducedMotion: Bool
        let accentColorHex: String
    }

    struct LoadedSettings {
        let mode: ThemeMode
        let useGlassEffects: Bool
        let reducedMotion: Bool
        let accentColor: Color
    }

    static func loadSettings() -> LoadedSettings {
        guard let data = UserDefaults.standard.data(forKey: "app.theme.settings"),
              let settings = try? JSONDecoder().decode(StoredSettings.self, from: data) else {
            return LoadedSettings(mode: .system, useGlassEffects: false, reducedMotion: false, accentColor: .blue)
        }

        let accentColor = Color(hexString: settings.accentColorHex)
        return LoadedSettings(mode: settings.mode, useGlassEffects: settings.useGlassEffects, reducedMotion: settings.reducedMotion, accentColor: accentColor)
    }

    func persist() {
        let settings = StoredSettings(
            mode: mode,
            useGlassEffects: useGlassEffects,
            reducedMotion: reducedMotion,
            accentColorHex: accentColor.toHex() ?? "#007AFF"
        )

        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "app.theme.settings")
        }
    }
}
