import Foundation

/// Factory for creating transcription services based on user preferences
@MainActor
final class TranscriptionServiceFactory {
    
    // MARK: - Properties
    
    fileprivate let downloadManager: ModelDownloadManager
    fileprivate let modelProvider: WhisperKitModelProvider
    private let logger = Logger.shared
    
    // Cached service instances for performance
    private var cloudService: TranscriptionAPI?
    private var localService: TranscriptionAPI?
    
    // MARK: - Initialization
    
    init(downloadManager: ModelDownloadManager, modelProvider: WhisperKitModelProvider) {
        self.downloadManager = downloadManager
        self.modelProvider = modelProvider
        logger.info("TranscriptionServiceFactory initialized")
    }
    
    // MARK: - Public Methods
    
    /// Creates the appropriate transcription service based on user preferences and availability
    /// - Returns: A transcription service ready for use
    func createTranscriptionService() -> TranscriptionAPI {
        let userPreference = UserDefaults.standard.selectedTranscriptionService
        // Reconcile install states before computing availability
        downloadManager.reconcileInstallStates()
        let selectedModel = UserDefaults.standard.selectedWhisperModelInfo
        let state = downloadManager.getDownloadState(for: selectedModel.id)
        let isSelectedInstalled = downloadManager.isModelAvailable(selectedModel.id)
        let installedIds = modelProvider.installedModelIds()
        let validInstalledIds = installedIds.filter { modelProvider.isModelValid(id: $0) }
        let anyInstalled = !validInstalledIds.isEmpty
        var effectiveService = UserDefaults.standard.getEffectiveTranscriptionService(downloadManager: downloadManager)
        
        // If user prefers local, allow any installed model to enable local service even when selected differs
        if userPreference == .localWhisperKit && effectiveService == .cloudAPI && anyInstalled {
            effectiveService = .localWhisperKit
            logger.warning("Selected local model not installed (id=\(selectedModel.id)); using available installed model(s): \(validInstalledIds)")
        }

        // If user prefers local but selected model is not installed, eagerly normalize the selection
        // to the first installed model to reduce confusion and align UI with actual behavior.
        if userPreference == .localWhisperKit && !isSelectedInstalled, let fallbackId = validInstalledIds.first {
            let previous = UserDefaults.standard.selectedWhisperModel
            UserDefaults.standard.selectedWhisperModel = fallbackId
            logger.info("Normalized selected Whisper model to installed fallback: \(fallbackId)")
            EventBus.shared.publish(.whisperModelNormalized(previous: previous, normalized: fallbackId))
        }
        
        logger.info("Creating transcription service - Preference: \(userPreference.displayName), Effective: \(effectiveService.displayName)")
        logger.debug("Local model availability — selectedId=\(selectedModel.id), state=\(state.displayName), selectedInstalled=\(isSelectedInstalled), installedIds=\(installedIds), validInstalledIds=\(validInstalledIds)")
        
        switch effectiveService {
        case .cloudAPI:
            return createCloudService()
        case .localWhisperKit:
            return createRoutedLocalService()
        }
    }
    
    /// Creates a transcription service with intelligent routing and fallback
    /// - Returns: A service that can route between local and cloud based on runtime conditions
    func createRoutedTranscriptionService() -> TranscriptionAPI {
        return RoutedTranscriptionService(factory: self)
    }
    
    /// Gets information about the current transcription service that would be used
    /// - Returns: Service info including type, availability, and any warnings
    func getCurrentServiceInfo() -> TranscriptionServiceInfo {
        let userPreference = UserDefaults.standard.selectedTranscriptionService
        let effectiveService = UserDefaults.standard.getEffectiveTranscriptionService(downloadManager: downloadManager)
        let isUsingPreferredService = userPreference == effectiveService
        
        var warnings: [String] = []
        var processingType: TranscriptionProcessingType = .unknown
        var estimatedSpeed: TranscriptionSpeed = .medium
        
        if !isUsingPreferredService {
            switch userPreference {
            case .cloudAPI:
                // This shouldn't happen since cloud is always available
                warnings.append("Cloud API unexpectedly unavailable")
            case .localWhisperKit:
                let selectedModel = UserDefaults.standard.selectedWhisperModelInfo
                let downloadState = downloadManager.getDownloadState(for: selectedModel.id)
                
                switch downloadState {
                case .notDownloaded:
                    warnings.append("Local model not downloaded, using cloud API instead")
                case .downloading:
                    warnings.append("Local model still downloading, using cloud API temporarily")
                case .failed:
                    warnings.append("Local model download failed, using cloud API instead")
                case .downloaded:
                    warnings.append("Local model downloaded but unavailable, using cloud API")
                case .stale:
                    warnings.append("Local model download stuck, using cloud API instead")
                }
            }
        }
        
        // Determine processing characteristics
        switch effectiveService {
        case .cloudAPI:
            processingType = .networkBased
            estimatedSpeed = .fast
        case .localWhisperKit:
            processingType = .localProcessing
            let selectedModel = UserDefaults.standard.selectedWhisperModelInfo
            estimatedSpeed = estimatedSpeedForModel(selectedModel)
        }
        
        return TranscriptionServiceInfo(
            userPreference: userPreference,
            effectiveService: effectiveService,
            isUsingPreferredService: isUsingPreferredService,
            warnings: warnings,
            processingType: processingType,
            estimatedSpeed: estimatedSpeed
        )
    }
    
