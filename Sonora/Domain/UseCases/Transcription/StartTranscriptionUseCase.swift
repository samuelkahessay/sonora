import AVFoundation
import Foundation

@MainActor
internal final class StartTranscriptionUseCase: StartTranscriptionUseCaseProtocol {

    // MARK: - Dependencies
    private let transcriptionRepository: any TranscriptionRepository
    private let transcriptionAPI: any TranscriptionAPI
    private let eventBus: any EventBusProtocol
    private let operationCoordinator: any OperationCoordinatorProtocol
    private let logger: any LoggerProtocol
    private let moderationService: any ModerationServiceProtocol
    private let fillerWordFilter: any FillerWordFiltering
    // New dependencies for chunked flow
    private let vadService: any VADSplittingService
    private let chunkManager: AudioChunkManager
    // Language evaluation and detection
    private let qualityEvaluator: any LanguageQualityEvaluator
    private let clientLanguageService: any ClientLanguageDetectionService
    private let languageFallbackConfig: LanguageFallbackConfig

    // MARK: - Initialization
    internal init(
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
        moderationService: any ModerationServiceProtocol,
        fillerWordFilter: any FillerWordFiltering
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
        self.fillerWordFilter = fillerWordFilter
    }

    // MARK: - Use Case Execution
    @MainActor
    internal func execute(memo: Memo) async throws {
        let context = LogContext(additionalInfo: [
            "memoId": memo.id.uuidString,
            "filename": memo.filename
        ])

        logger.info("Starting transcription for memo: \(memo.filename)", category: .transcription, context: context)

        // Preconditions and historical skip check
        try guardIdempotencyAndSilenceHistory(memo: memo, context: context)

        // Check for operation conflicts (e.g., can't transcribe while recording same memo)
        try await guardNoConflictingOperation(memo: memo, context: context)

        // Register transcription operation
        let operationId = try await registerTranscriptionOperation(memo: memo, context: context)

        do {
            await MainActor.run { CurrentTranscriptionContext.memoId = memo.id }
            defer { Task { await MainActor.run { CurrentTranscriptionContext.memoId = nil } } }
            // Check if transcription is already in progress
            // State is checked pre-registration; proceed

            // Check file exists and early tiny-clip skip
            let audioURL = try await ensureFileReady(memo: memo, operationId: operationId)
            if try await skipIfTooShort(audioURL: audioURL, memo: memo, operationId: operationId, context: context) {
                return
            }

            // Set state to in-progress
            await markInProgress(memo: memo)

            // Phase 1: Analyze audio (VAD + duration) and route
            let analysis = try await analyzeAudioAndSegments(audioURL: audioURL, memo: memo, operationId: operationId, context: context)
            if analysis.segments.isEmpty {
                await handleNoSpeech(memo: memo, operationId: operationId, context: context)
                return
            }

            if let lang = AppConfiguration.shared.preferredTranscriptionLanguage {
                try await processPreferredLanguagePath(audioURL: audioURL, lang: lang, analysis: analysis, memo: memo, operationId: operationId, context: context)
                return
            } else {
                try await processAutoDetectPath(audioURL: audioURL, analysis: analysis, memo: memo, operationId: operationId, context: context)
                return
            }

        } catch {
            logger.error("Transcription failed", category: .transcription, context: context, error: error)

            // Save failed state to repository
            await MainActor.run {
                let failedState = TranscriptionState.failed(error.localizedDescription)
                transcriptionRepository.saveTranscriptionState(failedState, for: memo.id)
            }

            // Fail the transcription operation
            await operationCoordinator.failOperation(operationId, errorDescription: error.localizedDescription)

            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func updateProgress(operationId: UUID, fraction: Double, step: String, index: Int? = nil, total: Int? = nil) async {
        let progress = OperationProgress(
            percentage: max(0.0, min(1.0, fraction)),
            currentStep: step,
            estimatedTimeRemaining: nil,
            extraInfo: nil,
            totalSteps: total,
            currentStepIndex: index
        )
        await operationCoordinator.updateProgress(operationId: operationId, progress: progress)
    }

    private func prepareTranscript(from text: String) -> (processed: String, original: String) {
        let original = text
        let sanitized = fillerWordFilter.removeFillerWords(from: text)
        // Ensure we never persist an empty transcript when the user actually spoke.
        if sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmedOriginal, original)
        }
        return (sanitized, original)
    }

