import Foundation
import Combine
import WhisperKit
import Network

/// Manager for downloading and tracking WhisperKit model downloads
@MainActor
final class ModelDownloadManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var downloadStates: [String: ModelDownloadState] = [:]
    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadErrors: [String: String] = [:]
    
    // MARK: - Properties
    
    private let logger = Logger.shared
    private let modelProvider: WhisperKitModelProvider
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private var pathMonitor: NWPathMonitor?
    private let pathQueue = DispatchQueue(label: "network.path.monitor")
    private let userDefaults = UserDefaults.standard
    private var downloadMetadata: [String: ModelDownloadMetadata] = [:]
    private var healthCheckTimer: Timer?
    
    // MARK: - Initialization
    
    init(provider: WhisperKitModelProvider) {
        self.modelProvider = provider
        loadDownloadStates()
        loadDownloadMetadata()
        cleanupStaleDownloads()  // Clean up before checking
        checkForStaleDownloads()
        setupPrefetchMonitorIfNeeded()
        startHealthCheckTimer()
        logger.info("ModelDownloadManager initialized")
    }
    
    deinit {
        healthCheckTimer?.invalidate()
        pathMonitor?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Gets the current download state for a model
    func getDownloadState(for modelId: String) -> ModelDownloadState {
        if modelProvider.isInstalled(modelId) { return .downloaded }
        return downloadStates[modelId] ?? .notDownloaded
    }
    
    /// Gets the current download progress for a model (0.0 to 1.0)
    func getDownloadProgress(for modelId: String) -> Double {
        return downloadProgress[modelId] ?? 0.0
    }
    
    /// Gets the current download error for a model
    func getDownloadError(for modelId: String) -> String? {
        return downloadErrors[modelId]
    }
    
    /// Starts downloading a model
    func downloadModel(_ modelId: String) {
        guard downloadStates[modelId] != .downloading else {
            logger.warning("Model \(modelId) is already downloading")
            return
        }

        logger.info("Starting download for model: \(modelId)")
        logger.warning("WhisperKit downloads may pause if app backgrounds; keep Sonora in foreground until complete.")
        
        // Get expected size from model info
        let expectedSize = WhisperModelInfo.model(withId: modelId)?.size
        let expectedBytes = estimatedSizeBytes(for: modelId)
        
        // Clear any previous errors
        downloadErrors.removeValue(forKey: modelId)
        
        // Create metadata
        let currentAttempts = downloadMetadata[modelId]?.attemptCount ?? 0
        let metadata = ModelDownloadMetadata(
            modelId: modelId,
            state: .downloading,
            attemptCount: currentAttempts + 1,
            expectedSizeBytes: expectedBytes
        )
        downloadMetadata[modelId] = metadata
        
        // Set initial state
        downloadStates[modelId] = .downloading
        downloadProgress[modelId] = 0.0
        saveDownloadMetadata(metadata)
        saveDownloadState(modelId: modelId, state: .downloading)
        
        // Start download task
        let task = Task {
            await performDownload(modelId: modelId)
        }
        
        downloadTasks[modelId] = task
    }
    
    /// Cancels an ongoing download
    func cancelDownload(for modelId: String) {
        logger.info("Cancelling download for model: \(modelId)")
        
        downloadTasks[modelId]?.cancel()
        downloadTasks.removeValue(forKey: modelId)
        
        downloadStates[modelId] = .notDownloaded
        downloadProgress.removeValue(forKey: modelId)
        downloadErrors.removeValue(forKey: modelId)
        downloadMetadata.removeValue(forKey: modelId)
        
        clearDownloadState(for: modelId)
    }
    
    /// Retries a failed download
    func retryDownload(for modelId: String) {
        logger.info("Retrying download for model: \(modelId)")
        downloadModel(modelId)
    }
    
    /// Forces a complete retry by clearing all cached state
    func forceRetryDownload(for modelId: String) {
        logger.info("Force retrying download for model: \(modelId) (clearing all state)")
        
        // Cancel any existing download
        cancelDownload(for: modelId)
        
        // Clear all cached state
        downloadMetadata.removeValue(forKey: modelId)
        clearDownloadState(for: modelId)
        
        // Start fresh download
        downloadModel(modelId)
    }
    
    /// Checks for and handles stale downloads
    private func checkForStaleDownloads() {
        for (modelId, metadata) in downloadMetadata {
            if metadata.isStale {
                logger.warning("Found stale download for model: \(modelId), marking as stale")
                downloadStates[modelId] = .stale
                downloadErrors[modelId] = "Download appears stuck (no progress for \(Int(metadata.timeElapsed/60)) minutes)"
            } else if metadata.state == .downloading {
                // Check if model was actually completed
                if modelProvider.isInstalled(modelId) {
                    logger.info("Found completed download that wasn't marked as finished: \(modelId)")
                    downloadStates[modelId] = .downloaded
                    downloadProgress[modelId] = 1.0
                    downloadErrors.removeValue(forKey: modelId)
                    
                    let completedMetadata = ModelDownloadMetadata(
                        modelId: metadata.modelId,
                        state: .downloaded,
                        startedAt: metadata.startedAt,
                        lastProgressUpdate: Date(),
                        attemptCount: metadata.attemptCount,
                        expectedSizeBytes: metadata.expectedSizeBytes,
                        currentProgress: 1.0,
                        errorMessage: nil
                    )
                    downloadMetadata[modelId] = completedMetadata
                    saveDownloadMetadata(completedMetadata)
                } else {
                    // Resume download if it was interrupted
                    logger.info("Resuming interrupted download for model: \(modelId)")
                    resumeDownload(for: modelId)
                }
            }
        }
    }
    
    /// Resumes an interrupted download
    private func resumeDownload(for modelId: String) {
        guard let metadata = downloadMetadata[modelId] else {
            logger.warning("No metadata found for resuming download: \(modelId)")
            downloadModel(modelId)
            return
        }
        
        // Check if we should give up after too many attempts
        if metadata.attemptCount >= 3 {
            logger.warning("Too many download attempts for \(modelId), marking as failed")
            downloadStates[modelId] = .failed
            downloadErrors[modelId] = "Download failed after \(metadata.attemptCount) attempts"
            return
        }
        
        logger.info("Resuming download for \(modelId) (attempt \(metadata.attemptCount + 1))")
        downloadModel(modelId)
    }
    
    /// Periodically checks for download timeouts
    func checkDownloadHealth() {
        for (modelId, metadata) in downloadMetadata {
            if metadata.state == .downloading {
                let timeStuck = Date().timeIntervalSince(metadata.lastProgressUpdate)
                if timeStuck > 3 * 60 { // 3 minutes without progress
                    logger.warning("Download timeout detected for \(modelId), marking as stale")
                    downloadStates[modelId] = .stale
                    downloadErrors[modelId] = "Download timeout (no progress for \(Int(timeStuck/60)) minutes)"
                }
            }
        }
    }

    /// Reconcile persisted states with actual installed files
    func reconcileInstallStates() {
        loadDownloadStates()
    }
    
    /// Starts periodic health checking
    private func startHealthCheckTimer() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkDownloadHealth()
            }
        }
    }
    
    /// Cleans up stale download states on app launch
    private func cleanupStaleDownloads() {
        let staleThreshold: TimeInterval = 5 * 60 // 5 minutes
        var cleanedCount = 0
        
        for (modelId, metadata) in downloadMetadata {
            if metadata.state == .downloading {
                let timeSinceStart = Date().timeIntervalSince(metadata.startedAt)
                if timeSinceStart > staleThreshold {
                    logger.info("Cleaning up stale download for \(modelId) (started \(Int(timeSinceStart/60)) minutes ago)")
                    downloadStates[modelId] = .notDownloaded
                    downloadProgress.removeValue(forKey: modelId)
                    downloadErrors.removeValue(forKey: modelId)
                    downloadMetadata.removeValue(forKey: modelId)
                    clearDownloadState(for: modelId)
                    cleanedCount += 1
                }
            }
        }
        
        if cleanedCount > 0 {
            logger.info("Cleaned up \(cleanedCount) stale download states")
        }
    }
    
    /// Manually clear all download states (for debugging)
    func clearAllDownloadStates() {
        logger.info("Clearing all download states")
        downloadStates.removeAll()
        downloadProgress.removeAll()
        downloadErrors.removeAll()
        downloadMetadata.removeAll()
        
        // Clear from UserDefaults
        for model in WhisperKitModelProvider.curatedModels {
            clearDownloadState(for: model.id)
        }
        
        // Reload fresh states
        loadDownloadStates()
    }

    /// Optionally prefetch the default model when on Wi‑Fi
    func maybePrefetchDefaultModelOnWiFi() {
        guard UserDefaults.standard.prefetchWhisperModelOnWiFi else { return }
        let defaultModelId = WhisperModelInfo.defaultModel.id
        guard !isModelAvailable(defaultModelId) else { return }
        logger.info("Prefetch is enabled. Monitoring Wi‑Fi to trigger prefetch.")
        setupPrefetchMonitorIfNeeded()
    }

    private func setupPrefetchMonitorIfNeeded() {
        guard UserDefaults.standard.prefetchWhisperModelOnWiFi else { return }
        if pathMonitor != nil { return }
        let monitor = NWPathMonitor()
        self.pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            if path.status == .satisfied && path.usesInterfaceType(.wifi) {
                Task { @MainActor in
                    let modelId = WhisperModelInfo.defaultModel.id
                    if !self.isModelAvailable(modelId) && self.downloadStates[modelId] != .downloading {
                        self.downloadModel(modelId)
                    }
                }
            }
        }
        monitor.start(queue: pathQueue)
    }
    
    /// Deletes a downloaded model
    func deleteModel(_ modelId: String) {
        logger.info("Deleting model: \(modelId)")
        
        // Cancel any ongoing download
        cancelDownload(for: modelId)
        Task {
            do {
                try await modelProvider.delete(id: modelId)
            } catch {
                self.logger.error("Failed deleting model files for \(modelId): \(error.localizedDescription)")
            }
            await MainActor.run {
                self.downloadStates[modelId] = .notDownloaded
                self.downloadProgress.removeValue(forKey: modelId)
                self.downloadErrors.removeValue(forKey: modelId)
                self.saveDownloadState(modelId: modelId, state: .notDownloaded)
            }
        }
    }
    
    /// Checks if a model is available for use
    func isModelAvailable(_ modelId: String) -> Bool {
        return modelProvider.isInstalled(modelId)
    }
    
    // MARK: - Private Methods
    
    private func performDownload(modelId: String) async {
        do {
            logger.info("Performing download for model: \(modelId)")

            try await modelProvider.download(id: modelId) { [weak self] p in
                guard let self = self else { return }
                Task { @MainActor in
                    self.downloadProgress[modelId] = p
                    
                    // Update metadata with progress
                    if var metadata = self.downloadMetadata[modelId] {
                        let updatedMetadata = ModelDownloadMetadata(
                            modelId: metadata.modelId,
                            state: .downloading,
                            startedAt: metadata.startedAt,
                            lastProgressUpdate: Date(),
                            attemptCount: metadata.attemptCount,
                            expectedSizeBytes: metadata.expectedSizeBytes,
                            currentProgress: p,
                            errorMessage: nil
                        )
                        self.downloadMetadata[modelId] = updatedMetadata
                        self.saveDownloadMetadata(updatedMetadata)
                    }
                    
                    self.logger.debug("Download progress for \(modelId): \(Int(p * 100))%")
                }
            }

            // Mark as completed
            await MainActor.run {
                self.downloadStates[modelId] = .downloaded
                self.downloadProgress[modelId] = 1.0
                
                // Update metadata for completion
                if var metadata = self.downloadMetadata[modelId] {
                    let completedMetadata = ModelDownloadMetadata(
                        modelId: metadata.modelId,
                        state: .downloaded,
                        startedAt: metadata.startedAt,
                        lastProgressUpdate: Date(),
                        attemptCount: metadata.attemptCount,
                        expectedSizeBytes: metadata.expectedSizeBytes,
                        currentProgress: 1.0,
                        errorMessage: nil
                    )
                    self.downloadMetadata[modelId] = completedMetadata
                    self.saveDownloadMetadata(completedMetadata)
                }
                
                self.saveDownloadState(modelId: modelId, state: .downloaded)
            }

            logger.info("Successfully downloaded model: \(modelId)")

        } catch {
            await MainActor.run {
                self.logger.error("Failed to download model \(modelId): \(error.localizedDescription)")
                self.downloadStates[modelId] = .failed
                self.downloadErrors[modelId] = error.localizedDescription
                
                // Update metadata for failure
                if var metadata = self.downloadMetadata[modelId] {
                    let failedMetadata = ModelDownloadMetadata(
                        modelId: metadata.modelId,
                        state: .failed,
                        startedAt: metadata.startedAt,
                        lastProgressUpdate: Date(),
                        attemptCount: metadata.attemptCount,
                        expectedSizeBytes: metadata.expectedSizeBytes,
                        currentProgress: metadata.currentProgress,
                        errorMessage: error.localizedDescription
                    )
                    self.downloadMetadata[modelId] = failedMetadata
                    self.saveDownloadMetadata(failedMetadata)
                }
                
                self.saveDownloadState(modelId: modelId, state: .failed)
            }
        }

        // Clean up task reference
        downloadTasks.removeValue(forKey: modelId)
    }
    
    // MARK: - Persistence
    
    private func loadDownloadStates() {
        let ids = WhisperKitModelProvider.curatedModels.map { $0.id }
        for id in ids {
            if modelProvider.isInstalled(id) {
                downloadStates[id] = .downloaded
                saveDownloadState(modelId: id, state: .downloaded)
            } else {
                let key = downloadStateKey(for: id)
                if let stateRawValue = userDefaults.object(forKey: key) as? String,
                   let state = ModelDownloadState(rawValue: stateRawValue) {
                    var reconciled = state
                    if state == .downloaded { reconciled = .notDownloaded }
                    if state == .downloading { reconciled = .notDownloaded }
                    downloadStates[id] = reconciled
                    if state == .downloaded || state == .downloading {
                        userDefaults.removeObject(forKey: key)
                        downloadProgress[id] = 0.0
                    }
                }
            }
        }
        logger.info("Reconciled download states; installed: \(downloadStates.filter { $0.value == .downloaded }.count)")
    }
    
    private func saveDownloadState(modelId: String, state: ModelDownloadState) {
        let key = downloadStateKey(for: modelId)
        userDefaults.set(state.rawValue, forKey: key)
        logger.debug("Saved download state for \(modelId): \(state.rawValue)")
    }
    
    private func downloadStateKey(for modelId: String) -> String {
        return "downloadState_\(modelId)"
    }
    
    private func downloadMetadataKey(for modelId: String) -> String {
        return "downloadMetadata_\(modelId)"
    }
    
    private func loadDownloadMetadata() {
        let ids = WhisperKitModelProvider.curatedModels.map { $0.id }
        for id in ids {
            let key = downloadMetadataKey(for: id)
            if let data = userDefaults.data(forKey: key),
               let metadata = try? JSONDecoder().decode(ModelDownloadMetadata.self, from: data) {
                downloadMetadata[id] = metadata
                // Restore progress from metadata
                downloadProgress[id] = metadata.currentProgress
                if let error = metadata.errorMessage {
                    downloadErrors[id] = error
                }
            }
        }
        logger.info("Loaded download metadata for \(downloadMetadata.count) models")
    }
    
    private func saveDownloadMetadata(_ metadata: ModelDownloadMetadata) {
        let key = downloadMetadataKey(for: metadata.modelId)
        if let data = try? JSONEncoder().encode(metadata) {
            userDefaults.set(data, forKey: key)
            logger.debug("Saved download metadata for \(metadata.modelId)")
        }
    }
    
    private func clearDownloadState(for modelId: String) {
        userDefaults.removeObject(forKey: downloadStateKey(for: modelId))
        userDefaults.removeObject(forKey: downloadMetadataKey(for: modelId))
        logger.debug("Cleared all download state for \(modelId)")
    }
    
    private func estimatedSizeBytes(for modelId: String) -> Int64? {
        return WhisperKitModelProvider.curatedModels.first { $0.id == modelId }?.sizeBytes
    }
}

