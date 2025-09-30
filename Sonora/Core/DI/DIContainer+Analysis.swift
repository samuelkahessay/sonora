import Foundation

// MARK: - DIContainer Analysis/AI Extensions

extension DIContainer {

    /// Create a transcription service based on current user preferences
    @MainActor
    func createTranscriptionService() -> any TranscriptionAPI {
        transcriptionServiceFactory().createTranscriptionService()
    }

    /// Get analysis service
    @MainActor
    func analysisService() -> any AnalysisServiceProtocol {
        ensureConfigured()
        trackServiceAccess("AnalysisService")

        if let existing = _analysisService {
            return existing
        }

        let service = AnalysisService()
        _analysisService = service
        return service
    }

    /// Get moderation service
    @MainActor
    func moderationService() -> any ModerationServiceProtocol {
        ensureConfigured()
        guard let svc = _moderationService else { fatalError("DIContainer not configured: moderationService") }
        return svc
    }

    /// Shared filler word filter for transcript post-processing.
    @MainActor
    func fillerWordFilter() -> any FillerWordFiltering {
        ensureConfigured()
        if let existing = _fillerWordFilter {
            return existing
        }
        let filter = DefaultFillerWordFilter()
        _fillerWordFilter = filter
        return filter
    }
}
