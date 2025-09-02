import Foundation
#if canImport(WhisperKit)
import WhisperKit
#endif

struct WhisperKitInstall {
    static func modelRoot() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = appSupport.appendingPathComponent("WhisperKitModels", isDirectory: true)
        if !FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }

    static func isInstalled(model id: String) throws -> Bool {
        func check(at root: URL) throws -> Bool {
            let dir = root.appendingPathComponent(id, isDirectory: true)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { return false }
            let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            // Require at least one compiled model directory and a config file
            let hasCompiled = contents.contains { $0.pathExtension == "mlmodelc" }
            let hasConfig = contents.contains { $0.lastPathComponent.lowercased().contains("config") }
            return hasCompiled && hasConfig
        }
        if try check(at: modelRoot()) { return true }
        let fm = FileManager.default
        let documentsBase = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cachesBase = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let appSupportBase = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let candidates: [URL] = [
            // Documents (observed actual download path)
            documentsBase.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml", isDirectory: true),
            documentsBase.appendingPathComponent("huggingface", isDirectory: true),
            // WhisperKit and HuggingFace caches
            cachesBase.appendingPathComponent("WhisperKit", isDirectory: true),
            cachesBase.appendingPathComponent("WhisperKit/Models", isDirectory: true),
            cachesBase.appendingPathComponent("huggingface", isDirectory: true),
            cachesBase.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml", isDirectory: true),
            // App support fallbacks
            appSupportBase.appendingPathComponent("WhisperKit/Models", isDirectory: true),
            appSupportBase.appendingPathComponent("WhisperKit", isDirectory: true),
            // Custom root
            try modelRoot()
        ]
        for root in candidates {
            if (try? check(at: root)) == true { return true }
        }
        return false
    }

    #if canImport(WhisperKit)
    static func makeConfig(model id: String, background: Bool, autoDownload: Bool = false) throws -> WhisperKitConfig {
        // Point to Documents directory where WhisperKit actually downloads models
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelPath = documents.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml/\(id)", isDirectory: true)

        // Debug logging to verify what WhisperKit is being configured with
        let exists = FileManager.default.fileExists(atPath: modelPath.path)
        Logger.shared.info("🔧 WhisperKit config for \(id):")
        Logger.shared.info("🔧   modelPath exists: \(exists)")
        Logger.shared.info("🔧   modelPath: \(modelPath.path)")

        // Log folder contents to verify expected files are present
        if let items = try? FileManager.default.contentsOfDirectory(at: modelPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            Logger.shared.info("🔧   folder contents (\(items.count)):")
            for entry in items {
                Logger.shared.info("🔧     - \(entry.lastPathComponent)")
            }
        } else {
            Logger.shared.info("🔧   folder contents: <unreadable or empty>")
        }

        // Use the exact model folder path so WhisperKit can load the local model
        return WhisperKitConfig(
            model: id,
            modelFolder: modelPath.path,  // exact model directory
            load: true,
            download: autoDownload,
            useBackgroundDownloadSession: background
        )
    }
    #endif

    static func clearDownloadState(for id: String) {
        let key = "downloadState_\(id)"
        UserDefaults.standard.removeObject(forKey: key)
        if let root = try? modelRoot() {
            let path = root.appendingPathComponent(id, isDirectory: true)
            try? FileManager.default.removeItem(at: path)
        }
    }
}
