import Foundation
import AVFoundation
import UIKit
#if canImport(WhisperKit)
@preconcurrency import WhisperKit
#endif

/// WhisperKit-based local transcription service
@MainActor
final class WhisperKitTranscriptionService: TranscriptionAPI {
    
    // MARK: - Properties
    
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
        logger.info("🎤 Starting adaptive WhisperKit transcription for: \(url.lastPathComponent)")
        let totalTimer = PerformanceTimer(operation: "WhisperKit transcription", category: .transcription)
        
        // Adaptive model routing
        let routingTimer = PerformanceTimer(operation: "Model routing", category: .transcription)
        let routingContext = try await buildRoutingContext(audioURL: url)
        let routingDecision = modelRouter.selectModel(for: routingContext)
        _ = routingTimer.finish(additionalInfo: "Selected: \(routingDecision.selectedModel.displayName)")
        
        // Use model manager with selected model
        let initTimer = PerformanceTimer(operation: "WhisperKit model retrieval", category: .transcription)
        // First, ensure the optimal model is selected in UserDefaults for model manager
        let previousModel = UserDefaults.standard.selectedWhisperModel
        UserDefaults.standard.selectedWhisperModel = routingDecision.selectedModel.id
        
        guard let whisperKit = try await modelManager.getWhisperKit() else {
            // Restore previous model selection on failure
            UserDefaults.standard.selectedWhisperModel = previousModel
            throw WhisperKitTranscriptionError.initializationFailed("WhisperKit not available from model manager")
        }
        _ = initTimer.finish()
        
        do {
            // Load and prepare audio
            let audioTimer = PerformanceTimer(operation: "Audio loading", category: .audio)
            let audioData = try await loadAudioData(from: url)
            _ = audioTimer.finish(additionalInfo: "\(audioData.count) samples")
            
            // Perform transcription
            let transcribeTimer = PerformanceTimer(operation: "WhisperKit transcribe", category: .transcription)
            #if canImport(WhisperKit)
            let options = buildDecodingOptions(language: language)
            // Use progress-enabled API
            let results: [TranscriptionResult]
            #if compiler(>=6)
            results = try await whisperKit.transcribe(audioArray: audioData, decodeOptions: options) { @Sendable [weak self] _ in
                guard let self = self else { return nil }
                Task { @MainActor in
                    let fraction = whisperKit.progress.fractionCompleted
                    self.onProgress?(fraction)
                }
                return Task.isCancelled ? false : nil
            }
            #else
            results = try await whisperKit.transcribe(
                audioArray: audioData,
                decodeOptions: options
            )
            #endif
            #else
            let results = try await whisperKit.transcribe(audioArray: audioData)
            #endif
            _ = transcribeTimer.finish()
            
            // Process results
            let transcriptionText = extractTextFromResults(results)
            let detectedLanguage = extractLanguageFromResults(results)
            let confidence = extractConfidenceFromResults(results)
            
            logger.info("🎤 WhisperKit transcription completed")
            
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
            
            // Check if we should retry with a larger model
            if modelRouter.shouldRetryWithLargerModel(result: response, context: routingContext),
               let largerModel = routingDecision.fallbackModels.first(where: { 
                   modelSizeOrder($0.id) > modelSizeOrder(routingDecision.selectedModel.id) 
               }) {
                
                logger.info("🎯 Retrying with larger model: \(largerModel.displayName)")
                
                // Unload current model first
                self.modelManager.unloadModel()
                
                // Retry with larger model
                UserDefaults.standard.selectedWhisperModel = largerModel.id
                
                if let retryWhisperKit = try? await modelManager.getWhisperKit() {
                    let retryOptions = buildDecodingOptions(language: language)
                    if let retryResults = try? await retryWhisperKit.transcribe(audioArray: audioData, decodeOptions: retryOptions),
                       let retryText = retryResults.first?.text,
                       !retryText.isEmpty {
                        
                        let retryResponse = TranscriptionResponse(
                            text: retryText,
                            detectedLanguage: detectedLanguage,
                            confidence: extractConfidenceFromResults(retryResults),
                            avgLogProb: nil,
                            duration: totalDuration
                        )
                        
                        logger.info("🎯 Retry with \(largerModel.displayName) succeeded")
                        UserDefaults.standard.selectedWhisperModel = previousModel
                        self.modelManager.unloadModel()
                        return retryResponse
                    }
                }
                
                // Retry failed, restore previous model
                UserDefaults.standard.selectedWhisperModel = previousModel
            }

            // Key optimization: Unload model after transcription using model manager
            self.modelManager.unloadModel()
            logger.info("🎤 WhisperKit model unloaded after transcription")

            return response
            
        } catch {
            logger.error("🎤 WhisperKit transcription failed",
                        category: .transcription,
                        context: LogContext(additionalInfo: ["audioFile": url.lastPathComponent]),
                        error: error)
            
            // Restore previous model selection on error
            UserDefaults.standard.selectedWhisperModel = previousModel
            
            // Still unload model on error to free memory
            self.modelManager.unloadModel()
            throw WhisperKitTranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }
    
