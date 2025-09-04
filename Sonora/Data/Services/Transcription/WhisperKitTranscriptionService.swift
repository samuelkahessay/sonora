import Foundation
import AVFoundation
#if canImport(WhisperKit)
@preconcurrency import WhisperKit
#endif

/// WhisperKit-based local transcription service
@MainActor
final class WhisperKitTranscriptionService: TranscriptionAPI {
    
    // MARK: - Properties
    
    private let downloadManager: ModelDownloadManager
    private let modelProvider: WhisperKitModelProvider
    private let logger = Logger.shared
    private var whisperKit: WhisperKit?
    private var isInitialized = false
    private let initializationQueue = DispatchQueue(label: "whisperkit.initialization", qos: .userInitiated)
    // Optional progress callback for long-running transcriptions (0.0 ... 1.0)
    var onProgress: ((Double) -> Void)?
    
    // MARK: - Initialization
    
    init(downloadManager: ModelDownloadManager, modelProvider: WhisperKitModelProvider) {
        self.downloadManager = downloadManager
        self.modelProvider = modelProvider
        logger.info("WhisperKitTranscriptionService initialized")
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
        logger.info("Starting WhisperKit transcription for: \(url.lastPathComponent)")
        let totalTimer = PerformanceTimer(operation: "WhisperKit transcription", category: .transcription)
        
        // Ensure WhisperKit is initialized with the correct model
        let initTimer = PerformanceTimer(operation: "WhisperKit initialization", category: .transcription)
        try await ensureWhisperKitInitialized()
        _ = initTimer.finish()
        
        guard let whisperKit = self.whisperKit else {
            throw WhisperKitTranscriptionError.notInitialized("WhisperKit instance is nil after initialization")
        }
        
        do {
            // Load and prepare audio
            let audioTimer = PerformanceTimer(operation: "Audio loading", category: .audio)
            let audioData = try await loadAudioData(from: url)
            _ = audioTimer.finish(additionalInfo: "\(audioData.count) samples")
            
            // Perform transcription
            let transcribeTimer = PerformanceTimer(operation: "WhisperKit transcribe", category: .transcription)
            #if canImport(WhisperKit)
            let options = buildDecodingOptions(language: language)
            // Attempt to use progress-enabled API if available
            let results: [TranscriptionResult]
            #if compiler(>=6)
            results = try await whisperKit.transcribe(audioArray: audioData, decodeOptions: options) { @Sendable [weak self] _ in
                guard let self = self else { return nil }
                Task { @MainActor in
                    let fraction = self.whisperKit?.progress.fractionCompleted ?? 0.0
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
            
            logger.info("WhisperKit transcription completed")
            
            let totalDuration = totalTimer.finish()
            let response = TranscriptionResponse(
                text: transcriptionText,
                detectedLanguage: detectedLanguage,
                confidence: confidence,
                avgLogProb: nil, // WhisperKit doesn't provide this directly
                duration: totalDuration
            )

            if AppConfiguration.shared.releaseLocalModelAfterTranscription {
                await whisperKit.unloadModels()
                self.isInitialized = false
                self.whisperKit = nil
                logger.info("WhisperKit models unloaded after transcription (per setting)")
            }

            return response
            
        } catch {
            logger.error("WhisperKit transcription failed",
                        category: .transcription,
                        context: LogContext(additionalInfo: ["audioFile": url.lastPathComponent]),
                        error: error)
            throw WhisperKitTranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }
    
    func transcribeChunks(segments: [VoiceSegment], audioURL: URL) async throws -> [ChunkTranscriptionResult] {
        return try await transcribeChunks(segments: segments, audioURL: audioURL, language: nil)
    }
    
    func transcribeChunks(segments: [VoiceSegment], audioURL: URL, language: String?) async throws -> [ChunkTranscriptionResult] {
        logger.info("Starting WhisperKit chunk transcription for \(segments.count) segments")
        
        // Ensure WhisperKit is initialized
        try await ensureWhisperKitInitialized()
        
        guard let whisperKit = self.whisperKit else {
            throw WhisperKitTranscriptionError.notInitialized("WhisperKit instance is nil after initialization")
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
                            let fraction = self.whisperKit?.progress.fractionCompleted ?? 0.0
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
                    logger.warning("Failed to transcribe segment \(segment.startTime)-\(segment.endTime): \(error)")
                    
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
            
            logger.info("WhisperKit chunk transcription completed: \(results.count) segments processed")
            if AppConfiguration.shared.releaseLocalModelAfterTranscription {
                await whisperKit.unloadModels()
                self.isInitialized = false
                self.whisperKit = nil
                logger.info("WhisperKit models unloaded after chunk transcription (per setting)")
            }
            return results
            
        } catch {
            logger.error("WhisperKit chunk transcription failed",
                        category: .transcription,
                        context: LogContext(additionalInfo: ["audioFile": audioURL.lastPathComponent, "segmentCount": "\(segments.count)"]),
                        error: error)
            throw WhisperKitTranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - WhisperKit Initialization
    
    private func ensureWhisperKitInitialized() async throws {
        if isInitialized && whisperKit != nil {
            return
        }
        
        logger.info("Initializing WhisperKit with selected model")
        
        var selectedModel = UserDefaults.standard.selectedWhisperModelInfo

        // Resolve concrete folder for the selected model, or fall back to any resolvable installed model
        var resolvedFolder: URL? = modelProvider.installedModelFolder(id: selectedModel.id)
        if resolvedFolder == nil {
            let installedIds = modelProvider.installedModelIds()
            if let (fallbackId, folder) = installedIds.compactMap({ id -> (String, URL)? in
                if let url = self.modelProvider.installedModelFolder(id: id) { return (id, url) }
                return nil
            }).first {
                logger.warning("Selected Whisper model not installed or folder not found: \(selectedModel.id). Falling back to installed model: \(fallbackId)")
                UserDefaults.standard.selectedWhisperModel = fallbackId
                resolvedFolder = folder
                if let info = WhisperModelInfo.model(withId: fallbackId) {
                    selectedModel = info
                } else {
                    selectedModel = WhisperModelInfo(
                        id: fallbackId,
                        displayName: fallbackId,
                        size: "",
                        description: "Installed model",
                        speedRating: .medium,
                        accuracyRating: .medium
                    )
                }
            }
        }

        guard let modelFolder = resolvedFolder else {
            throw WhisperKitTranscriptionError.modelNotAvailable("No installed WhisperKit models found or model folder not resolvable. Please download one in Settings.")
        }

        do {
            try await initializeWhisperKitWithFolder(modelId: selectedModel.id, folder: modelFolder, allowRedownload: true)
            isInitialized = true
            // Enhanced init logs: resolved folder and contents
            logger.info("WhisperKit resolved model folder: \(modelFolder.path)")
            if let items = try? FileManager.default.contentsOfDirectory(at: modelFolder, includingPropertiesForKeys: nil) {
                let names = items.map { $0.lastPathComponent }
                logger.info("WhisperKit model folder contents (\(names.count)): \(names.joined(separator: ", "))")
            } else {
                logger.warning("WhisperKit: Unable to list model folder contents at: \(modelFolder.path)")
            }
            logger.info("WhisperKit initialized successfully with model: \(selectedModel.displayName) at \(modelFolder.path)")
        } catch {
            logger.error("Failed to initialize WhisperKit: \(error.localizedDescription)")
            throw WhisperKitTranscriptionError.initializationFailed("Failed to initialize WhisperKit with model \(selectedModel.displayName): \(error.localizedDescription)")
        }
    }

    /// Initialize WhisperKit, set modelFolder, prewarm and load. If prewarm fails and allowed, re-download once and retry.
    private func initializeWhisperKitWithFolder(modelId: String, folder: URL, allowRedownload: Bool) async throws {
        // Initialize without auto-loading or downloading; we will set the folder explicitly
        whisperKit = try await WhisperKit(
            prewarm: false,
            load: false,
            download: false
        )

        guard let wk = whisperKit else {
            throw WhisperKitTranscriptionError.initializationFailed("WhisperKit instance is nil after creation")
        }

        // Set the actual model folder
        wk.modelFolder = folder

        do {
            try await wk.prewarmModels()
        } catch {
            logger.warning("Prewarm failed for \(modelId): \(error.localizedDescription)")
            // Retry once with a fresh download if allowed
            guard allowRedownload else { throw error }
            do {
                logger.info("Re-downloading model \(modelId) due to prewarm failure")
                try await modelProvider.download(id: modelId, progress: { _ in })
                // Resolve folder again after download
                guard let refreshedFolder = modelProvider.installedModelFolder(id: modelId) else {
                    throw WhisperKitTranscriptionError.modelNotAvailable("Model folder not found after re-download for \(modelId)")
                }
                // Retry init with the refreshed folder, without further redownload
                try await initializeWhisperKitWithFolder(modelId: modelId, folder: refreshedFolder, allowRedownload: false)
                return
            } catch {
                logger.error("Re-download failed for \(modelId): \(error.localizedDescription)")
                throw error
            }
        }
        // Validate tokenizer assets with a broader heuristic; if missing, re-download once, then retry
        var hasAssets = false
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            while let obj = enumerator.nextObject() as? URL {
                let n = obj.lastPathComponent.lowercased()
                if n == "tokenizer.json" || n == "tokenizer.model" || n == "vocabulary.json" || n.contains("merges") || n.contains("vocab") || n.contains("tokenizer") {
                    hasAssets = true
                    break
                }
            }
        }
        if !hasAssets {
            logger.warning("Tokenizer assets missing for \(modelId) at \(folder.path); re-downloading")
            guard allowRedownload else {
                throw WhisperKitTranscriptionError.initializationFailed("Tokenizer assets missing; re-download required")
            }
            try await modelProvider.download(id: modelId, progress: { _ in })
            guard let refreshedFolder = modelProvider.installedModelFolder(id: modelId) else {
                throw WhisperKitTranscriptionError.modelNotAvailable("Model folder not found after re-download for \(modelId)")
            }
            try await initializeWhisperKitWithFolder(modelId: modelId, folder: refreshedFolder, allowRedownload: false)
            return
        }

        try await wk.loadModels()
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
    
    // Linear resampler removed in favor of AVAudioConverter-based path above.
    
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
    /// Extend here with temperature/thresholds when supported by the SDK version in use.
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
