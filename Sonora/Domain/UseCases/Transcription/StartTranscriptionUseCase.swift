import Foundation

/// Use case for starting transcription of a memo
/// Encapsulates the business logic for initiating transcription
protocol StartTranscriptionUseCaseProtocol {
    func execute(memo: Memo) async throws
}

final class StartTranscriptionUseCase: StartTranscriptionUseCaseProtocol {
    
    // MARK: - Dependencies
    private let transcriptionRepository: any TranscriptionRepository
    private let transcriptionAPI: any TranscriptionAPI
    private let eventBus: any EventBusProtocol
    private let operationCoordinator: any OperationCoordinatorProtocol
    private let logger: any LoggerProtocol
    // New dependencies for chunked flow
    private let vadService: any VADSplittingService
    private let chunkManager: AudioChunkManager
    
    // MARK: - Initialization
    init(
        transcriptionRepository: any TranscriptionRepository,
        transcriptionAPI: any TranscriptionAPI,
        eventBus: any EventBusProtocol,
        operationCoordinator: any OperationCoordinatorProtocol,
        logger: any LoggerProtocol = Logger.shared,
        vadService: any VADSplittingService = DefaultVADSplittingService(),
        chunkManager: AudioChunkManager = AudioChunkManager()
    ) {
        self.transcriptionRepository = transcriptionRepository
        self.transcriptionAPI = transcriptionAPI
        self.eventBus = eventBus
        self.operationCoordinator = operationCoordinator
        self.logger = logger
        self.vadService = vadService
        self.chunkManager = chunkManager
    }
    
