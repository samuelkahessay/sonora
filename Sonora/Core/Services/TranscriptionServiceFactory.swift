import Foundation

/// Factory for creating transcription services based on user preferences
@MainActor
final class TranscriptionServiceFactory {
    private static var didWarnMissingSelectedModel: Bool = false
    private static var didInfoNormalizedModel: Bool = false
    
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
            if !Self.didWarnMissingSelectedModel {
                logger.warning("Selected local model not installed (id=\(selectedModel.id)); using available installed model(s): \(validInstalledIds)")
                Self.didWarnMissingSelectedModel = true
            } else {
                logger.debug("Selected local model not installed; using installed model(s): \(validInstalledIds)")
            }
        }

        // If user prefers local but selected model is not installed, eagerly normalize the selection
        // to the first installed model to reduce confusion and align UI with actual behavior.
        if userPreference == .localWhisperKit && !isSelectedInstalled, let fallbackId = validInstalledIds.first {
            let previous = UserDefaults.standard.selectedWhisperModel
            UserDefaults.standard.selectedWhisperModel = fallbackId
            if !Self.didInfoNormalizedModel {
                logger.info("Normalized selected Whisper model to installed fallback: \(fallbackId)")
                Self.didInfoNormalizedModel = true
            } else {
                logger.debug("Normalized selected Whisper model to installed fallback: \(fallbackId)")
            }
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
                    // Surface a clear reason for the UI; treat local failure as memory-related for on-device models
                    await MainActor.run { bus.publish(.transcriptionRouteDecided(memoId: memoId, route: "cloud", reason: "insufficient_memory")) }
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
    
    // Consolidated surface: callers perform chunking and call transcribe(url:language:) per chunk.
    
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

// Removed unused TranscriptionServiceError
