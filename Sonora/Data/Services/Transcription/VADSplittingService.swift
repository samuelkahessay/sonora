import Foundation
@preconcurrency import AVFoundation
import Accelerate

// MARK: - Voice Activity Types

struct VoiceSegment: Equatable, Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Double // 0.0 – 1.0 (derived from average dB above threshold)
}

struct VADConfig: Sendable {
    /// Energy threshold below which audio is considered silence (in dBFS)
    let silenceThreshold: Float
    /// Minimum duration for a voiced segment to be emitted
    let minSpeechDuration: TimeInterval
    /// Minimum consecutive silence to finalize a voiced segment
    let minSilenceGap: TimeInterval
    /// Window size in frames used for RMS computation
    let windowSize: Int

    init(
        silenceThreshold: Float = -45.0,
        minSpeechDuration: TimeInterval = 0.5,
        minSilenceGap: TimeInterval = 0.3,
        windowSize: Int = 1024
    ) {
        self.silenceThreshold = silenceThreshold
        self.minSpeechDuration = minSpeechDuration
        self.minSilenceGap = minSilenceGap
        self.windowSize = max(256, windowSize)
    }
}

// MARK: - Errors

enum VADError: LocalizedError {
    case cannotOpenFile(String)
    case unsupportedFormat(String)
    case cannotCreateConverter
    case readFailed(String)
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .cannotOpenFile(let path):
            return "Unable to open audio file: \(path)"
        case .unsupportedFormat(let desc):
            return "Unsupported audio format: \(desc)"
        case .cannotCreateConverter:
            return "Unable to create audio converter"
        case .readFailed(let reason):
            return "Failed to read audio: \(reason)"
        case .conversionFailed(let reason):
            return "Audio conversion failed: \(reason)"
        }
    }
}

// MARK: - Protocol

protocol VADSplittingService: Sendable {
    func detectVoiceSegments(audioURL: URL) async throws -> [VoiceSegment]
}

// MARK: - Implementation (Energy-based VAD)

final class DefaultVADSplittingService: VADSplittingService, @unchecked Sendable {
    private let config: VADConfig

    init(config: VADConfig = VADConfig()) {
        self.config = config
    }

    func detectVoiceSegments(audioURL: URL) async throws -> [VoiceSegment] {
        // Open file (bounded retry)
        let file: AVAudioFile
        do {
            file = try AudioReadiness.openIfReady(url: audioURL, maxWait: 0.5)
        } catch {
            throw VADError.cannotOpenFile(audioURL.lastPathComponent)
        }

        // Prepare conversion to mono Float32
        let srcFormat = file.processingFormat
        guard let dstFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: srcFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw VADError.unsupportedFormat("Cannot create destination format")
        }

        guard let converter = AVAudioConverter(from: srcFormat, to: dstFormat) else {
            throw VADError.cannotCreateConverter
        }

        // Source read buffer and output (window-sized) buffer
        let srcReadCapacity: AVAudioFrameCount = 4096
        let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: srcReadCapacity)!

        let windowFrames = AVAudioFrameCount(config.windowSize)
        var finished = false
        var positionFrames: AVAudioFramePosition = 0
        let sampleRate = dstFormat.sampleRate

        // State for segment detection
        var segments: [VoiceSegment] = []
        var isSpeech = false
        var segmentStartTime: Double = 0
        var segmentDBSum: Double = 0
        var segmentWindows: Int = 0
        var silenceAccum: Double = 0

        while !finished {
            guard let outBuffer = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: windowFrames) else {
                throw VADError.conversionFailed("Cannot allocate output buffer")
            }

            var convError: NSError?
            let status = converter.convert(to: outBuffer, error: &convError, withInputFrom: { requestedPackets, outStatus in
                if finished {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                let framesToRead = min(srcReadCapacity, requestedPackets)
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
                throw VADError.conversionFailed(convError?.localizedDescription ?? "unknown")
            }

            let frames = outBuffer.frameLength
            if frames == 0 { break }

            // Compute RMS dB for this window
            let db = Self.rmsDB(from: outBuffer)
            let currentEndTime = Double(positionFrames + AVAudioFramePosition(frames)) / sampleRate

            if db >= config.silenceThreshold {
                // Speech window
                if !isSpeech {
                    isSpeech = true
                    segmentStartTime = currentEndTime - Double(frames) / sampleRate
                    segmentDBSum = 0
                    segmentWindows = 0
                }
                silenceAccum = 0
                segmentDBSum += Double(db)
                segmentWindows += 1
            } else {
                // Silence window
                if isSpeech {
                    silenceAccum += Double(frames) / sampleRate
                    if silenceAccum >= config.minSilenceGap {
                        // Finalize segment at start of silence
                        let segmentEnd = currentEndTime - silenceAccum
                        let duration = segmentEnd - segmentStartTime
                        if duration >= config.minSpeechDuration, segmentWindows > 0 {
                            let avgDB = segmentDBSum / Double(segmentWindows)
                            let conf = Self.confidence(avgDB: Float(avgDB), threshold: config.silenceThreshold)
                            segments.append(VoiceSegment(startTime: segmentStartTime, endTime: segmentEnd, confidence: conf))
                        }
                        isSpeech = false
                        silenceAccum = 0
                        segmentDBSum = 0
                        segmentWindows = 0
                    }
                }
            }

            positionFrames += AVAudioFramePosition(frames)
        }

        // Close trailing speech segment at EOF
        if isSpeech {
            let totalDuration = Double(file.length) / file.processingFormat.sampleRate
            if totalDuration > segmentStartTime {
                let duration = totalDuration - segmentStartTime
                if duration >= config.minSpeechDuration, segmentWindows > 0 {
                    let avgDB = segmentDBSum / Double(segmentWindows)
                    let conf = Self.confidence(avgDB: Float(avgDB), threshold: config.silenceThreshold)
                    segments.append(VoiceSegment(startTime: segmentStartTime, endTime: totalDuration, confidence: conf))
                }
            }
        }

        return segments
    }

    // MARK: - Helpers

    private static func rmsDB(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return -120.0 }
        let frameLength = Int(buffer.frameLength)
        if frameLength == 0 { return -120.0 }

        // Mono buffer expected; if not, average channels properly
        let channels = max(1, Int(buffer.format.channelCount))
        var meanSquareAccum: Float = 0
        for ch in 0..<channels {
            let ptr = channelData[ch]
            var meanSquareCh: Float = 0
            // vDSP_measqv returns mean of squares over the vector
            vDSP_measqv(ptr, 1, &meanSquareCh, vDSP_Length(frameLength))
            meanSquareAccum += meanSquareCh
        }
        let meanSquare = meanSquareAccum / Float(channels)
        let rms = sqrtf(max(meanSquare, 1.0e-14))
        let db = 20.0 * log10f(rms)
        return db
    }

    private static func confidence(avgDB: Float, threshold: Float) -> Double {
        // Map average dB above threshold to 0..1 over a 20 dB range
        let delta = avgDB - threshold
        let conf = max(0.0, min(1.0, Double(delta / 20.0)))
        return conf
    }
}

// MARK: - Usage Example
// let vad = DefaultVADSplittingService()
// let segments = try await vad.detectVoiceSegments(audioURL: someURL)
// segments.forEach { print("\($0.startTime)-\($0.endTime) (conf: \($0.confidence))") }
