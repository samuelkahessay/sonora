import Foundation

// MARK: - DIContainer Analysis/AI Extensions

extension DIContainer {

    /// Create a transcription service based on current user preferences
    @MainActor
    func createTranscriptionService() -> any TranscriptionAPI {
        return transcriptionServiceFactory().createTranscriptionService()
    }

    /// Get analysis service
    @MainActor
    func analysisService() -> any AnalysisServiceProtocol {
        ensureConfigured()
        trackServiceAccess("AnalysisService")

        if AppConfiguration.shared.useLocalAnalysis {
            if _localAnalysisService == nil {
                _localAnalysisService = LocalAnalysisService()
                print("🤖 DIContainer: Created LocalAnalysisService instance")
            }
            return _localAnalysisService!
        }

        if let existing = _analysisService {
            return existing
        }

        _analysisService = AnalysisService()
        return _analysisService!
    }

    /// Explicit local analysis service (on-device)
    @MainActor
    func localAnalysisService() -> any AnalysisServiceProtocol {
        ensureConfigured()
        if _localAnalysisService == nil {
            _localAnalysisService = LocalAnalysisService()
        }
        return _localAnalysisService!
    }

    /// Get moderation service
    @MainActor
    func moderationService() -> any ModerationServiceProtocol {
        ensureConfigured()
        guard let svc = _moderationService else { fatalError("DIContainer not configured: moderationService") }
        return svc
    }
}
