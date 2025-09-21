import XCTest
import SwiftUI
@testable import Sonora

final class MemosViewSnapshotTests: SnapshotTestCase {
    func testMemosViewLightMode() {
        let view = MemosView(popToRoot: nil, navigationPath: .constant([]))
        assertSnapshot(view, name: "MemosView", appearance: .light)
    }

    func testMemosViewDarkMode() {
        let view = MemosView(popToRoot: nil, navigationPath: .constant([]))
        assertSnapshot(view, name: "MemosView", appearance: .dark)
    }
}