    /// Gets real-time service status for active operations
    /// - Returns: Current operational status
    func getServiceStatus() -> TranscriptionServiceStatus {
        let info = getCurrentServiceInfo()
        let selectedModel = UserDefaults.standard.selectedWhisperModelInfo
        let modelDownloadState = downloadManager.getDownloadState(for: selectedModel.id)
        
        return TranscriptionServiceStatus(
            serviceInfo: info,
            modelDownloadState: modelDownloadState,
            isReady: info.effectiveService == .cloudAPI || modelDownloadState == .downloaded,
            fallbackAvailable: info.effectiveService == .localWhisperKit
        )
    }
    
    private func estimatedSpeedForModel(_ model: WhisperModelInfo) -> TranscriptionSpeed {
        switch model.speedRating {
        case .veryHigh: return .veryFast
        case .high: return .fast
        case .medium: return .medium
        case .low: return .slow
        }
    }
    
    /// Invalidates cached services (call when user changes preferences or models)
    func invalidateCache() {
        logger.info("Invalidating transcription service cache")
        cloudService = nil
        localService = nil
    }
    
    // MARK: - Private Methods
    
    fileprivate func createCloudService() -> TranscriptionAPI {
        if let cached = cloudService {
            return cached
        }
        
        logger.info("Creating cloud transcription service")
        let service = TranscriptionService()
        cloudService = service
        return service
    }
    
    fileprivate func createLocalService() -> TranscriptionAPI {
        if let cached = localService {
            return cached
        }
        
        logger.info("Creating local WhisperKit transcription service with model manager and adaptive router")
        let modelManager = DIContainer.shared.whisperKitModelManager()
        let modelRouter = AdaptiveModelRouter(modelProvider: modelProvider)
        let service = WhisperKitTranscriptionService(
            downloadManager: downloadManager,
            modelProvider: modelProvider,
            modelManager: modelManager,
            modelRouter: modelRouter
        )
        // Prewarming is now handled by the model manager internally during first use
        localService = service
        return service
    }
    
    private func createRoutedLocalService() -> TranscriptionAPI {
        logger.info("Creating routed local transcription service with fallback")
        return RoutedTranscriptionService(factory: self, preferredService: .localWhisperKit)
    }
}

// MARK: - Service Information

/// Information about the current transcription service configuration
struct TranscriptionServiceInfo {
    let userPreference: TranscriptionServiceType
    let effectiveService: TranscriptionServiceType
    let isUsingPreferredService: Bool
    let warnings: [String]
    let processingType: TranscriptionProcessingType
    let estimatedSpeed: TranscriptionSpeed
    
    /// User-friendly description of the current service status
    var statusDescription: String {
        if isUsingPreferredService {
            return "Using \(effectiveService.displayName) as preferred"
        } else {
            return "Using \(effectiveService.displayName) (fallback from \(userPreference.displayName))"
        }
    }
}


// MARK: - Routed Transcription Service

/// Intelligent transcription service that routes between local and cloud based on runtime conditions
@MainActor
final class RoutedTranscriptionService: TranscriptionAPI {
    
    private let factory: TranscriptionServiceFactory
    private let preferredService: TranscriptionServiceType?
    private let logger = Logger.shared
    
    init(factory: TranscriptionServiceFactory, preferredService: TranscriptionServiceType? = nil) {
        self.factory = factory
        self.preferredService = preferredService
    }
    
    func transcribe(url: URL) async throws -> String {
        let response = try await transcribe(url: url, language: nil)
        return response.text
    }
    
