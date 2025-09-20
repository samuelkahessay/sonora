import Foundation

/// Protocol for transcription services that handle audio-to-text conversion
/// Provides a clean abstraction for the core transcription functionality
@MainActor
protocol TranscriptionAPI {
    /// Transcribes audio content from the given URL to text
    /// - Parameter url: The URL of the audio file to transcribe
    /// - Returns: The transcribed text as a string
    /// - Throws: TranscriptionError or networking errors if transcription fails
    func transcribe(url: URL) async throws -> String

    /// Transcribes audio content with an optional language hint and returns detailed response
    /// - Parameters:
    ///   - url: The URL of the audio file to transcribe
    ///   - language: Optional ISO 639-1 language code (e.g., "en", "es", "fr")
    /// - Returns: Detailed transcription response including optional metadata
    func transcribe(url: URL, language: String?) async throws -> TranscriptionResponse
}

/// Detailed transcription response, optionally including detected language and confidences
struct TranscriptionResponse: Equatable, Sendable {
    let text: String
    let detectedLanguage: String?
    let confidence: Double?
    let avgLogProb: Double?
    let duration: TimeInterval?
}

/// Result type for chunked transcription
struct ChunkTranscriptionResult: Equatable, Sendable {
    let segment: VoiceSegment
    let response: TranscriptionResponse
}

// Backward-compat helpers to minimize changes in call sites
extension ChunkTranscriptionResult {
    var text: String { response.text }
    var confidence: Double? { response.confidence }
    init(segment: VoiceSegment, text: String, confidence: Double? = nil) {
        self.segment = segment
        self.response = TranscriptionResponse(text: text, detectedLanguage: nil, confidence: confidence, avgLogProb: nil, duration: nil)
    }
}
