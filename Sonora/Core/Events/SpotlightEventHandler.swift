import Foundation

/// Event handler that keeps Core Spotlight index in sync with memo lifecycle
@MainActor
final class SpotlightEventHandler {
    private let subscriptionManager: EventSubscriptionManager
    private let indexer: any SpotlightIndexing

    init(
        logger: any LoggerProtocol = Logger.shared,
        eventBus: any EventBusProtocol,
        indexer: any SpotlightIndexing
    ) {
        self.subscriptionManager = EventSubscriptionManager(eventBus: eventBus)
        self.indexer = indexer

        setup()
        logger.info("SpotlightEventHandler initialized", category: .system, context: LogContext(additionalInfo: ["component": "Spotlight"]))
    }

    private func setup() {
        subscriptionManager.subscribe(to: AppEvent.self) { [weak self] event in
            Task { @MainActor in
                await self?.handle(event)
            }
        }
    }

    private func handle(_ event: AppEvent) async {
        guard AppConfiguration.shared.searchIndexingEnabled else { return }
        switch event {
        case .memoCreated(let memo):
            await indexer.index(memoID: memo.id)
        case .transcriptionCompleted(let memoId, _):
            await indexer.index(memoID: memoId)
        case .analysisCompleted(let memoId, _, _):
            await indexer.index(memoID: memoId)
        default:
            break
        }
    }
}
