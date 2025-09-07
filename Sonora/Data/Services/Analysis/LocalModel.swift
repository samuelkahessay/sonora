import Foundation
import UIKit

/// Supported local LLM models with device compatibility checking
enum LocalModel: String, CaseIterable {
    // Small, on-device friendly models (phones)
    case phi4_mini   = "phi-4-mini-instruct"        // 3.8B
    case llama32_3B  = "llama-3.2-3b-instruct"      // 3B
    case llama32_1B  = "llama-3.2-1b-instruct"      // 1B
    case gemma2_2B   = "gemma-2-2b-it"              // 2B
    case qwen25_3B   = "qwen2.5-3b-instruct"        // 3B
    case tinyllama_1B = "tinyllama-1.1b-chat"       // 1.1B
    
    /// Display name for the model in the UI
    var displayName: String {
        switch self {
        case .phi4_mini:
            return "Phi-4 Mini (3.8B)"
        case .llama32_3B:
            return "LLaMA 3.2 (3B)"
        case .llama32_1B:
            return "LLaMA 3.2 (1B)"
        case .gemma2_2B:
            return "Gemma 2 (2B)"
        case .qwen25_3B:
            return "Qwen2.5 (3B)"
        case .tinyllama_1B:
            return "TinyLlama (1.1B)"
        }
    }
    
    /// Candidate download URLs for the GGUF quantized model (verified or common mirrors)
    var candidateDownloadURLs: [URL] {
        switch self {
        case .phi4_mini:
            return [
                URL(string: "https://huggingface.co/bartowski/microsoft_Phi-4-mini-instruct-GGUF/resolve/main/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf?download=true")!
            ]
        case .llama32_3B:
            return [
                URL(string: "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf?download=true")!
            ]
        case .llama32_1B:
            return [
                URL(string: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf?download=true")!
            ]
        case .gemma2_2B:
            return [
                URL(string: "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf?download=true")!,
                URL(string: "https://huggingface.co/TheBloke/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf?download=true")!
            ]
        case .qwen25_3B:
            return [
                URL(string: "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf?download=true")!,
                URL(string: "https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf?download=true")!
            ]
        case .tinyllama_1B:
            return [
                URL(string: "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/TinyLlama-1.1B-Chat-v1.0-Q4_K_M.gguf?download=true")!,
                URL(string: "https://huggingface.co/bartowski/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/TinyLlama-1.1B-Chat-v1.0-Q4_K_M.gguf?download=true")!
            ]
        }
    }
    
    /// Candidate HF repositories to search for GGUF files (for sharded detection)
    var repoCandidates: [String] {
        switch self {
        case .phi4_mini:
            return ["bartowski/microsoft_Phi-4-mini-instruct-GGUF"]
        case .llama32_3B:
            return ["bartowski/Llama-3.2-3B-Instruct-GGUF"]
        case .llama32_1B:
            return ["bartowski/Llama-3.2-1B-Instruct-GGUF"]
        case .gemma2_2B:
            return ["bartowski/gemma-2-2b-it-GGUF", "TheBloke/gemma-2-2b-it-GGUF"]
        case .qwen25_3B:
            return ["Qwen/Qwen2.5-3B-Instruct-GGUF", "bartowski/Qwen2.5-3B-Instruct-GGUF"]
        case .tinyllama_1B:
            return ["TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF", "bartowski/TinyLlama-1.1B-Chat-v1.0-GGUF"]
        }
    }

    /// Preferred quantization suffix
    var preferredQuantization: String { "q4_k_m" }
    
    /// File name for the model when saved locally
    var modelFileName: String {
        switch self {
        case .phi4_mini:
            return "microsoft_Phi-4-mini-instruct-Q4_K_M.gguf"
        case .llama32_3B:
            return "Llama-3.2-3B-Instruct-Q4_K_M.gguf"
        case .llama32_1B:
            return "Llama-3.2-1B-Instruct-Q4_K_M.gguf"
        case .gemma2_2B:
            return "gemma-2-2b-it-Q4_K_M.gguf"
        case .qwen25_3B:
            return "qwen2.5-3b-instruct-q4_k_m.gguf"
        case .tinyllama_1B:
            return "TinyLlama-1.1B-Chat-v1.0-Q4_K_M.gguf"
        }
    }
    
    /// Approximate download size
    var approximateSize: String {
        switch self {
        case .phi4_mini:
            return "~2.2GB"
        case .llama32_3B:
            return "~1.9GB"
        case .llama32_1B:
            return "~1.2GB"
        case .gemma2_2B:
            return "~1.8GB"
        case .qwen25_3B:
            return "~2.6GB"
        case .tinyllama_1B:
            return "~0.8GB"
        }
    }
    
    /// The tier this model belongs to
    var tier: ModelTier {
        switch self {
        case .phi4_mini, .llama32_3B, .llama32_1B, .gemma2_2B, .qwen25_3B, .tinyllama_1B:
            return .fast
        }
    }
    
    /// Use case description for the model
    var useCaseDescription: String {
        switch self {
        case .phi4_mini:
            return "Latest Microsoft model with 128K context"
        case .llama32_3B:
            return "Reliable baseline for quick analysis"
        case .llama32_1B:
            return "Ultra-fast summaries with small footprint"
        case .gemma2_2B:
            return "Compact IT model with solid coherence"
        case .qwen25_3B:
            return "Qwen quality in a phone-friendly size"
        case .tinyllama_1B:
            return "Tiny fallback for very constrained devices"
        }
    }
    
    /// Performance badge emoji
    var performanceBadge: String {
        switch tier {
        case .fast:
            return "⚡"
        case .balanced:
            return "⚖️"
        }
    }
    
    /// Speed rating (1-5 bolts)
    var speedRating: Int {
        switch self {
        case .phi4_mini, .llama32_3B, .llama32_1B, .gemma2_2B, .qwen25_3B:
            return 5  // Very fast
        case .tinyllama_1B:
            return 5
        }
    }
    
    /// Quality rating (1-5 stars)
    var qualityRating: Int {
        switch self {
        case .phi4_mini:
            return 4  // Excellent for size
        case .llama32_3B:
            return 3  // Good baseline
        case .llama32_1B:
            return 2
        case .gemma2_2B:
            return 3
        case .qwen25_3B:
            return 4
        case .tinyllama_1B:
            return 1
        }
    }
    
    /// Whether this is a new model (shows NEW badge)
    var isNew: Bool {
        switch self {
        case .phi4_mini:
            return true  // Latest Microsoft model
        default:
            return false
        }
    }
    
    /// Minimum RAM required for this specific model (in bytes)
    var minRAMRequired: UInt64 {
        switch self {
        case .phi4_mini, .llama32_3B, .llama32_1B, .gemma2_2B, .qwen25_3B, .tinyllama_1B:
            return 3_000_000_000  // 3GB
        }
    }
    
    /// Whether this model requires a high-end device (iPhone 14+ Pro)
    var requiresHighEndDevice: Bool { false }
    
    /// Check if the current device is compatible with this model
    var isDeviceCompatible: Bool {
        // Avoid main-actor UIDevice; use physicalMemory
        let deviceRAM = ProcessInfo.processInfo.physicalMemory
        return deviceRAM >= minRAMRequired
    }
    
    /// Incompatibility reason for display in UI
    var incompatibilityReason: String? {
        guard !isDeviceCompatible else { return nil }
        
        let deviceRAM = ProcessInfo.processInfo.physicalMemory
        let requiredGB = Int(minRAMRequired / 1_000_000_000)
        let deviceGB = Int(deviceRAM / 1_000_000_000)
        
        return "Requires \(requiredGB)GB RAM (device has \(deviceGB)GB)"
    }
    
    /// Primary GGUF filename saved after a successful download (handles shard names)
    var savedPrimaryFileName: String? {
        UserDefaults.standard.string(forKey: "primaryGGUF_\(self.rawValue)")
    }

    /// Path where the model should be stored locally
    var localPath: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelsDirectory = documentsPath.appendingPathComponent("models")
        
        // Create models directory if it doesn't exist
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
        let primary = savedPrimaryFileName ?? modelFileName
        return modelsDirectory.appendingPathComponent(primary)
    }
    
