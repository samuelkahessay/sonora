import Foundation

/// Protocol for exporting AI analysis text as a shareable file.
public protocol AnalysisExporting {
    /// Creates a temporary UTF-8 `.txt` file containing the given analysis text.
    /// - Parameters:
    ///   - memo: Memo used to determine a user-friendly filename.
    ///   - text: Analysis content to write to disk.
    /// - Returns: URL to the created temporary file.
    func makeAnalysisFile(memo: Memo, text: String) throws -> URL
}
