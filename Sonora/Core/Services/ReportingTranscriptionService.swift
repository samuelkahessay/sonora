import Foundation

@MainActor
struct CurrentTranscriptionContext {
    static var memoId: UUID?
}

@MainActor
final class ReportingTranscriptionService: TranscriptionAPI {
    private let base: any TranscriptionAPI
    private let source: TranscriptionServiceType
    private let repo: any TranscriptionRepository

    init(base: any TranscriptionAPI, source: TranscriptionServiceType, repo: any TranscriptionRepository) {
        self.base = base
        self.source = source
        self.repo = repo
    }

    func transcribe(url: URL) async throws -> String {
        let text = try await base.transcribe(url: url)
        await saveSource()
        return text
    }

    func transcribe(url: URL, language: String?) async throws -> TranscriptionResponse {
        let resp = try await base.transcribe(url: url, language: language)
        await saveSource()
        return resp
    }

    func transcribeChunks(segments: [VoiceSegment], audioURL: URL) async throws -> [ChunkTranscriptionResult] {
        let results = try await base.transcribeChunks(segments: segments, audioURL: audioURL)
        await saveSource()
        return results
    }

    func transcribeChunks(segments: [VoiceSegment], audioURL: URL, language: String?) async throws -> [ChunkTranscriptionResult] {
        let results = try await base.transcribeChunks(segments: segments, audioURL: audioURL, language: language)
        await saveSource()
        return results
    }

    private func saveSource() async {
        guard let memoId = CurrentTranscriptionContext.memoId else { return }
        
        var meta = repo.getTranscriptionMetadata(for: memoId) ?? TranscriptionMetadata()
        meta.transcriptionService = source
        meta.whisperModel = UserDefaults.standard.selectedWhisperModel
        meta.timestamp = Date()
        repo.saveTranscriptionMetadata(meta, for: memoId)
    }
}
