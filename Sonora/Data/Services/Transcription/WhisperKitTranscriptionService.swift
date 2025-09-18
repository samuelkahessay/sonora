import Foundation
@preconcurrency import AVFoundation
@preconcurrency import AVFAudio
import UIKit
#if canImport(WhisperKit)
@preconcurrency import WhisperKit
#endif

private final class NonSendableBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

/// WhisperKit-based local transcription service
@MainActor
final class WhisperKitTranscriptionService: TranscriptionAPI {
    
    // MARK: - Properties
    
    private enum Constants {
        static let transcriptionTimeout: TimeInterval = 60
    }

    private let downloadManager: ModelDownloadManager
    private let modelProvider: WhisperKitModelProvider
    private let modelManager: WhisperKitModelManagerProtocol
    private let modelRouter: AdaptiveModelRouterProtocol
    private let logger = Logger.shared
    
    // Removed: whisperKit, isInitialized, initializationQueue - handled by modelManager now
    
    var onProgress: ((Double) -> Void)?
    
    // MARK: - Initialization
    
    init(downloadManager: ModelDownloadManager, modelProvider: WhisperKitModelProvider, modelManager: WhisperKitModelManagerProtocol? = nil, modelRouter: AdaptiveModelRouterProtocol? = nil) {
        self.downloadManager = downloadManager
        self.modelProvider = modelProvider
        self.modelManager = modelManager ?? WhisperKitModelManager(modelProvider: modelProvider)
        self.modelRouter = modelRouter ?? AdaptiveModelRouter(modelProvider: modelProvider)
        logger.info("WhisperKitTranscriptionService initialized with model manager and adaptive router")
    }
    
    convenience init(downloadManager: ModelDownloadManager) {
        self.init(downloadManager: downloadManager, modelProvider: WhisperKitModelProvider())
    }
    
    // MARK: - TranscriptionAPI Conformance
    
    func transcribe(url: URL) async throws -> String {
        let response = try await transcribe(url: url, language: nil)
        return response.text
    }
    
