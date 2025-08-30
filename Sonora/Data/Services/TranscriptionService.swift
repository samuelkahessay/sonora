import Foundation
import AVFoundation

final class TranscriptionService: TranscriptionAPI {
    private let config = AppConfiguration.shared
    
    struct APIError: LocalizedError { 
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: - Single-file Transcription
    func transcribe(url: URL) async throws -> String {
        let response = try await transcribe(url: url, language: nil)
        return response.text
    }

    func transcribe(url: URL, language: String?) async throws -> TranscriptionResponse {
        print("🎙️ Starting transcription for: \(url.lastPathComponent)")

        // Validate language code if provided (ISO 639-1 two-letter, lowercase)
        if let language = language, !language.isEmpty {
            guard Self.isValidLanguageCode(language) else {
                throw APIError(message: "Invalid language code: \(language)")
            }
        }

        // First attempt: include language if present
        do {
            return try await sendTranscriptionRequest(url: url, language: language)
        } catch {
            // If the server rejects language hint, fallback once without it
            if let apiErr = error as? APIError,
               let language = language, !language.isEmpty,
               Self.shouldFallbackWithoutLanguage(apiError: apiErr) {
                print("↩️ Fallback: retrying transcription without language hint")
                return try await sendTranscriptionRequest(url: url, language: nil)
            }
            throw error
        }
    }

    // MARK: - Chunked Transcription

    func transcribeChunks(segments: [VoiceSegment], audioURL: URL) async throws -> [ChunkTranscriptionResult] {
        return try await transcribeChunks(segments: segments, audioURL: audioURL, language: nil)
    }

    func transcribeChunks(segments: [VoiceSegment], audioURL: URL, language: String?) async throws -> [ChunkTranscriptionResult] {
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
                        let res = await self.processChunk(index: i, segment: seg, audioURL: audioURL, tempRoot: tempRoot, language: language)
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

    private func processChunk(index: Int, segment: VoiceSegment, audioURL: URL, tempRoot: URL, language: String?) async -> ChunkTranscriptionResult {
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
            return ChunkTranscriptionResult(segment: segment, response: TranscriptionResponse(text: "", detectedLanguage: nil, confidence: nil, avgLogProb: nil, duration: nil))
        }

        // Retry logic for network call (2 retries)
        let attempts = 3
        for attempt in 1...attempts {
            do {
                let resp = try await transcribe(url: readyURL, language: language)
                return ChunkTranscriptionResult(segment: segment, response: resp)
            } catch {
                print("⚠️ TranscriptionService: chunk transcribe failed (attempt \(attempt)/\(attempts)) index=\(index): \(error)")
                if attempt == attempts { break }
                try? await Task.sleep(nanoseconds: UInt64(500_000_000 * attempt)) // backoff: 0.5s, 1.0s
            }
        }
        return ChunkTranscriptionResult(segment: segment, response: TranscriptionResponse(text: "", detectedLanguage: nil, confidence: nil, avgLogProb: nil, duration: nil))
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

        // Wrap non-Sendable exporter to satisfy Swift concurrency checks
        final class NonSendableBox<T>: @unchecked Sendable { let value: T; init(_ value: T) { self.value = value } }
        let exporterBox = NonSendableBox(exporter)

        return try await withCheckedThrowingContinuation { cont in
            exporterBox.value.exportAsynchronously {
                switch exporterBox.value.status {
                case .completed:
                    cont.resume(returning: target)
                case .failed, .cancelled:
                    let err = exporterBox.value.error ?? NSError(domain: "TranscriptionService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
                    cont.resume(throwing: err)
                default:
                    // Should not happen; treat others as error
                    let err = exporterBox.value.error ?? NSError(domain: "TranscriptionService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Export unknown state"])
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

    private static func isValidLanguageCode(_ code: String) -> Bool {
        // Very light validation for ISO 639-1 two-letter codes
        let regex = try! NSRegularExpression(pattern: "^[a-z]{2}$")
        let range = NSRange(code.startIndex..<code.endIndex, in: code)
        return regex.firstMatch(in: code, options: [], range: range) != nil
    }

    private static func shouldFallbackWithoutLanguage(apiError: APIError) -> Bool {
        // Heuristic: when the server mentions "language" or "unsupported" or returns a 4xx in the message
        let msg = apiError.message.lowercased()
        if msg.contains("language") && (msg.contains("unknown") || msg.contains("unsupported") || msg.contains("invalid")) {
            return true
        }
        if msg.contains("server error 4") { // e.g. Server error 400/404/422
            return msg.contains("language")
        }
        return false
    }

    private func sendTranscriptionRequest(url: URL, language: String?) async throws -> TranscriptionResponse {
        var form = MultipartForm()
        try form.addFileField(name: "file", filename: url.lastPathComponent, mimeType: mimeType(for: url), fileURL: url)
        if let language, !language.isEmpty { form.addTextField(name: "language", value: language) }
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

        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            print("❌ Server error: \(text)")
            throw APIError(message: "Server error \(http.statusCode): \(text)")
        }

        // Try first with a structured payload
        struct Payload: Decodable {
            let text: String?
            let detectedLanguage: String?
            let confidence: Double?
            let avgLogProb: Double?
            let duration: Double?

            enum CodingKeys: String, CodingKey {
                case text
                case detectedLanguage = "detected_language"
                case confidence
                case avgLogProb = "avg_logprob"
                case duration
            }
        }

        do {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            let text = payload.text ?? ""
            let response = TranscriptionResponse(
                text: text,
                detectedLanguage: payload.detectedLanguage,
                confidence: payload.confidence,
                avgLogProb: payload.avgLogProb,
                duration: payload.duration
            )
            print("✅ Transcription completed: \(text.prefix(50))...")
            return response
        } catch {
            // Fallback to permissive JSON parsing if structure changes
            if let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                let text = (obj["text"] as? String) ?? ""
                let detectedLanguage = (obj["detected_language"] as? String)
                let confidence = (obj["confidence"] as? Double)
                let avgLogProb = (obj["avg_logprob"] as? Double)
                let duration = (obj["duration"] as? Double)
                let response = TranscriptionResponse(
                    text: text,
                    detectedLanguage: detectedLanguage,
                    confidence: confidence,
                    avgLogProb: avgLogProb,
                    duration: duration
                )
                print("✅ Transcription (fallback parse) completed: \(text.prefix(50))...")
                return response
            }
            // As last resort, just treat body as text
            let text = String(data: data, encoding: .utf8) ?? ""
            print("✅ Transcription (raw text) completed: \(text.prefix(50))...")
            return TranscriptionResponse(text: text, detectedLanguage: nil, confidence: nil, avgLogProb: nil, duration: nil)
        }
    }
}
