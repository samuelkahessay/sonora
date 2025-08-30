import Foundation
import AVFoundation

final class TranscriptionService: TranscriptionAPI {
    private let config = AppConfiguration.shared
    
    struct APIError: LocalizedError { 
        let message: String
        var errorDescription: String? { message }
    }

    func transcribe(url: URL) async throws -> String {
        print("🎙️ Starting transcription for: \(url.lastPathComponent)")
        
        var form = MultipartForm()
        try form.addFileField(name: "file", filename: url.lastPathComponent, mimeType: mimeType(for: url), fileURL: url)
        let body = form.finalize()

        let transcribeURL = config.apiBaseURL.appendingPathComponent("transcribe")
        var req = URLRequest(url: transcribeURL)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(form.boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = config.transcriptionTimeoutInterval
        
        print("🔧 TranscriptionService: Using API URL: \(transcribeURL.absoluteString)")
        print("🔧 TranscriptionService: Using timeout: \(req.timeoutInterval)s")
        print("🌐 Making request to: \(req.url?.absoluteString ?? "unknown")")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { 
            throw APIError(message: "No HTTP response") 
        }
        
        print("📡 Response status: \(http.statusCode)")
        
        if !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            print("❌ Server error: \(text)")
            throw APIError(message: "Server error \(http.statusCode): \(text)")
        }
        
        struct Payload: Decodable { let text: String? }
        let out = try JSONDecoder().decode(Payload.self, from: data)
        let transcription = out.text ?? ""
        print("✅ Transcription completed: \(transcription.prefix(50))...")
        return transcription
    }

    // MARK: - Chunked Transcription

    func transcribeChunks(segments: [VoiceSegment], audioURL: URL) async throws -> [ChunkTranscriptionResult] {
        guard !segments.isEmpty else { return [] }

        // Ensure temp folder exists under Documents/temp
        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tempRoot = documents.appendingPathComponent("temp", isDirectory: true)
        try? fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        // Process chunks in batches (concurrency limit = 3)
        let batchSize = 3
        var results: [ChunkTranscriptionResult?] = Array(repeating: nil, count: segments.count)
        var idx = 0

        while idx < segments.count {
            let end = min(idx + batchSize, segments.count)
            await withTaskGroup(of: (Int, ChunkTranscriptionResult).self) { group in
                for i in idx..<end {
                    let seg = segments[i]
                    group.addTask {
                        let res = await self.processChunk(index: i, segment: seg, audioURL: audioURL, tempRoot: tempRoot)
                        return (i, res)
                    }
                }
                for await (i, res) in group {
                    results[i] = res
                }
            }
            idx = end
        }

        // Compact results (all should be present)
        return results.compactMap { $0 }
    }

    private func processChunk(index: Int, segment: VoiceSegment, audioURL: URL, tempRoot: URL) async -> ChunkTranscriptionResult {
        // Prepare output chunk URL
        let chunkURL = tempRoot.appendingPathComponent("chunk_\(index)_\(UUID().uuidString).m4a")

        // Export the time range
        var exported: URL? = nil
        do {
            exported = try await exportChunk(from: audioURL, to: chunkURL, segment: segment)
        } catch {
            print("❌ TranscriptionService: exportChunk failed for index=\(index): \(error)")
        }

        defer {
            if let url = exported {
                try? FileManager.default.removeItem(at: url)
            }
        }

        guard let readyURL = exported else {
            return ChunkTranscriptionResult(segment: segment, text: "", confidence: nil)
        }

        // Retry logic for network call (2 retries)
        let attempts = 3
        for attempt in 1...attempts {
            do {
                let text = try await transcribe(url: readyURL)
                return ChunkTranscriptionResult(segment: segment, text: text, confidence: nil)
            } catch {
                print("⚠️ TranscriptionService: chunk transcribe failed (attempt \(attempt)/\(attempts)) index=\(index): \(error)")
                if attempt == attempts { break }
                try? await Task.sleep(nanoseconds: UInt64(500_000_000 * attempt)) // backoff: 0.5s, 1.0s
            }
        }
        return ChunkTranscriptionResult(segment: segment, text: "", confidence: nil)
    }

    private func exportChunk(from source: URL, to target: URL, segment: VoiceSegment) async throws -> URL {
        let asset = AVURLAsset(url: source)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "TranscriptionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot create AVAssetExportSession"])
        }
        exporter.outputURL = target
        exporter.outputFileType = .m4a
        let start = CMTime(seconds: segment.startTime, preferredTimescale: 600)
        let end = CMTime(seconds: segment.endTime, preferredTimescale: 600)
        exporter.timeRange = CMTimeRange(start: start, end: end)

        // Remove file if exists
        try? FileManager.default.removeItem(at: target)

        return try await withCheckedThrowingContinuation { cont in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    cont.resume(returning: target)
                case .failed, .cancelled:
                    let err = exporter.error ?? NSError(domain: "TranscriptionService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
                    cont.resume(throwing: err)
                default:
                    // Should not happen; treat others as error
                    let err = exporter.error ?? NSError(domain: "TranscriptionService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Export unknown state"])
                    cont.resume(throwing: err)
                }
            }
        }
    }

    // MARK: - Helpers
    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "m4a": return "audio/m4a"
        case "wav": return "audio/wav"
        case "mp3": return "audio/mpeg"
        case "caf": return "audio/x-caf"
        default: return "application/octet-stream"
        }
    }
}
