import Foundation

/// Centralized feature flags to control UI visibility and beta simplifications.
/// Toggle these for fast, reversible scope changes without deleting code.
enum FeatureFlags {
    // MARK: - Settings Sections Visibility
    static let showOnboarding: Bool = false
    static let showLanguage: Bool = false
    static let showAutoDetection: Bool = false

    /// Controls showing WhisperKit model management, selection, diagnostics, and advanced UI
    static let showWhisperKitModelConfig: Bool = false

    // MARK: - Simplified UI Modes
    /// Use a single on/off toggle for transcription (Cloud vs Local)
    static let useSimplifiedTranscriptionUI: Bool = true

    /// Use a simplified Local AI section (fixed model text, no selection UI)
    static let useSimplifiedLocalAIUI: Bool = true

    /// Use the consolidated Settings layout (Processing, Data & Privacy, About)
    /// Enabled by default for Development and TestFlight builds. App Store can opt-in via env/UD override.
    static var useConsolidatedSettings: Bool {
        // Optional runtime overrides for quick testing
        if let env = ProcessInfo.processInfo.environment["SONORA_FF_USE_CONSOLIDATED"], let b = Bool(env) {
            return b
        }
        if let override = UserDefaults.standard.object(forKey: "ff_useConsolidatedSettings") as? Bool {
            return override
        }
        switch BuildConfiguration.shared.distributionType {
        case .development: return true
        case .testFlight:  return true
        case .appStore:    return false
        }
    }
}
