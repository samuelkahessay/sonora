import Foundation

/// Factory for creating transcription services.
@MainActor
final class TranscriptionServiceFactory {
    private let logger = Logger.shared
    private var cloudService: TranscriptionAPI?

    init() {
        logger.debug("TranscriptionServiceFactory initialized (cloud-only mode)")
    }

    func createTranscriptionService() -> TranscriptionAPI {
        if let cached = cloudService {
            return cached
        }

        logger.info("Creating cloud transcription service")
        let service = TranscriptionService()
        cloudService = service
        return service
    }
}
