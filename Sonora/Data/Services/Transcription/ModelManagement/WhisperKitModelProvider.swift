import Foundation
#if canImport(WhisperKit)
@preconcurrency import WhisperKit
#endif

@MainActor
final class WhisperKitModelProvider {
    private let fm = FileManager.default
    private let logger = Logger.shared
    private lazy var cacheURL: URL = {
        // Bump cache filename to force refresh when curated set changes
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("WhisperKit/models_cache_v2.json")
    }()
    private lazy var foldersURL: URL = {
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("WhisperKit/download_folders.json")
    }()
    func listAvailableModels() async throws -> [WhisperModel] {
        if let cached = loadCachedModels() { return cached }
        let models = Self.curatedModels
        saveCachedModels(models)
        return models
    }
    func isInstalled(_ id: String) -> Bool {
        // Prefer concrete folder resolution across known roots rather than relying solely on WhisperKitInstall
        return installedModelFolder(id: id) != nil
    }

    /// Returns IDs of all installed WhisperKit models by scanning WhisperKit's expected locations
    func installedModelIds() -> [String] {
        var ids: Set<String> = []
        let fm = FileManager.default
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]

        // Primary WhisperKit/HuggingFace locations — check Documents first (actual download path), then Caches
        let primaryPaths: [URL] = [
            // Documents (observed actual download path)
            documents.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml", isDirectory: true),
            documents.appendingPathComponent("huggingface", isDirectory: true),
            // Caches fallbacks
            caches.appendingPathComponent("WhisperKit", isDirectory: true),
            caches.appendingPathComponent("huggingface", isDirectory: true),
            caches.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml", isDirectory: true)
        ]
        for root in primaryPaths where fm.fileExists(atPath: root.path) {
            scanForModels(at: root, into: &ids)
        }

