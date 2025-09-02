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
        saveSource()
        return text
    }

    func transcribe(url: URL, language: String?) async throws -> TranscriptionResponse {
        let resp = try await base.transcribe(url: url, language: language)
        saveSource()
        return resp
    }

    func transcribeChunks(segments: [VoiceSegment], audioURL: URL) async throws -> [ChunkTranscriptionResult] {
        let results = try await base.transcribeChunks(segments: segments, audioURL: audioURL)
        saveSource()
        return results
    }

    func transcribeChunks(segments: [VoiceSegment], audioURL: URL, language: String?) async throws -> [ChunkTranscriptionResult] {
        let results = try await base.transcribeChunks(segments: segments, audioURL: audioURL, language: language)
        saveSource()
        return results
    }

    private func saveSource() {
        guard let id = CurrentTranscriptionContext.memoId else { return }
        var meta = repo.getTranscriptionMetadata(for: id) ?? [:]
        meta["transcriptionService"] = (source == .localWhisperKit) ? "local_whisperkit" : "cloud_api"
        meta["whisperModel"] = UserDefaults.standard.selectedWhisperModel
        meta["timestamp"] = ISO8601DateFormatter().string(from: Date())
        repo.saveTranscriptionMetadata(meta, for: id)
    }
}

