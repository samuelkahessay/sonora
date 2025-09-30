import Foundation
@preconcurrency import Combine

@MainActor
final class LiveActivityEventHandler {
    private let logger: any LoggerProtocol
    private let subscriptionManager: EventSubscriptionManager

    private let memoRepository: any MemoRepository
    private let audioRepository: any AudioRepository
    private let startUseCase: any StartLiveActivityUseCaseProtocol
    private let updateUseCase: any UpdateLiveActivityUseCaseProtocol
    private let endUseCase: any EndLiveActivityUseCaseProtocol

    private var cancellables = Set<AnyCancellable>()
    private var lastLiveActivityUpdateAt: Date = .distantPast
    private let minUpdateInterval: TimeInterval = 0.5 // 2 Hz max

    init(
        logger: any LoggerProtocol,
        eventBus: any EventBusProtocol,
        memoRepository: any MemoRepository,
        audioRepository: any AudioRepository,
        startUseCase: any StartLiveActivityUseCaseProtocol,
        updateUseCase: any UpdateLiveActivityUseCaseProtocol,
        endUseCase: any EndLiveActivityUseCaseProtocol
    ) {
        self.logger = logger
        self.subscriptionManager = EventSubscriptionManager(eventBus: eventBus)
        self.memoRepository = memoRepository
        self.audioRepository = audioRepository
        self.startUseCase = startUseCase
        self.updateUseCase = updateUseCase
        self.endUseCase = endUseCase

        setupEventSubscriptions()
        setupRecordingTimeUpdates()

        logger.debug("LiveActivityEventHandler initialized", category: .system, context: LogContext())
    }

    convenience init(
        logger: any LoggerProtocol,
        eventBus: any EventBusProtocol
    ) {
        let container = DIContainer.shared
        let memoRepo = container.memoRepository()
        let audioRepo = container.audioRepository()
        let service = container.liveActivityService()
        let start = StartLiveActivityUseCase(liveActivityService: service)
        let update = UpdateLiveActivityUseCase(liveActivityService: service)
        let end = EndLiveActivityUseCase(liveActivityService: service)
        self.init(
            logger: logger,
            eventBus: eventBus,
            memoRepository: memoRepo,
            audioRepository: audioRepo,
            startUseCase: start,
            updateUseCase: update,
            endUseCase: end
        )
    }

    private func setupEventSubscriptions() {
        subscriptionManager.subscribe(to: AppEvent.self) { [weak self] event in
            Task { @MainActor in
                await self?.handle(event)
            }
        }
    }

    private func setupRecordingTimeUpdates() {
        // Throttle updates by relying on Combine polling already at 0.1s; ActivityKit handles rate internally.
        audioRepository.isRecordingPublisher
            .combineLatest(audioRepository.recordingTimePublisher, audioRepository.audioLevelPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording, time, level in
                guard let self = self else { return }
                guard isRecording else { return }
                // Throttle updates to 2 Hz
                let now = Date()
                if now.timeIntervalSince(self.lastLiveActivityUpdateAt) < self.minUpdateInterval { return }
                self.lastLiveActivityUpdateAt = now
                Task { @MainActor in
                    do {
                        // Use metered level from repository; fall back to calm cycle if NaN/out-of-range
                        let clamped = max(0.0, min(1.0, level.isFinite ? level : 0.0))
                        let effectiveLevel: Double
                        if clamped > 0 { effectiveLevel = clamped } else {
                            let phase = (time.truncatingRemainder(dividingBy: 3.0)) / 3.0
                            effectiveLevel = max(0.0, min(1.0, 0.5 + 0.35 * sin(2 * .pi * phase)))
                        }
                        try await self.updateUseCase.execute(
                            duration: time,
                            isCountdown: self.audioRepository.isInCountdown,
                            remainingTime: self.audioRepository.isInCountdown ? self.audioRepository.remainingTime : nil,
                            level: effectiveLevel
                        )
                    } catch {
                        // Ignore update errors when no activity is active
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func handle(_ event: AppEvent) async {
        switch event {
        case .recordingStarted(let memoId):
            let title = memoRepository.getMemo(by: memoId)?.filename ?? "Recording"
            do {
                try await startUseCase.execute(memoTitle: title, startTime: Date())
                logger.debug("Live Activity started for memo: \(memoId)", category: .system, context: LogContext())
            } catch {
                logger.error("Failed to start Live Activity", category: .system, context: LogContext(additionalInfo: ["memoId": memoId.uuidString]), error: error)
            }
        case .recordingCompleted:
            do {
                try await endUseCase.execute(dismissalPolicy: .afterDelay(4))
                logger.debug("Live Activity ended", category: .system, context: LogContext())
            } catch {
                logger.error("Failed to end Live Activity", category: .system, context: LogContext(), error: error)
            }
        default:
            break
        }
    }

    deinit {
        subscriptionManager.cleanup()
    }
}
