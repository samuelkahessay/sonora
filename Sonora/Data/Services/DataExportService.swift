import Foundation

#if canImport(ZIPFoundation)
import ZIPFoundation

/// ZIP-based exporter using ZIPFoundation
/// Add the package: https://github.com/weichsel/ZIPFoundation via SPM
final class ZipDataExportService: DataExporting {
    func export(options: ExportOptions) async throws -> URL {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
        let outURL = tmp.appendingPathComponent("Sonora_Export_\(Int(Date().timeIntervalSince1970)).zip")

        // Remove if exists
        try? fm.removeItem(at: outURL)

        // Use throwing initializer (current ZIPFoundation API)
        let archive: Archive
        do {
            archive = try Archive(url: outURL, accessMode: .create)
        } catch {
            throw ExportError.archiveCreateFailed
        }

        // Compose content root: Documents/Memos, Documents/transcriptions, Documents/analysis
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let memosDir = documents.appendingPathComponent("Memos", isDirectory: true)
        let transcriptionsDir = documents.appendingPathComponent("transcriptions", isDirectory: true)
        let analysisDir = documents.appendingPathComponent("analysis", isDirectory: true)

        if options.contains(.memos), fm.fileExists(atPath: memosDir.path) {
            try addDirectory(at: memosDir, to: archive, relativeTo: documents)
        }
        if options.contains(.transcripts), fm.fileExists(atPath: transcriptionsDir.path) {
            try addDirectory(at: transcriptionsDir, to: archive, relativeTo: documents)
        }
        if options.contains(.analysis), fm.fileExists(atPath: analysisDir.path) {
            try addDirectory(at: analysisDir, to: archive, relativeTo: documents)
        }

        // Always include app settings snapshot
        try addSettings(to: archive)

        return outURL
    }

    private func addDirectory(at baseURL: URL, to archive: Archive, relativeTo root: URL) throws {
        let fm = FileManager.default
        let enumerator = fm.enumerator(at: baseURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])

        while let fileURL = enumerator?.nextObject() as? URL {
            let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let relPath = fileURL.path.replacingOccurrences(of: root.path + "/", with: "")

            if isDir {
                // Skip explicit directory entries; they are inferred from file paths
                continue
            } else {
                // Add file with provider closure (ZIPFoundation current API)
                let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
                let fileSize = Int64(values?.fileSize ?? 0)
                let handle = try FileHandle(forReadingFrom: fileURL)
                defer { try? handle.close() }
                try archive.addEntry(
                    with: relPath,
                    type: .file,
                    uncompressedSize: fileSize,
                    compressionMethod: .deflate,
                    provider: { position, size in
                        handle.seek(toFileOffset: UInt64(position))
                        return handle.readData(ofLength: size)
                    }
                )
            }
        }
    }

    private func addSettings(to archive: Archive) throws {
        // Build a small JSON snapshot of app settings and configuration
        struct SettingsSnapshot: Codable {
            let themeSettingsRaw: String?
            let configuration: [String: String]
            let createdAt: String
        }

        let date = ISO8601DateFormatter().string(from: Date())
        let themeRaw = UserDefaults.standard.data(forKey: "app.theme.settings").flatMap { String(data: $0, encoding: .utf8) }

        // Pull a subset of AppConfiguration for context
        let cfg = AppConfiguration.shared
        var conf: [String: String] = [:]
        conf["apiBaseURL"] = cfg.apiBaseURL.absoluteString
        conf["analysisTimeoutInterval"] = String(cfg.analysisTimeoutInterval)
        conf["transcriptionTimeoutInterval"] = String(cfg.transcriptionTimeoutInterval)
        conf["maxRecordingDuration"] = String(cfg.maxRecordingDuration)
        conf["maxRecordingFileSize"] = String(cfg.maxRecordingFileSize)
        conf["audioSampleRate"] = String(cfg.audioSampleRate)
        conf["audioChannels"] = String(cfg.audioChannels)

        let snapshot = SettingsSnapshot(
            themeSettingsRaw: themeRaw,
            configuration: conf,
            createdAt: date
        )
        let data = try JSONEncoder().encode(snapshot)

        // Add as settings/settings.json
        let entryPath = "settings/settings.json"
        let size = Int64(data.count)
        try archive.addEntry(
            with: entryPath,
            type: .file,
            uncompressedSize: size,
            compressionMethod: .deflate,
            provider: { position, size in
                let start = Int(position)
                let end = min(start + size, data.count)
                return data.subdata(in: start..<end)
            }
        )
    }

    enum ExportError: LocalizedError {
        case archiveCreateFailed
        var errorDescription: String? { "Failed to create ZIP archive" }
    }
}
#endif
