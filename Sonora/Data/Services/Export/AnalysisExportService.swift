import Foundation

/// Concrete exporter that writes analysis text to a UTF-8 `.txt` file in the temporary directory.
final class AnalysisExportService: AnalysisExporting {
    func makeAnalysisFile(memo: Memo, text: String) throws -> URL {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
        let filename = memo.preferredShareableFileName + "_analysis.txt"
        let fileURL = tempDir.appendingPathComponent(filename)

        // Ensure directory exists
        let parentDir = fileURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: parentDir.path) {
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        // Overwrite any existing file
        if fm.fileExists(atPath: fileURL.path) {
            try fm.removeItem(at: fileURL)
        }

        try text.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