    // MARK: - Use Case Execution
    func execute(memo: Memo) async throws {
        let context = LogContext(additionalInfo: [
            "memoId": memo.id.uuidString,
            "filename": memo.filename
        ])
        
        logger.info("Starting transcription for memo: \(memo.filename)", category: .transcription, context: context)
        
        // Check for operation conflicts (e.g., can't transcribe while recording same memo)
        guard await operationCoordinator.canStartTranscription(for: memo.id) else {
            logger.warning("Cannot start transcription - conflicting operation (recording) active", 
                          category: .transcription, context: context, error: nil)
            throw TranscriptionError.conflictingOperation
        }
        
        // Register transcription operation
        guard let operationId = await operationCoordinator.registerOperation(.transcription(memoId: memo.id)) else {
            logger.warning("Transcription rejected by operation coordinator", category: .transcription, context: context, error: nil)
            throw TranscriptionError.systemBusy
        }
        
        logger.debug("Transcription operation registered with ID: \(operationId)", category: .transcription, context: context)
        
        do {
            // Check if transcription is already in progress
            let currentState = await MainActor.run {
                transcriptionRepository.getTranscriptionState(for: memo.id)
            }
            guard !currentState.isInProgress else {
                await operationCoordinator.failOperation(operationId, error: TranscriptionError.alreadyInProgress)
                throw TranscriptionError.alreadyInProgress
            }

            // Check if file exists
            let audioURL = memo.fileURL
            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                await operationCoordinator.failOperation(operationId, error: TranscriptionError.fileNotFound)
                throw TranscriptionError.fileNotFound
            }

            // Set state to in-progress
            await MainActor.run {
                transcriptionRepository.saveTranscriptionState(.inProgress, for: memo.id)
            }

            // Phase 1: VAD Analysis (10%)
            await updateProgress(operationId: operationId, fraction: 0.0, step: "Analyzing speech patterns...")
            let segments = try await vadService.detectVoiceSegments(audioURL: audioURL)

            // If VAD found nothing, skip server call and report no speech
            if segments.isEmpty {
                await updateProgress(operationId: operationId, fraction: 0.9, step: "No speech detected")
                await MainActor.run {
                    let failedState = TranscriptionState.failed("No speech detected")
                    transcriptionRepository.saveTranscriptionState(failedState, for: memo.id)
                }
                await operationCoordinator.failOperation(operationId, error: TranscriptionError.noSpeechDetected)
                logger.info("Transcription skipped: No speech detected", category: .transcription, context: context)
                return
            }

            // Phase 2: Create chunks (10%)
            await updateProgress(operationId: operationId, fraction: 0.1, step: "Preparing audio segments...")
            let chunks = try await chunkManager.createChunks(from: audioURL, segments: segments)
            defer { Task { await chunkManager.cleanupChunks(chunks) } }

            // Phase 3: Transcribe chunks with progress (70%)
            await updateProgress(operationId: operationId, fraction: 0.2, step: "Transcribing speech...")
            let results = try await transcribeChunksWithProgress(operationId: operationId, chunks: chunks, baseFraction: 0.2, fractionBudget: 0.7)

            // Phase 4: Aggregate and save (10%)
            await updateProgress(operationId: operationId, fraction: 0.9, step: "Finalizing transcription...")
            let aggregator = TranscriptionAggregator()
            let aggregated = aggregator.aggregate(results)
            // Optionally treat extreme failure ratio as an error in the future (currently per-chunk retries already applied)
            let finalText = aggregated.text
            await MainActor.run {
                let completedState = TranscriptionState.completed(finalText)
                transcriptionRepository.saveTranscriptionState(completedState, for: memo.id)
                transcriptionRepository.saveTranscriptionText(finalText, for: memo.id)
            }

            logger.info("Transcription completed successfully (chunked)", category: .transcription, context: LogContext(
                additionalInfo: ["memoId": memo.id.uuidString, "textLength": finalText.count]
            ))

            // Publish transcriptionCompleted event
            await MainActor.run { [eventBus] in
                eventBus.publish(.transcriptionCompleted(memoId: memo.id, text: finalText))
            }

            // Complete op
            await operationCoordinator.completeOperation(operationId)
            logger.debug("Transcription operation completed: \(operationId)", category: .transcription, context: context)

        } catch {
            logger.error("Transcription failed", category: .transcription, context: context, error: error)
            
            // Save failed state to repository
            await MainActor.run {
                let failedState = TranscriptionState.failed(error.localizedDescription)
                transcriptionRepository.saveTranscriptionState(failedState, for: memo.id)
            }
            
            // Fail the transcription operation
            await operationCoordinator.failOperation(operationId, error: error)
            
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func updateProgress(operationId: UUID, fraction: Double, step: String, index: Int? = nil, total: Int? = nil) async {
        let progress = OperationProgress(
            percentage: max(0.0, min(1.0, fraction)),
            currentStep: step,
            estimatedTimeRemaining: nil,
            additionalInfo: nil,
            totalSteps: total,
            currentStepIndex: index
        )
        await operationCoordinator.updateProgress(operationId: operationId, progress: progress)
    }

    private func transcribeChunksWithProgress(operationId: UUID, chunks: [ChunkFile], baseFraction: Double, fractionBudget: Double) async throws -> [ChunkTranscriptionResult] {
        guard !chunks.isEmpty else { return [] }
        var results: [ChunkTranscriptionResult] = []
        results.reserveCapacity(chunks.count)

        for (i, chunk) in chunks.enumerated() {
            let stepFraction = Double(i) / Double(chunks.count)
            let current = baseFraction + fractionBudget * stepFraction
            await updateProgress(operationId: operationId, fraction: current, step: "Transcribing chunk \(i+1)/\(chunks.count)...", index: i+1, total: chunks.count)

            do {
                let text = try await transcriptionAPI.transcribe(url: chunk.url)
                results.append(ChunkTranscriptionResult(segment: chunk.segment, text: text, confidence: nil))
            } catch {
                logger.warning("Chunk transcription failed; continuing", category: .transcription, context: LogContext(additionalInfo: ["index": i]), error: error)
                results.append(ChunkTranscriptionResult(segment: chunk.segment, text: "", confidence: nil))
            }
        }

        // Final progress at end of chunking
        await updateProgress(operationId: operationId, fraction: baseFraction + fractionBudget, step: "Transcription stage complete")
        return results
    }

    private func aggregateResults(_ results: [ChunkTranscriptionResult]) -> String {
        // Keep original order and join non-empty texts with a single space
        return results
            .sorted { $0.segment.startTime < $1.segment.startTime }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func saveAndComplete(operationId: UUID, memoId: UUID, text: String, context: LogContext) async {
        await MainActor.run {
            let completedState = TranscriptionState.completed(text)
            transcriptionRepository.saveTranscriptionState(completedState, for: memoId)
            transcriptionRepository.saveTranscriptionText(text, for: memoId)
        }

        await MainActor.run { [eventBus] in
            eventBus.publish(.transcriptionCompleted(memoId: memoId, text: text))
        }

        await operationCoordinator.completeOperation(operationId)
        logger.debug("Transcription operation completed (single-shot fallback)", category: .transcription, context: context)
    }
}

// MARK: - Transcription Errors
enum TranscriptionError: LocalizedError {
    case alreadyInProgress
    case alreadyCompleted
    case invalidState
    case fileNotFound
    case invalidAudioFormat
    case networkError(String)
    case serviceUnavailable
    case transcriptionFailed(String)
    case conflictingOperation
    case systemBusy
    case noSpeechDetected
    
    var errorDescription: String? {
        switch self {
        case .alreadyInProgress:
            return "Transcription is already in progress for this memo"
        case .alreadyCompleted:
            return "Transcription has already been completed for this memo"
        case .invalidState:
            return "Invalid transcription state for retry operation"
        case .fileNotFound:
            return "Audio file not found"
        case .invalidAudioFormat:
            return "Invalid audio format for transcription"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serviceUnavailable:
            return "Transcription service is currently unavailable"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .conflictingOperation:
            return "Cannot start transcription while recording is in progress"
        case .systemBusy:
            return "System is busy - transcription queue is full"
        case .noSpeechDetected:
            return "No speech detected"
        }
    }
}
