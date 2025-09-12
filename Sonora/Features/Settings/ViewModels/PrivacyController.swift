import Foundation
import Combine

@MainActor
final class PrivacyController: ObservableObject {
    // Dependencies
    private let resolver: Resolver
    private let memoRepository: any MemoRepository
    private let exportService: any DataExporting
    private let logger: any LoggerProtocol

    // Export state
    @Published var isExporting: Bool = false
    @Published var exportURL: URL?
    @Published var isPresentingShareSheet: Bool = false

    // Export options
    @Published var exportMemos: Bool = true
    @Published var exportTranscripts: Bool = true
    @Published var exportAnalysis: Bool = true

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
         exportService: (any DataExporting)? = nil) {
        let resolved = resolver ?? DIContainer.shared
        self.resolver = resolved
        let container = (resolved as? DIContainer) ?? DIContainer.shared
        self.memoRepository = resolved.resolve((any MemoRepository).self) ?? container.memoRepository()
        self.logger = resolved.resolve((any LoggerProtocol).self) ?? container.logger()
        #if canImport(ZIPFoundation)
        self.exportService = exportService ?? ZipDataExportService()
        #else
        self.exportService = exportService ?? StubDataExportService()
        #endif
    }

    var hasDataToExport: Bool {
        return !memoRepository.memos.isEmpty
    }

    var canExport: Bool {
        // At least one category selected and at least one selected category has content
        let anySelected = exportMemos || exportTranscripts || exportAnalysis
        guard anySelected else { return false }

        if exportMemos, !memoRepository.memos.isEmpty { return true }
        if exportTranscripts, directoryHasFiles(named: "transcriptions") { return true }
        if exportAnalysis, directoryHasFiles(named: "analysis") { return true }
        return false
    }

    private func directoryHasFiles(named name: String) -> Bool {
        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = documents.appendingPathComponent(name, isDirectory: true)
        guard fm.fileExists(atPath: dir.path) else { return false }
        let e = fm.enumerator(at: dir, includingPropertiesForKeys: nil)
        return e?.nextObject() != nil
    }

    func exportData() async {
        guard !isExporting else { return }
        // Availability validated below using selection-aware checks

        // Validate selection & availability
        guard exportMemos || exportTranscripts || exportAnalysis else {
            alertItem = AlertItem(title: "Nothing Selected", message: "Select at least one category to export.")
            return
        }
        guard canExport else {
            alertItem = AlertItem(title: "Nothing to Export", message: "No data found for the selected categories.")
            return
        }

        isExporting = true
        do {
            var opts: ExportOptions = []
            if exportMemos { opts.insert(.memos) }
            if exportTranscripts { opts.insert(.transcripts) }
            if exportAnalysis { opts.insert(.analysis) }
            let url = try await exportService.export(options: opts)
            self.exportURL = url
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
        } catch {
            alertItem = AlertItem(title: "Delete Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - Protocols & Stubs

struct ExportOptions: OptionSet {
    let rawValue: Int
    static let memos        = ExportOptions(rawValue: 1 << 0)
    static let transcripts  = ExportOptions(rawValue: 1 << 1)
    static let analysis     = ExportOptions(rawValue: 1 << 2)
}

@MainActor
protocol DataExporting {
    func export(options: ExportOptions) async throws -> URL
}
