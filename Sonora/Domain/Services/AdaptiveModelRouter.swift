//
//  AdaptiveModelRouter.swift
//  Sonora
//
//  Multi-tier model routing for optimal cost/accuracy balance
//  Routes transcription to appropriate model size based on content complexity
//

import Foundation
import AVFoundation

/// Protocol for intelligent model routing decisions
protocol AdaptiveModelRouterProtocol: Sendable {
    func selectModel(for context: RoutingContext) -> ModelRoutingDecision
    func shouldRetryWithLargerModel(result: TranscriptionResponse, context: RoutingContext) -> Bool
}

/// Context information for making routing decisions
struct RoutingContext: Sendable {
    let audioURL: URL
    let audioDurationSeconds: TimeInterval
    let estimatedComplexity: AudioComplexity
    let userPreference: WhisperModelInfo
    let availableModels: [String] // IDs of downloaded models
    let batteryLevel: Float // -1 if unknown
    let thermalState: ProcessInfo.ThermalState
    let networkCondition: NetworkCondition
    
    enum AudioComplexity: Int, CaseIterable, Sendable {
        case simple = 1    // Clear speech, single speaker, quiet background
        case moderate = 2  // Some background noise or multiple speakers
        case complex = 3   // Noisy environment, accents, technical terms
        
        var description: String {
            switch self {
            case .simple: return "Simple"
            case .moderate: return "Moderate" 
            case .complex: return "Complex"
            }
        }
    }
    
    enum NetworkCondition: Sendable {
        case wifi
        case cellular
        case poor
        case offline
    }
}

/// Decision result from model routing
struct ModelRoutingDecision: Sendable {
    let selectedModel: WhisperModelInfo
    let rationale: String
    let fallbackModels: [WhisperModelInfo] // Ordered list of fallbacks
    let estimatedProcessingTime: TimeInterval
    let confidenceThreshold: Float // Threshold for retry logic
}

/// Intelligent model router that balances speed, accuracy, and resource usage
final class AdaptiveModelRouter: AdaptiveModelRouterProtocol, @unchecked Sendable {
    
    // MARK: - Configuration
    
    private struct RouterConfig {
        static let shortAudioThreshold: TimeInterval = 30.0 // seconds
        static let longAudioThreshold: TimeInterval = 300.0 // 5 minutes
        static let lowBatteryThreshold: Float = 0.2
        static let retryConfidenceThreshold: Float = 0.6
        static let maxModelSize: ModelSize = .small // Don't use medium unless explicitly selected
    }
    
    private enum ModelSize: Int, CaseIterable {
        case tiny = 39
        case base = 142
        case small = 488
        case medium = 1500
        
        var modelId: String {
            switch self {
            case .tiny: return "openai_whisper-tiny.en"
            case .base: return "openai_whisper-base.en" 
            case .small: return "openai_whisper-small"
            case .medium: return "openai_whisper-medium"
            }
        }
    }
    
    // MARK: - Dependencies
    
    private let logger: Logger
    private let modelProvider: WhisperKitModelProvider
    
    // MARK: - Initialization
    
    init(modelProvider: WhisperKitModelProvider) {
        self.modelProvider = modelProvider
        self.logger = Logger.shared
    }
    
    @MainActor
    convenience init() {
        self.init(modelProvider: WhisperKitModelProvider())
    }
    
    // MARK: - Routing Logic
    
    func selectModel(for context: RoutingContext) -> ModelRoutingDecision {
        logger.info("🎯 Routing model selection", 
                   category: .performance,
                   context: LogContext(additionalInfo: [
                       "duration": context.audioDurationSeconds,
                       "complexity": context.estimatedComplexity.description,
                       "battery": context.batteryLevel,
                       "thermal": context.thermalState.rawValue
                   ]))
        
        // Start with user preference but allow intelligent downgrade
        var targetModel = determineTargetModel(context: context)
        let availableModelInfos = context.availableModels.compactMap { WhisperModelInfo.model(withId: $0) }
        
        // Ensure the target model is available, fallback if needed
        if !availableModelInfos.contains(where: { $0.id == targetModel.id }) {
            targetModel = selectBestAvailableModel(from: availableModelInfos, context: context)
        }
        
        // Create fallback chain
        let fallbacks = createFallbackChain(primary: targetModel, available: availableModelInfos)
        
        // Estimate processing time
        let processingTime = estimateProcessingTime(
            model: targetModel,
            duration: context.audioDurationSeconds,
            complexity: context.estimatedComplexity
        )
        
        let rationale = buildRationale(
            selected: targetModel,
            context: context,
            processingTime: processingTime
        )
        
        logger.info("🎯 Model selected: \(targetModel.displayName)", 
                   category: .performance,
                   context: LogContext(additionalInfo: [
                       "rationale": rationale,
                       "processingTimeEst": processingTime,
                       "fallbackCount": fallbacks.count
                   ]))
        
        return ModelRoutingDecision(
            selectedModel: targetModel,
            rationale: rationale,
            fallbackModels: fallbacks,
            estimatedProcessingTime: processingTime,
            confidenceThreshold: RouterConfig.retryConfidenceThreshold
        )
    }
    
