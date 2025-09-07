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
}

