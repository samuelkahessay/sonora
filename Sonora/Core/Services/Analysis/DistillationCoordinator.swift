import Combine
import Foundation

private enum DistillationCoordinatorError: Error {
    case transcriptUnavailable
    case dataUnavailable
}

/// Simple LRU cache with maximum size limit
private struct LRUCache<Key: Hashable, Value> {
    private var cache: [Key: Value] = [:]
    private var accessOrder: [Key] = []
    private let maxSize: Int

    init(maxSize: Int) {
        self.maxSize = maxSize
    }

    mutating func get(_ key: Key) -> Value? {
        guard let value = cache[key] else { return nil }
        // Move to end (most recently used)
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        return value
    }

    mutating func set(_ key: Key, value: Value?) {
        if let value = value {
            // Remove if exists to update position
            if cache[key] != nil {
                accessOrder.removeAll { $0 == key }
            }

            cache[key] = value
            accessOrder.append(key)

            // Evict oldest if over capacity
            while accessOrder.count > maxSize {
                if let oldest = accessOrder.first {
                    accessOrder.removeFirst()
                    cache.removeValue(forKey: oldest)
                }
            }
        } else {
            // Remove if value is nil
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
    }

    func contains(_ key: Key) -> Bool {
        cache[key] != nil
    }

    subscript(key: Key) -> Value? {
        get { cache[key] }
    }

    var allEntries: [(key: Key, value: Value)] {
        cache.map { ($0.key, $0.value) }
    }
}

/// Entry tracking state with optional success retention metadata
private struct StateEntry {
    let state: DistillationState
    let retainedAt: Date?  // Non-nil if success state retained after job deletion

    init(state: DistillationState, retainedAt: Date? = nil) {
        self.state = state
        self.retainedAt = retainedAt
    }

    /// Create a retained success entry
    static func retainedSuccess(mode: AnalysisMode) -> StateEntry {
        StateEntry(state: .success(mode), retainedAt: Date())
    }
}

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

    // Single source of truth: combines active states and retained success states
    private var stateEntries = LRUCache<UUID, StateEntry>(maxSize: 100)

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
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { [weak self] memos in
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
        // Check consolidated state cache first
        if let entry = stateEntries.get(memoId) {
            return entry.state
        }

        // Check active jobs
        if let job = jobRepository.job(for: memoId) {
            let derived = DistillationState(job: job)
            stateEntries.set(memoId, value: StateEntry(state: derived))
            stateByMemo[memoId] = derived
            return derived
        }

        // Check if analysis result exists in repository (cache miss)
        let mode: AnalysisMode = storeKitService.isPro ? .distill : .liteDistill
        let hasCached = await analysisRepository.hasAnalysisResult(for: memoId, mode: mode)
        if hasCached {
            let entry = StateEntry.retainedSuccess(mode: mode)
            stateEntries.set(memoId, value: entry)
            stateByMemo[memoId] = entry.state
            return entry.state
        }

        return .idle
    }

    func enqueue(memoId: UUID) {
        Task {
            let mode: AnalysisMode = storeKitService.isPro ? .distill : .liteDistill
            let hasCached = await analysisRepository.hasAnalysisResult(for: memoId, mode: mode)
            if hasCached {
                await MainActor.run {
                    let entry = StateEntry.retainedSuccess(mode: mode)
                    stateEntries.set(memoId, value: entry)
                    stateByMemo[memoId] = entry.state
                }
                return
            }

            await MainActor.run {
                stateEntries.set(memoId, value: nil)
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
                            retryCount: existing.retryCount + 1,
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
            stateEntries.set(job.memoId, value: StateEntry(state: state))
        }

        // Preserve retained success states for memos without active jobs
        for (memoId, entry) in stateEntries.allEntries where updatedStates[memoId] == nil {
            if entry.retainedAt != nil {  // Only include explicitly retained successes
                updatedStates[memoId] = entry.state
            }
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
                let entry = StateEntry.retainedSuccess(mode: successMode)
                stateEntries.set(job.memoId, value: entry)
                stateByMemo[job.memoId] = entry.state
                jobRepository.deleteJob(for: job.memoId)
                currentTask = nil
                processQueueIfNeeded()
            }
        } catch {
            await MainActor.run { [weak self] in
                guard let self else { return }
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
                stateEntries.set(job.memoId, value: StateEntry(state: failedState))
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
            await MainActor.run {
                jobRepository.deleteJob(for: job.memoId)
                stateByMemo[job.memoId] = .idle
            }
            return
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

        let mode: AnalysisMode = storeKitService.isPro ? .distill : .liteDistill
        let hasCached = await analysisRepository.hasAnalysisResult(for: memo.id, mode: mode)
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
