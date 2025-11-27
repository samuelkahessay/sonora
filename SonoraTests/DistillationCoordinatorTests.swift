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
}
