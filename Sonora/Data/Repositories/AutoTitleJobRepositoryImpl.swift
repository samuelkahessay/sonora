import Foundation
import Combine
import SwiftData

@MainActor
final class AutoTitleJobRepositoryImpl: ObservableObject, AutoTitleJobRepository {
    @Published private var jobsCache: [AutoTitleJob] = []

    private let context: ModelContext

    var jobsPublisher: AnyPublisher<[AutoTitleJob], Never> {
        $jobsCache.eraseToAnyPublisher()
    }

    init(context: ModelContext) {
        self.context = context
        reloadCache()
    }

    func fetchAllJobs() -> [AutoTitleJob] {
        jobsCache
    }

    func fetchQueuedJobs() -> [AutoTitleJob] {
        jobsCache.filter { $0.status == .queued || $0.status == .processing }
    }

    func job(for memoId: UUID) -> AutoTitleJob? {
        jobsCache.first { $0.memoId == memoId }
    }

    func save(_ job: AutoTitleJob) {
        let model: AutoTitleJobModel
        if let existing = fetchModel(for: job.memoId) {
            model = existing
        } else {
            model = AutoTitleJobModel(
                id: job.memoId,
                memoId: job.memoId,
                statusRaw: job.status.rawValue,
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
            print("❌ AutoTitleJobRepository: Failed to save job for memo \(job.memoId): \(error)")
        }
        reloadCache()
    }

    func deleteJob(for memoId: UUID) {
        guard let model = fetchModel(for: memoId) else { return }
        context.delete(model)
        do {
            try context.save()
        } catch {
            print("❌ AutoTitleJobRepository: Failed to delete job for memo \(memoId): \(error)")
        }
        reloadCache()
    }

    // MARK: - Private Helpers

    private func reloadCache() {
        let descriptor = FetchDescriptor<AutoTitleJobModel>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        do {
            let models = try context.fetch(descriptor)
            jobsCache = models.map { mapModel($0) }
        } catch {
            print("❌ AutoTitleJobRepository: Failed to fetch jobs: \(error)")
            jobsCache = []
        }
    }

    private func mapModel(_ model: AutoTitleJobModel) -> AutoTitleJob {
        let status = AutoTitleJob.Status(rawValue: model.statusRaw) ?? .queued
        return AutoTitleJob(
            memoId: model.memoId,
            status: status,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            retryCount: model.retryCount,
            lastError: model.lastError,
            nextRetryAt: model.nextRetryAt,
            failureReason: model.failureReasonRaw.flatMap(AutoTitleJob.FailureReason.init(rawValue:))
        )
    }

    private func fetchModel(for memoId: UUID) -> AutoTitleJobModel? {
        let descriptor = FetchDescriptor<AutoTitleJobModel>(predicate: #Predicate { $0.memoId == memoId })
        return (try? context.fetch(descriptor))?.first
    }

    private func fetchMemoModel(for memoId: UUID) -> MemoModel? {
        let descriptor = FetchDescriptor<MemoModel>(predicate: #Predicate { $0.id == memoId })
        return (try? context.fetch(descriptor))?.first
    }
}
