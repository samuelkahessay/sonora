import Combine
import Foundation

private enum DistillationCoordinatorError: Error {
    case transcriptUnavailable
    case dataUnavailable
    case memoNotFound
}

/// Coordinates auto-distillation jobs for memos
///
/// State Management:
/// - stateByMemo: Published UI state for all memos
/// - successStateByMemo: Lightweight cache of analyzed memos
///   - Prevents redundant analysis checks
///   - Auto-cleaned when memos deleted
///   - Memory: ~48 bytes/entry, bounded by memo count
///
/// Job Processing:
/// - Sequential processing (currentTask guards concurrency)
/// - Failed jobs retry up to 3 times
/// - Success results cached, jobs deleted from repository
@MainActor
final class DistillationCoordinator: ObservableObject {
    @Published private(set) var stateByMemo: [UUID: DistillationState] = [:]

    private let maxRetryCount = 3
    private let analyzeLiteDistillUseCase: any AnalyzeLiteDistillUseCaseProtocol
    private let analyzeDistillUseCase: any AnalyzeDistillUseCaseProtocol
    private let analyzeDistillParallelUseCase: any AnalyzeDistillParallelUseCaseProtocol
    private let memoRepository: any MemoRepository
    private let transcriptionRepository: any TranscriptionRepository
    private let analysisRepository: any AnalysisRepository
    private let jobRepository: any AutoDistillJobRepository
    private let storeKitService: any StoreKitServiceProtocol
    private let logger: any LoggerProtocol

    private var jobsCancellable: AnyCancellable?
    private var memoCancellable: AnyCancellable?
    private var currentTask: Task<Void, Never>?

    /// Success state cache: stores analysis mode for completed distillations
    /// - Populated: when job succeeds or repository check finds existing result
    /// - Queried: in state(for:) to avoid repository lookups
    /// - Cleaned: when memos are deleted via memosPublisher subscription
    /// - Lifecycle: exists as long as memo exists in repository
    /// - Memory: ~48 bytes per entry (typical: 10-100 entries = 480-4800 bytes)
    private var successStateByMemo: [UUID: AnalysisMode] = [:]

