import Foundation

/// Metadata attached to outbound transcription requests so the server and logs can correlate events.
struct TranscriptionRequestContext: Sendable {
    let correlationId: String
    let memoId: UUID?
    let chunkIndex: Int?
    let chunkCount: Int?
}

/// Protocol for transcription services that handle audio-to-text conversion
/// Provides a clean abstraction for the core transcription functionality
protocol TranscriptionAPI: Sendable {
    /// Core transcription entry-point used by all higher-level helpers.
    /// - Parameters:
    ///   - url: Local URL of the audio file.
    ///   - language: Optional ISO 639-1 language hint.
    ///   - context: Optional metadata for diagnostics/correlation.
    func transcribe(
        url: URL,
        language: String?,
        context: TranscriptionRequestContext?
    ) async throws -> TranscriptionResponse
}

extension TranscriptionAPI {
    /// Backward-compatible helper that preserves the existing call sites returning plain text.
    func transcribe(url: URL) async throws -> String {
        try await transcribe(url: url, language: nil, context: nil).text
    }

    /// Backward-compatible helper that preserves the existing call sites requesting metadata.
    func transcribe(url: URL, language: String?) async throws -> TranscriptionResponse {
        try await transcribe(url: url, language: language, context: nil)
    }
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
