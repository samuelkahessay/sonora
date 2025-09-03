import Foundation
import AVFoundation

// Language fallback configuration
struct LanguageFallbackConfig {
    let confidenceThreshold: Double
    init(confidenceThreshold: Double = 0.7) {
        self.confidenceThreshold = max(0.0, min(1.0, confidenceThreshold))
    }
}

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
    private let moderationService: any ModerationServiceProtocol
    // New dependencies for chunked flow
    private let vadService: any VADSplittingService
    private let chunkManager: AudioChunkManager
    // Language evaluation and detection
    private let qualityEvaluator: any LanguageQualityEvaluator
    private let clientLanguageService: any ClientLanguageDetectionService
    private let languageFallbackConfig: LanguageFallbackConfig
    
    // MARK: - Initialization
    init(
        transcriptionRepository: any TranscriptionRepository,
        transcriptionAPI: any TranscriptionAPI,
        eventBus: any EventBusProtocol,
        operationCoordinator: any OperationCoordinatorProtocol,
        logger: any LoggerProtocol = Logger.shared,
        vadService: any VADSplittingService = DefaultVADSplittingService(),
        chunkManager: AudioChunkManager = AudioChunkManager(),
        qualityEvaluator: any LanguageQualityEvaluator = DefaultLanguageQualityEvaluator(),
        clientLanguageService: any ClientLanguageDetectionService = DefaultClientLanguageDetectionService(),
        languageFallbackConfig: LanguageFallbackConfig = LanguageFallbackConfig(),
        moderationService: any ModerationServiceProtocol
    ) {
        self.transcriptionRepository = transcriptionRepository
        self.transcriptionAPI = transcriptionAPI
        self.eventBus = eventBus
        self.operationCoordinator = operationCoordinator
        self.logger = logger
        self.vadService = vadService
        self.chunkManager = chunkManager
        self.qualityEvaluator = qualityEvaluator
        self.clientLanguageService = clientLanguageService
        self.languageFallbackConfig = languageFallbackConfig
        self.moderationService = moderationService
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
            await MainActor.run { CurrentTranscriptionContext.memoId = memo.id }
            defer { Task { await MainActor.run { CurrentTranscriptionContext.memoId = nil } } }
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

            // Assess duration for gating (use async loader for iOS 16+)
            let asset = AVURLAsset(url: audioURL)
            let durationTime = try await asset.load(.duration)
            let totalDurationSec = CMTimeGetSeconds(durationTime)

            // Branch: Preferred language set
            let preferredLang = AppConfiguration.shared.preferredTranscriptionLanguage
            if let lang = preferredLang {
                if totalDurationSec < 90.0 {
                    // Single-shot for short recordings
                    await updateProgress(operationId: operationId, fraction: 0.2, step: "Transcribing (\(lang.uppercased()))...")
                    // Wire fine-grained engine progress if supported
                    if let progressSvc = transcriptionAPI as? TranscriptionProgressReporting {
                        await progressSvc.setProgressHandler { [weak self] fraction in
                            guard let self = self else { return }
                            // Map engine fraction into overall (0.2 -> 0.95)
                            let mapped = 0.2 + 0.75 * max(0.0, min(1.0, fraction))
                            Task { await self.updateProgress(operationId: operationId, fraction: mapped, step: "Transcribing...") }
                        }
                    }
                    defer {
                        Task { @MainActor in
                            (transcriptionAPI as? TranscriptionProgressReporting)?.clearProgressHandler()
                        }
                    }
                    let resp = try await transcriptionAPI.transcribe(url: audioURL, language: lang)
                    let eval = qualityEvaluator.evaluateQuality(resp, text: resp.text)

                    // Save and complete
                    await updateProgress(operationId: operationId, fraction: 0.97, step: "Finalizing transcription...")
                    let textToSave = resp.text
                    let langToSave = resp.detectedLanguage ?? lang
                    let qualityToSave = eval.overallScore
                    let textLen = textToSave.count
                    await MainActor.run {
                        // Save final text (also sets state to completed)
                        transcriptionRepository.saveTranscriptionText(textToSave, for: memo.id)
                        transcriptionRepository.saveTranscriptionMetadata([
                            "detectedLanguage": langToSave,
                            "qualityScore": qualityToSave
                        ], for: memo.id)
                    }
                    await annotateAIMetadataAndModerate(memoId: memo.id, text: textToSave)
                    // Include service used in log context (WhisperKit local vs Cloud API)
                    let meta = await MainActor.run { transcriptionRepository.getTranscriptionMetadata(for: memo.id) }
                    let serviceKey = (meta?["transcriptionService"] as? String) ?? "unknown"
                    let serviceLabel: String = (serviceKey == "local_whisperkit") ? "WhisperKit (local)" : (serviceKey == "cloud_api" ? "Cloud API" : "unknown")
                    var info: [String: Any] = [
                        "memoId": memo.id.uuidString,
                        "textLength": textLen,
                        "language": langToSave,
                        "quality": qualityToSave,
                        "service": serviceLabel,
                        "serviceKey": serviceKey
                    ]
                    if let model = meta?["whisperModel"] as? String { info["whisperModel"] = model }
                    // Lower to debug; MemoEventHandler will emit the single info-level summary
                    logger.debug("Transcription completed (single, preferred language)", category: .transcription, context: LogContext(additionalInfo: info))
                    await MainActor.run { [eventBus, textToSave] in
                        eventBus.publish(.transcriptionCompleted(memoId: memo.id, text: textToSave))
                    }
                    await operationCoordinator.completeOperation(operationId)
                    return
                }

                // Long recording with preferred language: chunk with language hint per chunk
                await updateProgress(operationId: operationId, fraction: 0.1, step: "Preparing audio segments...")
                let chunks = try await chunkManager.createChunks(from: audioURL, segments: segments)
                defer { Task { await chunkManager.cleanupChunks(chunks) } }

                await updateProgress(operationId: operationId, fraction: 0.2, step: "Transcribing (\(lang.uppercased()))...")
                let primary = try await transcribeChunksWithLanguage(operationId: operationId, chunks: chunks, baseFraction: 0.2, fractionBudget: 0.6, language: lang, stageLabel: "Transcribing (\(lang))")
                let aggregator = TranscriptionAggregator()
                let agg = aggregator.aggregate(primary)
                let textToSave = agg.text
                let langToSave = lang
                let qualityToSave = agg.confidence
                let textLen = textToSave.count
                await updateProgress(operationId: operationId, fraction: 0.97, step: "Finalizing transcription...")
                await MainActor.run {
                    // Save final text (also sets state to completed)
                    transcriptionRepository.saveTranscriptionText(textToSave, for: memo.id)
                    transcriptionRepository.saveTranscriptionMetadata([
                        "detectedLanguage": langToSave,
                        "qualityScore": qualityToSave
                    ], for: memo.id)
                }
                await annotateAIMetadataAndModerate(memoId: memo.id, text: textToSave)
                // Include service used in log context
                let meta = await MainActor.run { transcriptionRepository.getTranscriptionMetadata(for: memo.id) }
                let serviceKey = (meta?["transcriptionService"] as? String) ?? "unknown"
                let serviceLabel: String = (serviceKey == "local_whisperkit") ? "WhisperKit (local)" : (serviceKey == "cloud_api" ? "Cloud API" : "unknown")
                var info: [String: Any] = [
                    "memoId": memo.id.uuidString,
                    "textLength": textLen,
                    "language": langToSave,
                    "quality": qualityToSave,
                    "service": serviceLabel,
                    "serviceKey": serviceKey
                ]
                if let model = meta?["whisperModel"] as? String { info["whisperModel"] = model }
                logger.debug("Transcription completed (chunked, preferred language)", category: .transcription, context: LogContext(additionalInfo: info))
                await MainActor.run { [eventBus, textToSave] in
                    eventBus.publish(.transcriptionCompleted(memoId: memo.id, text: textToSave))
                }
                await operationCoordinator.completeOperation(operationId)
                return
            }

            // Branch: Auto-detect mode
            if totalDurationSec < 60.0 {
                // Single-shot auto with fallback if needed
                await updateProgress(operationId: operationId, fraction: 0.2, step: "Transcribing (auto)...")
                // Wire fine-grained engine progress if supported
                if let progressSvc = transcriptionAPI as? TranscriptionProgressReporting {
                    await progressSvc.setProgressHandler { [weak self] fraction in
                        guard let self = self else { return }
                        let mapped = 0.2 + 0.75 * max(0.0, min(1.0, fraction))
                        Task { await self.updateProgress(operationId: operationId, fraction: mapped, step: "Transcribing...") }
                    }
                }
                defer {
                    Task { @MainActor in
                        (transcriptionAPI as? TranscriptionProgressReporting)?.clearProgressHandler()
                    }
                }
                let primaryResp = try await transcriptionAPI.transcribe(url: audioURL, language: nil)
                let primaryEval = qualityEvaluator.evaluateQuality(primaryResp, text: primaryResp.text)

                var finalResp = primaryResp
                var finalEval = primaryEval
                if qualityEvaluator.shouldTriggerFallback(primaryEval, threshold: languageFallbackConfig.confidenceThreshold) {
                    await updateProgress(operationId: operationId, fraction: 0.82, step: "Low confidence. Retrying with English...")
                    do {
                        let fallbackResp = try await transcriptionAPI.transcribe(url: audioURL, language: "en")
                        let fallbackEval = qualityEvaluator.evaluateQuality(fallbackResp, text: fallbackResp.text)
                        let comparison = qualityEvaluator.compareTwoResults(primaryEval, fallbackEval)
                        switch comparison {
                        case .useFallback:
                            finalResp = fallbackResp
                            finalEval = fallbackEval
                        case .usePrimary:
                            break
                        }
                    } catch {
                        logger.warning("Fallback transcription failed; using primary result", category: .transcription, context: context, error: error)
                    }
                }

                // Save and complete
                await updateProgress(operationId: operationId, fraction: 0.97, step: "Finalizing transcription...")
                let textToSave = finalResp.text
                let langToSave = DefaultClientLanguageDetectionService.iso639_1(fromBCP47: finalResp.detectedLanguage) ?? finalResp.detectedLanguage ?? "und"
                let qualityToSave = finalEval.overallScore
                let textLen = textToSave.count
                await MainActor.run {
                    // Save final text (also sets state to completed)
                    transcriptionRepository.saveTranscriptionText(textToSave, for: memo.id)
                    transcriptionRepository.saveTranscriptionMetadata([
                        "detectedLanguage": langToSave,
                        "qualityScore": qualityToSave
                    ], for: memo.id)
                }
                // Include service used in log context
                let meta = await MainActor.run { transcriptionRepository.getTranscriptionMetadata(for: memo.id) }
                let serviceKey = (meta?["transcriptionService"] as? String) ?? "unknown"
                let serviceLabel: String = (serviceKey == "local_whisperkit") ? "WhisperKit (local)" : (serviceKey == "cloud_api" ? "Cloud API" : "unknown")
                var info: [String: Any] = [
                    "memoId": memo.id.uuidString,
                    "textLength": textLen,
                    "language": langToSave,
                    "quality": qualityToSave,
                    "service": serviceLabel,
                    "serviceKey": serviceKey
                ]
                if let model = meta?["whisperModel"] as? String { info["whisperModel"] = model }
                logger.debug("Transcription completed (single, auto)", category: .transcription, context: LogContext(additionalInfo: info))
                await MainActor.run { [eventBus, textToSave] in
                    eventBus.publish(.transcriptionCompleted(memoId: memo.id, text: textToSave))
                }
                await operationCoordinator.completeOperation(operationId)
                return
            }

            // For longer Auto mode: proceed with chunking and fallback logic
            await updateProgress(operationId: operationId, fraction: 0.1, step: "Preparing audio segments...")
            let chunks = try await chunkManager.createChunks(from: audioURL, segments: segments)
            defer { Task { await chunkManager.cleanupChunks(chunks) } }

            await updateProgress(operationId: operationId, fraction: 0.2, step: "Transcribing with language detection...")
            let primary = try await transcribeChunksWithLanguage(operationId: operationId, chunks: chunks, baseFraction: 0.2, fractionBudget: 0.6, language: nil, stageLabel: "Transcribing (auto)")
            let aggregator = TranscriptionAggregator()
            let primaryAgg = aggregator.aggregate(primary)
            let primaryText = primaryAgg.text

            // Phase 4: Evaluate quality and decide on fallback
            await updateProgress(operationId: operationId, fraction: 0.8, step: "Evaluating transcription quality...")
            let primarySummary = summarizeResponse(from: primary, aggregatedText: primaryText)
            let primaryEval = qualityEvaluator.evaluateQuality(primarySummary, text: primaryText)

            var finalText = primaryText
            var finalEval = primaryEval
            var finalLanguage = primaryEval.language

            // Only trigger English fallback when using auto-detect; skip when user prefers a specific language
            if preferredLang == nil && qualityEvaluator.shouldTriggerFallback(primaryEval, threshold: languageFallbackConfig.confidenceThreshold) {
                await updateProgress(operationId: operationId, fraction: 0.82, step: "Low confidence. Retrying with English...")
                do {
                    let fallback = try await transcribeChunksWithLanguage(operationId: operationId, chunks: chunks, baseFraction: 0.82, fractionBudget: 0.12, language: "en", stageLabel: "Transcribing (en)")
                    let fallbackAgg = aggregator.aggregate(fallback)
                    let fallbackText = fallbackAgg.text
                    let fallbackSummary = summarizeResponse(from: fallback, aggregatedText: fallbackText, overrideLanguage: "en")
                    let fallbackEval = qualityEvaluator.evaluateQuality(fallbackSummary, text: fallbackText)

                    await updateProgress(operationId: operationId, fraction: 0.95, step: "Selecting best transcription...")
                    let comparison = qualityEvaluator.compareTwoResults(primaryEval, fallbackEval)
                    switch comparison {
                    case .useFallback:
                        finalText = fallbackText
                        finalEval = fallbackEval
                        finalLanguage = "en"
                    case .usePrimary:
                        break
                    }
                } catch {
                    logger.warning("Fallback transcription failed; using primary result", category: .transcription, context: context, error: error)
                }
            }

            // Phase 5: Save and complete
            await updateProgress(operationId: operationId, fraction: 0.97, step: "Finalizing transcription...")
            let textToSave = finalText
            let langToSave = finalLanguage
            let qualityToSave = finalEval.overallScore
            let textLen = textToSave.count
                await MainActor.run {
                    // Save final text (also sets state to completed)
                    transcriptionRepository.saveTranscriptionText(textToSave, for: memo.id)
                    transcriptionRepository.saveTranscriptionMetadata([
                        "detectedLanguage": langToSave,
                        "qualityScore": qualityToSave
                    ], for: memo.id)
                }
            await annotateAIMetadataAndModerate(memoId: memo.id, text: textToSave)

            logger.info("Transcription completed successfully (chunked)", category: .transcription, context: LogContext(
                additionalInfo: ["memoId": memo.id.uuidString, "textLength": textLen, "language": langToSave, "quality": qualityToSave]
            ))

            // Publish transcriptionCompleted event
            await MainActor.run { [eventBus, textToSave] in
                eventBus.publish(.transcriptionCompleted(memoId: memo.id, text: textToSave))
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

    private func transcribeChunksWithLanguage(operationId: UUID, chunks: [ChunkFile], baseFraction: Double, fractionBudget: Double, language: String?, stageLabel: String) async throws -> [ChunkTranscriptionResult] {
        guard !chunks.isEmpty else { return [] }
        var results: [ChunkTranscriptionResult] = []
        results.reserveCapacity(chunks.count)

        for (i, chunk) in chunks.enumerated() {
            let stepFraction = Double(i) / Double(chunks.count)
            let current = baseFraction + fractionBudget * stepFraction
            await updateProgress(operationId: operationId, fraction: current, step: "\(stageLabel) \(i+1)/\(chunks.count)...", index: i+1, total: chunks.count)

            do {
                let response = try await transcriptionAPI.transcribe(url: chunk.url, language: language)
                results.append(ChunkTranscriptionResult(segment: chunk.segment, response: response))
            } catch {
                logger.warning("Chunk transcription failed; continuing", category: .transcription, context: LogContext(additionalInfo: ["index": i, "lang": language ?? "auto"]), error: error)
                results.append(ChunkTranscriptionResult(segment: chunk.segment, response: TranscriptionResponse(text: "", detectedLanguage: nil, confidence: nil, avgLogProb: nil, duration: nil)))
            }
        }

        // Final progress at end of chunking
        await updateProgress(operationId: operationId, fraction: baseFraction + fractionBudget, step: "Transcription stage complete")
        return results
    }

    private func summarizeResponse(from results: [ChunkTranscriptionResult], aggregatedText: String, overrideLanguage: String? = nil) -> TranscriptionResponse {
        // Aggregate server-provided metadata across chunks
        var langWeights: [String: Double] = [:]
        var confs: [Double] = []
        var logProbs: [Double] = []
        var totalDuration: TimeInterval = 0

        for r in results {
            if let dur = (r.response.duration) { totalDuration += dur }
            if let c = r.response.confidence { confs.append(c) }
            if let lp = r.response.avgLogProb { logProbs.append(lp) }
            if let l = r.response.detectedLanguage {
                let iso = DefaultClientLanguageDetectionService.iso639_1(fromBCP47: l) ?? l
                let weight = r.response.confidence ?? 1.0
                langWeights[iso, default: 0.0] += weight
            }
        }

        let detectedLang: String? = overrideLanguage ?? langWeights.max(by: { $0.value < $1.value })?.key
        let avgConf: Double? = confs.isEmpty ? nil : (confs.reduce(0, +) / Double(confs.count))
        let avgLP: Double? = logProbs.isEmpty ? nil : (logProbs.reduce(0, +) / Double(logProbs.count))

        return TranscriptionResponse(
            text: aggregatedText,
            detectedLanguage: detectedLang,
            confidence: avgConf,
            avgLogProb: avgLP,
            duration: totalDuration > 0 ? totalDuration : nil
        )
    }

    private func saveAndComplete(operationId: UUID, memoId: UUID, text: String, context: LogContext) async {
        await MainActor.run {
            // Save final text (also sets state to completed)
            transcriptionRepository.saveTranscriptionText(text, for: memoId)
        }

        await annotateAIMetadataAndModerate(memoId: memoId, text: text)

        await MainActor.run { [eventBus] in
            eventBus.publish(.transcriptionCompleted(memoId: memoId, text: text))
        }

        await operationCoordinator.completeOperation(operationId)
        logger.debug("Transcription operation completed (single-shot fallback)", category: .transcription, context: context)
    }

    // MARK: - AI Labeling & Moderation
    private func annotateAIMetadataAndModerate(memoId: UUID, text: String) async {
        let existingMeta: [String: Any] = await MainActor.run {
            DIContainer.shared.transcriptionRepository().getTranscriptionMetadata(for: memoId) ?? [:]
        }
        var workingMeta = existingMeta
        workingMeta["aiGenerated"] = true
        do {
            let mod = try await moderationService.moderate(text: text)
            workingMeta["moderationFlagged"] = mod.flagged
            if let cats = mod.categories { workingMeta["moderationCategories"] = cats }
        } catch {
            // Best-effort; keep AI label.
        }
        let metaToSave = workingMeta
        await MainActor.run {
            DIContainer.shared.transcriptionRepository().saveTranscriptionMetadata(metaToSave, for: memoId)
        }
    }
}

// MARK: - Transcription Errors
public enum TranscriptionError: LocalizedError {
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
    
    public var errorDescription: String? {
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
