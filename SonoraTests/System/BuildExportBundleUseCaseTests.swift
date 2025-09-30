@testable import Sonora
import XCTest

@MainActor
final class BuildExportBundleUseCaseTests: XCTestCase {
    func testExecutePassesSelectedComponentsToExporter() async throws {
        let exporter = DataExporterStub()
        let logger = LoggerStub()
        let sut = BuildExportBundleUseCase(exporter: exporter, logger: logger)

        let request = ExportRequest(components: [.memos, .analysis])
        let url = try await sut.execute(request: request)

        XCTAssertEqual(url, exporter.stubURL)
        XCTAssertTrue(exporter.capturedOptions.contains(.memos))
        XCTAssertTrue(exporter.capturedOptions.contains(.analysis))
        XCTAssertFalse(exporter.capturedOptions.contains(.transcripts))
    }

    func testExecuteNoComponentsThrows() async {
        let exporter = DataExporterStub()
        let logger = LoggerStub()
        let sut = BuildExportBundleUseCase(exporter: exporter, logger: logger)

        do {
            _ = try await sut.execute(request: ExportRequest(components: []))
            XCTFail("Expected error")
        } catch let error as SonoraError {
            XCTAssertEqual(error, .dataFormatInvalid("Select at least one export component"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

@MainActor
private final class DataExporterStub: DataExporting {
    var capturedOptions: ExportOptions = []
    let stubURL = FileManager.default.temporaryDirectory.appendingPathComponent("export.zip")

    func export(options: ExportOptions) async throws -> URL {
        capturedOptions = options
        return stubURL
    }
}

private final class LoggerStub: LoggerProtocol, @unchecked Sendable {
    func log(level: LogLevel, category: LogCategory, message: String, context: LogContext?, error: Error?) {}
    func verbose(_ message: String, category: LogCategory, context: LogContext?) {}
    func debug(_ message: String, category: LogCategory, context: LogContext?) {}
    func info(_ message: String, category: LogCategory, context: LogContext?) {}
    func warning(_ message: String, category: LogCategory, context: LogContext?, error: Error?) {}
    func error(_ message: String, category: LogCategory, context: LogContext?, error: Error?) {}
    func critical(_ message: String, category: LogCategory, context: LogContext?, error: Error?) {}
}
