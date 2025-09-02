import Foundation
import AVFoundation
import WhisperKit

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
        
        // Ensure WhisperKit is initialized with the correct model
        try await ensureWhisperKitInitialized()
        
        guard let whisperKit = self.whisperKit else {
            throw WhisperKitTranscriptionError.notInitialized("WhisperKit instance is nil after initialization")
        }
        
        do {
            // Load and prepare audio
            let audioData = try await loadAudioData(from: url)
            logger.debug("Loaded audio data: \(audioData.count) samples")
            
            // Perform transcription
            let startTime = Date()
            #if canImport(WhisperKit)
            // Build decoding options per v0.13.1 API (task must precede language)
            let options = DecodingOptions(
                task: .transcribe,
                language: language,
                wordTimestamps: false,
                chunkingStrategy: .vad
            )
            let results = try await whisperKit.transcribe(
                audioArray: audioData,
                decodeOptions: options
            )
            #else
            let results = try await whisperKit.transcribe(audioArray: audioData)
            #endif
            let latency = Date().timeIntervalSince(startTime) * 1000 // Convert to milliseconds
            
            // Process results
            let transcriptionText = extractTextFromResults(results)
            let detectedLanguage = extractLanguageFromResults(results)
            let confidence = extractConfidenceFromResults(results)
            
            logger.info("WhisperKit transcription completed in \(Int(latency))ms")
            
            return TranscriptionResponse(
                text: transcriptionText,
                detectedLanguage: detectedLanguage,
                confidence: confidence,
                avgLogProb: nil, // WhisperKit doesn't provide this directly
                duration: latency / 1000.0
            )
            
        } catch {
            logger.error("WhisperKit transcription failed: \(error.localizedDescription)")
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
                    let options = DecodingOptions(
                        task: .transcribe,
                        language: language,
                        wordTimestamps: false,
                        chunkingStrategy: .vad
                    )
                    let segmentResults = try await whisperKit.transcribe(
                        audioArray: segmentData,
                        decodeOptions: options
                    )
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
            return results
            
        } catch {
            logger.error("WhisperKit chunk transcription failed: \(error.localizedDescription)")
            throw WhisperKitTranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - WhisperKit Initialization
    
    private func ensureWhisperKitInitialized() async throws {
        if isInitialized && whisperKit != nil {
            return
        }
        
        logger.info("Initializing WhisperKit with selected model")
        
        let selectedModel = UserDefaults.standard.selectedWhisperModelInfo
        
        // Check if model is already downloaded
        guard (try? WhisperKitInstall.isInstalled(model: selectedModel.id)) == true else {
            throw WhisperKitTranscriptionError.modelNotAvailable("Model \(selectedModel.displayName) is not downloaded. Please download it first.")
        }
        
        do {
            // Initialize with download:false to use existing model only
            let cfg = try WhisperKitInstall.makeConfig(
                model: selectedModel.id, 
                background: true, 
                autoDownload: false  // Don't auto-download during initialization
            )
            whisperKit = try await WhisperKit(cfg)
            
            isInitialized = true
            logger.info("WhisperKit initialized successfully with model: \(selectedModel.displayName)")
            
        } catch {
            logger.error("Failed to initialize WhisperKit: \(error.localizedDescription)")
            throw WhisperKitTranscriptionError.initializationFailed("Failed to initialize WhisperKit with model \(selectedModel.displayName): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Audio Processing
    
    private func loadAudioData(from url: URL) async throws -> [Float] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Load audio file
                    let audioFile = try AVAudioFile(forReading: url)
                    let audioFormat = audioFile.processingFormat
                    let audioFrameCount = AVAudioFrameCount(audioFile.length)
                    
                    // Create buffer
                    guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount) else {
                        continuation.resume(throwing: WhisperKitTranscriptionError.audioProcessingFailed("Failed to create audio buffer"))
                        return
                    }
                    
                    // Read audio data
                    try audioFile.read(into: audioBuffer)
                    
                    // Convert to Float array for WhisperKit
                    guard let channelData = audioBuffer.floatChannelData else {
                        continuation.resume(throwing: WhisperKitTranscriptionError.audioProcessingFailed("Failed to get audio channel data"))
                        return
                    }
                    
                    let frameLength = Int(audioBuffer.frameLength)
                    let audioArray = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
                    
                    // Resample to 16kHz if necessary
                    let resampledAudio = try self.resampleAudioIfNeeded(
                        audioArray,
                        fromSampleRate: audioFormat.sampleRate,
                        toSampleRate: 16000.0
                    )
                    
                    continuation.resume(returning: resampledAudio)
                    
                } catch {
                    continuation.resume(throwing: WhisperKitTranscriptionError.audioProcessingFailed("Failed to load audio: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    nonisolated private func resampleAudioIfNeeded(_ audio: [Float], fromSampleRate: Double, toSampleRate: Double) throws -> [Float] {
        // If sample rates match, no resampling needed
        if abs(fromSampleRate - toSampleRate) < 0.1 {
            return audio
        }
        
        // Simple resampling using linear interpolation
        // For production, consider using a more sophisticated resampling algorithm
        let ratio = fromSampleRate / toSampleRate
        let newLength = Int(Double(audio.count) / ratio)
        var resampled: [Float] = []
        resampled.reserveCapacity(newLength)
        
        for i in 0..<newLength {
            let sourceIndex = Double(i) * ratio
            let lowerIndex = Int(sourceIndex)
            let upperIndex = min(lowerIndex + 1, audio.count - 1)
            let fraction = Float(sourceIndex - Double(lowerIndex))
            
            let sample = audio[lowerIndex] * (1.0 - fraction) + audio[upperIndex] * fraction
            resampled.append(sample)
        }
        
        return resampled
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
