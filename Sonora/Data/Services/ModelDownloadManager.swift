import Foundation
import Combine
import WhisperKit

/// Manager for downloading and tracking WhisperKit model downloads
@MainActor
final class ModelDownloadManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var downloadStates: [String: ModelDownloadState] = [:]
    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadErrors: [String: String] = [:]
    
    // MARK: - Properties
    
    private let logger = Logger.shared
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Initialization
    
    init() {
        loadDownloadStates()
        logger.info("ModelDownloadManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// Gets the current download state for a model
    func getDownloadState(for modelId: String) -> ModelDownloadState {
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
        
        // Clear any previous errors
        downloadErrors.removeValue(forKey: modelId)
        
        // Set initial state
        downloadStates[modelId] = .downloading
        downloadProgress[modelId] = 0.0
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
        
        saveDownloadState(modelId: modelId, state: .notDownloaded)
    }
    
    /// Retries a failed download
    func retryDownload(for modelId: String) {
        logger.info("Retrying download for model: \(modelId)")
        downloadModel(modelId)
    }
    
    /// Deletes a downloaded model
    func deleteModel(_ modelId: String) {
        logger.info("Deleting model: \(modelId)")
        
        // Cancel any ongoing download
        cancelDownload(for: modelId)
        
        // TODO: Implement actual model deletion when WhisperKit provides the API
        // For now, just update the state
        downloadStates[modelId] = .notDownloaded
        downloadProgress.removeValue(forKey: modelId)
        downloadErrors.removeValue(forKey: modelId)
        
        saveDownloadState(modelId: modelId, state: .notDownloaded)
    }
    
    /// Checks if a model is available for use
    func isModelAvailable(_ modelId: String) -> Bool {
        return downloadStates[modelId] == .downloaded
    }
    
    // MARK: - Private Methods
    
    private func performDownload(modelId: String) async {
        do {
            logger.info("Performing download for model: \(modelId)")
            
            // Simulate progressive download with WhisperKit
            // In a real implementation, this would use WhisperKit's download methods
            try await simulateModelDownload(modelId: modelId)
            
            // Mark as completed
            downloadStates[modelId] = .downloaded
            downloadProgress[modelId] = 1.0
            saveDownloadState(modelId: modelId, state: .downloaded)
            
            logger.info("Successfully downloaded model: \(modelId)")
            
        } catch {
            logger.error("Failed to download model \(modelId): \(error.localizedDescription)")
            
            downloadStates[modelId] = .failed
            downloadErrors[modelId] = error.localizedDescription
            saveDownloadState(modelId: modelId, state: .failed)
        }
        
        // Clean up task reference
        downloadTasks.removeValue(forKey: modelId)
    }
    
    private func simulateModelDownload(modelId: String) async throws {
        // Simulate download progress for demo purposes
        // Replace this with actual WhisperKit download logic
        
        let progressSteps = 20
        let stepDelay = 0.2 // seconds
        
        for step in 1...progressSteps {
            // Check for cancellation
            try Task.checkCancellation()
            
            let progress = Double(step) / Double(progressSteps)
            downloadProgress[modelId] = progress
            
            logger.debug("Download progress for \(modelId): \(Int(progress * 100))%")
            
            // Add some variability to simulate real download
            let delay = stepDelay + Double.random(in: -0.1...0.1)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            // Simulate occasional errors for testing
            if step == 15 && modelId.contains("medium") && Bool.random() {
                throw ModelDownloadError.networkError("Simulated network error")
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadDownloadStates() {
        for model in WhisperModelInfo.availableModels {
            let key = downloadStateKey(for: model.id)
            if let stateRawValue = userDefaults.object(forKey: key) as? String,
               let state = ModelDownloadState(rawValue: stateRawValue) {
                downloadStates[model.id] = state
            }
        }
        logger.info("Loaded download states for \(downloadStates.count) models")
    }
    
    private func saveDownloadState(modelId: String, state: ModelDownloadState) {
        let key = downloadStateKey(for: modelId)
        userDefaults.set(state.rawValue, forKey: key)
        logger.debug("Saved download state for \(modelId): \(state.rawValue)")
    }
    
    private func downloadStateKey(for modelId: String) -> String {
        return "downloadState_\(modelId)"
    }
}

// MARK: - Download States

enum ModelDownloadState: String, CaseIterable {
    case notDownloaded = "not_downloaded"
    case downloading = "downloading"
    case downloaded = "downloaded"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .notDownloaded: return "Not Downloaded"
        case .downloading: return "Downloading"
        case .downloaded: return "Downloaded"
        case .failed: return "Download Failed"
        }
    }
    
    var isActionable: Bool {
        switch self {
        case .notDownloaded, .failed: return true
        case .downloading, .downloaded: return false
        }
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