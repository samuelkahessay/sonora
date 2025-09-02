import Foundation

/// Concrete exporter that writes transcript text to a UTF-8 `.txt` file in the temporary directory.
///
/// The file is named using the memo's `preferredShareableFileName` with a `.txt` extension.
/// The provided `text` is written verbatim; callers can pass pre-formatted content
/// (e.g., including headers via existing helpers) to control the final file contents.
final class TranscriptExportService: TranscriptExporting {
    func makeTranscriptFile(memo: Memo, text: String) throws -> URL {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
        let filename = memo.preferredShareableFileName + ".txt"
        let fileURL = tempDir.appendingPathComponent(filename)

        // Ensure parent directory exists (defensive; tempDir should exist but we guard anyway)
        let parentDir = fileURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: parentDir.path) {
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
        }

        // Remove any existing file at this path to ensure a clean write
        if fm.fileExists(atPath: fileURL.path) {
            try fm.removeItem(at: fileURL)
        }

        // Write UTF-8 contents atomically
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
