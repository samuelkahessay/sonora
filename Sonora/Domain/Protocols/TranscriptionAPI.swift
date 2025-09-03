import Foundation

/// Protocol for transcription services that handle audio-to-text conversion
/// Provides a clean abstraction for the core transcription functionality
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

    /// Transcribe voiced chunks and return per-segment results in original order.
    /// Implementations should handle per-chunk failures gracefully and continue others.
    func transcribeChunks(segments: [VoiceSegment], audioURL: URL) async throws -> [ChunkTranscriptionResult]

    /// Transcribe voiced chunks with an optional language hint.
    func transcribeChunks(segments: [VoiceSegment], audioURL: URL, language: String?) async throws -> [ChunkTranscriptionResult]
}

/// Optional progress reporting for long-running transcriptions.
/// Implemented by local engines to surface fine-grained progress.
protocol TranscriptionProgressReporting {
    @MainActor func setProgressHandler(_ handler: @escaping (Double) -> Void)
    @MainActor func clearProgressHandler()
}

/// Detailed transcription response, optionally including detected language and confidences
struct TranscriptionResponse: Equatable {
    let text: String
    let detectedLanguage: String?
    let confidence: Double?
    let avgLogProb: Double?
    let duration: TimeInterval?
}

/// Result type for chunked transcription
struct ChunkTranscriptionResult: Equatable {
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
