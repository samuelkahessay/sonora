import XCTest
import SwiftUI
@testable import Sonora

final class AnalysisSectionViewSnapshotTests: SnapshotTestCase {
    func testAnalysisSectionViewLightMode() {
        let vm = MemoDetailViewModel()
        let view = AnalysisSectionView(transcript: "Hello world. This is a sample transcript.", viewModel: vm)
        assertSnapshot(view, name: "AnalysisSectionView", appearance: .light)
    }

    func testAnalysisSectionViewDarkMode() {
        let vm = MemoDetailViewModel()
        let view = AnalysisSectionView(transcript: "Hello world. This is a sample transcript.", viewModel: vm)
        assertSnapshot(view, name: "AnalysisSectionView", appearance: .dark)
    }
}

