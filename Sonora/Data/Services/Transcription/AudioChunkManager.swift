import AVFoundation
import Foundation

struct ChunkFile: Equatable {
    let url: URL
    let segment: VoiceSegment
    let duration: TimeInterval
}

enum AudioChunkError: LocalizedError {
    case cannotCreateDirectory(String)
    case exportSessionInitFailed
    case exportFailed(String)
    case invalidSegment
    case insufficientDiskSpace

    var errorDescription: String? {
        switch self {
        case .cannotCreateDirectory(let path):
            return "Cannot create chunk directory: \(path)"
        case .exportSessionInitFailed:
            return "Cannot create AVAssetExportSession"
        case .exportFailed(let reason):
            return "Chunk export failed: \(reason)"
        case .invalidSegment:
            return "Invalid segment range"
        case .insufficientDiskSpace:
            return "Insufficient disk space to export chunks"
        }
    }
}

/// Utility class for creating and cleaning up audio chunks referenced by VoiceSegments.
final class AudioChunkManager: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let chunkRoot: URL
    private let preferredTimescale: CMTimeScale = 600

    init() {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.chunkRoot = documents.appendingPathComponent("temp/chunks", isDirectory: true)
    }

    /// Create audio chunks for the given segments. Exports in parallel to maximize throughput.
    @discardableResult
    func createChunks(from audioURL: URL, segments: [VoiceSegment]) async throws -> [ChunkFile] {
        guard !segments.isEmpty else { return [] }
        try ensureChunkDirectory()

        // Basic disk space guard using estimated size
        if try await !hasSufficientSpace(for: audioURL, segments: segments) {
            throw AudioChunkError.insufficientDiskSpace
        }

        let asset = AVURLAsset(url: audioURL)
        let assetDurationTime = try await asset.load(.duration)
        let assetDuration = CMTimeGetSeconds(assetDurationTime)

        // Configuration for parallel export
        let maxConcurrentExports = 4 // Balance between throughput and I/O contention

        // Pre-validate all segments and prepare export tasks
        struct ExportTask: Sendable {
            let index: Int
            let segment: VoiceSegment
            let start: TimeInterval
            let end: TimeInterval
            let duration: TimeInterval
            let target: URL
        }

        var exportTasks: [ExportTask] = []
        exportTasks.reserveCapacity(segments.count)

        for (index, seg) in segments.enumerated() {
            // Clamp to asset duration and validate
            let start = max(0.0, min(seg.startTime, assetDuration))
            let end = max(0.0, min(seg.endTime, assetDuration))
            let duration = end - start
            if duration <= 0.01 { continue } // skip too-short invalid segments

            // Choose target file name and type
            let filename = "chunk_\(index)_\(UUID().uuidString).m4a"
            let target = chunkRoot.appendingPathComponent(filename)

            // Remove any existing file
            try? fileManager.removeItem(at: target)

            exportTasks.append(ExportTask(index: index, segment: seg, start: start, end: end, duration: duration, target: target))
        }

        // Export chunks in parallel with concurrency limit
        var resultsByIndex: [Int: ChunkFile] = [:]

        do {
            try await withThrowingTaskGroup(of: (Int, ChunkFile).self) { group in
                var startIndex = 0

                // Add initial batch of export tasks (up to maxConcurrent)
                for task in exportTasks.prefix(maxConcurrentExports) {
                    group.addTask { [asset] in
                        let exported = try await self.export(asset: asset, start: task.start, end: task.end, to: task.target)
                        return (task.index, ChunkFile(url: exported, segment: task.segment, duration: task.duration))
                    }
                    startIndex += 1
                }

                // As tasks complete, add new ones to maintain concurrency limit
                while let (index, chunkFile) = try await group.next() {
                    resultsByIndex[index] = chunkFile

                    // Add next export task if any remain
                    if startIndex < exportTasks.count {
                        let nextTask = exportTasks[startIndex]
                        group.addTask { [asset] in
                            let exported = try await self.export(asset: asset, start: nextTask.start, end: nextTask.end, to: nextTask.target)
                            return (nextTask.index, ChunkFile(url: exported, segment: nextTask.segment, duration: nextTask.duration))
                        }
                        startIndex += 1
                    }
                }
            }
        } catch {
            // On failure, clean up any successfully created chunks
            let createdChunks = resultsByIndex.values.map { $0 }
            await cleanupChunks(createdChunks)
            throw error
        }

        // Reconstruct results in original segment order
        let orderedChunks = exportTasks.compactMap { resultsByIndex[$0.index] }
        guard orderedChunks.count == exportTasks.count else {
            // This should never happen, but safety check
            await cleanupChunks(Array(resultsByIndex.values))
            throw AudioChunkError.exportFailed("Failed to export all chunks")
        }

        return orderedChunks
    }

    /// Remove the given chunk files from disk; best-effort.
    func cleanupChunks(_ chunks: [ChunkFile]) async {
        for chunk in chunks { try? fileManager.removeItem(at: chunk.url) }
        // Attempt to remove empty chunk directory (ignore errors)
        if let files = try? fileManager.contentsOfDirectory(atPath: chunkRoot.path), files.isEmpty {
            try? fileManager.removeItem(at: chunkRoot)
        }
    }

    // MARK: - Private Helpers

    private func ensureChunkDirectory() throws {
        if !fileManager.fileExists(atPath: chunkRoot.path) {
            do { try fileManager.createDirectory(at: chunkRoot, withIntermediateDirectories: true) } catch { throw AudioChunkError.cannotCreateDirectory(chunkRoot.path) }
        }
    }

    private func export(asset: AVAsset, start: TimeInterval, end: TimeInterval, to target: URL) async throws -> URL {
        // Prefer high-quality m4a; fall back to passthrough if needed
        let preset = AVAssetExportPresetAppleM4A
        guard let exporter = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw AudioChunkError.exportSessionInitFailed
        }
        exporter.outputURL = target
        exporter.outputFileType = .m4a
        let timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: preferredTimescale),
                                    end: CMTime(seconds: end, preferredTimescale: preferredTimescale))
        exporter.timeRange = timeRange

        final class ExportSessionBox: @unchecked Sendable { let exporter: AVAssetExportSession; init(_ e: AVAssetExportSession) { exporter = e } }
        let box = ExportSessionBox(exporter)
        return try await withCheckedThrowingContinuation { cont in
            box.exporter.exportAsynchronously {
                switch box.exporter.status {
                case .completed:
                    cont.resume(returning: target)
                case .failed, .cancelled:
                    let reason = box.exporter.error?.localizedDescription ?? "unknown"
                    cont.resume(throwing: AudioChunkError.exportFailed(reason))
                default:
                    let reason = box.exporter.error?.localizedDescription ?? "invalid exporter state"
                    cont.resume(throwing: AudioChunkError.exportFailed(reason))
                }
            }
        }
    }

    private func hasSufficientSpace(for audioURL: URL, segments: [VoiceSegment]) async throws -> Bool {
        // Estimate export size from asset bitrate and total voiced duration
        let asset = AVURLAsset(url: audioURL)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        var avgBitrate: Double = 96_000.0
        if let first = tracks.first, let rate: Float = try? await first.load(.estimatedDataRate) {
            avgBitrate = Double(rate)
        }
        let totalDuration = segments.reduce(0.0) { $0 + max(0.0, $1.endTime - $1.startTime) }
        let estimatedBytes = (avgBitrate / 8.0) * totalDuration // bytes

        // Obtain available capacity
        let values = try chunkRoot.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let free = values.volumeAvailableCapacityForImportantUsage {
            return Double(free) > estimatedBytes * 1.2 // 20% headroom
        }
        return true // If unknown, allow
    }
}
