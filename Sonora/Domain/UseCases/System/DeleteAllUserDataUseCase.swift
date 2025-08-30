import Foundation

/// Atomically delete all on-device user data by staging to a Trash folder first.
/// If staging succeeds, the Trash is removed. On any failure, previously moved
/// items are rolled back to their original locations.
@MainActor
protocol DeleteAllUserDataUseCaseProtocol {
    func execute() async throws
}

@MainActor
final class DeleteAllUserDataUseCase: DeleteAllUserDataUseCaseProtocol {
    private let memoRepository: any MemoRepository
    private let transcriptionRepository: any TranscriptionRepository
    private let analysisRepository: any AnalysisRepository
    private let logger: any LoggerProtocol

    init(
        memoRepository: any MemoRepository,
        transcriptionRepository: any TranscriptionRepository,
        analysisRepository: any AnalysisRepository,
        logger: any LoggerProtocol
    ) {
        self.memoRepository = memoRepository
        self.transcriptionRepository = transcriptionRepository
        self.analysisRepository = analysisRepository
        self.logger = logger
    }

    func execute() async throws {
        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let trashRoot = documents.appendingPathComponent(".Trash", isDirectory: true)
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let trash = trashRoot.appendingPathComponent(timestamp, isDirectory: true)

        let targets: [String] = ["Memos", "transcriptions", "analysis"]
        var moves: [(from: URL, to: URL)] = []

        // Ensure Trash path exists
        do {
            if !fm.fileExists(atPath: trash.path) {
                try fm.createDirectory(at: trash, withIntermediateDirectories: true)
            }
        } catch {
            logger.error("Failed to create Trash directory", category: .repository, context: LogContext(additionalInfo: ["path": trash.path]), error: error)
            throw error
        }

        // Stage: move each target directory into Trash
        do {
            for name in targets {
                let src = documents.appendingPathComponent(name, isDirectory: true)
                guard fm.fileExists(atPath: src.path) else { continue }
                let dst = trash.appendingPathComponent(name, isDirectory: true)
                try fm.moveItem(at: src, to: dst)
                moves.append((from: src, to: dst))
            }
        } catch {
            // Rollback any staged moves
            logger.warning("Staging move failed; rolling back", category: .repository, context: nil, error: error)
            for (from, to) in moves.reversed() {
                if fm.fileExists(atPath: to.path) {
                    try? fm.moveItem(at: to, to: from)
                }
            }
            // Best-effort cleanup of empty trash
            try? fm.removeItem(at: trash)
            throw error
        }

        // Commit: remove the staged Trash folder
        do {
            try fm.removeItem(at: trash)
        } catch {
            // Deletion failed; rollback for atomicity
            logger.warning("Trash delete failed; rolling back", category: .repository, context: LogContext(additionalInfo: ["trash": trash.path]), error: error)
            for (from, to) in moves.reversed() {
                if fm.fileExists(atPath: to.path) {
                    try? fm.moveItem(at: to, to: from)
                }
            }
            // Attempt to remove the created Trash folder if empty
            try? fm.removeItem(at: trash)
            throw error
        }

        // Refresh repositories after deletion
        memoRepository.loadMemos()
        transcriptionRepository.clearTranscriptionCache()
        analysisRepository.clearCache()
    }
}