        // Fallback to app support locations we previously used
        if let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            let fallbackPaths: [URL] = [
                appSupport.appendingPathComponent("WhisperKit/Models", isDirectory: true),
                appSupport.appendingPathComponent("WhisperKit", isDirectory: true)
            ]
            for root in fallbackPaths where fm.fileExists(atPath: root.path) {
                scanForModels(at: root, into: &ids)
            }
        }

        // Include custom modelRoot() last as a fallback
        if let custom = try? WhisperKitInstall.modelRoot(), fm.fileExists(atPath: custom.path) {
            scanForModels(at: custom, into: &ids)
        }
        return Array(ids)
    }

    /// Scan a directory tree (depth 2) for recognizable WhisperKit model folders
    private func scanForModels(at root: URL, into ids: inout Set<String>) {
        let fm = FileManager.default
        guard let level1 = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }
        for entry in level1 {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else { continue }
            if looksLikeModelFolder(entry) {
                ids.insert(entry.lastPathComponent)
            } else {
                // Dive one level deeper (e.g., WhisperKit/Models/<id> or huggingface/.../whisperkit-coreml/<id>)
                if let level2 = try? fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                    for sub in level2 {
                        var isDir2: ObjCBool = false
                        guard fm.fileExists(atPath: sub.path, isDirectory: &isDir2), isDir2.boolValue else { continue }
                        if looksLikeModelFolder(sub) {
                            ids.insert(sub.lastPathComponent)
                        }
                    }
                }
            }
        }
    }

    /// Heuristic to detect a model folder by presence of compiled models
    private func looksLikeModelFolder(_ url: URL) -> Bool {
        let fm = FileManager.default
        if let children = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            return children.contains { $0.pathExtension == "mlmodelc" }
        }
        return false
    }

    /// Resolve the concrete installed folder URL for a given model id, if present.
    /// Searches known WhisperKit locations (Documents, Caches, App Support, custom modelRoot).
    func installedModelFolder(id: String) -> URL? {
        // Prefer persisted exact folder path first
        if let persisted = loadPersistedFolder(for: id) {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: persisted.path, isDirectory: &isDir), isDir.boolValue, looksLikeModelFolder(persisted) {
                return persisted
            } else {
                // Remove stale mapping
                removePersistedFolder(for: id)
            }
        }
        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let appSupport = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))

        // Candidate roots that may directly contain model folders by id
        var roots: [URL] = []
        roots.append(documents.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml", isDirectory: true))
        roots.append(documents.appendingPathComponent("huggingface", isDirectory: true))
        roots.append(caches.appendingPathComponent("WhisperKit", isDirectory: true))
        roots.append(caches.appendingPathComponent("WhisperKit/Models", isDirectory: true))
        roots.append(caches.appendingPathComponent("huggingface", isDirectory: true))
        roots.append(caches.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml", isDirectory: true))
        if let appSupport {
            roots.append(appSupport.appendingPathComponent("WhisperKit/Models", isDirectory: true))
            roots.append(appSupport.appendingPathComponent("WhisperKit", isDirectory: true))
        }
        if let custom = try? WhisperKitInstall.modelRoot() {
            roots.append(custom)
        }

        // Check <root>/<id>
        for root in roots where fm.fileExists(atPath: root.path) {
            let candidate = root.appendingPathComponent(id, isDirectory: true)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue, looksLikeModelFolder(candidate) {
                return candidate
            }
        }
        return nil
    }

    /// Check whether the installed model folder for the given id appears valid (compiled models + tokenizer assets)
    func isModelValid(id: String) -> Bool {
        guard let folder = installedModelFolder(id: id) else { return false }
        return validateModelAtPath(folder)
    }
    func modelURL(id: String) -> URL? {
        guard (try? WhisperKitInstall.isInstalled(model: id)) == true,
              let root = try? WhisperKitInstall.modelRoot() else { return nil }
        return root.appendingPathComponent(id, isDirectory: true)
    }
    func download(id: String, progress: @escaping @MainActor @Sendable (Double) -> Void) async throws {
        #if canImport(WhisperKit)
        logger.info("Starting WhisperKit download for model: \(id)")
        progress(0.0)

        do {
            // Proactively ensure common HuggingFace directories exist to avoid CFNetwork move errors
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            // Documents paths used by HF on iOS
            let hfBaseDocs = docs.appendingPathComponent("huggingface", isDirectory: true)
            let hfModelsDocs = hfBaseDocs.appendingPathComponent("models/argmaxinc/whisperkit-coreml", isDirectory: true)
            let hfAnalyticsDocs = hfBaseDocs.appendingPathComponent("analytics", isDirectory: true)
            try? fm.createDirectory(at: hfBaseDocs, withIntermediateDirectories: true)
            try? fm.createDirectory(at: hfModelsDocs, withIntermediateDirectories: true)
            try? fm.createDirectory(at: hfAnalyticsDocs, withIntermediateDirectories: true)
            // Caches paths used by HF/WhisperKit as alternates
            let hfBaseCaches = caches.appendingPathComponent("huggingface", isDirectory: true)
            let hfAnalyticsCaches = hfBaseCaches.appendingPathComponent("analytics", isDirectory: true)
            try? fm.createDirectory(at: hfBaseCaches, withIntermediateDirectories: true)
            try? fm.createDirectory(at: hfAnalyticsCaches, withIntermediateDirectories: true)

            // Also ensure per-model folder exists to avoid CFNetwork move/rename failures
            let modelDir = hfModelsDocs.appendingPathComponent(id, isDirectory: true)
            try? fm.createDirectory(at: modelDir, withIntermediateDirectories: true)

            var downloadedFolder: URL? = nil
            if AppConfiguration.shared.whisperBackgroundDownloads {
                logger.info("Using background download session for Whisper model: \(id)")
                do {
                    let cfg = WhisperKitConfig(
                        model: id,
                        modelRepo: "argmaxinc/whisperkit-coreml",
                        useBackgroundDownloadSession: true
                    )
                    let wk = try await WhisperKit(cfg)
                    if let folder = wk.modelFolder { downloadedFolder = folder }
                    await wk.unloadModels()
                } catch {
                    logger.warning("Background download path failed, falling back: \(error.localizedDescription)")
                }
            }
            if downloadedFolder == nil {
                downloadedFolder = try await WhisperKit.download(
                    variant: id,
                    from: "argmaxinc/whisperkit-coreml",
                    progressCallback: { @Sendable progressObject in
                        let fractionCompleted = progressObject.fractionCompleted
                        Task { @MainActor in
                            progress(fractionCompleted)
                        }
                        Logger.shared.debug("Download progress for \(id): \(Int(fractionCompleted * 100))%")
                    }
                )
            }

            guard let downloadedFolder else {
                throw ModelDownloadError.networkError("Download did not return a folder URL")
            }

            // Log the actual download location and its immediate contents for diagnostics
            logger.info("🔍 WhisperKit downloaded \(id) to: \(downloadedFolder.path)")
            logger.info("🔍 Download folder contents:")
            if let items = try? FileManager.default.contentsOfDirectory(at: downloadedFolder, includingPropertiesForKeys: nil, options: []) {
                for entry in items {
                    logger.info("🔍   - \(entry.lastPathComponent)")
                }
            }

            var eval = evaluateModelAtPath(downloadedFolder)
            if !eval.hasTokenizerAssets && eval.hasCompiled {
                // Attempt to fetch tokenizers from canonical sources
                let fetcher = TokenizerFetcher()
                let ok = await fetcher.fetch(for: id, into: downloadedFolder)
                if ok {
                    eval = evaluateModelAtPath(downloadedFolder)
                }
            }
            guard eval.hasCompiled && eval.hasTokenizerAssets else {
                throw ModelDownloadError.storageError("Model validation failed at \(downloadedFolder.path)")
            }
            // Persist the exact folder path for future resolution
            savePersistedFolder(downloadedFolder, for: id)
            
            progress(1.0)
            logger.info("WhisperKitModelProvider: Successfully downloaded and validated model: \(id)")

        } catch let e as ModelDownloadError {
            logger.error("WhisperKitModelProvider: WhisperKit download failed for \(id): \(e.localizedDescription)")
            throw e
        } catch {
            logger.error("WhisperKitModelProvider: WhisperKit download failed for \(id): \(error.localizedDescription)")
            throw ModelDownloadError.networkError(error.localizedDescription)
        }
        #else
        // WhisperKit SDK not available; surface a clear error instead of simulating
        throw ModelDownloadError.networkError("WhisperKit SDK is not available in this build")
        #endif
    }
    
    
    // Validate the actual download path returned by WhisperKit
    private func validateModelAtPath(_ path: URL) -> Bool {
        let eval = evaluateModelAtPath(path)
        if !eval.hasCompiled {
            logger.warning("WhisperKitModelProvider: No compiled .mlmodelc found under \(path.path)")
        }
        if !eval.hasTokenizerAssets {
            logger.warning("WhisperKitModelProvider: No tokenizer assets detected under \(path.lastPathComponent)")
        }
        return eval.hasCompiled && eval.hasTokenizerAssets
    }

    private func evaluateModelAtPath(_ path: URL) -> (hasCompiled: Bool, hasTokenizerAssets: Bool) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path.path, isDirectory: &isDir), isDir.boolValue else { return (false, false) }
        // Scan recursively (shallow) for compiled models and tokenizer assets
        var hasCompiled = false
        var hasTokenizerAssets = false
        let fm = FileManager.default
        let enumerator = fm.enumerator(at: path, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        while let item = enumerator?.nextObject() as? URL {
            let name = item.lastPathComponent.lowercased()
            if item.pathExtension == "mlmodelc" { hasCompiled = true }
            if name == "tokenizer.json" || name == "tokenizer.model" || name == "vocabulary.json" { hasTokenizerAssets = true }
            if name.contains("merges") { hasTokenizerAssets = true }
            if name.contains("vocab") { hasTokenizerAssets = true }
            if name.contains("tokenizer") { hasTokenizerAssets = true }
            if hasCompiled && hasTokenizerAssets { break }
        }
        return (hasCompiled, hasTokenizerAssets)
    }

    /// Clear persisted folder mapping for a model id (used when folder becomes invalid/stale)
    func clearPersistedFolder(for id: String) {
        removePersistedFolder(for: id)
    }

    // MARK: - Persisted folder mapping
    private func loadPersistedFolders() -> [String: String] {
        guard fm.fileExists(atPath: foldersURL.path) else { return [:] }
        do {
            let data = try Data(contentsOf: foldersURL)
            let dict = try JSONDecoder().decode([String: String].self, from: data)
            return dict
        } catch {
            logger.warning("WhisperKitModelProvider: Failed to load folder map: \(error.localizedDescription)")
            return [:]
        }
    }

    private func savePersistedFolders(_ map: [String: String]) {
        do {
            let data = try JSONEncoder().encode(map)
            // Ensure parent directory exists
            try fm.createDirectory(at: foldersURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: foldersURL, options: .atomic)
        } catch {
            logger.warning("WhisperKitModelProvider: Failed to save folder map: \(error.localizedDescription)")
        }
    }

    private func loadPersistedFolder(for id: String) -> URL? {
        let map = loadPersistedFolders()
        if let path = map[id] { return URL(fileURLWithPath: path) }
        return nil
    }

    private func savePersistedFolder(_ url: URL, for id: String) {
        var map = loadPersistedFolders()
        map[id] = url.path
        savePersistedFolders(map)
    }

    private func removePersistedFolder(for id: String) {
        var map = loadPersistedFolders()
        map.removeValue(forKey: id)
        savePersistedFolders(map)
    }
    func delete(id: String) async throws {
        // Remove the actually installed folder first if resolvable
        if let installed = installedModelFolder(id: id) {
            do {
                try fm.removeItem(at: installed)
                logger.info("WhisperKitModelProvider: Deleted model at resolved path: \(installed.path)")
            } catch {
                logger.warning("WhisperKitModelProvider: Failed deleting resolved path for \(id): \(error.localizedDescription)")
            }
        }
        // Also attempt deletion from WhisperKitInstall.modelRoot() as a fallback
        if let root = try? WhisperKitInstall.modelRoot() {
            let dir = root.appendingPathComponent(id, isDirectory: true)
            if fm.fileExists(atPath: dir.path) {
                do {
                    try fm.removeItem(at: dir)
                    logger.info("WhisperKitModelProvider: Deleted model from default root: \(dir.path)")
                } catch {
                    logger.warning("WhisperKitModelProvider: Failed deleting default root path for \(id): \(error.localizedDescription)")
                }
            }
        }
        // Clear persisted folder mapping and any internal download state
        removePersistedFolder(for: id)
        WhisperKitInstall.clearDownloadState(for: id)
    }
    func clearDownloadState(for id: String) {
        WhisperKitInstall.clearDownloadState(for: id)
    }
    private func loadCachedModels() -> [WhisperModel]? {
        guard fm.fileExists(atPath: cacheURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: cacheURL)
            let models = try JSONDecoder().decode([WhisperModel].self, from: data)
            return models
        } catch {
            logger.warning("WhisperKitModelProvider: Failed to load cached models: \(error.localizedDescription)")
            return nil
        }
    }
    private func saveCachedModels(_ models: [WhisperModel]) {
        do {
            let data = try JSONEncoder().encode(models)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            logger.warning("WhisperKitModelProvider: Failed to save model cache: \(error.localizedDescription)")
        }
    }
    static let curatedModels: [WhisperModel] = [
        WhisperModel(
            id: WKModel.small.rawValue,
            displayName: "Small",
            sizeBytes: 488 * 1024 * 1024,
            description: "Higher accuracy, moderate speed."
        ),
        WhisperModel(
            id: WKModel.medium.rawValue,
            displayName: "Medium",
            sizeBytes: 1_550 * 1024 * 1024,
            description: "High accuracy. Heavier model; slower and larger."
        ),
        WhisperModel(
            id: WKModel.largeV3.rawValue,
            displayName: "Large v3",
            sizeBytes: 2_900 * 1024 * 1024,
            description: "Maximum accuracy. Largest local model."
        )
    ]
    enum WKModel: String {
        case small = "openai_whisper-small"
        case medium = "openai_whisper-medium"
        case largeV3 = "openai_whisper-large-v3"
    }
}

struct WhisperModel: Equatable, Hashable, Codable, Sendable {
    let id: String
    let displayName: String
    let sizeBytes: Int64?
    let description: String
}