    func transcribe(url: URL, language: String?) async throws -> TranscriptionResponse {
        return try await AIModelCoordinator.shared.acquireTranscribing { [weak self] in
            guard let self = self else { throw WhisperKitTranscriptionError.transcriptionFailed("Service deallocated") }
            await AIModelCoordinator.shared.registerUnloadHandlers(unloadWhisper: { [weak self] in self?.modelManager.unloadModel() })
            self.logger.info("🎤 Starting adaptive WhisperKit transcription for: \(url.lastPathComponent)")
            let totalTimer = PerformanceTimer(operation: "WhisperKit transcription", category: .transcription)

            // Adaptive model routing
            let routingTimer = PerformanceTimer(operation: "Model routing", category: .transcription)
            let routingContext = try await self.buildRoutingContext(audioURL: url)
            let routingDecision = self.modelRouter.selectModel(for: routingContext)
            _ = routingTimer.finish(additionalInfo: "Selected: \(routingDecision.selectedModel.displayName)")

            // Use model manager with selected model
            let initTimer = PerformanceTimer(operation: "WhisperKit model retrieval", category: .transcription)
            let previousModel = UserDefaults.standard.selectedWhisperModel
            UserDefaults.standard.selectedWhisperModel = routingDecision.selectedModel.id
            let whisperKit: WhisperKit
            do {
                guard let loadedKit = try await self.modelManager.getWhisperKit() else {
                    UserDefaults.standard.selectedWhisperModel = previousModel
                    throw WhisperKitTranscriptionError.initializationFailed("WhisperKit not available from model manager")
                }
                whisperKit = loadedKit
            } catch let managerError as WhisperKitModelManagerError {
                UserDefaults.standard.selectedWhisperModel = previousModel
                throw self.mapModelManagerError(managerError)
            }
            _ = initTimer.finish()

            do {
                // Load and prepare audio
                let audioTimer = PerformanceTimer(operation: "Audio loading", category: .audio)
                let audioData = try await self.loadAudioData(from: url)
                _ = audioTimer.finish(additionalInfo: "\(audioData.count) samples")

                // Perform transcription
                let transcribeTimer = PerformanceTimer(operation: "WhisperKit transcribe", category: .transcription)
                #if canImport(WhisperKit)
                let options = self.buildDecodingOptions(language: language)
                let results: [TranscriptionResult]
                do {
                    #if compiler(>=6)
                    results = try await withTimeout(seconds: Constants.transcriptionTimeout, operationDescription: "WhisperKit transcription") {
                        try await whisperKit.transcribe(audioArray: audioData, decodeOptions: options) { @Sendable [weak self] _ in
                            guard let self = self else { return nil }
                            Task { @MainActor in
                                let fraction = whisperKit.progress.fractionCompleted
                                self.onProgress?(fraction)
                            }
                            return Task.isCancelled ? false : nil
                        }
                    }
                    #else
                    results = try await withTimeout(seconds: Constants.transcriptionTimeout, operationDescription: "WhisperKit transcription") {
                        try await whisperKit.transcribe(
                            audioArray: audioData,
                            decodeOptions: options
                        )
                    }
                    #endif
                } catch let timeout as AsyncTimeoutError {
                    throw WhisperKitTranscriptionError.timeout(timeout.message)
                }
                #else
                let results = try await withTimeout(seconds: Constants.transcriptionTimeout, operationDescription: "WhisperKit transcription") {
                    try await whisperKit.transcribe(audioArray: audioData)
                }
                #endif
                _ = transcribeTimer.finish()

                // Process results
                let transcriptionText = self.extractTextFromResults(results)
                let detectedLanguage = self.extractLanguageFromResults(results)
                let confidence = self.extractConfidenceFromResults(results)

                self.logger.info("🎤 WhisperKit transcription completed")

                let totalDuration = totalTimer.finish()
                let response = TranscriptionResponse(
                    text: transcriptionText,
                    detectedLanguage: detectedLanguage,
                    confidence: confidence,
                    avgLogProb: nil,
                    duration: totalDuration
                )

                // Restore previous model selection
                UserDefaults.standard.selectedWhisperModel = previousModel

                // Optional retry with larger model
                if self.modelRouter.shouldRetryWithLargerModel(result: response, context: routingContext),
                   let largerModel = routingDecision.fallbackModels.first(where: { self.modelSizeOrder($0.id) > self.modelSizeOrder(routingDecision.selectedModel.id) }) {
                    self.logger.info("🎯 Retrying with larger model: \(largerModel.displayName)")
                    self.modelManager.unloadModel()
                    UserDefaults.standard.selectedWhisperModel = largerModel.id
                    if let retryWhisperKit = try? await self.modelManager.getWhisperKit() {
                        let retryOptions = self.buildDecodingOptions(language: language)
                        if let retryResults = try? await retryWhisperKit.transcribe(audioArray: audioData, decodeOptions: retryOptions),
                           let retryText = retryResults.first?.text,
                           !retryText.isEmpty {
                            let retryResponse = TranscriptionResponse(
                                text: retryText,
                                detectedLanguage: detectedLanguage,
                                confidence: self.extractConfidenceFromResults(retryResults),
                                avgLogProb: nil,
                                duration: totalDuration
                            )
                            self.logger.info("🎯 Retry with \(largerModel.displayName) succeeded")
                            UserDefaults.standard.selectedWhisperModel = previousModel
                            self.modelManager.unloadModel()
                            return retryResponse
                        }
                    }
                    UserDefaults.standard.selectedWhisperModel = previousModel
                }

                self.modelManager.unloadModel()
                self.logger.info("🎤 WhisperKit model unloaded after transcription")
                return response
            } catch {
                self.logger.error("🎤 WhisperKit transcription failed",
                            category: .transcription,
                            context: LogContext(additionalInfo: ["audioFile": url.lastPathComponent]),
                            error: error)
                UserDefaults.standard.selectedWhisperModel = previousModel
                self.modelManager.unloadModel()
                if let whisperError = error as? WhisperKitTranscriptionError {
                    throw whisperError
                }
                throw WhisperKitTranscriptionError.transcriptionFailed(error.localizedDescription)
            }
        }
    }
    
