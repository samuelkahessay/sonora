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

    // Consolidated surface: callers perform chunking and call transcribe(url:language:) per chunk.

    private func saveSource() async {
        guard let memoId = CurrentTranscriptionContext.memoId else { return }
        
        var meta = repo.getTranscriptionMetadata(for: memoId) ?? TranscriptionMetadata()
        meta.transcriptionService = source
        meta.whisperModel = UserDefaults.standard.selectedWhisperModel
        meta.timestamp = Date()
        repo.saveTranscriptionMetadata(meta, for: memoId)
    }
}
