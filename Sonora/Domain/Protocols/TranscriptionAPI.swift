import Foundation

/// Protocol for transcription services that handle audio-to-text conversion
/// Provides a clean abstraction for the core transcription functionality
protocol TranscriptionAPI {
    /// Transcribes audio content from the given URL to text
    /// - Parameter url: The URL of the audio file to transcribe
    /// - Returns: The transcribed text as a string
    /// - Throws: TranscriptionError or networking errors if transcription fails
    func transcribe(url: URL) async throws -> String
}