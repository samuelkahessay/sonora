import XCTest
import SwiftUI
@testable import Sonora

final class AnalysisResultsViewSnapshotTests: SnapshotTestCase {
    private func sampleEnvelope<T: Codable>(mode: AnalysisMode, data: T) -> AnalyzeEnvelope<T> {
        .init(mode: mode, data: data, model: "gpt-4o-mini", tokens: .init(input: 1234, output: 567), latency_ms: 420)
    }

    func testAnalysisResults_TLDR_LightMode() {
        let data = TLDRData(summary: "Short summary goes here.", key_points: ["Point A", "Point B", "Point C"])
        let env = sampleEnvelope(mode: .tldr, data: data)
        let view = AnalysisResultsView(mode: .tldr, result: data, envelope: env, memoId: nil)
        assertSnapshot(view, name: "AnalysisResults_TLDR", appearance: .light)
    }

    func testAnalysisResults_TLDR_DarkMode() {
        let data = TLDRData(summary: "Short summary goes here.", key_points: ["Point A", "Point B", "Point C"])
        let env = sampleEnvelope(mode: .tldr, data: data)
        let view = AnalysisResultsView(mode: .tldr, result: data, envelope: env, memoId: nil)
        assertSnapshot(view, name: "AnalysisResults_TLDR", appearance: .dark)
    }

    func testAnalysisResults_Themes_LightMode() {
        let data = ThemesData(themes: [
            .init(name: "UI Polish", evidence: ["We should tweak the shadows", "Increase corner radius"]),
            .init(name: "Performance", evidence: ["Cache API responses", "Batch network calls"])
        ], sentiment: "mixed")
        let env = sampleEnvelope(mode: .themes, data: data)
        let view = AnalysisResultsView(mode: .themes, result: data, envelope: env, memoId: nil)
        assertSnapshot(view, name: "AnalysisResults_Themes", appearance: .light)
    }

    func testAnalysisResults_Themes_DarkMode() {
        let data = ThemesData(themes: [
            .init(name: "UI Polish", evidence: ["We should tweak the shadows", "Increase corner radius"]),
            .init(name: "Performance", evidence: ["Cache API responses", "Batch network calls"])
        ], sentiment: "mixed")
        let env = sampleEnvelope(mode: .themes, data: data)
        let view = AnalysisResultsView(mode: .themes, result: data, envelope: env, memoId: nil)
        assertSnapshot(view, name: "AnalysisResults_Themes", appearance: .dark)
    }
}