    func shouldRetryWithLargerModel(result: TranscriptionResponse, context: RoutingContext) -> Bool {
        // Retry conditions:
        // 1. Low confidence score
        // 2. Very short result for long audio (likely failed)
        // 3. Audio is important (long duration suggests intentional recording)
        
        let confidence = Float(result.confidence ?? 1.0)
        let hasLowConfidence = confidence < RouterConfig.retryConfidenceThreshold
        
        let transcriptionLength = result.text.trimmingCharacters(in: .whitespacesAndNewlines).count
        let expectedMinLength = Int(context.audioDurationSeconds * 2) // ~2 chars per second minimum
        let suspiciouslyShort = transcriptionLength < expectedMinLength && context.audioDurationSeconds > 15.0
        
        let isImportantAudio = context.audioDurationSeconds > RouterConfig.shortAudioThreshold
        
        let shouldRetry = (hasLowConfidence || suspiciouslyShort) && isImportantAudio
        
        if shouldRetry {
            logger.warning("🎯 Recommending retry with larger model",
                          category: .performance,
                          context: LogContext(additionalInfo: [
                              "confidence": confidence,
                              "textLength": transcriptionLength,
                              "expectedMinLength": expectedMinLength,
                              "audioDuration": context.audioDurationSeconds
                          ]))
        }
        
        return shouldRetry
    }
    
    // MARK: - Private Implementation
    
    private func determineTargetModel(context: RoutingContext) -> WhisperModelInfo {
        // Resource-constrained conditions favor smaller models
        let isResourceConstrained = (
            context.batteryLevel >= 0 && context.batteryLevel < RouterConfig.lowBatteryThreshold
        ) || context.thermalState.rawValue >= 2 // serious/critical
        
        let isShortAudio = context.audioDurationSeconds < RouterConfig.shortAudioThreshold
        let isLongAudio = context.audioDurationSeconds > RouterConfig.longAudioThreshold
        
        // Decision matrix:
        switch (context.estimatedComplexity, isResourceConstrained, isShortAudio, isLongAudio) {
        case (.simple, true, _, _):
            // Battery saving mode - always use tiny
            return WhisperModelInfo.model(withId: ModelSize.tiny.modelId) ?? context.userPreference
            
        case (.simple, false, true, false):
            // Short simple audio - tiny is fine
            return WhisperModelInfo.model(withId: ModelSize.tiny.modelId) ?? context.userPreference
            
        case (.simple, false, false, _):
            // Normal simple audio - base model
            return WhisperModelInfo.model(withId: ModelSize.base.modelId) ?? context.userPreference
            
        case (.moderate, true, _, _):
            // Resource constrained moderate - base model
            return WhisperModelInfo.model(withId: ModelSize.base.modelId) ?? context.userPreference
            
        case (.moderate, false, _, _):
            // Normal moderate audio - small model for better accuracy
            return WhisperModelInfo.model(withId: ModelSize.small.modelId) ?? context.userPreference
            
        case (.complex, _, _, _):
            // Complex audio always needs small+ model
            if context.userPreference.id.contains("medium") {
                return context.userPreference // Honor explicit medium selection
            } else {
                return WhisperModelInfo.model(withId: ModelSize.small.modelId) ?? context.userPreference
            }
        default:
            // Fallback case for any missed combinations
            return WhisperModelInfo.model(withId: ModelSize.base.modelId) ?? context.userPreference
        }
    }
    
    private func selectBestAvailableModel(from available: [WhisperModelInfo], context: RoutingContext) -> WhisperModelInfo {
        // Prefer models in order: small -> base -> tiny -> medium (medium last due to size)
        let preferenceOrder: [String] = [
            ModelSize.small.modelId,
            ModelSize.base.modelId, 
            ModelSize.tiny.modelId,
            ModelSize.medium.modelId
        ]
        
        for preferredId in preferenceOrder {
            if let model = available.first(where: { $0.id == preferredId }) {
                return model
            }
        }
        
        // Fallback to first available or user preference
        return available.first ?? context.userPreference
    }
    
