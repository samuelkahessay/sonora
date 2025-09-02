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
            // Use WhisperKit's static download method with real progress tracking
            try await WhisperKit.download(
                variant: id,
                progressCallback: { progressObject in
                    let fractionCompleted = progressObject.fractionCompleted
                    progress(fractionCompleted)
                    self.logger.debug("Download progress for \(id): \(Int(fractionCompleted * 100))%")
                }
            )
            
            progress(1.0)
            logger.info("WhisperKitModelProvider: Successfully downloaded model: \(id)")
            
        } catch {
            logger.error("WhisperKitModelProvider: WhisperKit download failed for \(id): \(error.localizedDescription)")
            throw ModelDownloadError.networkError(error.localizedDescription)
        }
        #else
        // Simulate download with periodic progress updates
        await simulateDownloadProgress(for: id, progressCallback: progress)
        #endif
    }
    
    
    private func simulateDownloadProgress(for modelId: String, progressCallback: @escaping (Double) -> Void) async {
        let steps = 20
        for i in 0...steps {
            try? await Task.sleep(for: .milliseconds(100))
            let progress = Double(i) / Double(steps)
            progressCallback(progress)
        }
        
        // Create simulation files
        let dir = (try? WhisperKitInstall.modelRoot())?.appendingPathComponent(modelId, isDirectory: true)
        if let dir, !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        if let dir {
            let marker = dir.appendingPathComponent("installed.marker")
            try? Data("installed".utf8).write(to: marker, options: .atomic)
        }
        
        logger.info("WhisperKitModelProvider: Simulated install for model: \(modelId)")
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
            let root = try WhisperKitInstall.modelRoot()
            let cfg = WhisperKitConfig(
                model: name,
                downloadBase: root,
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