    private func transcribeChunksWithProgress(operationId: UUID, chunks: [ChunkFile], baseFraction: Double, fractionBudget: Double) async throws -> [ChunkTranscriptionResult] {
        guard !chunks.isEmpty else { return [] }
        var results: [ChunkTranscriptionResult] = []
        results.reserveCapacity(chunks.count)

        for (i, chunk) in chunks.enumerated() {
            let stepFraction = Double(i) / Double(chunks.count)
            let current = baseFraction + fractionBudget * stepFraction
            await updateProgress(operationId: operationId, fraction: current, step: "Transcribing chunk...", index: i + 1, total: chunks.count)

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
        results
            .sorted { $0.segment.startTime < $1.segment.startTime }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func transcribeChunksWithLanguage(operationId: UUID, chunks: [ChunkFile], baseFraction: Double, fractionBudget: Double, language: String?, stageLabel: String) async throws -> [ChunkTranscriptionResult] {
        guard !chunks.isEmpty else { return [] }

        // Configuration for parallel transcription
        let maxConcurrentTranscriptions = 3 // Limit concurrent API requests to avoid overwhelming server
        let transcriptionAPI = self.transcriptionAPI
        let logger = self.logger

        // Use dictionary to preserve ordering (index -> result)
        var resultsByIndex: [Int: ChunkTranscriptionResult] = [:]
        var completedCount = 0
        let totalCount = chunks.count

        // Create indexed chunks for proper ordering
        let indexedChunks = chunks.enumerated().map { ($0.offset, $0.element) }

        // Helper to transcribe a single chunk with preserved ordering information
        func transcribeSingleChunk(chunk: ChunkFile, index: Int, language: String?) async -> (Int, ChunkTranscriptionResult) {
            do {
                let response = try await transcriptionAPI.transcribe(url: chunk.url, language: language)
                return (index, ChunkTranscriptionResult(segment: chunk.segment, response: response))
            } catch {
                logger.warning("Chunk transcription failed; continuing", category: .transcription, context: LogContext(additionalInfo: ["index": index, "lang": language ?? "auto-detect"]), error: error)
                return (index, ChunkTranscriptionResult(segment: chunk.segment, response: TranscriptionResponse(text: "", detectedLanguage: nil, confidence: nil, avgLogProb: nil, duration: nil)))
            }
        }

        // Process chunks in parallel with concurrency limit
        try await withThrowingTaskGroup(of: (Int, ChunkTranscriptionResult).self) { group in
            var startIndex = 0

            // Add initial batch of tasks (up to maxConcurrent)
            for (index, chunk) in indexedChunks.prefix(maxConcurrentTranscriptions) {
                group.addTask {
                    await transcribeSingleChunk(chunk: chunk, index: index, language: language)
                }
                startIndex += 1
            }

            // As tasks complete, add new ones to maintain concurrency limit
            while let (index, result) = try await group.next() {
                resultsByIndex[index] = result
                completedCount += 1

                // Update progress based on completion ratio
                let progressFraction = Double(completedCount) / Double(totalCount)
                let current = baseFraction + fractionBudget * progressFraction
                await updateProgress(operationId: operationId, fraction: current, step: stageLabel, index: completedCount, total: totalCount)

                // Add next chunk to process if any remain
                if startIndex < indexedChunks.count {
                    let (nextIndex, nextChunk) = indexedChunks[startIndex]
                    group.addTask {
                        await transcribeSingleChunk(chunk: nextChunk, index: nextIndex, language: language)
                    }
                    startIndex += 1
                }
            }
        }

        // Reconstruct results in original order
        let orderedResults = (0..<chunks.count).compactMap { resultsByIndex[$0] }
        guard orderedResults.count == chunks.count else {
            throw TranscriptionError.transcriptionFailed("Failed to process all chunks")
        }

        // Final progress at end of chunking
        await updateProgress(operationId: operationId, fraction: baseFraction + fractionBudget, step: "Transcription stage complete")
        return orderedResults
    }

    private func summarizeResponse(from results: [ChunkTranscriptionResult], aggregatedText: String, overrideLanguage: String? = nil) -> TranscriptionResponse {
        // Aggregate server-provided metadata across chunks
        var langWeights: [String: Double] = [:]
        var confs: [Double] = []
        var logProbs: [Double] = []
        var totalDuration: TimeInterval = 0

        for r in results {
            if let duration = r.response.duration { totalDuration += duration }
            if let confidence = r.response.confidence { confs.append(confidence) }
            if let avgLP = r.response.avgLogProb { logProbs.append(avgLP) }
            if let lang = r.response.detectedLanguage {
                let iso = DefaultClientLanguageDetectionService.iso639_1(fromBCP47: lang) ?? lang
                let weight = r.response.confidence ?? 1.0
                langWeights[iso, default: 0.0] += weight
            }
        }

        let detectedLang: String? = overrideLanguage ?? langWeights.max { $0.value < $1.value }?.key
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

        await MainActor.run {
            EventBus.shared.publish(.transcriptionCompleted(memoId: memoId, text: text))
        }

        await operationCoordinator.completeOperation(operationId)
        logger.debug("Transcription operation completed (single-shot fallback)", category: .transcription, context: context)
    }

    // MARK: - AI Labeling & Moderation
    private func annotateAIMetadataAndModerate(memoId: UUID, text: String) async {
        var meta: TranscriptionMetadata = await MainActor.run {
            DIContainer.shared.transcriptionRepository().getTranscriptionMetadata(for: memoId) ?? TranscriptionMetadata()
        }
        meta.aiGenerated = true
        do {
            let mod = try await moderationService.moderate(text: text)
            meta.moderationFlagged = mod.flagged
            meta.moderationCategories = mod.categories
        } catch {
            // Best-effort; keep AI label.
        }
        await MainActor.run {
            DIContainer.shared.transcriptionRepository().saveTranscriptionMetadata(meta, for: memoId)
        }
    }
}

// Supporting types for StartTranscriptionUseCase
internal struct LanguageFallbackConfig {
    let confidenceThreshold: Double
    init(confidenceThreshold: Double = 0.5) {
        self.confidenceThreshold = max(0.0, min(1.0, confidenceThreshold))
    }
}

@MainActor
internal protocol StartTranscriptionUseCaseProtocol {
    func execute(memo: Memo) async throws
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
            return "Sonora didn't quite catch that"
        }
    }
}

