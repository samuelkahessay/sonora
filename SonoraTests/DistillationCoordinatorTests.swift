import XCTest
@testable import Sonora

final class DistillationCoordinatorTests: XCTestCase {

    func test_stateFromFailedJob_mapsFailureReason() {
        let job = AutoDistillJob(
            memoId: UUID(),
            status: .failed,
            mode: .distill,
            failureReason: .network
        )

        let state = DistillationState(job: job)

        switch state {
        case .failed(let reason, _):
            XCTAssertEqual(reason, .network)
        default:
            XCTFail("Expected failed state for job")
        }
    }

    func test_retryCounterPreservation_whenEnqueueingFailedJob() {
        // Given: A failed job with retryCount = 1
        let memoId = UUID()
        let failedJob = AutoDistillJob(
            memoId: memoId,
            status: .failed,
            mode: .distill,
            retryCount: 1,
            failureReason: .network
        )

        // When: The job is retried using the updating method (same as enqueue does)
        let retriedJob = failedJob.updating(
            status: .queued,
            mode: .distill,
            updatedAt: Date(),
            retryCount: failedJob.retryCount,  // Should preserve existing count
            lastError: nil,
            failureReason: nil
        )

        // Then: The retry count should remain unchanged (not incremented)
        XCTAssertEqual(retriedJob.retryCount, 1, "Retry count should be preserved when re-enqueueing")
        XCTAssertEqual(retriedJob.status, .queued, "Job status should be queued")
        XCTAssertNil(retriedJob.failureReason, "Failure reason should be cleared")
        XCTAssertNil(retriedJob.lastError, "Last error should be cleared")
    }

    func test_retryCounterIncrement_onlyOnFailure() {
        // Given: A processing job with retryCount = 1
        let memoId = UUID()
        let processingJob = AutoDistillJob(
            memoId: memoId,
            status: .processing,
            mode: .distill,
            retryCount: 1
        )

        // When: The job fails (simulating the failure handler in run(job:))
        let failedJob = processingJob.updating(
            status: .failed,
            updatedAt: Date(),
            retryCount: processingJob.retryCount + 1,  // Only incremented here
            lastError: "Network error",
            failureReason: .network
        )

        // Then: The retry count should be incremented by exactly 1
        XCTAssertEqual(failedJob.retryCount, 2, "Retry count should increment by 1 on failure")
        XCTAssertEqual(failedJob.status, .failed, "Job status should be failed")
    }

    func test_fullRetryFlow_respectsMaxRetryCount() {
        // Given: Initial job
        let memoId = UUID()
        var job = AutoDistillJob(
            memoId: memoId,
            status: .queued,
            mode: .distill,
            retryCount: 0
        )

        // Simulate the full flow:
        // 1. Initial attempt fails
        job = job.updating(status: .failed, retryCount: 1, failureReason: .network)
        XCTAssertEqual(job.retryCount, 1)

        // 2. User retries - count preserved
        job = job.updating(status: .queued, retryCount: job.retryCount, lastError: nil, failureReason: nil)
        XCTAssertEqual(job.retryCount, 1, "Count should be preserved on re-enqueue")

        // 3. Second attempt fails
        job = job.updating(status: .failed, retryCount: job.retryCount + 1, failureReason: .network)
        XCTAssertEqual(job.retryCount, 2)

        // 4. User retries - count preserved
        job = job.updating(status: .queued, retryCount: job.retryCount, lastError: nil, failureReason: nil)
        XCTAssertEqual(job.retryCount, 2, "Count should be preserved on re-enqueue")

        // 5. Third attempt fails
        job = job.updating(status: .failed, retryCount: job.retryCount + 1, failureReason: .network)
        XCTAssertEqual(job.retryCount, 3)

        // 6. Check if max retry count (3) is reached
        let maxRetryCount = 3
        XCTAssertTrue(job.retryCount >= maxRetryCount, "Should have reached max retry count")
    }

    func test_distillationState_fromFailedJobWithMemoNotFound() {
        // Given: A failed job with validation failure reason (memo not found)
        let job = AutoDistillJob(
            memoId: UUID(),
            status: .failed,
            mode: .distill,
            retryCount: 1,
            lastError: "Memo not found",
            failureReason: .validation
        )

        // When: Converting to DistillationState
        let state = DistillationState(job: job)

        // Then: State should be failed with validation reason
        switch state {
        case .failed(let reason, let message):
            XCTAssertEqual(reason, .validation, "Should map to validation failure reason")
            XCTAssertEqual(message, "Memo not found", "Should preserve error message")
        default:
            XCTFail("Expected failed state with validation reason")
        }
    }
}
