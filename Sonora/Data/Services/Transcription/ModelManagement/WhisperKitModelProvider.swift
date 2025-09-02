import Foundation
#if canImport(WhisperKit)
import WhisperKit
#endif

@MainActor
final class WhisperKitModelProvider {
    private let fm = FileManager.default
    private let logger = Logger.shared
    private lazy var cacheURL: URL = {
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("WhisperKit/models_cache.json")
    }()
    func listAvailableModels() async throws -> [WhisperModel] {
        if let cached = loadCachedModels() { return cached }
        let models = Self.curatedModels
        saveCachedModels(models)
        return models
    }
    func isInstalled(_ id: String) -> Bool {
        (try? WhisperKitInstall.isInstalled(model: id)) ?? false
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
    func modelURL(id: String) -> URL? {
        guard (try? WhisperKitInstall.isInstalled(model: id)) == true,
              let root = try? WhisperKitInstall.modelRoot() else { return nil }
        return root.appendingPathComponent(id, isDirectory: true)
    }
    func download(id: String, progress: @escaping (Double) -> Void) async throws {
        #if canImport(WhisperKit)
        logger.info("Starting WhisperKit download for model: \(id)")
        progress(0.0)

        do {
            // WhisperKit returns the actual folder URL for the download
            let downloadedFolder = try await WhisperKit.download(
                variant: id,
                from: "argmaxinc/whisperkit-coreml",
                progressCallback: { progressObject in
                    let fractionCompleted = progressObject.fractionCompleted
                    progress(fractionCompleted)
                    self.logger.debug("Download progress for \(id): \(Int(fractionCompleted * 100))%")
                }
            )

            // Log the actual download location and its immediate contents for diagnostics
            logger.info("🔍 WhisperKit downloaded \(id) to: \(downloadedFolder.path)")
            logger.info("🔍 Download folder contents:")
            if let items = try? FileManager.default.contentsOfDirectory(at: downloadedFolder, includingPropertiesForKeys: nil, options: []) {
                for entry in items {
                    logger.info("🔍   - \(entry.lastPathComponent)")
                }
            }

            guard validateModelAtPath(downloadedFolder) else {
                throw ModelDownloadError.storageError("Model validation failed at \(downloadedFolder.path)")
            }
            
            progress(1.0)
            logger.info("WhisperKitModelProvider: Successfully downloaded and validated model: \(id)")

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
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path.path, isDirectory: &isDir), isDir.boolValue else { return false }
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            let hasCompiled = contents.contains { $0.pathExtension == "mlmodelc" }
            return hasCompiled
        } catch {
            return false
        }
    }
    func delete(id: String) async throws {
        let root = try WhisperKitInstall.modelRoot()
        let dir = root.appendingPathComponent(id, isDirectory: true)
        if fm.fileExists(atPath: dir.path) {
            try fm.removeItem(at: dir)
            logger.info("WhisperKitModelProvider: Deleted model: \(id)")
        }
    }
    func clearDownloadState(for id: String) {
        WhisperKitInstall.clearDownloadState(for: id)
    }
    enum ModelChoice {
        case recommended
        case exact(name: String)
        case hosted(name: String, repo: String, background: Bool)
    }
    func makePipeline(for choice: ModelChoice) async throws -> WhisperKit {
        #if canImport(WhisperKit)
        switch choice {
        case .recommended:
            return try await WhisperKit()
        case .exact(let name):
            let cfg = try WhisperKitInstall.makeConfig(model: name, background: true)
            return try await WhisperKit(cfg)
        case .hosted(let name, let repo, let background):
            let cfg = WhisperKitConfig(
                model: name,
                modelRepo: repo,
                useBackgroundDownloadSession: background
            )
            return try await WhisperKit(cfg)
        }
        #else
        throw WhisperKitTranscriptionError.initializationFailed("WhisperKit SDK not available")
        #endif
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
            id: WKModel.tiny.rawValue,
            displayName: "Tiny",
            sizeBytes: 39 * 1024 * 1024,
            description: "Fastest processing, basic accuracy."
        ),
        WhisperModel(
            id: WKModel.tinyEN.rawValue,
            displayName: "Tiny (EN)",
            sizeBytes: 39 * 1024 * 1024,
            description: "English-only tiny model."
        ),
        WhisperModel(
            id: WKModel.base.rawValue,
            displayName: "Base",
            sizeBytes: 142 * 1024 * 1024,
            description: "Balanced speed and accuracy."
        ),
        WhisperModel(
            id: WKModel.baseEN.rawValue,
            displayName: "Base (EN)",
            sizeBytes: 142 * 1024 * 1024,
            description: "English-only base model."
        ),
        WhisperModel(
            id: WKModel.small.rawValue,
            displayName: "Small",
            sizeBytes: 488 * 1024 * 1024,
            description: "Higher accuracy, moderate speed."
        )
    ]
    enum WKModel: String {
        case tiny = "openai_whisper-tiny"
        case tinyEN = "openai_whisper-tiny.en"
        case base = "openai_whisper-base"
        case baseEN = "openai_whisper-base.en"
        case small = "openai_whisper-small"
    }
}

struct WhisperModel: Equatable, Hashable, Codable {
    let id: String
    let displayName: String
    let sizeBytes: Int64?
    let description: String
}