// MARK: - Imported Audio Heuristics and Orchestration
extension StartTranscriptionUseCase {
    private func enrichedServiceInfo(for memoId: UUID, base: [String: Any]) async -> [String: Any] {
        var info = base
        let meta = await MainActor.run { transcriptionRepository.getTranscriptionMetadata(for: memoId) }
        let serviceKey = meta?.transcriptionService?.rawValue ?? "unknown"
        let serviceLabel: String = serviceKey == "cloud_api" ? "Cloud API" : "unknown"
        info["serviceKey"] = serviceKey
        info["service"] = serviceLabel
        return info
    }

    private struct FinalizationPayload {
        let operationId: UUID
        let memo: Memo
        let textToSave: String
        let processedText: String
        let originalText: String
        let langToSave: String
        let qualityToSave: Double?
        let info: [String: Any]
        let logMessage: String
        let logLevel: LogLevel
    }

    private func finalize(using payload: FinalizationPayload) async {
        await MainActor.run {
            transcriptionRepository.saveTranscriptionText(payload.textToSave, for: payload.memo.id)
            transcriptionRepository.saveTranscriptionMetadata(
                TranscriptionMetadata(
                    text: payload.processedText,
                    originalText: payload.originalText,
                    detectedLanguage: payload.langToSave,
                    qualityScore: payload.qualityToSave
                ),
                for: payload.memo.id
            )
        }
        await annotateAIMetadataAndModerate(memoId: payload.memo.id, text: payload.textToSave)
        switch payload.logLevel {
        case .info:
            logger.info(payload.logMessage, category: .transcription, context: LogContext(additionalInfo: payload.info))
        case .debug:
            logger.debug(payload.logMessage, category: .transcription, context: LogContext(additionalInfo: payload.info))
        default:
            logger.log(level: payload.logLevel, category: .transcription, message: payload.logMessage, context: LogContext(additionalInfo: payload.info), error: nil)
        }
        await MainActor.run { [text = payload.textToSave] in
            EventBus.shared.publish(.transcriptionCompleted(memoId: payload.memo.id, text: text))
        }
        await operationCoordinator.completeOperation(payload.operationId)
    }
    private struct AudioAnalysis { let segments: [VoiceSegment]; let forceChunk: Bool; let totalDurationSec: Double }

