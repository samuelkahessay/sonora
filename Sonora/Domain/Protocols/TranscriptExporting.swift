import Foundation

/// Protocol for exporting a memo transcript as a shareable file.
///
/// Conforming types should write the provided text to a UTF-8 encoded `.txt`
/// file in a temporary location and return the resulting file URL.
public protocol TranscriptExporting {
    /// Creates a temporary `.txt` file for sharing a memo's transcript.
    /// - Parameters:
    ///   - memo: The memo used for naming (uses `preferredShareableFileName`).
    ///   - text: The transcript contents to write. Callers may pre-format using
    ///           existing helpers (e.g., header + transcript body).
    /// - Returns: URL to the created temporary file.
    /// - Throws: Any file system write/removal errors encountered during export.
    func makeTranscriptFile(memo: Memo, text: String) throws -> URL
}
