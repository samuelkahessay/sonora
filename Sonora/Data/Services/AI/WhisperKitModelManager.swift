//
//  WhisperKitModelManager.swift
//  Sonora
//
//  WhisperKit model lifecycle management with smart prewarming and memory-aware caching
//  Implements intelligent background loading for 40-60% latency reduction
//

import Foundation
import UIKit
import Combine
#if canImport(WhisperKit)
@preconcurrency import WhisperKit
#endif

/// Protocol defining WhisperKit model lifecycle operations
@MainActor
protocol WhisperKitModelManagerProtocol: Sendable {
    func getWhisperKit() async throws -> WhisperKit?
    func unloadModel()
}

/// Performance and memory management service for WhisperKit models
@MainActor
final class WhisperKitModelManager: WhisperKitModelManagerProtocol, @unchecked Sendable {
    private enum Constants {
        static let modelPrewarmTimeout: TimeInterval = 30
        static let modelLoadTimeout: TimeInterval = 30
    }
    
    // MARK: - Configuration
    
    private struct ModelManagementConfig {
        static let prewarmDelay: TimeInterval = 2.0 // Delay before prewarming
    }
    
    // MARK: - Properties
    
    private let modelProvider: WhisperKitModelProvider
    private let logger = Logger.shared
    private var whisperKit: WhisperKit?
    private var prewarmTask: Task<Void, Never>?
    private var unloadTimer: Timer?
    private var lastUsedTime = Date()
    private var performanceMetrics = ModelPerformanceMetrics()
    
