import Foundation

/// Handles WhisperKit lifecycle events to optimize performance and memory
/// - Prewarms the local model when recording starts to cut transcription latency
/// - Optionally unloads the model after transcription completes to free memory
@MainActor
public final class WhisperKitEventHandler {
    private let logger: any LoggerProtocol
    private let subscriptionManager: EventSubscriptionManager
    private let config = AppConfiguration.shared

    init(
        logger: any LoggerProtocol = Logger.shared,
        eventBus: any EventBusProtocol = EventBus.shared
    ) {
        self.logger = logger
        self.subscriptionManager = EventSubscriptionManager(eventBus: eventBus)

        setupSubscriptions()
        logger.info("WhisperKitEventHandler initialized", category: .system, context: LogContext())
    }

    private func setupSubscriptions() {
        subscriptionManager.subscribe(to: AppEvent.self) { [weak self] event in
            Task { @MainActor in
                await self?.handle(event)
            }
        }
    }

    private func handle(_ event: AppEvent) async {
        switch event {
        case .recordingStarted:
            // Prewarm disabled due to strict mutual exclusion + memory constraints
            logger.debug("WhisperKitEventHandler: recordingStarted → prewarm skipped", category: .transcription, context: LogContext())

        case .transcriptionCompleted:
            // Optionally unload after transcription to reduce memory pressure
            if config.releaseLocalModelAfterTranscription {
                logger.info("WhisperKitEventHandler: transcriptionCompleted → unloading model (per config)", category: .transcription, context: LogContext())
                DIContainer.shared.whisperKitModelManager().unloadModel()
            }

        default:
            break
        }
    }

    deinit {
        subscriptionManager.cleanup()
    }
}
