import Combine
import Foundation
import SwiftData

@MainActor
final class AutoDistillJobRepositoryImpl: AutoDistillJobRepository {
    private let jobsSubject = CurrentValueSubject<[AutoDistillJob], Never>([])
    private let context: ModelContext

    var jobsPublisher: AnyPublisher<[AutoDistillJob], Never> {
        jobsSubject.eraseToAnyPublisher()
    }

    init(context: ModelContext) {
        self.context = context
        reloadCache()
    }

    func fetchAllJobs() -> [AutoDistillJob] {
        jobsSubject.value
    }

    func fetchQueuedJobs() -> [AutoDistillJob] {
        jobsSubject.value.filter { $0.status == .queued || $0.status == .processing }
    }

    func job(for memoId: UUID) -> AutoDistillJob? {
        jobsSubject.value.first { $0.memoId == memoId }
    }

    func save(_ job: AutoDistillJob) {
        let model: AutoDistillJobModel
        if let existing = fetchModel(for: job.memoId) {
            model = existing
        } else {
            model = AutoDistillJobModel(
                id: job.memoId,
                memoId: job.memoId,
                statusRaw: job.status.rawValue,
                modeRaw: job.mode.rawValue,
                createdAt: job.createdAt,
                updatedAt: job.updatedAt,
                retryCount: job.retryCount,
                lastError: job.lastError,
                nextRetryAt: job.nextRetryAt,
                failureReasonRaw: job.failureReason?.rawValue
            )
            model.memo = fetchMemoModel(for: job.memoId)
            context.insert(model)
        }

        model.memoId = job.memoId
        model.statusRaw = job.status.rawValue
        model.modeRaw = job.mode.rawValue
        model.createdAt = job.createdAt
        model.updatedAt = job.updatedAt
        model.retryCount = job.retryCount
        model.lastError = job.lastError
        model.nextRetryAt = job.nextRetryAt
        model.failureReasonRaw = job.failureReason?.rawValue

        if model.memo == nil {
            model.memo = fetchMemoModel(for: job.memoId)
        }

        do {
            try context.save()
        } catch {
            print("❌ AutoDistillJobRepository: Failed to save job for memo \(job.memoId): \(error)")
        }
        reloadCache()
    }

    func deleteJob(for memoId: UUID) {
        guard let model = fetchModel(for: memoId) else { return }
        context.delete(model)
        do {
            try context.save()
        } catch {
            print("❌ AutoDistillJobRepository: Failed to delete distill job for memo \(memoId): \(error)")
        }
        reloadCache()
    }

    // MARK: - Private Helpers

    private func reloadCache() {
        let descriptor = FetchDescriptor<AutoDistillJobModel>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        do {
            let models = try context.fetch(descriptor)
            jobsSubject.send(models.map { mapModel($0) })
        } catch {
            print("❌ AutoDistillJobRepository: Failed to fetch jobs: \(error)")
            jobsSubject.send([])
        }
    }

    private func mapModel(_ model: AutoDistillJobModel) -> AutoDistillJob {
        let status = AutoDistillJob.Status(rawValue: model.statusRaw) ?? .queued
        let mode = AnalysisMode(rawValue: model.modeRaw) ?? .distill
        return AutoDistillJob(
            memoId: model.memoId,
            status: status,
            mode: mode,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            retryCount: model.retryCount,
            lastError: model.lastError,
            nextRetryAt: model.nextRetryAt,
            failureReason: model.failureReasonRaw.flatMap(AutoDistillJob.FailureReason.init(rawValue:))
        )
    }

    private func fetchModel(for memoId: UUID) -> AutoDistillJobModel? {
        let descriptor = FetchDescriptor<AutoDistillJobModel>(predicate: #Predicate { $0.memoId == memoId })
        return (try? context.fetch(descriptor))?.first
    }

    private func fetchMemoModel(for memoId: UUID) -> MemoModel? {
        let descriptor = FetchDescriptor<MemoModel>(predicate: #Predicate { $0.id == memoId })
        return (try? context.fetch(descriptor))?.first
    }
}