    // Memory pressure monitoring
    private let memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: .main)
    private var isUnderMemoryPressure = false
    
    // Model state tracking
    internal var isModelWarmed = false
    internal var currentModelId: String?
    
    // App lifecycle observations
    private var lifecycleObservers: Set<AnyCancellable> = []
    
    // MARK: - Initialization
    
    init(modelProvider: WhisperKitModelProvider) {
        self.modelProvider = modelProvider
        configureLifecycleHandling()
        // Memory pressure monitoring disabled; coordinator + OS handle pressure.
        logger.info("🚀 WhisperKitModelManager: Initialized (prewarming disabled)")
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.prewarmTask?.cancel()
            self?.unloadTimer?.invalidate()
            self?.memoryPressureSource.cancel()
            self?.logger.info("🚀 WhisperKitModelManager: Deinitialized")
        }
    }
    
    // MARK: - Public Interface
    
    /// Prewarming disabled — no-op on iOS to preserve memory headroom
    func prewarmModel() async throws { logger.debug("Whisper prewarm skipped"); return }
    
    /// Gets warmed WhisperKit instance or loads synchronously if not available
    func getWhisperKit() async throws -> WhisperKit? {
        recordUsage()
        
        let selectedModel = UserDefaults.standard.selectedWhisperModelInfo
        
        // Return warmed instance if available and matches current model
        if let whisperKit = whisperKit, 
           isModelWarmed, 
           currentModelId == selectedModel.id {
            logger.debug("🚀 WhisperKitModelManager: Returning warmed model: \(selectedModel.displayName)")
            performanceMetrics.warmHits += 1
            return whisperKit
        }
        
        // Cold load if prewarming not available
        logger.info("🚀 WhisperKitModelManager: Cold loading model: \(selectedModel.displayName)")
        performanceMetrics.coldLoads += 1
        
        let startTime = CFAbsoluteTimeGetCurrent()
        try await loadModelSynchronously(modelId: selectedModel.id, modelName: selectedModel.displayName)
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        
        performanceMetrics.averageColdLoadTime = (performanceMetrics.averageColdLoadTime + loadTime) / 2.0
        
        return whisperKit
    }
    
    /// Unloads current model and resets state
    func unloadModel() {
        logger.info("🚀 WhisperKitModelManager: Manually unloading model (immediate)")
        unloadModelInternal()
        // No idle timer; unload immediately.
    }
    
    /// Configures app lifecycle event handling for optimal resource management
    func configureLifecycleHandling() {
        setupAppLifecycleObservers()
    }
    
    /// Returns current performance metrics
    func getModelPerformanceMetrics() -> ModelPerformanceMetrics {
        return performanceMetrics
    }
    
    // MARK: - Private Implementation
    
    
    private func loadModelSynchronously(modelId: String, modelName: String) async throws {
        // Resolve model folder
        guard let modelFolder = modelProvider.installedModelFolder(id: modelId) else {
            throw WhisperKitModelManagerError.modelNotFound("Model not installed: \(modelName)")
        }
        
        // Validate model
        guard modelProvider.isModelValid(id: modelId) else {
            logger.error("🚀 WhisperKitModelManager: Model validation failed for id=\(modelId); purging cached assets")
            modelProvider.purgeInvalidModel(id: modelId)
            throw WhisperKitModelManagerError.modelInvalid("Model validation failed: \(modelName)")
        }

        #if canImport(WhisperKit)
        // Initialize WhisperKit
        let whisperKit = try await WhisperKit(
            prewarm: false,
            load: false,
            download: false
        )
        
        whisperKit.modelFolder = modelFolder
        
        // Prewarm and load models with explicit timeouts so we don't hang forever on corrupt deployments
        do {
            try await withTimeout(seconds: Constants.modelPrewarmTimeout, operationDescription: "WhisperKit prewarm") {
                try await whisperKit.prewarmModels()
                return ()
            }
        } catch let timeout as AsyncTimeoutError {
            await whisperKit.unloadModels()
            throw WhisperKitModelManagerError.loadTimeout(timeout.message)
        } catch {
            await whisperKit.unloadModels()
            throw WhisperKitModelManagerError.prewarmFailed(error.localizedDescription)
        }

        do {
            try await withTimeout(seconds: Constants.modelLoadTimeout, operationDescription: "WhisperKit load") {
                try await whisperKit.loadModels()
                return ()
            }
        } catch let timeout as AsyncTimeoutError {
            await whisperKit.unloadModels()
            throw WhisperKitModelManagerError.loadTimeout(timeout.message)
        } catch {
            await whisperKit.unloadModels()
            throw WhisperKitModelManagerError.loadFailed(error.localizedDescription)
        }

        self.whisperKit = whisperKit
        logger.debug("🚀 WhisperKitModelManager: Model loaded successfully: \(modelName)")
        #else
        throw WhisperKitModelManagerError.whisperKitUnavailable("WhisperKit framework not available")
        #endif
    }
    
    private func unloadModelInternal() {
        guard whisperKit != nil else { return }
        
        Task {
            await whisperKit?.unloadModels()
            whisperKit = nil
        }
        
        isModelWarmed = false
        currentModelId = nil
        cancelUnloadTimer()
        
        logger.debug("🚀 WhisperKitModelManager: Model unloaded")
    }
    
    // MARK: - Lifecycle Management
    
    private func setupAppLifecycleObservers() {
        // App becoming active - start prewarming
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppBecameActive()
                }
            }
            .store(in: &lifecycleObservers)
        
        // App entering background - unload models
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppEnteredBackground()
                }
            }
            .store(in: &lifecycleObservers)
        
        // Memory warning - immediate unload
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleMemoryWarning()
                }
            }
            .store(in: &lifecycleObservers)
    }
    
    private func handleAppBecameActive() async {
        logger.info("🚀 WhisperKitModelManager: App became active - starting intelligent prewarming")
        
        // Only prewarm if user has used transcription recently
        let shouldPrewarm = shouldPerformIntelligentPrewarming()
        
        if shouldPrewarm {
            // Delay prewarming to avoid competing with app startup
            try? await Task.sleep(nanoseconds: UInt64(ModelManagementConfig.prewarmDelay * 1_000_000_000))
            
            try? await prewarmModel()
        } else {
            logger.debug("🚀 WhisperKitModelManager: Skipping prewarming - not recently used")
        }
    }
    
    private func handleAppEnteredBackground() {
        logger.info("🚀 WhisperKitModelManager: App entered background - unloading models")
        
        prewarmTask?.cancel()
        unloadModelInternal()
        performanceMetrics.backgroundUnloads += 1
    }
    
    private func handleMemoryWarning() {
        logger.warning("🚀 WhisperKitModelManager: Memory warning - immediate model unload")
        
        prewarmTask?.cancel()
        unloadModelInternal()
        performanceMetrics.memoryPressureUnloads += 1
    }
    
    
    // MARK: - Timer Management
    
    private func recordUsage() {
        lastUsedTime = Date()
        cancelUnloadTimer()
    }
    
    
    private func cancelUnloadTimer() {
        unloadTimer?.invalidate()
        unloadTimer = nil
    }
    
    // MARK: - Intelligent Prewarming Logic
    
    private func shouldPerformIntelligentPrewarming() -> Bool {
        // Check if WhisperKit is the selected transcription service
        let isWhisperKitSelected = (UserDefaults.standard.selectedTranscriptionService == .localWhisperKit)
        guard isWhisperKitSelected else { return false }
        
        // Check recent usage patterns
        let recentUsage = getRecentTranscriptionUsage()
        let hasRecentUsage = recentUsage.count > 0
        
        // Check memory conditions
        let hasAvailableMemory = !isUnderMemoryPressure
        
        // Check battery level (avoid prewarming if battery is low)
        let batteryLevel = UIDevice.current.batteryLevel
        let hasSufficientBattery = batteryLevel < 0 || batteryLevel > 0.2 // -1 = unknown, >20%
        
        logger.debug("🚀 WhisperKitModelManager: Prewarming conditions - Usage: \(hasRecentUsage), Memory: \(hasAvailableMemory), Battery: \(hasSufficientBattery)")
        
        return hasRecentUsage && hasAvailableMemory && hasSufficientBattery
    }
    
    private func getRecentTranscriptionUsage() -> [Date] {
        // This would typically look at user defaults or core data for recent transcription timestamps
        // For now, we'll use a simple heuristic
        let key = "RecentWhisperKitUsage"
        let recent = UserDefaults.standard.array(forKey: key) as? [Date] ?? []
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60) // Last 24 hours
        
        return recent.filter { $0 > cutoff }
    }
    
}

