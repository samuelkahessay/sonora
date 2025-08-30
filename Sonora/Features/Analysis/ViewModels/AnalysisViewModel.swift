import Foundation
import SwiftUI

@MainActor
final class AnalysisViewModel: ObservableObject {
    // Selected analysis mode and results
    @Published var selectedMode: AnalysisMode?
    @Published var isAnalyzing: Bool = false
    @Published var result: Any?
    @Published var envelope: Any?
    @Published var error: String?

    init() {}

    // Placeholder for future coordination of analysis use cases
    func performAnalysis(mode: AnalysisMode, transcript: String) {
        // Intentionally left unimplemented; actual coordination lives in feature ViewModels
        // such as MemoDetailViewModel today. This provides a seam for future reuse.
        selectedMode = mode
    }
}

