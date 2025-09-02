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
            let config = dir.appendingPathComponent("config.json")
            guard FileManager.default.fileExists(atPath: config.path) else { return false }
            let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            let modelDirs = contents.filter { $0.pathExtension == "mlmodelc" }
            return modelDirs.count >= 2
        }
        if try check(at: modelRoot()) { return true }
        let fm = FileManager.default
        let cachesBase = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let appSupportBase = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let candidates: [URL] = [
            cachesBase.appendingPathComponent("WhisperKit/Models", isDirectory: true),
            appSupportBase.appendingPathComponent("WhisperKit/Models", isDirectory: true),
            appSupportBase.appendingPathComponent("WhisperKit", isDirectory: true)
        ]
        for root in candidates {
            if (try? check(at: root)) == true { return true }
        }
        return false
    }

    #if canImport(WhisperKit)
    static func makeConfig(model id: String, background: Bool, autoDownload: Bool = false) throws -> WhisperKitConfig {
        let root = try modelRoot()
        return WhisperKitConfig(
            model: id,
            downloadBase: root,
            modelRepo: "argmaxinc/whisperkit-coreml",
            load: true,              // Always load the model
            download: autoDownload,  // Control download behavior
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
