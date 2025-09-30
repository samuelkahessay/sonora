import XCTest
import SwiftUI
@testable import Sonora

final class TranscriptionStatusViewSnapshotTests: SnapshotTestCase {
    private func host(_ view: some View) -> some View { AnyView(view.padding().background(Color(UIColor.systemBackground))) }

    func testTranscriptionStatusView_NotStarted_Light() {
        let view = host(TranscriptionStatusView(state: .notStarted, compact: false))
        assertSnapshot(view, name: "TranscriptionStatus_NotStarted", appearance: .light)
    }

    func testTranscriptionStatusView_NotStarted_Dark() {
        let view = host(TranscriptionStatusView(state: .notStarted, compact: false))
        assertSnapshot(view, name: "TranscriptionStatus_NotStarted", appearance: .dark)
    }

    func testTranscriptionStatusView_Completed_Light() {
        let view = host(TranscriptionStatusView(state: .completed("text"), compact: true))
        assertSnapshot(view, name: "TranscriptionStatus_Completed", appearance: .light)
    }

    func testTranscriptionStatusView_Completed_Dark() {
        let view = host(TranscriptionStatusView(state: .completed("text"), compact: true))
        assertSnapshot(view, name: "TranscriptionStatus_Completed", appearance: .dark)
    }
}
