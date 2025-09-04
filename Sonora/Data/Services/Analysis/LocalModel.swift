import Foundation
import UIKit

/// Supported local LLM models with device compatibility checking
enum LocalModel: String, CaseIterable {
    case llama32_3B = "llama-3.2-3b-instruct"
    case qwen25_7B = "qwen2.5-7b-instruct"
    
    /// Display name for the model in the UI
    var displayName: String {
        switch self {
        case .llama32_3B:
            return "LLaMA 3.2 3B"
        case .qwen25_7B:
            return "Qwen2.5 7B Instruct"
        }
    }
    
    /// Download URL for the GGUF quantized model
    var downloadURL: URL {
        switch self {
        case .llama32_3B:
            return URL(string: "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf")!
        case .qwen25_7B:
            return URL(string: "https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/qwen2.5-7b-instruct-q4_k_m.gguf")!
        }
    }
    
    /// File name for the model when saved locally
    var modelFileName: String {
        switch self {
        case .llama32_3B:
            return "Llama-3.2-3B-Instruct-Q4_K_M.gguf"
        case .qwen25_7B:
            return "qwen2.5-7b-instruct-q4_k_m.gguf"
        }
    }
    
    /// Approximate download size
    var approximateSize: String {
        switch self {
        case .llama32_3B:
            return "~2GB"
        case .qwen25_7B:
            return "~4.7GB"
        }
    }
    
    /// Whether this model requires a high-end device (iPhone 15 Pro+)
    var requiresHighEndDevice: Bool {
        switch self {
        case .llama32_3B:
            return false  // Works on iPhone 12+
        case .qwen25_7B:
            return true   // iPhone 15 Pro+ only
        }
    }
    
    /// Check if the current device is compatible with this model
    var isDeviceCompatible: Bool {
        // All devices can run smaller models
        guard requiresHighEndDevice else { return true }
        
        // Check for iPhone 15 Pro or newer for large models
        let deviceModel = UIDevice.current.modelIdentifier
        let compatibleModels = [
            "iPhone16,1",  // iPhone 15 Pro
            "iPhone16,2",  // iPhone 15 Pro Max
            "iPhone17,1",  // iPhone 16 Pro
            "iPhone17,2",  // iPhone 16 Pro Max
        ]
        let isCompatibleModel = compatibleModels.contains { deviceModel.hasPrefix($0) }

        // Memory check: use our estimated capacity mapping (safer than raw physicalMemory),
        // and a decimal 8GB threshold to match Apple's marketing sizes.
        let estimatedBytes = UIDevice.current.estimatedRAMCapacity
        let requiredBytes: UInt64 = 8_000_000_000 // 8 GB (decimal)
        let hasEnoughMemory = estimatedBytes >= requiredBytes

        return isCompatibleModel && hasEnoughMemory
    }
    
    /// Incompatibility reason for display in UI
    var incompatibilityReason: String? {
        guard !isDeviceCompatible else { return nil }
        
        if requiresHighEndDevice {
            return "Requires iPhone 15 Pro or newer with 8GB RAM"
        }
        
        return nil
    }
    
    /// Path where the model should be stored locally
    var localPath: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelsDirectory = documentsPath.appendingPathComponent("models")
        
        // Create models directory if it doesn't exist
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
        return modelsDirectory.appendingPathComponent(modelFileName)
    }
    
    /// Check if the model is downloaded and available locally
    var isDownloaded: Bool {
        return FileManager.default.fileExists(atPath: localPath.path)
    }
    
    /// Initialize from string identifier (for UserDefaults persistence)
    init?(rawValue: String) {
        switch rawValue {
        case "llama-3.2-3b-instruct":
            self = .llama32_3B
        case "qwen2.5-7b-instruct":
            self = .qwen25_7B
        default:
            return nil
        }
    }
}

extension LocalModel {
    /// Default model for new installations
    static var defaultModel: LocalModel {
        return .llama32_3B
    }
    
    /// Get compatible models for the current device
    static var compatibleModels: [LocalModel] {
        return allCases.filter { $0.isDeviceCompatible }
    }
}
