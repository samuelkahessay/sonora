import XCTest
import SwiftUI
@testable import Sonora

final class LiveActivitySnapshotTests: SnapshotTestCase {
    func testLiveActivityAttributesLightMode() throws {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            let attributes = SonoraLiveActivityAttributes(memoId: "demo")
            let state = SonoraLiveActivityAttributes.ContentState(
                memoTitle: "Demo Memo",
                startTime: Date().addingTimeInterval(-42),
                duration: 42,
                isCountdown: false,
                remainingTime: nil,
                emoji: "🎙️"
            )
            // Render a simple representative view for attributes/state so we at least snapshot data mapping.
            // Full widget UI snapshot requires WidgetKit rendering which is outside this test target.
            let view = VStack(alignment: .leading, spacing: 8) {
                Text(attributes.memoId).font(.headline)
                Text(state.memoTitle).font(.subheadline)
                Text("Duration: \(Int(state.duration))s").font(.caption)
            }.padding()
            assertSnapshot(view, name: "LiveActivity_Attributes", appearance: .light)
            return
        }
        #endif
        throw XCTSkip("ActivityKit not available or not testable in this target.")
    }

    func testLiveActivityAttributesDarkMode() throws {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            let attributes = SonoraLiveActivityAttributes(memoId: "demo")
            let state = SonoraLiveActivityAttributes.ContentState(
                memoTitle: "Demo Memo",
                startTime: Date().addingTimeInterval(-42),
                duration: 42,
                isCountdown: true,
                remainingTime: 9,
                emoji: "🎙️"
            )
            let view = VStack(alignment: .leading, spacing: 8) {
                Text(attributes.memoId).font(.headline)
                Text(state.memoTitle).font(.subheadline)
                Text("Countdown: \(Int(state.remainingTime ?? 0))s").font(.caption)
            }.padding()
            assertSnapshot(view, name: "LiveActivity_Attributes", appearance: .dark)
            return
        }
        #endif
        throw XCTSkip("ActivityKit not available or not testable in this target.")
    }
}

