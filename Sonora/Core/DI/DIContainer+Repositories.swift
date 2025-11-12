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

    /// Recording usage repository (UserDefaults-backed)
    @MainActor
    func recordingUsageRepository() -> any RecordingUsageRepository {
        ensureConfigured()
        if let repo = _recordingUsageRepository { return repo }
        guard let repo = resolve((any RecordingUsageRepository).self) else {
            fatalError("DIContainer not configured: recordingUsageRepository")
        }
        _recordingUsageRepository = repo
        return repo
    }

    /// Recording quota policy (monthly limits)
    @MainActor
    func recordingQuotaPolicy() -> any RecordingQuotaPolicyProtocol {
        ensureConfigured()
        if let policy = _recordingQuotaPolicy { return policy }
        guard let policy = resolve((any RecordingQuotaPolicyProtocol).self) else {
            fatalError("DIContainer not configured: recordingQuotaPolicy")
        }
        _recordingQuotaPolicy = policy
        return policy
    }

    // MARK: - Use Cases (Recording Quota)

    @MainActor
    func getRemainingMonthlyQuotaUseCase() -> any GetRemainingMonthlyQuotaUseCaseProtocol {
        ensureConfigured()
        if let uc = _getRemainingMonthlyQuotaUseCase { return uc }
        let uc = GetRemainingMonthlyQuotaUseCase(
            quotaPolicy: recordingQuotaPolicy(),
            usageRepository: recordingUsageRepository()
        )
        _getRemainingMonthlyQuotaUseCase = uc
        return uc
    }

    /// Get model context for direct SwiftData access (use sparingly)
    @MainActor
    func modelContext() -> ModelContext {
        ensureConfigured()
        guard let ctx = _modelContext else {
            fatalError("DIContainer not configured: modelContext")
        }
        return ctx
    }
}
