@testable import Sonora
import XCTest

final class MemoRecordingEndDateTests: XCTestCase {
    func testRecordingEndDateUsesStoredDuration() {
        let creation = Date(timeIntervalSince1970: 1_725_000_000)
        let memo = Memo(
            id: UUID(),
            filename: "test.m4a",
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            creationDate: creation,
            durationSeconds: 42
        )

        XCTAssertEqual(memo.duration, 42, accuracy: 0.001)
        XCTAssertEqual(
            memo.recordingEndDate.timeIntervalSince1970,
            creation.addingTimeInterval(42).timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testRecordingEndDateFallsBackToCreationWhenDurationUnavailable() {
        let creation = Date(timeIntervalSince1970: 1_725_000_000)
        let memo = Memo(
            id: UUID(),
            filename: "test.m4a",
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            creationDate: creation,
            durationSeconds: nil
        )

        XCTAssertEqual(
            memo.recordingEndDate.timeIntervalSince1970,
            creation.timeIntervalSince1970,
            accuracy: 0.001
        )
    }
}
