import Foundation
import SwiftData

// MARK: - DIContainer Repository Extensions

extension DIContainer {

    /// Get memo repository
    @MainActor
    func memoRepository() -> any MemoRepository {
        ensureConfigured()
        trackServiceAccess("MemoRepository")

        if let existing = _memoRepository {
            return existing
        }

        // Re-create if needed
        initializePersistenceIfNeeded()

        guard let repository = _memoRepository else {
            fatalError("DIContainer: Failed to create MemoRepository")
        }

        return repository
    }

    /// Get transcription repository
    @MainActor
    func transcriptionRepository() -> any TranscriptionRepository {
        ensureConfigured()
        if _transcriptionRepository == nil { initializePersistenceIfNeeded() }
        guard let repo = _transcriptionRepository else { fatalError("DIContainer not configured: transcriptionRepository") }
        return repo
    }

    /// Get analysis repository
    @MainActor
    func analysisRepository() -> any AnalysisRepository {
        ensureConfigured()
        if _analysisRepository == nil { initializePersistenceIfNeeded() }
        guard let repo = _analysisRepository else { fatalError("DIContainer not configured: analysisRepository") }
        return repo
    }
}

