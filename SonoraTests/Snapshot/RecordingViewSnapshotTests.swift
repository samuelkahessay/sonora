import XCTest
import SwiftUI
@testable import Sonora

final class RecordingViewSnapshotTests: SnapshotTestCase {
    func testRecordViewLightMode() {
        let view = RecordingView()
            .ignoresSafeArea()
        assertSnapshot(view, name: "RecordingView", appearance: .light)
    }

    func testRecordViewDarkMode() {
        let view = RecordingView()
            .ignoresSafeArea()
        assertSnapshot(view, name: "RecordingView", appearance: .dark)
    }
}
