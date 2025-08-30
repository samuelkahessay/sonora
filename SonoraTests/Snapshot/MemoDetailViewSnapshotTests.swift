import XCTest
import SwiftUI
@testable import Sonora

final class MemoDetailViewSnapshotTests: SnapshotTestCase {
    private func sampleMemo() -> Memo {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("sample.m4a")
        return Memo(
            filename: "sample.m4a",
            fileURL: tmp,
            creationDate: Date(timeIntervalSince1970: 1_725_000_000),
            transcriptionStatus: .notStarted,
            analysisResults: []
        )
    }

    func testMemoDetailViewLightMode() {
        let view = NavigationStack { MemoDetailView(memo: sampleMemo()) }
        assertSnapshot(view, name: "MemoDetailView", appearance: .light)
    }

    func testMemoDetailViewDarkMode() {
        let view = NavigationStack { MemoDetailView(memo: sampleMemo()) }
        assertSnapshot(view, name: "MemoDetailView", appearance: .dark)
    }
}