// MARK: - Download States

enum ModelDownloadState: String, CaseIterable, Codable {
    case notDownloaded = "not_downloaded"
    case downloading = "downloading"
    case downloaded = "downloaded"
    case failed = "failed"
    case stale = "stale" // Download stuck or expired
    
    var displayName: String {
        switch self {
        case .notDownloaded: return "Not Downloaded"
        case .downloading: return "Downloading"
        case .downloaded: return "Downloaded"
        case .failed: return "Download Failed"
        case .stale: return "Download Stuck"
        }
    }
    
    var isActionable: Bool {
        switch self {
        case .notDownloaded, .failed, .stale: return true
        case .downloading, .downloaded: return false
        }
    }
}

// MARK: - Download Metadata

/// Enhanced metadata for download tracking and recovery
struct ModelDownloadMetadata: Codable {
    let modelId: String
    let state: ModelDownloadState
    let startedAt: Date
    let lastProgressUpdate: Date
    let attemptCount: Int
    let expectedSizeBytes: Int64?
    let currentProgress: Double
    let errorMessage: String?
    
    init(
        modelId: String,
        state: ModelDownloadState,
        startedAt: Date = Date(),
        lastProgressUpdate: Date = Date(),
        attemptCount: Int = 1,
        expectedSizeBytes: Int64? = nil,
        currentProgress: Double = 0.0,
        errorMessage: String? = nil
    ) {
        self.modelId = modelId
        self.state = state
        self.startedAt = startedAt
        self.lastProgressUpdate = lastProgressUpdate
        self.attemptCount = attemptCount
        self.expectedSizeBytes = expectedSizeBytes
        self.currentProgress = currentProgress
        self.errorMessage = errorMessage
    }
    
    var isStale: Bool {
        let stalePeriod: TimeInterval = 5 * 60 // 5 minutes
        return state == .downloading && Date().timeIntervalSince(lastProgressUpdate) > stalePeriod
    }
    
    var timeElapsed: TimeInterval {
        return Date().timeIntervalSince(startedAt)
    }
}

// MARK: - Download Errors

enum ModelDownloadError: LocalizedError {
    case networkError(String)
    case storageError(String)
    case modelNotFound(String)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .storageError(let message):
            return "Storage error: \(message)"
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        case .cancelled:
            return "Download was cancelled"
        }
    }
}