    /// Check if the model is downloaded and available locally (basic size validation)
    var isDownloaded: Bool {
        let path = localPath.path
        guard FileManager.default.fileExists(atPath: path) else { return false }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attrs[.size] as? NSNumber {
            return size.uint64Value > 10_000_000 // >10MB to avoid partial/HTML files
        }
        return false
    }
    
    /// Initialize from string identifier (for UserDefaults persistence)
    init?(rawValue: String) {
        switch rawValue {
        case "phi-4-mini-instruct":
            self = .phi4_mini
        case "llama-3.2-3b-instruct":
            self = .llama32_3B
        case "llama-3.2-1b-instruct":
            self = .llama32_1B
        case "gemma-2-2b-it":
            self = .gemma2_2B
        case "qwen2.5-3b-instruct":
            self = .qwen25_3B
        case "tinyllama-1.1b-chat":
            self = .tinyllama_1B
        default:
            return nil
        }
    }
}

extension LocalModel {
    /// Default model for new installations (prefer latest/best model for device)
    static var defaultModel: LocalModel {
        // Prefer Phi-4 mini; fallback to LLaMA 3.2 3B
        return LocalModel.phi4_mini.isDeviceCompatible ? LocalModel.phi4_mini : LocalModel.llama32_3B
    }
    
    /// Get recommended model for the current device tier
    static var recommendedModel: LocalModel {
        return .phi4_mini
    }
    
    /// Get compatible models for the current device
    static var compatibleModels: [LocalModel] {
        return allCases.filter { $0.isDeviceCompatible }
    }
    
    /// Get models for a specific tier
    static func modelsForTier(_ tier: ModelTier) -> [LocalModel] {
        return allCases.filter { $0.tier == tier }
    }
    
    /// Get models grouped by tier
    static var modelsByTier: [ModelTier: [LocalModel]] {
        var grouped: [ModelTier: [LocalModel]] = [:]
        for tier in ModelTier.allCases { grouped[tier] = modelsForTier(tier) }
        return grouped
    }
}
