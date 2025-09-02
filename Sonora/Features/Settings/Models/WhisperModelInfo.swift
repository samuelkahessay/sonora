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
            id: "openai_whisper-tiny",
            displayName: "Tiny",
            size: "~40 MB",
            description: "Fastest processing, basic accuracy. Good for quick drafts and real-time use.",
            speedRating: .veryHigh,
            accuracyRating: .low
        ),
        
        WhisperModelInfo(
            id: "openai_whisper-base",
            displayName: "Base", 
            size: "~150 MB",
            description: "Balanced speed and accuracy. Recommended for most users.",
            speedRating: .high,
            accuracyRating: .medium
        ),
        
        WhisperModelInfo(
            id: "openai_whisper-small",
            displayName: "Small",
            size: "~500 MB", 
            description: "Good accuracy with moderate speed. Better for important transcriptions.",
            speedRating: .medium,
            accuracyRating: .high
        ),
        
        WhisperModelInfo(
            id: "openai_whisper-medium",
            displayName: "Medium",
            size: "~1.5 GB",
            description: "High accuracy, slower processing. Best for professional use.",
            speedRating: .low,
            accuracyRating: .veryHigh
        )
    ]
    
    /// Default model recommendation
    static let defaultModel = availableModels[1] // Base model
    
    /// Find model by ID
    static func model(withId id: String) -> WhisperModelInfo? {
        return availableModels.first { $0.id == id }
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    private static let whisperModelKey = "selectedWhisperModel"
    
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
}