    private func createFallbackChain(primary: WhisperModelInfo, available: [WhisperModelInfo]) -> [WhisperModelInfo] {
        // Create fallback order: smaller models first (faster recovery), then larger (accuracy recovery)
        let fallbackOrder: [String] = [
            ModelSize.tiny.modelId,
            ModelSize.base.modelId,
            ModelSize.small.modelId,
            ModelSize.medium.modelId
        ]
        
        return fallbackOrder.compactMap { id in
            available.first { $0.id == id && $0.id != primary.id }
        }
    }
    
    private func estimateProcessingTime(model: WhisperModelInfo, duration: TimeInterval, complexity: RoutingContext.AudioComplexity) -> TimeInterval {
        // Base processing multipliers (processing_time = audio_duration * multiplier)
        let baseMultiplier: Double
        switch model.speedRating {
        case .veryHigh: baseMultiplier = 0.1  // Tiny: ~6 seconds for 1 minute audio
        case .high:     baseMultiplier = 0.25 // Base: ~15 seconds for 1 minute audio  
        case .medium:   baseMultiplier = 0.5  // Small: ~30 seconds for 1 minute audio
        case .low:      baseMultiplier = 1.0  // Medium: ~60 seconds for 1 minute audio
        }
        
        // Complexity adjustments
        let complexityMultiplier: Double
        switch complexity {
        case .simple:   complexityMultiplier = 1.0
        case .moderate: complexityMultiplier = 1.3
        case .complex:  complexityMultiplier = 1.6
        }
        
        return duration * baseMultiplier * complexityMultiplier
    }
    
    private func buildRationale(selected: WhisperModelInfo, context: RoutingContext, processingTime: TimeInterval) -> String {
        var reasons: [String] = []
        
        // Primary reason
        switch context.estimatedComplexity {
        case .simple:
            reasons.append("Simple audio content")
        case .moderate:
            reasons.append("Moderate complexity detected")
        case .complex:
            reasons.append("Complex audio requires higher accuracy")
        }
        
        // Resource considerations
        if context.batteryLevel >= 0 && context.batteryLevel < RouterConfig.lowBatteryThreshold {
            reasons.append("Low battery (\(Int(context.batteryLevel * 100))%)")
        }
        
        if context.thermalState.rawValue >= 2 {
            reasons.append("Thermal throttling")
        }
        
        // Duration considerations
        if context.audioDurationSeconds < RouterConfig.shortAudioThreshold {
            reasons.append("Short audio (\(Int(context.audioDurationSeconds))s)")
        } else if context.audioDurationSeconds > RouterConfig.longAudioThreshold {
            reasons.append("Long audio (\(Int(context.audioDurationSeconds))s)")
        }
        
        let reasonText = reasons.joined(separator: ", ")
        return "\(selected.displayName) model selected - \(reasonText). Est. processing: \(Int(processingTime))s"
    }
}

// MARK: - Audio Complexity Analysis

/// Utility for analyzing audio complexity from file characteristics
enum AudioComplexityAnalyzer {
    
    /// Analyze audio file to estimate transcription complexity
    /// - Parameter url: Audio file URL
    /// - Returns: Estimated complexity level
    static func analyzeComplexity(audioURL: URL) async -> RoutingContext.AudioComplexity {
        // For now, use simple heuristics based on file characteristics
        // Future: Could analyze actual audio features (SNR, spectral analysis, etc.)
        
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            let fileSize = (fileAttributes[.size] as? NSNumber)?.intValue ?? 0
            
            // Get audio duration if available
            let asset = AVURLAsset(url: audioURL)
            let duration = try await asset.load(.duration).seconds
            
            // Simple heuristic: larger files relative to duration suggest higher quality/complexity
            let bytesPerSecond = duration > 0 ? Double(fileSize) / duration : 0
            
            // Thresholds based on typical voice memo characteristics
            switch bytesPerSecond {
            case 0..<8000:      return .simple    // Low bitrate, likely clear speech
            case 8000..<20000:  return .moderate  // Medium bitrate, some complexity
            default:            return .complex   // High bitrate, high complexity
            }
            
        } catch {
            // Default to moderate if analysis fails
            return .moderate
        }
    }
}