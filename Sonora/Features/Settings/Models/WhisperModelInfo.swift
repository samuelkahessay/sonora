import Foundation

/// Information about available WhisperKit models
struct WhisperModelInfo {
    let id: String
    let displayName: String
    let size: String
    let description: String
    let speedRating: ModelPerformance
    let accuracyRating: ModelPerformance
    
    enum ModelPerformance: String, CaseIterable {
        case low = "Low"
        case medium = "Medium" 
        case high = "High"
        case veryHigh = "Very High"
        
        var color: String {
            switch self {
            case .low: return "orange"
            case .medium: return "yellow" 
            case .high: return "green"
            case .veryHigh: return "blue"
            }
        }
    }
}

// MARK: - Available Models

extension WhisperModelInfo {
    
    /// Standard WhisperKit models available for local transcription
    static let availableModels: [WhisperModelInfo] = [
        WhisperModelInfo(
            id: "openai_whisper-large-v3",
            displayName: "Large v3",
            size: "~2.9 GB",
            description: "Maximum accuracy local model (largest).",
            speedRating: .low,
            accuracyRating: .veryHigh
        ),
        WhisperModelInfo(
            id: "openai_whisper-medium",
            displayName: "Medium",
            size: "~1.5 GB",
            description: "High accuracy. Heavier and slower; use on newer devices.",
            speedRating: .low,
            accuracyRating: .veryHigh
        ),
        WhisperModelInfo(
            id: "openai_whisper-small",
            displayName: "Small",
            size: "~488 MB",
            description: "Higher accuracy with moderate speed. Better for important transcriptions.",
            speedRating: .medium,
            accuracyRating: .high
        ),
        WhisperModelInfo(
            id: "openai_whisper-base.en",
            displayName: "Base (English)",
            size: "~142 MB",
            description: "English-only base model. Recommended for most English users.",
            speedRating: .high,
            accuracyRating: .medium
        ),
        WhisperModelInfo(
            id: "openai_whisper-base",
            displayName: "Base",
            size: "~142 MB",
            description: "Balanced speed and accuracy. Good general-purpose model.",
            speedRating: .high,
            accuracyRating: .medium
        ),
        WhisperModelInfo(
            id: "openai_whisper-tiny.en",
            displayName: "Tiny (English)",
            size: "~39 MB", 
            description: "English-only tiny model. Fastest option for English transcription.",
            speedRating: .veryHigh,
            accuracyRating: .low
        ),
        WhisperModelInfo(
            id: "openai_whisper-tiny",
            displayName: "Tiny",
            size: "~39 MB",
            description: "Fastest processing, basic accuracy. Good for quick drafts and real-time use.",
            speedRating: .veryHigh,
            accuracyRating: .low
        )
    ]
    
    /// Default model recommendation
    static var defaultModel: WhisperModelInfo {
        if FeatureFlags.useFixedModelsForBeta {
            return availableModels.first { $0.id == "openai_whisper-large-v3" } ?? availableModels.first!
        }
        return availableModels.first!
    }
    
    /// Find model by ID
    static func model(withId id: String) -> WhisperModelInfo? {
        return availableModels.first { $0.id == id }
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    private static let whisperModelKey = "selectedWhisperModel"
    private static let prefetchKey = "prefetchWhisperModelOnWiFi"
    
    var selectedWhisperModel: String {
        get {
            return string(forKey: Self.whisperModelKey) ?? WhisperModelInfo.defaultModel.id
        }
        set {
            set(newValue, forKey: Self.whisperModelKey)
        }
    }
    
    var selectedWhisperModelInfo: WhisperModelInfo {
        let modelId = selectedWhisperModel
        return WhisperModelInfo.model(withId: modelId) ?? WhisperModelInfo.defaultModel
    }

    /// Toggle to prefetch default Whisper model on Wi‑Fi
    var prefetchWhisperModelOnWiFi: Bool {
        get { bool(forKey: Self.prefetchKey) }
        set { set(newValue, forKey: Self.prefetchKey) }
    }
}