    func transcribe(url: URL, language: String?) async throws -> TranscriptionResponse {
        logger.info("Starting routed transcription for: \(url.lastPathComponent)")
        
        let targetService = determineTargetService()
        logger.debug("Target service determined: \(targetService.displayName)")
        // Publish initial route decision
        if let memoId = CurrentTranscriptionContext.memoId {
            let bus = DIContainer.shared.eventBus()
            await MainActor.run { bus.publish(.transcriptionRouteDecided(memoId: memoId, route: targetService == .localWhisperKit ? "local" : "cloud", reason: nil)) }
        }
        
        do {
            let service = createServiceForType(targetService)
            let result = try await service.transcribe(url: url, language: language)
            
            logger.info("Routed transcription completed successfully using \(targetService.displayName)")
            return result
            
        } catch {
            logger.warning("Primary service \(targetService.displayName) failed: \(error.localizedDescription)")
            
            // Attempt fallback if primary was local
            if targetService == .localWhisperKit && shouldFallbackToCloud(error: error) {
                if AppConfiguration.shared.strictLocalWhisper {
                    logger.warning("Strict local whisper enabled; not falling back to Cloud API")
                    throw error
                }
                // Publish fallback route change
                if let memoId = CurrentTranscriptionContext.memoId {
                    let bus = DIContainer.shared.eventBus()
                    await MainActor.run { bus.publish(.transcriptionRouteDecided(memoId: memoId, route: "cloud", reason: error.localizedDescription)) }
                }
                logger.info("Attempting fallback to Cloud API")
                
                do {
                    let cloudService = factory.createCloudService()
                    let result = try await cloudService.transcribe(url: url, language: language)
                    
                    logger.info("Fallback transcription completed successfully using Cloud API")
                    return result
                    
                } catch let fallbackError {
                    logger.error("Fallback to Cloud API also failed: \(fallbackError.localizedDescription)")
                    // Re-throw the original error as it's more relevant
                    throw error
                }
            }
            
            throw error
        }
    }
    
    func transcribeChunks(segments: [VoiceSegment], audioURL: URL) async throws -> [ChunkTranscriptionResult] {
        return try await transcribeChunks(segments: segments, audioURL: audioURL, language: nil)
    }
    
    func transcribeChunks(segments: [VoiceSegment], audioURL: URL, language: String?) async throws -> [ChunkTranscriptionResult] {
        logger.info("Starting routed chunk transcription for \(segments.count) segments")
        
        let targetService = determineTargetService()
        logger.debug("Target service determined: \(targetService.displayName)")
        
        do {
            let service = createServiceForType(targetService)
            let results = try await service.transcribeChunks(segments: segments, audioURL: audioURL, language: language)
            
            logger.info("Routed chunk transcription completed successfully using \(targetService.displayName)")
            return results
            
        } catch {
            logger.warning("Primary service \(targetService.displayName) failed for chunk transcription: \(error.localizedDescription)")
            
            // Attempt fallback if primary was local
            if targetService == .localWhisperKit && shouldFallbackToCloud(error: error) {
                logger.info("Attempting chunk transcription fallback to Cloud API")
                
                do {
                    let cloudService = factory.createCloudService()
                    let results = try await cloudService.transcribeChunks(segments: segments, audioURL: audioURL, language: language)
                    
                    logger.info("Fallback chunk transcription completed successfully using Cloud API")
                    return results
                    
                } catch let fallbackError {
                    logger.error("Fallback to Cloud API also failed for chunks: \(fallbackError.localizedDescription)")
                    // Re-throw the original error as it's more relevant
                    throw error
                }
            }
            
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func determineTargetService() -> TranscriptionServiceType {
        // Use preferred service if specified and available
        if let preferred = preferredService {
            let isAvailable = factory.downloadManager.isModelAvailable(UserDefaults.standard.selectedWhisperModelInfo.id)
            if preferred == .localWhisperKit && isAvailable {
                return .localWhisperKit
            }
        }
        
        // Otherwise use effective service from user defaults
        return UserDefaults.standard.getEffectiveTranscriptionService(downloadManager: factory.downloadManager)
    }
    
    private func createServiceForType(_ type: TranscriptionServiceType) -> TranscriptionAPI {
        let base: any TranscriptionAPI
        switch type {
        case .cloudAPI:
            base = factory.createCloudService()
        case .localWhisperKit:
            base = factory.createLocalService()
        }
        let repo = DIContainer.shared.transcriptionRepository()
        return ReportingTranscriptionService(base: base, source: type, repo: repo)
    }
    
    private func shouldFallbackToCloud(error: Error) -> Bool {
        // Define conditions under which we should fallback to cloud
        if let whisperError = error as? WhisperKitTranscriptionError {
            switch whisperError {
            case .notInitialized, .initializationFailed, .modelNotAvailable:
                // These are initialization issues - fallback makes sense
                return true
            case .transcriptionFailed, .audioProcessingFailed:
                // These might be model-specific issues - could try fallback
                return true
            }
        }
        
        // For unknown errors, be conservative and try fallback
        return true
    }
}

// MARK: - Error Types

enum TranscriptionServiceError: LocalizedError {
    case serviceNotImplemented(String)
    case serviceUnavailable(String)
    case factoryError(String)
    
    var errorDescription: String? {
        switch self {
        case .serviceNotImplemented(let message):
            return "Service not implemented: \(message)"
        case .serviceUnavailable(let message):
            return "Service unavailable: \(message)"
        case .factoryError(let message):
            return "Factory error: \(message)"
        }
    }
}
