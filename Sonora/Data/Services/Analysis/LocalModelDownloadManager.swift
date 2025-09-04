import Foundation

/// Manages downloading and storage of multiple local LLM models
@MainActor
final class LocalModelDownloadManager: ObservableObject {
    static let shared = LocalModelDownloadManager()
    
    // Per-model download states
    @Published private var downloadStates: [LocalModel: ModelDownloadState] = [:]
    
    // Active downloads
    private var downloadTasks: [LocalModel: URLSessionDownloadTask] = [:]
    private var progressObservations: [LocalModel: NSKeyValueObservation] = [:]
    
    private struct ModelDownloadState {
        var isDownloading: Bool = false
        var downloadProgress: Float = 0.0
        var isModelReady: Bool = false
    }
    
    init() {
        // Initialize states for all models
        for model in LocalModel.allCases {
            downloadStates[model] = ModelDownloadState(isModelReady: model.isDownloaded)
        }
    }
    
    // MARK: - Public Interface
    
    /// Check if a model is currently downloading
    func isDownloading(_ model: LocalModel) -> Bool {
        return downloadStates[model]?.isDownloading ?? false
    }
    
    /// Get download progress for a model (0.0 to 1.0)
    func downloadProgress(for model: LocalModel) -> Float {
        return downloadStates[model]?.downloadProgress ?? 0.0
    }
    
    /// Check if a model is ready for use
    func isModelReady(_ model: LocalModel) -> Bool {
        return downloadStates[model]?.isModelReady ?? false
    }
    
    /// Get the local file path for a model if it exists
    func modelPath(for model: LocalModel) -> URL? {
        return model.isDownloaded ? model.localPath : nil
    }
    
    /// Download a specific model
    func downloadModel(_ model: LocalModel) {
        // Prevent duplicate downloads
        guard !isDownloading(model), !isModelReady(model) else { return }
        
        // Check device compatibility
        guard model.isDeviceCompatible else {
            print("❌ Device not compatible with \(model.displayName)")
            return
        }
        
        print("🔄 Starting download of \(model.displayName)")
        
        // Update state
        downloadStates[model]?.isDownloading = true
        downloadStates[model]?.downloadProgress = 0.0
        
        // Create download task
        let downloadTask = URLSession.shared.downloadTask(with: model.downloadURL) { [weak self] tempURL, response, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    print("❌ Download error for \(model.displayName): \(error)")
                    self.downloadStates[model]?.isDownloading = false
                    return
                }
                
                guard let tempURL = tempURL else {
                    print("❌ No temp URL for \(model.displayName)")
                    self.downloadStates[model]?.isDownloading = false
                    return
                }
                
                do {
                    let finalPath = model.localPath
                    
                    // Remove existing file if present
                    try? FileManager.default.removeItem(at: finalPath)
                    
                    // Move downloaded file to final location
                    try FileManager.default.moveItem(at: tempURL, to: finalPath)
                    
                    // Update state
                    self.downloadStates[model]?.isModelReady = true
                    self.downloadStates[model]?.isDownloading = false
                    self.downloadStates[model]?.downloadProgress = 1.0
                    
                    print("✅ \(model.displayName) downloaded successfully")
                    
                } catch {
                    print("❌ Failed to save \(model.displayName): \(error)")
                    self.downloadStates[model]?.isDownloading = false
                }
                
                // Clean up
                self.downloadTasks.removeValue(forKey: model)
                self.progressObservations[model]?.invalidate()
                self.progressObservations.removeValue(forKey: model)
            }
        }
        
        // Store task and observe progress
        downloadTasks[model] = downloadTask
        progressObservations[model] = downloadTask.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor in
                self?.downloadStates[model]?.downloadProgress = Float(progress.fractionCompleted)
            }
        }
        
        downloadTask.resume()
    }
    
    /// Cancel download for a specific model
    func cancelDownload(for model: LocalModel) {
        guard let downloadTask = downloadTasks[model] else { return }
        
        downloadTask.cancel()
        progressObservations[model]?.invalidate()
        
        downloadTasks.removeValue(forKey: model)
        progressObservations.removeValue(forKey: model)
        
        downloadStates[model]?.isDownloading = false
        downloadStates[model]?.downloadProgress = 0.0
        
        print("🔄 Cancelled download of \(model.displayName)")
    }
    
    /// Delete a downloaded model
    func deleteModel(_ model: LocalModel) {
        // Cancel any active download first
        cancelDownload(for: model)
        
        let modelPath = model.localPath
        
        do {
            try FileManager.default.removeItem(at: modelPath)
            downloadStates[model]?.isModelReady = false
            downloadStates[model]?.downloadProgress = 0.0
            print("🗑️ Deleted \(model.displayName)")
        } catch {
            print("❌ Failed to delete \(model.displayName): \(error)")
        }
    }
    
    /// Get download status summary for all models
    func getModelStatus() -> [(model: LocalModel, isDownloaded: Bool, isDownloading: Bool, progress: Float)] {
        return LocalModel.allCases.map { model in
            (
                model: model,
                isDownloaded: isModelReady(model),
                isDownloading: isDownloading(model),
                progress: downloadProgress(for: model)
            )
        }
    }
    
    /// Refresh model status (check file system)
    func refreshModelStatus() {
        for model in LocalModel.allCases {
            let isReady = model.isDownloaded
            downloadStates[model]?.isModelReady = isReady
            
            // If model was deleted externally, reset progress
            if !isReady && !isDownloading(model) {
                downloadStates[model]?.downloadProgress = 0.0
            }
        }
    }
    
    /// Get total disk space used by downloaded models
    func getTotalDiskSpaceUsed() -> UInt64 {
        var totalSize: UInt64 = 0
        
        for model in LocalModel.allCases where model.isDownloaded {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: model.localPath.path)
                if let fileSize = attributes[.size] as? UInt64 {
                    totalSize += fileSize
                }
            } catch {
                print("⚠️ Failed to get size for \(model.displayName): \(error)")
            }
        }
        
        return totalSize
    }
    
    /// Format file size for display
    func formatFileSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
