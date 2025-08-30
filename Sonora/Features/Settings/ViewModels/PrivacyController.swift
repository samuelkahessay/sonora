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

    // Delete state
    @Published var isDeleting: Bool = false
    @Published var deleteScheduled: Bool = false
    @Published var deleteCountdown: Int = 0
    @Published var showDeleteConfirmation: Bool = false

    // Alerts
    struct AlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
    @Published var alertItem: AlertItem?

    private var countdownCancellable: AnyCancellable?

    init(resolver: Resolver = DIContainer.shared,
         exportService: (any DataExporting)? = nil) {
        self.resolver = resolver
        self.memoRepository = resolver.resolve((any MemoRepository).self) ?? DIContainer.shared.memoRepository()
        self.logger = resolver.resolve((any LoggerProtocol).self) ?? DIContainer.shared.logger()
        self.exportService = exportService ?? StubDataExportService()
    }

    var hasDataToExport: Bool {
        return !memoRepository.memos.isEmpty
    }

    func exportData() async {
        guard !isExporting else { return }
        if !hasDataToExport {
            alertItem = AlertItem(title: "Nothing to Export", message: "There are no memos or app data to include in an export.")
            return
        }

        isExporting = true
        do {
            let url = try await exportService.export()
            self.exportURL = url
            self.alertItem = AlertItem(title: "Export Complete", message: "Your data export is ready.")
        } catch {
            self.alertItem = AlertItem(title: "Export Failed", message: error.localizedDescription)
        }
        isExporting = false
    }

    func requestDeleteAll() {
        showDeleteConfirmation = true
    }

    func scheduleDeleteAll(countdown seconds: Int = 10) {
        guard !deleteScheduled, !isDeleting else { return }
        deleteScheduled = true
        deleteCountdown = seconds
        startCountdown()
    }

    func undoDelete() {
        countdownCancellable?.cancel()
        deleteScheduled = false
        deleteCountdown = 0
    }

    private func startCountdown() {
        countdownCancellable?.cancel()
        countdownCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.deleteCountdown > 0 {
                    self.deleteCountdown -= 1
                }
                if self.deleteCountdown == 0 {
                    self.countdownCancellable?.cancel()
                    Task { await self.performDeleteNow() }
                }
            }
    }

    private func performDeleteNow() async {
        guard deleteScheduled, !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false; deleteScheduled = false }

        do {
            // Best-effort deletion via repository API
            let existing = memoRepository.memos
            for memo in existing {
                memoRepository.deleteMemo(memo)
            }
            // Verify
            if !memoRepository.memos.isEmpty {
                throw PrivacyControllerError.deletionIncomplete
            }
            alertItem = AlertItem(title: "Data Deleted", message: "All memos and related data were deleted.")
        } catch {
            alertItem = AlertItem(title: "Delete Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - Protocols & Stubs

protocol DataExporting {
    func export() async throws -> URL
}

enum PrivacyControllerError: LocalizedError {
    case deletionIncomplete

    var errorDescription: String? {
        switch self {
        case .deletionIncomplete:
            return "Some items could not be deleted. Please try again."
        }
    }
}

/// Basic export stub that writes a small file with a .zip extension
struct StubDataExportService: DataExporting {
    func export() async throws -> URL {
        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate work
        let tmp = FileManager.default.temporaryDirectory
        let filename = "Sonora_Export_\(Int(Date().timeIntervalSince1970)).zip"
        let url = tmp.appendingPathComponent(filename)
        let data = Data("Sonora export placeholder".utf8)
        try data.write(to: url, options: .atomic)
        return url
    }
}

