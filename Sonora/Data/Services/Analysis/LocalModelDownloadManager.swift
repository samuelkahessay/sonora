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
        
        // Try to resolve correct file names (including shards) via HF API; fallback to static candidates
        Task {
            // Reset state
            await MainActor.run {
                self.downloadStates[model]?.isDownloading = true
                self.downloadStates[model]?.downloadProgress = 0.0
                self.downloadStates[model]?.isModelReady = false
            }

            if let plan = await self.resolveGGUFParts(for: model) {
                await self.downloadPartsSequentially(model: model, baseResolveURL: plan.base, filenames: plan.parts)
            } else {
                // Fallback: try simple single-file candidates sequentially
                self.attemptSimpleCandidates(model)
            }
        }
    }

    // MARK: - Resolution and Multi-part Download

    private struct ResolutionPlan { let base: String; let parts: [String] }

    /// Queries HuggingFace API to resolve actual GGUF filenames (including sharded), preferring the configured quantization.
    private func resolveGGUFParts(for model: LocalModel) async -> ResolutionPlan? {
        // Attempt repos in order
        for repo in model.repoCandidates {
            let api = URL(string: "https://huggingface.co/api/models/\(repo)?expand=siblings")!
            var req = URLRequest(url: api)
            req.setValue("curl/8.5.0", forHTTPHeaderField: "User-Agent")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { continue }
                guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let siblings = obj["siblings"] as? [[String: Any]] else { continue }
                // Collect gguf files matching preferred quantization
                let ggufs: [String] = siblings.compactMap { $0["rfilename"] as? String }
                    .filter { $0.lowercased().hasSuffix(".gguf") }
                    .filter { $0.lowercased().contains(model.preferredQuantization) }
                if ggufs.isEmpty { continue }

                // Prefer sharded if present (look for -00001-of- pattern)
                if let firstShard = ggufs.first(where: { $0.lowercased().contains("-00001-of-") }) {
                    // Parse shard pattern with regex capturing groups
                    let pattern = "-(\\d+)-of-(\\d+)\\.gguf$"
                    if let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                        let full = firstShard as NSString
                        let range = NSRange(location: 0, length: full.length)
                        if let m = re.firstMatch(in: firstShard, options: [], range: range) {
                            let partDigits = full.substring(with: m.range(at: 1)) // e.g., 00001
                            let totalDigits = full.substring(with: m.range(at: 2)) // e.g., 00002
                            let partWidth = partDigits.count
                            let totalWidth = totalDigits.count
                            let total = Int(totalDigits) ?? 0
                            let prefix = full.replacingCharacters(in: m.range, with: "") // remove -00001-of-00002.gguf
                            // Construct full part list
                            let parts: [String] = (1...total).map { i in
                                let part = String(format: "%0*d", partWidth, i)
                                let tot = String(format: "%0*d", totalWidth, total)
                                return "\(prefix)-\(part)-of-\(tot).gguf"
                            }
                            let base = "https://huggingface.co/\(repo)/resolve/main/"
                            return ResolutionPlan(base: base, parts: parts)
                        }
                    }
                }

                // Otherwise pick a single-file gguf (prefer largest filename variant)
                // Choose the one with longest name (often includes more hints); ordering is not size, but good enough.
                if let single = ggufs.sorted(by: { $0.count > $1.count }).first {
                    let base = "https://huggingface.co/\(repo)/resolve/main/"
                    return ResolutionPlan(base: base, parts: [single])
                }
            } catch {
                // Try next repo
                continue
            }
        }
        return nil
    }

    /// Downloads a list of files sequentially into the models folder, updating progress per-part.
    private func downloadPartsSequentially(model: LocalModel, baseResolveURL: String, filenames: [String]) async {
        let totalParts = max(1, filenames.count)
        for (idx, name) in filenames.enumerated() {
            let url = URL(string: baseResolveURL + name + "?download=true")!
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60 * 60)

            // Use a semaphore-like continuation to await completion
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                let task = URLSession.shared.downloadTask(with: request) { [weak self] tempURL, response, error in
                    guard let self = self else { cont.resume(); return }
                    Task { @MainActor in
                        defer { cont.resume() }
                        if let error = error {
                            print("❌ Download error for \(model.displayName) part \(idx+1): \(error)")
                            self.downloadStates[model]?.isDownloading = false
                            self.downloadStates[model]?.isModelReady = false
                            return
                        }
                        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                            print("❌ HTTP error for \(model.displayName) part \(idx+1): status=\(http.statusCode)")
                            self.downloadStates[model]?.isDownloading = false
                            self.downloadStates[model]?.isModelReady = false
                            return
                        }
                        guard let tempURL = tempURL else {
                            print("❌ No temp URL for \(model.displayName) part \(idx+1)")
                            self.downloadStates[model]?.isDownloading = false
                            self.downloadStates[model]?.isModelReady = false
                            return
                        }
                        do {
                            let dest = model.localPath.deletingLastPathComponent().appendingPathComponent(name)
                            try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                            try? FileManager.default.removeItem(at: dest)
                            try FileManager.default.moveItem(at: tempURL, to: dest)
                            let attrs = try FileManager.default.attributesOfItem(atPath: dest.path)
                            let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
                            if size < 10_000_000 {
                                print("⚠️ Downloaded file too small (\(size) bytes): \(name)")
                                try? FileManager.default.removeItem(at: dest)
                                self.downloadStates[model]?.isDownloading = false
                                self.downloadStates[model]?.isModelReady = false
                                return
                            }
                            // Update progress to end of this part
                            let fraction = Float(idx + 1) / Float(totalParts)
                            self.downloadStates[model]?.downloadProgress = min(1.0, fraction)
                        } catch {
                            print("❌ Failed to save part \(idx+1) for \(model.displayName): \(error)")
                            self.downloadStates[model]?.isDownloading = false
                            self.downloadStates[model]?.isModelReady = false
                            return
                        }
                    }
                }
                // Observe per-part progress and map to aggregate
                self.progressObservations[model]?.invalidate()
                self.progressObservations[model] = task.progress.observe(\Progress.fractionCompleted) { [weak self] (progress: Progress, change: NSKeyValueObservedChange<Double>) in
                    Task { @MainActor in
                        guard let self = self else { return }
                        let base = Float(idx) / Float(totalParts)
                        let partFrac = Float(progress.fractionCompleted) / Float(totalParts)
                        self.downloadStates[model]?.downloadProgress = min(1.0, base + partFrac)
                    }
                }
                self.downloadTasks[model] = task
                task.resume()
            }
        }
        // For sharded models, do NOT join to avoid memory pressure.
        // LLM.swift/llama.cpp loaders can open the first shard and read siblings.
        let primaryName: String = filenames.first ?? model.modelFileName
        await MainActor.run {
            UserDefaults.standard.set(primaryName, forKey: "primaryGGUF_\(model.rawValue)")
            self.downloadStates[model]?.isDownloading = false
            self.downloadStates[model]?.isModelReady = true
            self.downloadStates[model]?.downloadProgress = 1.0
            self.refreshModelStatus()
        }
    }

    // Removed: shard-join routine to prevent memory spikes on device.

    /// Fallback to the legacy single-file candidate URLs if HF API resolution failed.
    private func attemptSimpleCandidates(_ model: LocalModel) {
        let candidates = model.candidateDownloadURLs
        attemptDownload(model, candidates: candidates, index: 0)
    }

    /// Attempts simple single-file downloads by trying candidate URLs in order.
    private func attemptDownload(_ model: LocalModel, candidates: [URL], index: Int) {
        if index >= candidates.count {
            Task { @MainActor in
                self.downloadStates[model]?.isDownloading = false
                self.downloadStates[model]?.isModelReady = false
            }
            return
        }

        let url = candidates[index]
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60 * 60)
        let task = URLSession.shared.downloadTask(with: request) { [weak self] tempURL, response, error in
            guard let self = self else { return }
            Task { @MainActor in
                if let error = error {
                    print("❌ Download error for \(model.displayName): \(error)")
                    self.progressObservations[model]?.invalidate()
                    self.progressObservations.removeValue(forKey: model)
                    self.downloadTasks.removeValue(forKey: model)
                    Task { @MainActor in self.attemptDownload(model, candidates: candidates, index: index + 1) }
                    return
                }

                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    print("❌ HTTP error for \(model.displayName): status=\(http.statusCode)")
                    self.progressObservations[model]?.invalidate()
                    self.progressObservations.removeValue(forKey: model)
                    self.downloadTasks.removeValue(forKey: model)
                    Task { @MainActor in self.attemptDownload(model, candidates: candidates, index: index + 1) }
                    return
                }

                guard let tempURL = tempURL else {
                    print("❌ No temp URL for \(model.displayName)")
                    self.progressObservations[model]?.invalidate()
                    self.progressObservations.removeValue(forKey: model)
                    self.downloadTasks.removeValue(forKey: model)
                    Task { @MainActor in self.attemptDownload(model, candidates: candidates, index: index + 1) }
                    return
                }

                do {
                    let finalPath = model.localPath
                    let dir = finalPath.deletingLastPathComponent()
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    try? FileManager.default.removeItem(at: finalPath)
                    try FileManager.default.moveItem(at: tempURL, to: finalPath)

                    let attrs = try FileManager.default.attributesOfItem(atPath: finalPath.path)
                    let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
                    if size < 10_000_000 { // < 10 MB indicates a bad/canceled download
                        print("⚠️ Downloaded file too small (\(size) bytes) for \(model.displayName). Trying next candidate.")
                        try? FileManager.default.removeItem(at: finalPath)
                        self.progressObservations[model]?.invalidate()
                        self.progressObservations.removeValue(forKey: model)
                        self.downloadTasks.removeValue(forKey: model)
                        Task { @MainActor in self.attemptDownload(model, candidates: candidates, index: index + 1) }
                        return
                    }

                    UserDefaults.standard.set(finalPath.lastPathComponent, forKey: "primaryGGUF_\(model.rawValue)")

                    self.downloadStates[model]?.isModelReady = true
                    self.downloadStates[model]?.isDownloading = false
                    self.downloadStates[model]?.downloadProgress = 1.0

                    print("✅ \(model.displayName) downloaded successfully")
                    self.refreshModelStatus()

                } catch {
                    print("❌ Failed to save \(model.displayName): \(error)")
                    self.downloadStates[model]?.isDownloading = false
                    self.downloadStates[model]?.isModelReady = false
                }

                self.downloadTasks.removeValue(forKey: model)
                self.progressObservations[model]?.invalidate()
                self.progressObservations.removeValue(forKey: model)
            }
        }

        self.downloadTasks[model] = task
        self.progressObservations[model] = task.progress.observe(\Progress.fractionCompleted) { [weak self] (progress: Progress, change: NSKeyValueObservedChange<Double>) in
            Task { @MainActor in
                self?.downloadStates[model]?.downloadProgress = Float(progress.fractionCompleted)
            }
        }

        task.resume()
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