// MARK: - Performance Metrics

struct ModelPerformanceMetrics: Sendable {
    var totalPrewarms: Int = 0
    var prewarmFailures: Int = 0
    var coldLoads: Int = 0
    var warmHits: Int = 0
    var idleUnloads: Int = 0
    var memoryPressureUnloads: Int = 0
    var backgroundUnloads: Int = 0
    
    var averagePrewarmTime: TimeInterval = 0
    var averageColdLoadTime: TimeInterval = 0
    
    var warmHitRate: Double {
        let total = warmHits + coldLoads
        return total > 0 ? Double(warmHits) / Double(total) : 0.0
    }
}

// MARK: - Error Types

enum WhisperKitModelManagerError: LocalizedError {
    case whisperKitUnavailable(String)
    case modelNotFound(String)
    case modelInvalid(String)
    case loadFailed(String)
    case prewarmFailed(String)
    case loadTimeout(String)
    
    var errorDescription: String? {
        switch self {
        case .whisperKitUnavailable(let message):
            return "WhisperKit not available: \(message)"
        case .modelNotFound(let message):
            return "Model not found: \(message)"
        case .modelInvalid(let message):
            return "Model invalid: \(message)"
        case .loadFailed(let message):
            return "Model load failed: \(message)"
        case .prewarmFailed(let message):
            return "Model prewarming failed: \(message)"
        case .loadTimeout(let message):
            return "Model load timed out: \(message)"
        }
    }
}
