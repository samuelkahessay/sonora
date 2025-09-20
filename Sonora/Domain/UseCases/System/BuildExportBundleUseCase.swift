import Foundation

@MainActor
protocol BuildExportBundleUseCaseProtocol {
    func execute(request: ExportRequest) async throws -> URL
}

@MainActor
final class BuildExportBundleUseCase: BuildExportBundleUseCaseProtocol {
    private let exporter: any DataExporting
    private let logger: any LoggerProtocol

    init(exporter: any DataExporting, logger: any LoggerProtocol) {
        self.exporter = exporter
        self.logger = logger
    }

    func execute(request: ExportRequest) async throws -> URL {
        guard !request.components.isEmpty else {
            logger.warning("Export requested with no components", category: .useCase, context: nil, error: nil)
            throw SonoraError.dataFormatInvalid("Select at least one export component")
        }

        var options: ExportOptions = []
        if request.components.contains(.memos) { options.insert(.memos) }
        if request.components.contains(.transcripts) { options.insert(.transcripts) }
        if request.components.contains(.analysis) { options.insert(.analysis) }

        // Currently only `.all` scope is supported. Future scope filters will adjust exporter configuration here.
        logger.info("Building export bundle", category: .useCase, context: LogContext(additionalInfo: [
            "components": request.components.map { String(describing: $0) }.joined(separator: ",")
        ]))

        let url = try await exporter.export(options: options)
        logger.useCase("Export bundle ready", level: .info, context: LogContext(additionalInfo: ["filename": url.lastPathComponent]))
        return url
    }
}