    private func analyzeAudioAndSegments(audioURL: URL, memo: Memo, operationId: UUID, context: LogContext) async throws -> AudioAnalysis {
        await updateProgress(operationId: operationId, fraction: 0.0, step: "Analyzing speech patterns...")
        let forceChunk = await shouldForceChunking(audioURL: audioURL)
        let vadToUse: any VADSplittingService = {
            if forceChunk, let _ = vadService as? DefaultVADSplittingService {
                return DefaultVADSplittingService(config: VADConfig(silenceThreshold: -50.0, minSpeechDuration: 0.4, minSilenceGap: 0.25, windowSize: 1_024))
            }
            return vadService
        }()
        let segments = try await vadToUse.detectVoiceSegments(audioURL: audioURL)
        let asset = AVURLAsset(url: audioURL)
        let durationTime = try await asset.load(.duration)
        let totalDurationSec = CMTimeGetSeconds(durationTime)
        return AudioAnalysis(segments: segments, forceChunk: forceChunk, totalDurationSec: totalDurationSec)
    }

    private func handleNoSpeech(memo: Memo, operationId: UUID, context: LogContext) async {
        await updateProgress(operationId: operationId, fraction: 0.9, step: "Sonora didn't quite catch that")
        await MainActor.run {
            let failedState = TranscriptionState.failed("Sonora didn't quite catch that")
            transcriptionRepository.saveTranscriptionState(failedState, for: memo.id)
        }
        await operationCoordinator.completeOperation(operationId)
        logger.info("Transcription skipped (no speech)", category: .transcription, context: context)
    }

    private func processPreferredLanguagePath(audioURL: URL, lang: String, analysis: AudioAnalysis, memo: Memo, operationId: UUID, context: LogContext) async throws {
        if !analysis.forceChunk && analysis.totalDurationSec < 90.0 {
            await updateProgress(operationId: operationId, fraction: 0.2, step: "Transcribing...")
            let resp = try await transcriptionAPI.transcribe(url: audioURL, language: lang)
            let eval = qualityEvaluator.evaluateQuality(resp, text: resp.text)
            let textToSave = resp.text
            let (processedText, originalText) = prepareTranscript(from: resp.text)
            await updateProgress(operationId: operationId, fraction: 0.97, step: "Finalizing transcription...")
            let langToSave = resp.detectedLanguage ?? lang
            let qualityToSave = eval.overallScore
            let textLen = processedText.count
        var baseInfo: [String: Any] = [
            "memoId": memo.id.uuidString,
            "textLength": textLen,
            "language": langToSave,
            "quality": qualityToSave
        ]
        baseInfo = await enrichedServiceInfo(for: memo.id, base: baseInfo)
        let payload = FinalizationPayload(operationId: operationId, memo: memo, textToSave: textToSave, processedText: processedText, originalText: originalText, langToSave: langToSave, qualityToSave: qualityToSave, info: baseInfo, logMessage: "Transcription completed (single, preferred language)", logLevel: .debug)
        await finalize(using: payload)
            return
        }

        await updateProgress(operationId: operationId, fraction: 0.1, step: "Preparing audio segments...")
        let chunks = try await chunkManager.createChunks(from: audioURL, segments: analysis.segments)
        defer { Task { await chunkManager.cleanupChunks(chunks) } }
        await updateProgress(operationId: operationId, fraction: 0.2, step: "Transcribing...")
        let primary = try await transcribeChunksWithLanguage(operationId: operationId, chunks: chunks, baseFraction: 0.2, fractionBudget: 0.6, language: lang, stageLabel: "Transcribing...")
        let aggregator = TranscriptionAggregator()
        let agg = aggregator.aggregate(primary)
        let textToSave = agg.text
        let (processedText, originalText) = prepareTranscript(from: agg.text)
        let langToSave = lang
        let qualityToSave = agg.confidence
        let textLen = processedText.count
        await updateProgress(operationId: operationId, fraction: 0.97, step: "Finalizing transcription...")
        var baseInfo: [String: Any] = [
            "memoId": memo.id.uuidString,
            "textLength": textLen,
            "language": langToSave,
            "quality": qualityToSave
        ]
        baseInfo = await enrichedServiceInfo(for: memo.id, base: baseInfo)
        let payload = FinalizationPayload(operationId: operationId, memo: memo, textToSave: textToSave, processedText: processedText, originalText: originalText, langToSave: langToSave, qualityToSave: qualityToSave, info: baseInfo, logMessage: "Transcription completed (chunked, preferred language)", logLevel: .debug)
        await finalize(using: payload)
    }

