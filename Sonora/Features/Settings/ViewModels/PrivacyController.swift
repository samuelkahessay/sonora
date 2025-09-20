import Foundation
import Combine

@MainActor
final class PrivacyController: ObservableObject {
    // Dependencies
    private let resolver: Resolver
    private let memoRepository: any MemoRepository
    private let buildExportBundleUseCase: any BuildExportBundleUseCaseProtocol
    private let logger: any LoggerProtocol

    // Export state
    @Published var isExporting: Bool = false
    @Published var exportURL: URL?
    @Published var isPresentingShareSheet: Bool = false
    @Published var isPresentingExportSheet: Bool = false

    // Export options
    @Published var exportMemos: Bool = true
    @Published var exportTranscripts: Bool = true
    @Published var exportAnalysis: Bool = true

    private var hasInitializedExportSelection = false

    // Delete state
    @Published var isDeleting: Bool = false
    @Published var showDeleteConfirmation: Bool = false

    // Alerts
    struct AlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
    @Published var alertItem: AlertItem?

    // No timers required after confirmation-only delete

    init(resolver: Resolver? = nil,
         buildExportBundleUseCase: (any BuildExportBundleUseCaseProtocol)? = nil) {
        let resolved = resolver ?? DIContainer.shared
        self.resolver = resolved
        let container = (resolved as? DIContainer) ?? DIContainer.shared
        self.memoRepository = resolved.resolve((any MemoRepository).self) ?? container.memoRepository()
        self.logger = resolved.resolve((any LoggerProtocol).self) ?? container.logger()
        self.buildExportBundleUseCase = buildExportBundleUseCase ?? container.buildExportBundleUseCase()
    }

    var hasDataToExport: Bool {
        hasMemosContent || hasTranscriptContent || hasAnalysisContent
    }

    var canExport: Bool {
        let selectedComponents = selectedComponents()
        guard !selectedComponents.isEmpty else { return false }

        if selectedComponents.contains(.memos), hasMemosContent { return true }
        if selectedComponents.contains(.transcripts), hasTranscriptContent { return true }
        if selectedComponents.contains(.analysis), hasAnalysisContent { return true }
        return false
    }

    private var hasMemosContent: Bool { !memoRepository.memos.isEmpty }
    private var hasTranscriptContent: Bool { directoryHasFiles(named: "transcriptions") }
    private var hasAnalysisContent: Bool { directoryHasFiles(named: "analysis") }

    var memosAvailable: Bool { hasMemosContent }
    var transcriptsAvailable: Bool { hasTranscriptContent }
    var analysisAvailable: Bool { hasAnalysisContent }

    private func directoryHasFiles(named name: String) -> Bool {
        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = documents.appendingPathComponent(name, isDirectory: true)
        guard fm.fileExists(atPath: dir.path) else { return false }
        let e = fm.enumerator(at: dir, includingPropertiesForKeys: nil)
        return e?.nextObject() != nil
    }

    func presentExportSheet() {
        syncSelectionsWithAvailability()
        isPresentingExportSheet = true
    }

    func exportData() async {
        guard !isExporting else { return }
        // Availability validated below using selection-aware checks

        // Validate selection & availability
        guard !selectedComponents().isEmpty else {
            alertItem = AlertItem(title: "Nothing Selected", message: "Select at least one category to export.")
            return
        }
        guard canExport else {
            alertItem = AlertItem(title: "Nothing to Export", message: "No data found for the selected categories.")
            return
        }

        isExporting = true
        do {
            let request = ExportRequest(components: selectedComponents(), scope: .all)
            let url = try await buildExportBundleUseCase.execute(request: request)
            self.exportURL = url
            self.isPresentingExportSheet = false
            // Present share sheet on success
            self.isPresentingShareSheet = true
        } catch {
            self.alertItem = AlertItem(title: "Export Failed", message: error.localizedDescription)
        }
        isExporting = false
    }

    func requestDeleteAll() {
        // Guard: nothing to delete across categories
        let hasMemos = !memoRepository.memos.isEmpty
        let hasTranscripts = directoryHasFiles(named: "transcriptions")
        let hasAnalysis = directoryHasFiles(named: "analysis")
        if !(hasMemos || hasTranscripts || hasAnalysis) {
            alertItem = AlertItem(title: "Nothing to Delete", message: "There is no memo, transcript, or analysis data to delete.")
            return
        }
        showDeleteConfirmation = true
    }

    func deleteAllNow() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            let container = DIContainer.shared
            let deleteAll = DeleteAllUserDataUseCase(
                memoRepository: memoRepository,
                transcriptionRepository: container.transcriptionRepository(),
                analysisRepository: container.analysisRepository(),
                logger: container.logger()
            )
            try await deleteAll.execute()
            alertItem = AlertItem(title: "Data Deleted", message: "All memos, transcripts, and analysis were permanently deleted.")
            hasInitializedExportSelection = false
            syncSelectionsWithAvailability()
        } catch {
            alertItem = AlertItem(title: "Delete Failed", message: error.localizedDescription)
        }
    }

    private func selectedComponents() -> Set<ExportComponent> {
        var components = Set<ExportComponent>()
        if exportMemos { components.insert(.memos) }
        if exportTranscripts { components.insert(.transcripts) }
        if exportAnalysis { components.insert(.analysis) }
        return components
    }

    private func syncSelectionsWithAvailability() {
        if !hasMemosContent { exportMemos = false }
        if !hasTranscriptContent { exportTranscripts = false }
        if !hasAnalysisContent { exportAnalysis = false }

        if !hasInitializedExportSelection {
            if hasMemosContent { exportMemos = true }
            if hasTranscriptContent { exportTranscripts = true }
            if hasAnalysisContent { exportAnalysis = true }
            hasInitializedExportSelection = true
        }

        if selectedComponents().isEmpty {
            if hasMemosContent { exportMemos = true }
            else if hasTranscriptContent { exportTranscripts = true }
            else if hasAnalysisContent { exportAnalysis = true }
        }
    }
}
