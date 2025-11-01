#if canImport(SwiftData)
@testable import Sonora
import Combine
import SwiftData
import XCTest

@MainActor
final class AutoTitleJobRepositoryImplTests: XCTestCase {

    // MARK: - Test Infrastructure

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            MemoModel.self,
            AutoTitleJobModel.self,
            TranscriptionModel.self,
            AnalysisResultModel.self
        ])

        if let configInit = ModelConfigurationInit.inMemory() {
            let container = try ModelContainer(for: schema, configurations: configInit)
            return ModelContext(container)
        } else {
            let container = try ModelContainer(for: schema)
            return ModelContext(container)
        }
    }

    private func makeTestMemo(in context: ModelContext, id: UUID = UUID()) throws -> MemoModel {
        let memo = MemoModel(
            id: id,
            creationDate: Date(),
            filename: "test_memo.m4a",
            audioFilePath: "/path/to/test.m4a",
            duration: 120.0
        )
        context.insert(memo)
        try context.save()
        return memo
    }

    private func makeTestJob(memoId: UUID, status: AutoTitleJob.Status = .queued) -> AutoTitleJob {
        AutoTitleJob(
            memoId: memoId,
            status: status,
            createdAt: Date(),
            updatedAt: Date(),
            retryCount: 0,
            lastError: nil,
            nextRetryAt: nil,
            failureReason: nil
        )
    }

    // MARK: - Save and Fetch Tests

    func test_saveAndFetchJob_Success() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)
        let job = makeTestJob(memoId: memo.id, status: .queued)

        // Save
        repository.save(job)

        // Fetch
        let retrieved = repository.job(for: memo.id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.memoId, memo.id)
        XCTAssertEqual(retrieved?.status, .queued)
        XCTAssertEqual(retrieved?.retryCount, 0)
    }

    func test_saveUpdatesExistingJob() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        // Save initial job
        let initialJob = makeTestJob(memoId: memo.id, status: .queued)
        repository.save(initialJob)

        // Update to processing
        let updatedJob = initialJob.updating(status: .processing, retryCount: 1)
        repository.save(updatedJob)

        // Verify update
        let retrieved = repository.job(for: memo.id)
        XCTAssertEqual(retrieved?.status, .processing)
        XCTAssertEqual(retrieved?.retryCount, 1)
    }

    func test_saveJobWithFailureInfo() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        let failedJob = AutoTitleJob(
            memoId: memo.id,
            status: .failed,
            createdAt: Date(),
            updatedAt: Date(),
            retryCount: 3,
            lastError: "Network timeout",
            nextRetryAt: Date().addingTimeInterval(300),
            failureReason: .timeout
        )

        repository.save(failedJob)

        let retrieved = repository.job(for: memo.id)
        XCTAssertEqual(retrieved?.status, .failed)
        XCTAssertEqual(retrieved?.retryCount, 3)
        XCTAssertEqual(retrieved?.lastError, "Network timeout")
        XCTAssertEqual(retrieved?.failureReason, .timeout)
        XCTAssertNotNil(retrieved?.nextRetryAt)
    }

    // MARK: - Fetch All Jobs Tests

    func test_fetchAllJobs_ReturnsAllJobs() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)

        let memo1 = try makeTestMemo(in: context, id: UUID())
        let memo2 = try makeTestMemo(in: context, id: UUID())
        let memo3 = try makeTestMemo(in: context, id: UUID())

        repository.save(makeTestJob(memoId: memo1.id, status: .queued))
        repository.save(makeTestJob(memoId: memo2.id, status: .processing))
        repository.save(makeTestJob(memoId: memo3.id, status: .failed))

        let allJobs = repository.fetchAllJobs()

        XCTAssertEqual(allJobs.count, 3)
        XCTAssertTrue(allJobs.contains(where: { $0.memoId == memo1.id }))
        XCTAssertTrue(allJobs.contains(where: { $0.memoId == memo2.id }))
        XCTAssertTrue(allJobs.contains(where: { $0.memoId == memo3.id }))
    }

    func test_fetchAllJobs_EmptyRepository_ReturnsEmpty() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)

        let allJobs = repository.fetchAllJobs()

        XCTAssertTrue(allJobs.isEmpty)
    }

    // MARK: - Fetch Queued Jobs Tests

    func test_fetchQueuedJobs_OnlyReturnsQueuedAndProcessing() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)

        let memo1 = try makeTestMemo(in: context, id: UUID())
        let memo2 = try makeTestMemo(in: context, id: UUID())
        let memo3 = try makeTestMemo(in: context, id: UUID())
        let memo4 = try makeTestMemo(in: context, id: UUID())

        repository.save(makeTestJob(memoId: memo1.id, status: .queued))
        repository.save(makeTestJob(memoId: memo2.id, status: .processing))
        repository.save(makeTestJob(memoId: memo3.id, status: .failed))
        repository.save(makeTestJob(memoId: memo4.id, status: .queued))

        let queuedJobs = repository.fetchQueuedJobs()

        XCTAssertEqual(queuedJobs.count, 3)
        XCTAssertTrue(queuedJobs.contains(where: { $0.memoId == memo1.id && $0.status == .queued }))
        XCTAssertTrue(queuedJobs.contains(where: { $0.memoId == memo2.id && $0.status == .processing }))
        XCTAssertTrue(queuedJobs.contains(where: { $0.memoId == memo4.id && $0.status == .queued }))
        XCTAssertFalse(queuedJobs.contains(where: { $0.status == .failed }))
    }

    func test_fetchQueuedJobs_NoQueuedJobs_ReturnsEmpty() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)

        let memo = try makeTestMemo(in: context)
        repository.save(makeTestJob(memoId: memo.id, status: .failed))

        let queuedJobs = repository.fetchQueuedJobs()

        XCTAssertTrue(queuedJobs.isEmpty)
    }

    // MARK: - Delete Tests

    func test_deleteJob_RemovesJob() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        repository.save(makeTestJob(memoId: memo.id, status: .queued))
        XCTAssertNotNil(repository.job(for: memo.id))

        repository.deleteJob(for: memo.id)

        XCTAssertNil(repository.job(for: memo.id))
    }

    func test_deleteJob_OnlyRemovesSpecificJob() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)

        let memo1 = try makeTestMemo(in: context, id: UUID())
        let memo2 = try makeTestMemo(in: context, id: UUID())

        repository.save(makeTestJob(memoId: memo1.id, status: .queued))
        repository.save(makeTestJob(memoId: memo2.id, status: .queued))

        repository.deleteJob(for: memo1.id)

        XCTAssertNil(repository.job(for: memo1.id))
        XCTAssertNotNil(repository.job(for: memo2.id))
    }

    func test_deleteJob_NonExistentJob_DoesNotThrow() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)

        // Should not throw
        repository.deleteJob(for: UUID())

        // Verify repository is still functional
        let allJobs = repository.fetchAllJobs()
        XCTAssertTrue(allJobs.isEmpty)
    }

    // MARK: - Publisher Tests

    func test_jobsPublisher_EmitsOnSave() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        var receivedJobs: [[AutoTitleJob]] = []
        let cancellable = repository.jobsPublisher
            .sink { jobs in
                receivedJobs.append(jobs)
            }

        // Initial empty state
        XCTAssertEqual(receivedJobs.count, 1)
        XCTAssertTrue(receivedJobs[0].isEmpty)

        // Save a job
        repository.save(makeTestJob(memoId: memo.id, status: .queued))

        // Should receive updated jobs
        XCTAssertEqual(receivedJobs.count, 2)
        XCTAssertEqual(receivedJobs[1].count, 1)
        XCTAssertEqual(receivedJobs[1].first?.memoId, memo.id)

        cancellable.cancel()
    }

    func test_jobsPublisher_EmitsOnUpdate() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        var receivedJobs: [[AutoTitleJob]] = []
        let cancellable = repository.jobsPublisher
            .sink { jobs in
                receivedJobs.append(jobs)
            }

        // Save initial job
        let initialJob = makeTestJob(memoId: memo.id, status: .queued)
        repository.save(initialJob)

        // Update status
        let updatedJob = initialJob.updating(status: .processing)
        repository.save(updatedJob)

        // Should have received 3 updates: initial empty, save, update
        XCTAssertEqual(receivedJobs.count, 3)
        XCTAssertEqual(receivedJobs[2].first?.status, .processing)

        cancellable.cancel()
    }

    func test_jobsPublisher_EmitsOnDelete() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        var receivedJobs: [[AutoTitleJob]] = []
        let cancellable = repository.jobsPublisher
            .sink { jobs in
                receivedJobs.append(jobs)
            }

        // Save a job
        repository.save(makeTestJob(memoId: memo.id, status: .queued))

        // Delete the job
        repository.deleteJob(for: memo.id)

        // Should have received 3 updates: initial empty, save, delete
        XCTAssertEqual(receivedJobs.count, 3)
        XCTAssertTrue(receivedJobs[2].isEmpty)

        cancellable.cancel()
    }

    func test_jobsPublisher_MultipleSubscribers() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        var subscriber1Jobs: [[AutoTitleJob]] = []
        var subscriber2Jobs: [[AutoTitleJob]] = []

        let cancellable1 = repository.jobsPublisher
            .sink { jobs in
                subscriber1Jobs.append(jobs)
            }

        let cancellable2 = repository.jobsPublisher
            .sink { jobs in
                subscriber2Jobs.append(jobs)
            }

        repository.save(makeTestJob(memoId: memo.id, status: .queued))

        // Both subscribers should receive updates
        XCTAssertEqual(subscriber1Jobs.count, 2) // initial + save
        XCTAssertEqual(subscriber2Jobs.count, 2) // initial + save
        XCTAssertEqual(subscriber1Jobs.last?.count, 1)
        XCTAssertEqual(subscriber2Jobs.last?.count, 1)

        cancellable1.cancel()
        cancellable2.cancel()
    }

    // MARK: - Job Retrieval Tests

    func test_jobForMemoId_NonExistent_ReturnsNil() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)

        let job = repository.job(for: UUID())

        XCTAssertNil(job)
    }

    // MARK: - Status Transition Tests

    func test_jobStatusTransitions() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        // Queued
        let queuedJob = makeTestJob(memoId: memo.id, status: .queued)
        repository.save(queuedJob)
        XCTAssertEqual(repository.job(for: memo.id)?.status, .queued)

        // Processing
        let processingJob = queuedJob.updating(status: .processing)
        repository.save(processingJob)
        XCTAssertEqual(repository.job(for: memo.id)?.status, .processing)

        // Failed
        let failedJob = processingJob.updating(
            status: .failed,
            retryCount: 1,
            lastError: "Test error",
            failureReason: .network
        )
        repository.save(failedJob)

        let retrieved = repository.job(for: memo.id)
        XCTAssertEqual(retrieved?.status, .failed)
        XCTAssertEqual(retrieved?.retryCount, 1)
        XCTAssertEqual(retrieved?.lastError, "Test error")
        XCTAssertEqual(retrieved?.failureReason, .network)
    }

    // MARK: - Edge Cases

    func test_saveJobWithoutMemo_StillWorks() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)

        // Create job for non-existent memo
        let orphanMemoId = UUID()
        let orphanJob = makeTestJob(memoId: orphanMemoId, status: .queued)

        repository.save(orphanJob)

        // Should still save successfully
        let retrieved = repository.job(for: orphanMemoId)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.memoId, orphanMemoId)
    }

    func test_multipleJobsOrdering() throws {
        let context = try makeInMemoryContext()
        let repository = AutoTitleJobRepositoryImpl(context: context)

        // Create jobs with specific creation times
        let now = Date()
        let memo1 = try makeTestMemo(in: context, id: UUID())
        let memo2 = try makeTestMemo(in: context, id: UUID())

        let job1 = AutoTitleJob(
            memoId: memo1.id,
            status: .queued,
            createdAt: now.addingTimeInterval(-100),
            updatedAt: now
        )
        let job2 = AutoTitleJob(
            memoId: memo2.id,
            status: .queued,
            createdAt: now,
            updatedAt: now
        )

        repository.save(job2)
        repository.save(job1)

        let allJobs = repository.fetchAllJobs()

        // Should be ordered by creation date (oldest first)
        XCTAssertEqual(allJobs.count, 2)
        XCTAssertEqual(allJobs[0].memoId, memo1.id, "Older job should come first")
        XCTAssertEqual(allJobs[1].memoId, memo2.id, "Newer job should come second")
    }
}
#endif