    private func processAutoDetectPath(audioURL: URL, analysis: AudioAnalysis, memo: Memo, operationId: UUID, context: LogContext) async throws {
        if !analysis.forceChunk && analysis.totalDurationSec < 60.0 {
            await updateProgress(operationId: operationId, fraction: 0.2, step: "Transcribing...")
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
            await updateProgress(operationId: operationId, fraction: 0.97, step: "Finalizing transcription...")
            let textToSave = finalResp.text
            let (processedText, originalText) = prepareTranscript(from: finalResp.text)
            let langToSave = DefaultClientLanguageDetectionService.iso639_1(fromBCP47: finalResp.detectedLanguage) ?? finalResp.detectedLanguage ?? "und"
            let qualityToSave = finalEval.overallScore
            let textLen = processedText.count
            var baseInfo: [String: Any] = [
                "memoId": memo.id.uuidString,
                "textLength": textLen,
                "language": langToSave,
                "quality": qualityToSave
            ]
            baseInfo = await enrichedServiceInfo(for: memo.id, base: baseInfo)
            let payload = FinalizationPayload(operationId: operationId, memo: memo, textToSave: textToSave, processedText: processedText, originalText: originalText, langToSave: langToSave, qualityToSave: qualityToSave, info: baseInfo, logMessage: "Transcription completed (single, cloud)", logLevel: .debug)
            await finalize(using: payload)
            return
        }

        let result = try await performAutoChunked(audioURL: audioURL, analysis: analysis, operationId: operationId, context: context)
        let finalText = result.text
        let finalLanguage = result.lang
        await updateProgress(operationId: operationId, fraction: 0.97, step: "Finalizing transcription...")
        let textToSave = finalText
        let (processedText, originalText) = prepareTranscript(from: finalText)
        let langToSave = finalLanguage
        let qualityToSave = result.qualityScore
        let textLen = processedText.count
        var baseInfo: [String: Any] = [
            "memoId": memo.id.uuidString,
            "textLength": textLen,
            "language": langToSave,
            "quality": qualityToSave
        ]
        baseInfo = await enrichedServiceInfo(for: memo.id, base: baseInfo)
        let payload = FinalizationPayload(operationId: operationId, memo: memo, textToSave: textToSave, processedText: processedText, originalText: originalText, langToSave: langToSave, qualityToSave: qualityToSave, info: baseInfo, logMessage: "Transcription completed successfully (chunked)", logLevel: .info)
        await finalize(using: payload)
    }

    private func performAutoChunked(audioURL: URL, analysis: AudioAnalysis, operationId: UUID, context: LogContext) async throws -> (text: String, lang: String, qualityScore: Double?) {
        await updateProgress(operationId: operationId, fraction: 0.1, step: "Preparing audio segments...")
        let chunks = try await chunkManager.createChunks(from: audioURL, segments: analysis.segments)
        defer { Task { await chunkManager.cleanupChunks(chunks) } }
        await updateProgress(operationId: operationId, fraction: 0.2, step: "Transcribing...")
        let primary = try await transcribeChunksWithLanguage(operationId: operationId, chunks: chunks, baseFraction: 0.2, fractionBudget: 0.6, language: nil, stageLabel: "Transcribing...")
        let aggregator = TranscriptionAggregator()
        let primaryAgg = aggregator.aggregate(primary)
        let primaryText = primaryAgg.text
        await updateProgress(operationId: operationId, fraction: 0.8, step: "Evaluating transcription quality...")
        let primarySummary = summarizeResponse(from: primary, aggregatedText: primaryText)
        let primaryEval = qualityEvaluator.evaluateQuality(primarySummary, text: primaryText)
        var finalText = primaryText
        var finalEval = primaryEval
        var finalLanguage = primaryEval.language
        if qualityEvaluator.shouldTriggerFallback(primaryEval, threshold: languageFallbackConfig.confidenceThreshold) {
            await updateProgress(operationId: operationId, fraction: 0.82, step: "Low confidence. Retrying with English...")
            do {
                let fallback = try await transcribeChunksWithLanguage(operationId: operationId, chunks: chunks, baseFraction: 0.82, fractionBudget: 0.12, language: "en", stageLabel: "Transcribing...")
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
                logger.warning("Fallback chunked transcription failed; using primary result", category: .transcription, context: context, error: error)
            }
        }
        return (finalText, finalLanguage, finalEval.overallScore)
    }
    // Extracted guards and setup
    private func guardIdempotencyAndSilenceHistory(memo: Memo, context: LogContext) throws {
        let preState = transcriptionRepository.getTranscriptionState(for: memo.id)
        if preState.isInProgress { throw TranscriptionError.alreadyInProgress }
        if case .completed = preState { throw TranscriptionError.alreadyCompleted }
        if case .failed(let msg) = preState,
           msg.lowercased().contains("no speech detected") || msg.localizedCaseInsensitiveContains("didn't quite catch") {
            logger.info("Skipping transcription: previous attempt reported no speech", category: .transcription, context: context)
            throw TranscriptionError.noSpeechDetected
        }
    }

