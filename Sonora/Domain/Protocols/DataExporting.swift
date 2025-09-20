import Foundation

/// Bitmask option set sent to concrete exporters. Bridges legacy services while we expand domain models.
struct ExportOptions: OptionSet {
    let rawValue: Int

    static let memos       = ExportOptions(rawValue: 1 << 0)
    static let transcripts = ExportOptions(rawValue: 1 << 1)
    static let analysis    = ExportOptions(rawValue: 1 << 2)
}

@MainActor
protocol DataExporting {
    func export(options: ExportOptions) async throws -> URL
}