    func transcribeChunks(segments: [VoiceSegment], audioURL: URL) async throws -> [ChunkTranscriptionResult] {
        return try await transcribeChunks(segments: segments, audioURL: audioURL, language: nil)
    }
    
    func transcribeChunks(segments: [VoiceSegment], audioURL: URL, language: String?) async throws -> [ChunkTranscriptionResult] {
        logger.info("🎤 Starting WhisperKit chunk transcription for \(segments.count) segments")
        
        // Use model manager for initialization
        guard let whisperKit = try await modelManager.getWhisperKit() else {
            throw WhisperKitTranscriptionError.initializationFailed("WhisperKit not available from model manager")
        }
        
        var results: [ChunkTranscriptionResult] = []
        
        do {
            // Load full audio file
            let audioData = try await loadAudioData(from: audioURL)
            let sampleRate = 16000.0 // WhisperKit expects 16kHz audio
            
            for segment in segments {
                do {
                    // Extract audio segment
                    let startSample = Int(segment.startTime * sampleRate)
                    let endSample = Int(segment.endTime * sampleRate)
                    let segmentData = extractAudioSegment(from: audioData, startSample: startSample, endSample: endSample)
                    
                    // Transcribe segment
                    #if canImport(WhisperKit)
                    let options = buildDecodingOptions(language: language)
                    let segmentResults: [TranscriptionResult]
                    #if compiler(>=6)
                    segmentResults = try await whisperKit.transcribe(audioArray: segmentData, decodeOptions: options) { @Sendable [weak self] _ in
                        guard let self = self else { return nil }
                        Task { @MainActor in
                            let fraction = whisperKit.progress.fractionCompleted
                            self.onProgress?(fraction)
                        }
                        return Task.isCancelled ? false : nil
                    }
                    #else
                    segmentResults = try await whisperKit.transcribe(
                        audioArray: segmentData,
                        decodeOptions: options
                    )
                    #endif
                    #else
                    let segmentResults = try await whisperKit.transcribe(audioArray: segmentData)
                    #endif
                    
                    let transcriptionText = extractTextFromResults(segmentResults)
                    let detectedLanguage = extractLanguageFromResults(segmentResults)
                    let confidence = extractConfidenceFromResults(segmentResults)
                    
                    let response = TranscriptionResponse(
                        text: transcriptionText,
                        detectedLanguage: detectedLanguage,
                        confidence: confidence,
                        avgLogProb: nil,
                        duration: segment.endTime - segment.startTime
                    )
                    
                    results.append(ChunkTranscriptionResult(segment: segment, response: response))
                    
                } catch {
                    logger.warning("🎤 Failed to transcribe segment \(segment.startTime)-\(segment.endTime): \(error)")
                    
                    // Create empty result for failed segment
                    let response = TranscriptionResponse(
                        text: "",
                        detectedLanguage: nil,
                        confidence: 0.0,
                        avgLogProb: nil,
                        duration: segment.endTime - segment.startTime
                    )
                    results.append(ChunkTranscriptionResult(segment: segment, response: response))
                }
            }
            
            logger.info("🎤 WhisperKit chunk transcription completed: \(results.count) segments processed")
            
            // Unload model after all chunks are processed
            self.modelManager.unloadModel()
            logger.info("🎤 WhisperKit model unloaded after chunk transcription")
            
            return results
            
        } catch {
            logger.error("🎤 WhisperKit chunk transcription failed",
                        category: .transcription,
                        context: LogContext(additionalInfo: ["audioFile": audioURL.lastPathComponent, "segmentCount": "\(segments.count)"]),
                        error: error)
            
            // Still unload model on error
            self.modelManager.unloadModel()
            throw WhisperKitTranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }
    
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
                    let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: srcCapacity)!
                    let outChunk: AVAudioFrameCount = 1024
                    var finished = false
                    var output: [Float] = []
                    output.reserveCapacity(Int(file.length))

                    while !finished {
                        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: outChunk) else {
                            continuation.resume(throwing: WhisperKitTranscriptionError.audioProcessingFailed("Failed to allocate output buffer"))
                            return
                        }
                        var convError: NSError?
                        let status = converter.convert(to: outBuffer, error: &convError, withInputFrom: { requestedPackets, outStatus in
                            if finished {
                                outStatus.pointee = .noDataNow
                                return nil
                            }
                            let framesToRead = min(srcCapacity, requestedPackets)
                            do {
                                try file.read(into: srcBuffer, frameCount: framesToRead)
                            } catch {
                                finished = true
                                outStatus.pointee = .endOfStream
                                return nil
                            }
                            if srcBuffer.frameLength == 0 {
                                finished = true
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
                        let frames = Int(outBuffer.frameLength)
                        if frames > 0, let ch = outBuffer.floatChannelData {
                            output.append(contentsOf: UnsafeBufferPointer(start: ch[0], count: frames))
                        } else if status == .endOfStream || finished {
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
    
    private func extractAudioSegment(from audioData: [Float], startSample: Int, endSample: Int) -> [Float] {
        let safeStart = max(0, startSample)
        let safeEnd = min(audioData.count, endSample)
        
        guard safeStart < safeEnd else {
            return []
        }
        
        return Array(audioData[safeStart..<safeEnd])
    }
    
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
        }
    }
}