    private func guardNoConflictingOperation(memo: Memo, context: LogContext) async throws {
        guard await operationCoordinator.canStartTranscription(for: memo.id) else {
            logger.warning("Cannot start transcription - conflicting operation (recording) active", category: .transcription, context: context, error: nil)
            throw TranscriptionError.conflictingOperation
        }
    }

    private func registerTranscriptionOperation(memo: Memo, context: LogContext) async throws -> UUID {
        guard let operationId = await operationCoordinator.registerOperation(.transcription(memoId: memo.id)) else {
            logger.warning("Transcription rejected by operation coordinator", category: .transcription, context: context, error: nil)
            throw TranscriptionError.systemBusy
        }
        logger.debug("Transcription operation registered with ID: \(operationId)", category: .transcription, context: context)
        return operationId
    }

    private func ensureFileReady(memo: Memo, operationId: UUID) async throws -> URL {
        let audioURL = memo.fileURL
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            await operationCoordinator.failOperation(operationId, errorDescription: TranscriptionError.fileNotFound.errorDescription ?? "Audio file not found")
            throw TranscriptionError.fileNotFound
        }
        _ = await AudioReadiness.ensureReady(url: audioURL, maxWait: 0.8)
        return audioURL
    }

    private func skipIfTooShort(audioURL: URL, memo: Memo, operationId: UUID, context: LogContext) async throws -> Bool {
        do {
            let asset = AVURLAsset(url: audioURL)
            let durationTime = try await asset.load(.duration)
            let totalDurationSec = CMTimeGetSeconds(durationTime)
            if totalDurationSec < 0.8 {
                await MainActor.run {
                    transcriptionRepository.saveTranscriptionState(.failed("Clip too short"), for: memo.id)
                }
                await operationCoordinator.completeOperation(operationId)
                logger.info("Transcription skipped (clip too short)", category: .transcription, context: context)
                return true
            }
        } catch {
            // If duration probing fails, continue; VAD will handle silence/invalid format
        }
        return false
    }

    private func markInProgress(memo: Memo) async {
        await MainActor.run {
            transcriptionRepository.saveTranscriptionState(.inProgress, for: memo.id)
        }
    }
    /// Decide whether to force chunked transcription based on audio characteristics typical of imported files
    private func shouldForceChunking(audioURL: URL) async -> Bool {
        let ext = audioURL.pathExtension.lowercased()
        if ext != "m4a" { return true }
        // Inspect basic format; if stereo or not voice-optimized sample rate, prefer chunking
        do {
            let audioFile = try AudioReadiness.openIfReady(url: audioURL, maxWait: 0.4)
            let sr = audioFile.processingFormat.sampleRate
            let ch = Int(audioFile.processingFormat.channelCount)
            let voiceSR = AppConfiguration.shared.voiceOptimizedSampleRate
            if ch != 1 { return true }
            if abs(sr - voiceSR) > 200 { return true }
        } catch {
            // If we cannot inspect, err on the safe side (no force)
        }
        return false
    }
}
