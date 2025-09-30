import Foundation

/// Use case for creating a shareable transcript file for a memo.
/// Writes a UTF-8 `.txt` file to the temporary directory using a sanitized
/// filename derived from `memo.preferredShareableFileName`.
protocol CreateTranscriptShareFileUseCaseProtocol: Sendable {
    func execute(memo: Memo, text: String) async throws -> URL
}

final class CreateTranscriptShareFileUseCase: CreateTranscriptShareFileUseCaseProtocol, @unchecked Sendable {

    // MARK: - Dependencies
    private let exporter: any TranscriptExporting
    private let logger: any LoggerProtocol

    // MARK: - Initialization
    init(
        exporter: any TranscriptExporting,
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.exporter = exporter
        self.logger = logger
    }

    // MARK: - Execution
    func execute(memo: Memo, text: String) async throws -> URL {
        let correlationId = UUID().uuidString
        let context = LogContext(correlationId: correlationId, additionalInfo: [
            "memoId": memo.id.uuidString,
            "filename": memo.filename
        ])

        logger.useCase("Creating transcript share file", level: .info, context: context)

        do {
            // Basic input sanitization (trim whitespace-only payloads)
            let sanitizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sanitizedText.isEmpty else {
                logger.useCase("Transcript text is empty; cannot create file", level: .warning, context: context)
                throw SonoraError.dataFormatInvalid("Transcript text is empty")
            }

            // Delegate to exporter (handles overwrite semantics and UTF-8 write)
            let url = try exporter.makeTranscriptFile(memo: memo, text: sanitizedText)

            logger.useCase(
                "Transcript file created successfully: \(url.lastPathComponent)",
                level: .info,
                context: context
            )
            return url

        } catch let error as RepositoryError {
            // Not expected here, but mapped for consistency
            logger.error("CreateTranscriptShareFileUseCase repository error", category: .useCase, context: context, error: error)
            throw error.asSonoraError
        } catch let error as ServiceError {
            logger.error("CreateTranscriptShareFileUseCase service error", category: .useCase, context: context, error: error)
            throw error.asSonoraError
        } catch let error as NSError {
            logger.error("CreateTranscriptShareFileUseCase system error", category: .useCase, context: context, error: error)
            throw ErrorMapping.mapError(error)
        } catch {
            logger.error("CreateTranscriptShareFileUseCase unknown error", category: .useCase, context: context, error: error)
            throw SonoraError.storageWriteFailed("Failed to create transcript file: \(error.localizedDescription)")
        }
    }
}