    init(
        analyzeLiteDistillUseCase: any AnalyzeLiteDistillUseCaseProtocol,
        analyzeDistillUseCase: any AnalyzeDistillUseCaseProtocol,
        analyzeDistillParallelUseCase: any AnalyzeDistillParallelUseCaseProtocol,
        memoRepository: any MemoRepository,
        transcriptionRepository: any TranscriptionRepository,
        analysisRepository: any AnalysisRepository,
        jobRepository: any AutoDistillJobRepository,
        storeKitService: any StoreKitServiceProtocol,
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.analyzeLiteDistillUseCase = analyzeLiteDistillUseCase
        self.analyzeDistillUseCase = analyzeDistillUseCase
        self.analyzeDistillParallelUseCase = analyzeDistillParallelUseCase
        self.memoRepository = memoRepository
        self.transcriptionRepository = transcriptionRepository
        self.analysisRepository = analysisRepository
        self.jobRepository = jobRepository
        self.storeKitService = storeKitService
        self.logger = logger

        jobsCancellable = jobRepository.jobsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] jobs in
                self?.handleJobsUpdate(jobs)
            }

        memoCancellable = memoRepository.memosPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] memos in
                self?.cleanupSuccessStates(validMemos: memos)
                Task { await self?.resumePendingJobsIfNeeded(memos: memos) }
            }

        handleJobsUpdate(jobRepository.fetchAllJobs())
        Task {
            await resumePendingJobsIfNeeded(memos: memoRepository.memos)
        }
        processQueueIfNeeded()
    }

    func statePublisher(for memoId: UUID) -> AnyPublisher<DistillationState, Never> {
        $stateByMemo
            .map { $0[memoId] ?? .idle }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func state(for memoId: UUID) async -> DistillationState {
        // Check active jobs first
        if let job = jobRepository.job(for: memoId) {
            let derived = DistillationState(job: job)
            stateByMemo[memoId] = derived
            return derived
        }

        // Check success cache
        if let mode = successStateByMemo[memoId] {
            let state = DistillationState.success(mode)
            stateByMemo[memoId] = state
            return state
        }

        // Fallback: check repository
        let (hasCached, mode) = await hasCachedResult(for: memoId)
        if hasCached {
            successStateByMemo[memoId] = mode
            let state = DistillationState.success(mode)
            stateByMemo[memoId] = state
            return state
        }

        return .idle
    }

    func enqueue(memoId: UUID) {
        Task {
            let (hasCached, mode) = await hasCachedResult(for: memoId)
            if hasCached {
                await MainActor.run {
                    successStateByMemo[memoId] = mode
                    stateByMemo[memoId] = .success(mode)
                }
                return
            }

            await MainActor.run {
                if let existing = jobRepository.job(for: memoId) {
                    switch existing.status {
                    case .queued, .processing:
                        return
                    case .failed:
                        // Check if maximum retry count exceeded
                        if existing.retryCount >= maxRetryCount {
                            let permanentFailure = DistillationState.failed(
                                reason: .unknown,
                                message: "Maximum retry attempts (\(maxRetryCount)) exceeded"
                            )
                            stateByMemo[memoId] = permanentFailure
                            logger.warning(
                                "Auto distillation permanently failed after max retries",
                                category: .analysis,
                                context: LogContext(additionalInfo: [
                                    "memoId": memoId.uuidString,
                                    "retryCount": String(existing.retryCount)
                                ]),
                                error: nil
                            )
                            return
                        }
                        let retryJob = existing.updating(
                            status: .queued,
                            mode: mode,
                            updatedAt: Date(),
                            retryCount: existing.retryCount,
                            lastError: nil,
                            failureReason: nil
                        )
                        jobRepository.save(retryJob)
                    }
                } else {
                    let job = AutoDistillJob(
                        memoId: memoId,
                        status: .queued,
                        mode: mode,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                    jobRepository.save(job)
                }

                stateByMemo[memoId] = .inProgress
                processQueueIfNeeded()
            }
        }
    }

    func appDidBecomeActive() {
        Task {
            await resumePendingJobsIfNeeded(memos: memoRepository.memos)
        }
        processQueueIfNeeded()
    }

    // MARK: - Internal Processing

    private func handleJobsUpdate(_ jobs: [AutoDistillJob]) {
        var updatedStates: [UUID: DistillationState] = [:]

        // Update states for active jobs
        for job in jobs {
            let state: DistillationState
            // Preserve streaming progress if job hasn't failed
            if case .streaming(let progress) = stateByMemo[job.memoId], job.status != .failed {
                state = .streaming(progress)
            } else {
                state = DistillationState(job: job)
            }
            updatedStates[job.memoId] = state
        }

        // Preserve retained success states for memos without active jobs
        for (memoId, mode) in successStateByMemo where updatedStates[memoId] == nil {
            updatedStates[memoId] = .success(mode)
        }

        stateByMemo = updatedStates
        processQueueIfNeeded()
    }

    private func processQueueIfNeeded() {
        guard currentTask == nil else { return }
        let pendingJobs = jobRepository.fetchQueuedJobs()
            .sorted { lhs, rhs in lhs.createdAt < rhs.createdAt }
        guard let nextJob = pendingJobs.first else { return }
        currentTask = Task { [weak self] in
            await self?.run(job: nextJob)
        }
    }

    private func resumePendingJobsIfNeeded(memos: [Memo]) async {
        guard !memos.isEmpty else { return }

        var candidates: [Memo] = []
        for memo in memos {
            if await shouldAutoDistill(memo) && jobRepository.job(for: memo.id) == nil {
                candidates.append(memo)
            }
        }

        guard !candidates.isEmpty else { return }

        candidates.forEach { memo in
            logger.info(
                "Resuming auto-distill job",
                category: .analysis,
                context: LogContext(additionalInfo: ["memoId": memo.id.uuidString])
            )
            enqueue(memoId: memo.id)
        }
    }

    /// Remove success state entries for memos that no longer exist
    ///
    /// This method is called whenever the memo list changes (via memosPublisher).
    /// It prevents unbounded memory growth by removing cache entries for deleted memos.
    ///
    /// - Parameter validMemos: Current list of memos from repository
    /// - Complexity: O(m + s) where m = memo count, s = success state count
    /// - Note: Runs synchronously on main actor; minimal performance impact
    private func cleanupSuccessStates(validMemos: [Memo]) {
        let validMemoIds = Set(validMemos.map { $0.id })
        let entriesToRemove = successStateByMemo.keys.filter { !validMemoIds.contains($0) }

        guard !entriesToRemove.isEmpty else { return }

        for memoId in entriesToRemove {
            successStateByMemo.removeValue(forKey: memoId)
        }

        logger.debug(
            "Cleaned up \(entriesToRemove.count) success state entries for deleted memos",
            category: .analysis,
            context: LogContext()
        )
    }

    private func run(job: AutoDistillJob) async {
        await MainActor.run {
            let processingJob = job.updating(status: .processing, updatedAt: Date())
            jobRepository.save(processingJob)
            stateByMemo[job.memoId] = .inProgress
        }

        do {
            try await executeJob(for: job)
            await MainActor.run { [weak self] in
                guard let self else { return }
                let successMode = storeKitService.isPro ? AnalysisMode.distill : .liteDistill
                successStateByMemo[job.memoId] = successMode
                stateByMemo[job.memoId] = .success(successMode)
                jobRepository.deleteJob(for: job.memoId)
                currentTask = nil
                processQueueIfNeeded()
            }
        } catch {
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let coordinatorError = error as? DistillationCoordinatorError,
                   coordinatorError == .memoNotFound {
                    jobRepository.deleteJob(for: job.memoId)
                    successStateByMemo.removeValue(forKey: job.memoId)
                    stateByMemo[job.memoId] = .idle
                    currentTask = nil
                    processQueueIfNeeded()
                    logger.info(
                        "Dropping auto distillation job because memo is missing",
                        category: .analysis,
                        context: LogContext(additionalInfo: [
                            "memoId": job.memoId.uuidString
                        ])
                    )
                    return
                }
                let reason = classifyFailure(error)
                let message = failureMessage(from: error)
                let failedJob = job.updating(
                    status: .failed,
                    updatedAt: Date(),
                    retryCount: job.retryCount + 1,
                    lastError: message,
                    failureReason: reason
                )
                jobRepository.save(failedJob)
                let failedState = DistillationState(job: failedJob)
                stateByMemo[job.memoId] = failedState
                currentTask = nil
                processQueueIfNeeded()
                logger.warning(
                    "Auto distillation failed",
                    category: .analysis,
                    context: LogContext(additionalInfo: [
                        "memoId": job.memoId.uuidString,
                        "reason": reason.rawValue,
                        "message": message
                    ]),
                    error: error
                )
            }
        }
    }

    private func executeJob(for job: AutoDistillJob) async throws {
        guard let memo = memoRepository.getMemo(by: job.memoId) else {
            logger.warning(
                "Memo not found when executing distillation job",
                category: .analysis,
                context: LogContext(additionalInfo: [
                    "memoId": job.memoId.uuidString,
                    "jobStatus": job.status.rawValue,
                    "jobCreatedAt": job.createdAt.ISO8601Format()
                ]),
                error: nil
            )
            throw DistillationCoordinatorError.memoNotFound
        }

        guard let transcript = await transcriptionRepository.getTranscriptionText(for: job.memoId), !transcript.isEmpty else {
            throw DistillationCoordinatorError.transcriptUnavailable
        }

        let mode: AnalysisMode = storeKitService.isPro ? .distill : .liteDistill

        if mode == .liteDistill {
            _ = try await analyzeLiteDistillUseCase.execute(transcript: transcript, memoId: memo.id)
            return
        }

        do {
            _ = try await analyzeDistillParallelUseCase.execute(
                transcript: transcript,
                memoId: memo.id
            ) { @MainActor [weak self] progress in
                self?.stateByMemo[memo.id] = .streaming(progress)
            }
        } catch {
            // If parallel fails, fall back to non-parallel distill
            _ = try await analyzeDistillUseCase.execute(transcript: transcript, memoId: memo.id)
        }
    }

    private func hasCachedResult(for memoId: UUID) async -> (Bool, AnalysisMode) {
        let mode: AnalysisMode = storeKitService.isPro ? .distill : .liteDistill
        let hasCached = await analysisRepository.hasAnalysisResult(for: memoId, mode: mode)
        return (hasCached, mode)
    }

    private func shouldAutoDistill(_ memo: Memo) async -> Bool {
        guard memo.transcriptionStatus.isCompleted else { return false }

        let currentState = stateByMemo[memo.id] ?? .idle
        if case .success = currentState { return false }

        if let job = jobRepository.job(for: memo.id) {
            switch job.status {
            case .queued, .processing:
                return false
            case .failed:
                break
            }
        }

        let (hasCached, _) = await hasCachedResult(for: memo.id)
        if hasCached { return false }

        guard let transcript = await transcriptionRepository.getTranscriptionText(for: memo.id),
              !transcript.isEmpty else { return false }
        let wordCount = tokenizeWords(transcript).count
        guard wordCount >= 2 else { return false }

        return true
    }

    private func classifyFailure(_ error: Error) -> AutoDistillJob.FailureReason {
        if let coordinatorError = error as? DistillationCoordinatorError {
            switch coordinatorError {
            case .transcriptUnavailable: return .transcriptUnavailable
            case .dataUnavailable: return .configuration
            case .memoNotFound: return .validation
            }
        }

        if let analysisError = error as? AnalysisError {
            switch analysisError {
            case .timeout: return .timeout
            case .networkError: return .network
            case .serverError: return .server
            case .emptyTranscript, .transcriptTooShort, .invalidMemoId: return .validation
            case .analysisServiceError(let message):
                if message.lowercased().contains("quota") { return .quotaExceeded }
                return .server
            case .paymentRequired: return .quotaExceeded
            case .invalidResponse, .serviceUnavailable, .cacheError, .repositoryError: return .server
            case .invalidURL, .noData, .decodingError, .systemBusy: return .configuration
            }
        }

        if let serviceError = error as? ServiceError {
            switch serviceError {
            case .analysisServiceTimeout: return .timeout
            case .analysisAPIQuotaExceeded: return .quotaExceeded
            case .analysisServiceOffline, .analysisModelUnavailable, .analysisResultInvalid, .analysisProcessingFailed: return .server
            case .analysisInputTooShort, .analysisInputTooLong, .analysisLanguageUnsupported: return .validation
            case .analysisAPIKeyInvalid: return .configuration
            case .analysisServiceRateLimited: return .server
            default: return .unknown
            }
        }

        if let urlError = error as? URLError {
            return urlError.code == .timedOut ? .timeout : .network
        }

        return .unknown
    }

    private func failureMessage(from error: Error) -> String {
        let description = error.localizedDescription
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? description : trimmed
    }

    private func tokenizeWords(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
}