    // Consolidated surface: callers perform chunking and call transcribe(url:language:) per chunk.
    
    // MARK: - Audio Processing
    
private func loadAudioData(from url: URL) async throws -> [Float] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Stream-convert the source file to Float32 mono @ 16kHz using AVAudioConverter
                    let file = try AVAudioFile(forReading: url)
                    let srcFormat = file.processingFormat
                    guard let dstFormat = AVAudioFormat(
                        commonFormat: .pcmFormatFloat32,
                        sampleRate: 16000.0,
                        channels: 1,
                        interleaved: false
                    ) else {
                        continuation.resume(throwing: WhisperKitTranscriptionError.audioProcessingFailed("Failed to create destination audio format"))
                        return
                    }
                    guard let converter = AVAudioConverter(from: srcFormat, to: dstFormat) else {
                        continuation.resume(throwing: WhisperKitTranscriptionError.audioProcessingFailed("Failed to create audio converter"))
                        return
                    }

                    let srcCapacity: AVAudioFrameCount = 4096
                    let srcBufferBox = NonSendableBox(AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: srcCapacity)!)
                    let outChunk: AVAudioFrameCount = 1024
                    let finished = ManagedCriticalState(false)
                    var output: [Float] = []
                    output.reserveCapacity(Int(file.length))

                    while finished.withLock({ !$0 }) {
                        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: outChunk) else {
                            continuation.resume(throwing: WhisperKitTranscriptionError.audioProcessingFailed("Failed to allocate output buffer"))
                            return
                        }
                        var convError: NSError?
                        let status = converter.convert(to: outBuffer, error: &convError, withInputFrom: { requestedPackets, outStatus in
                            if finished.withLock({ $0 }) {
                                outStatus.pointee = .noDataNow
                                return nil
                            }
                            let framesToRead = min(srcCapacity, requestedPackets)
                            let srcBuffer = srcBufferBox.value
                            do {
                                try file.read(into: srcBuffer, frameCount: framesToRead)
                            } catch {
                                finished.withLock { $0 = true }
                                outStatus.pointee = .endOfStream
                                return nil
                            }
                            if srcBuffer.frameLength == 0 {
                                finished.withLock { $0 = true }
                                outStatus.pointee = .endOfStream
                                return nil
                            }
                            outStatus.pointee = .haveData
                            return srcBuffer
                        })
                        if status == .error {
                            continuation.resume(throwing: WhisperKitTranscriptionError.audioProcessingFailed(convError?.localizedDescription ?? "Conversion error"))
                            return
                        }
                        if status == .endOfStream {
                            finished.withLock { $0 = true }
                        }
                        let frames = Int(outBuffer.frameLength)
                        if frames > 0, let ch = outBuffer.floatChannelData {
                            output.append(contentsOf: UnsafeBufferPointer(start: ch[0], count: frames))
                        } else if status == .endOfStream || finished.withLock({ $0 }) {
                            break
                        }
                    }

                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: WhisperKitTranscriptionError.audioProcessingFailed("Failed to load audio: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    // Removed chunk extraction helper; not needed with consolidated API.
    
    // MARK: - Result Processing
    
    private func extractTextFromResults(_ results: [TranscriptionResult]) -> String {
        return results.compactMap { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractLanguageFromResults(_ results: [TranscriptionResult]) -> String? {
        return results.first?.language
    }
    
    private func extractConfidenceFromResults(_ results: [TranscriptionResult]) -> Double? {
        // WhisperKit may not provide direct confidence scores
        // Return a reasonable default for now
        return 0.8
    }

    #if canImport(WhisperKit)
    /// Build decoding options with language mapping and VAD chunking.
    private func buildDecodingOptions(language: String?) -> DecodingOptions {
        let mapped = mapLanguageCode(language) ?? AppConfiguration.shared.preferredTranscriptionLanguage
        let timestamps = AppConfiguration.shared.whisperWordTimestamps
        let chunkingRaw = AppConfiguration.shared.whisperChunkingStrategy
        let chunking: ChunkingStrategy = (chunkingRaw == "none") ? .none : .vad
        return DecodingOptions(
            task: .transcribe,
            language: mapped,
            wordTimestamps: timestamps,
            chunkingStrategy: chunking
        )
    }

    /// Map human-readable language names to ISO codes expected by WhisperKit.
    private func mapLanguageCode(_ input: String?) -> String? {
        guard let raw = input?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let lower = raw.lowercased()
        // If already an ISO-like code (e.g., "en", "en-us"), normalize
        if lower.range(of: "^[a-z]{2}(-[a-z]{2})?$", options: .regularExpression) != nil {
            return lower
        }
        let map: [String: String] = [
            "english": "en",
            "spanish": "es",
            "french": "fr",
            "german": "de",
            "italian": "it",
            "portuguese": "pt",
            "japanese": "ja",
            "korean": "ko",
            "chinese": "zh"
        ]
        return map[lower] ?? lower
    }
    #endif
    
    // MARK: - Adaptive Routing Helpers
    
    /// Build routing context from audio file and system state
    private func buildRoutingContext(audioURL: URL) async throws -> RoutingContext {
        // Get audio duration
        let asset = AVURLAsset(url: audioURL)
        let duration = try await asset.load(.duration).seconds
        
        // Analyze complexity
        let complexity = await AudioComplexityAnalyzer.analyzeComplexity(audioURL: audioURL)
        
        // Get system conditions
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let batteryLevel = device.batteryLevel
        let thermalState = ProcessInfo.processInfo.thermalState
        
        // Get available models
        let availableModels = modelProvider.installedModelIds().filter { modelProvider.isModelValid(id: $0) }
        
        // Determine network condition (simplified)
        let networkCondition: RoutingContext.NetworkCondition = .wifi // Simplified for now
        
        return RoutingContext(
            audioURL: audioURL,
            audioDurationSeconds: duration,
            estimatedComplexity: complexity,
            userPreference: UserDefaults.standard.selectedWhisperModelInfo,
            availableModels: availableModels,
            batteryLevel: batteryLevel,
            thermalState: thermalState,
            networkCondition: networkCondition
        )
    }
    
    /// Get model size ordering for comparison
    private func modelSizeOrder(_ modelId: String) -> Int {
        switch modelId {
        case let id where id.contains("tiny"): return 1
        case let id where id.contains("base"): return 2
        case let id where id.contains("small"): return 3
        case let id where id.contains("medium"): return 4
        default: return 0
        }
    }

    private func mapModelManagerError(_ error: WhisperKitModelManagerError) -> WhisperKitTranscriptionError {
        switch error {
        case .whisperKitUnavailable(let message):
            return .initializationFailed(message)
        case .modelNotFound(let message), .modelInvalid(let message):
            return .modelNotAvailable(message)
        case .loadFailed(let message), .prewarmFailed(let message):
            return .initializationFailed(message)
        case .loadTimeout(let message):
            return .timeout(message)
        }
    }
}

// MARK: - TranscriptionProgressReporting
extension WhisperKitTranscriptionService: TranscriptionProgressReporting {
    @MainActor func setProgressHandler(_ handler: @escaping (Double) -> Void) {
        self.onProgress = handler
    }
    @MainActor func clearProgressHandler() {
        self.onProgress = nil
    }
}

// MARK: - Error Types

enum WhisperKitTranscriptionError: LocalizedError {
    case notInitialized(String)
    case initializationFailed(String)
    case modelNotAvailable(String)
    case transcriptionFailed(String)
    case audioProcessingFailed(String)
    case timeout(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized(let message):
            return "WhisperKit not initialized: \(message)"
        case .initializationFailed(let message):
            return "WhisperKit initialization failed: \(message)"
        case .modelNotAvailable(let message):
            return "Model not available: \(message)"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .audioProcessingFailed(let message):
            return "Audio processing failed: \(message)"
        case .timeout(let message):
            return "Transcription timed out: \(message)"
        }
    }
}
