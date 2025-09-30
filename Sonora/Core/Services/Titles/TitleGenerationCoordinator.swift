import Combine
import Foundation

private enum TitleCoordinatorError: Error {
    case transcriptUnavailable
}

private actor TitleStreamingFlag {
    private var value = false

    func mark() { value = true }
    func isMarked() -> Bool { value }
}

@MainActor
final class TitleGenerationCoordinator: ObservableObject {
    @Published private(set) var stateByMemo: [UUID: TitleGenerationState] = [:]
    @Published private(set) var metrics = TitlePipelineMetrics()

    private let titleService: any TitleServiceProtocol
    private let memoRepository: any MemoRepository
    private let transcriptionRepository: any TranscriptionRepository
    private let jobRepository: any AutoTitleJobRepository
    private let logger: any LoggerProtocol

    private var jobsCancellable: AnyCancellable?
    private var memoCancellable: AnyCancellable?
    private var currentTask: Task<Void, Never>?
    private var successStateByMemo: [UUID: String] = [:]
    private var streamingTasks: [UUID: Task<Void, Never>] = [:]

    init(
        titleService: any TitleServiceProtocol,
        memoRepository: any MemoRepository,
        transcriptionRepository: any TranscriptionRepository,
        jobRepository: any AutoTitleJobRepository,
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.titleService = titleService
        self.memoRepository = memoRepository
        self.transcriptionRepository = transcriptionRepository
        self.jobRepository = jobRepository
        self.logger = logger

        jobsCancellable = jobRepository.jobsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] jobs in
                self?.handleJobsUpdate(jobs)
            }

        memoCancellable = memoRepository.memosPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] memos in
                self?.resumePendingJobsIfNeeded(memos: memos)
            }

        handleJobsUpdate(jobRepository.fetchAllJobs())
        resumePendingJobsIfNeeded(memos: memoRepository.memos)
        processQueueIfNeeded()
    }

    func enqueue(memoId: UUID) {
        successStateByMemo[memoId] = nil
        streamingTasks[memoId]?.cancel()
        streamingTasks[memoId] = nil

        if let existing = jobRepository.job(for: memoId) {
            switch existing.status {
            case .queued, .processing:
                return
            case .failed:
                let retryJob = AutoTitleJob(
                    memoId: memoId,
                    status: .queued,
                    createdAt: existing.createdAt,
                    updatedAt: Date(),
                    retryCount: existing.retryCount + 1,
                    lastError: nil,
                    nextRetryAt: nil,
                    failureReason: nil
                )
                jobRepository.save(retryJob)
            }
        } else {
            let job = AutoTitleJob(
                memoId: memoId,
                status: .queued,
                createdAt: Date(),
                updatedAt: Date()
            )
            jobRepository.save(job)
        }

        stateByMemo[memoId] = .inProgress
        processQueueIfNeeded()
    }

    func appDidBecomeActive() {
        resumePendingJobsIfNeeded(memos: memoRepository.memos)
        processQueueIfNeeded()
    }

    func state(for memoId: UUID) -> TitleGenerationState {
        if let state = stateByMemo[memoId] {
            return state
        }
        if let job = jobRepository.job(for: memoId) {
            return TitleGenerationState(job: job)
        }
        return .idle
    }

    // MARK: - Internal Processing

    private func handleJobsUpdate(_ jobs: [AutoTitleJob]) {
        var updatedStates: [UUID: TitleGenerationState] = [:]

        for job in jobs {
            if case .streaming(let partial) = stateByMemo[job.memoId], job.status != .failed {
                updatedStates[job.memoId] = .streaming(partial)
            } else {
                updatedStates[job.memoId] = TitleGenerationState(job: job)
            }
        }

        for (memoId, title) in successStateByMemo where updatedStates[memoId] == nil {
            updatedStates[memoId] = .success(title)
        }

        stateByMemo = updatedStates
        metrics = metrics(for: jobs)
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

    private func resumePendingJobsIfNeeded(memos: [Memo]) {
        guard !memos.isEmpty else { return }

        let candidates = memos.filter { memo in
            shouldAutoTitle(memo) && jobRepository.job(for: memo.id) == nil
        }

        guard !candidates.isEmpty else { return }

        candidates.forEach { memo in
            logger.info(
                "Resuming auto-title job",
                category: .system,
                context: LogContext(additionalInfo: ["memoId": memo.id.uuidString])
            )
            enqueue(memoId: memo.id)
        }
    }

    private func run(job: AutoTitleJob) async {
        await MainActor.run {
            let processingJob = AutoTitleJob(
                memoId: job.memoId,
                status: .processing,
                createdAt: job.createdAt,
                updatedAt: Date(),
                retryCount: job.retryCount,
                lastError: job.lastError,
                nextRetryAt: job.nextRetryAt
            )
            jobRepository.save(processingJob)
            stateByMemo[job.memoId] = .inProgress
        }

        do {
            try await executeJob(for: job.memoId)
        } catch {
            await MainActor.run {
                let reason = classifyFailure(error)
                let message = failureMessage(from: error)
                let failedJob = AutoTitleJob(
                    memoId: job.memoId,
                    status: .failed,
                    createdAt: job.createdAt,
                    updatedAt: Date(),
                    retryCount: job.retryCount + 1,
                    lastError: message,
                    nextRetryAt: nil,
                    failureReason: reason
                )
                jobRepository.save(failedJob)
                successStateByMemo[job.memoId] = nil
                stateByMemo[job.memoId] = TitleGenerationState(job: failedJob)
                metrics = metrics(for: jobRepository.fetchAllJobs())
                logger.warning(
                    "Auto title generation failed",
                    category: .system,
                    context: LogContext(additionalInfo: [
                        "memoId": job.memoId.uuidString,
                        "reason": reason.rawValue,
                        "message": message
                    ]),
                    error: error
                )
            }
        }

        await MainActor.run { [weak self] in
            guard let self else { return }
            currentTask = nil
            processQueueIfNeeded()
        }
    }

    private func executeJob(for memoId: UUID) async throws {
        guard let memo = memoRepository.getMemo(by: memoId) else {
            await MainActor.run {
                jobRepository.deleteJob(for: memoId)
                stateByMemo[memoId] = .idle
                successStateByMemo[memoId] = nil
                metrics = metrics(for: jobRepository.fetchAllJobs())
            }
            return
        }

        if let title = memo.customTitle, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await MainActor.run {
                jobRepository.deleteJob(for: memoId)
                stateByMemo[memoId] = .idle
                successStateByMemo[memoId] = nil
                metrics = metrics(for: jobRepository.fetchAllJobs())
            }
            return
        }

        guard let transcript = transcriptionRepository.getTranscriptionText(for: memoId), !transcript.isEmpty else {
            throw TitleCoordinatorError.transcriptUnavailable
        }

        let slice = slice(transcript: transcript)
        let languageHint = transcriptionRepository.getTranscriptionMetadata(for: memoId)?.detectedLanguage

        do {
            let streamingFlag = TitleStreamingFlag()
            let title = try await titleService.generateTitle(
                transcript: slice,
                languageHint: languageHint
            )                { [weak self] update in
                    guard let self, !update.isFinal else { return }
                    Task { @MainActor in
                        guard !update.text.isEmpty else { return }
                        await streamingFlag.mark()
                        self.streamingTasks[memoId]?.cancel()
                        self.streamingTasks[memoId] = nil
                        self.stateByMemo[memoId] = .streaming(update.text)
                    }
                }

            if let title {
                let didReceiveStreamingUpdate = await streamingFlag.isMarked()
                if !didReceiveStreamingUpdate {
                    await animateFallbackStreaming(for: memoId, finalTitle: title)
                }
                memoRepository.renameMemo(memo, newTitle: title)
                jobRepository.deleteJob(for: memoId)
                successStateByMemo[memoId] = title
                streamingTasks[memoId]?.cancel()
                streamingTasks[memoId] = nil
                stateByMemo[memoId] = .success(title)
                metrics = metrics(for: jobRepository.fetchAllJobs())
                logger.info("Auto title generated", category: .system, context: LogContext(additionalInfo: ["memoId": memoId.uuidString, "title": title]))
                return
            }
            throw TitleServiceError.validationFailed
        } catch {
            throw error
        }
    }

    private func slice(transcript: String) -> String {
        let maxFirst = 1_500
        let maxLast = 400
        if transcript.count <= maxFirst { return transcript }
        let firstPart = String(transcript.prefix(maxFirst))
        let lastPart = String(transcript.suffix(maxLast))
        return firstPart + "\n\n" + lastPart
    }

    private func shouldAutoTitle(_ memo: Memo) -> Bool {
        if let customTitle = memo.customTitle, !customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        guard memo.transcriptionStatus.isCompleted else { return false }
        guard let transcript = transcriptionRepository.getTranscriptionText(for: memo.id), !transcript.isEmpty else { return false }
        return true
    }

    private func classifyFailure(_ error: Error) -> AutoTitleJob.FailureReason {
        if let coordinatorError = error as? TitleCoordinatorError {
            switch coordinatorError {
            case .transcriptUnavailable:
                return .transcriptUnavailable
            }
        }

        if let serviceError = error as? TitleServiceError {
            switch serviceError {
            case .networking(let urlError):
                return urlError.code == .timedOut ? .timeout : .network
            case .unexpectedStatus(let status, _):
                switch status {
                case 408:
                    return .timeout
                case 429:
                    return .server
                case 500...599:
                    return .server
                case 400...499:
                    return .validation
                default:
                    return .server
                }
            case .validationFailed:
                return .validation
            case .invalidResponse, .decodingFailed:
                return .server
            case .encodingFailed:
                return .configuration
            case .streamingUnsupported:
                return .server
            }
        }

        if let urlError = error as? URLError {
            return urlError.code == .timedOut ? .timeout : .network
        }

        return .unknown
    }

    private func failureMessage(from error: Error) -> String {
        if let serviceError = error as? TitleServiceError {
            switch serviceError {
            case .unexpectedStatus(_, let data):
                if let body = String(data: data, encoding: .utf8), !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return body.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            default:
                break
            }
        }
        let description = error.localizedDescription
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? description : trimmed
    }

    private func metrics(for jobs: [AutoTitleJob]) -> TitlePipelineMetrics {
        var queuedOrProcessing = 0
        var failures: [AutoTitleJob] = []

        for job in jobs {
            switch job.status {
            case .queued, .processing:
                queuedOrProcessing += 1
            case .failed:
                failures.append(job)
            }
        }

        let latestFailure = failures.max { $0.updatedAt < $1.updatedAt }

        return TitlePipelineMetrics(
            inProgressCount: queuedOrProcessing,
            failedCount: failures.count,
            lastFailureReason: latestFailure.map { TitleGenerationFailureReason(jobReason: $0.failureReason) },
            lastFailureMessage: latestFailure?.lastError,
            lastUpdated: Date()
        )
    }

    private func animateFallbackStreaming(for memoId: UUID, finalTitle: String) async {
        await MainActor.run {
            streamingTasks[memoId]?.cancel()
            streamingTasks[memoId] = nil
        }

        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            var partial = ""
            for character in finalTitle {
                partial.append(character)
                await MainActor.run {
                    self.stateByMemo[memoId] = .streaming(partial)
                }
                try? await Task.sleep(nanoseconds: 45_000_000)
            }
        }

        await task.value

        await MainActor.run {
            streamingTasks[memoId] = nil
        }
    }
}
