import XCTest
import SwiftUI
@testable import Sonora

final class ContentViewSnapshotTests: SnapshotTestCase {
    func testContentViewLightMode() {
        let view = ContentView()
        assertSnapshot(view, name: "ContentView", appearance: .light)
    }

    func testContentViewDarkMode() {
        let view = ContentView()
        assertSnapshot(view, name: "ContentView", appearance: .dark)
    }
}
