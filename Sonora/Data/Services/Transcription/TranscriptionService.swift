import Foundation
import AVFoundation

final class TranscriptionService: TranscriptionAPI, @unchecked Sendable {
    private let config = AppConfiguration.shared
    private let logger: any LoggerProtocol = Logger.shared
    
    struct APIError: LocalizedError { 
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: - Single-file Transcription
    func transcribe(url: URL) async throws -> String {
        let response = try await transcribe(url: url, language: config.preferredTranscriptionLanguage)
        return response.text
    }

    func transcribe(url: URL, language: String?) async throws -> TranscriptionResponse {
        let context = LogContext(additionalInfo: ["file": url.lastPathComponent, "language": language ?? "auto"])
        logger.debug("Starting cloud transcription", category: .transcription, context: context)

        // Validate language code if provided (Whisper-supported code)
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
                logger.debug("Fallback: retrying without language hint", category: .transcription, context: context)
                return try await sendTranscriptionRequest(url: url, language: nil)
            }
            throw error
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
        WhisperLanguages.supportedCodes.contains(code.lowercased())
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
        if let language, !language.isEmpty { form.addTextField(name: "language", value: language) }
        // Stabilize output; keep in-source language
        form.addTextField(name: "response_format", value: "verbose_json")
        form.addTextField(name: "temperature", value: "0")
        form.addTextField(name: "translate", value: "false")
        try form.addFileField(name: "file", filename: url.lastPathComponent, mimeType: mimeType(for: url), fileURL: url)
        let (bodyURL, contentLength) = try form.writeBodyToTemporaryFile()
        defer { try? FileManager.default.removeItem(at: bodyURL) }

        let transcribeURL = config.apiBaseURL.appendingPathComponent("transcribe")
        var req = URLRequest(url: transcribeURL)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(form.boundary)", forHTTPHeaderField: "Content-Type")
        if let contentLength {
            req.setValue(String(contentLength), forHTTPHeaderField: "Content-Length")
        }
        req.timeoutInterval = config.transcriptionTimeoutInterval

        logger.debug("Using API URL: \(transcribeURL.absoluteString)", category: .network, context: nil)
        logger.debug("Timeout: \(req.timeoutInterval)s", category: .network, context: nil)
        logger.debug("Making request: \(req.url?.absoluteString ?? "unknown")", category: .network, context: nil)

        let (data, resp) = try await URLSession.shared.upload(for: req, fromFile: bodyURL)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError(message: "No HTTP response")
        }
        logger.debug("Response status: \(http.statusCode)", category: .network, context: nil)

        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            logger.error("Server error \(http.statusCode): \(text)", category: .network, context: nil, error: APIError(message: text))
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
            logger.info("Cloud transcription completed", category: .transcription, context: LogContext(additionalInfo: ["preview": String(text.prefix(50))]))
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
                logger.info("Cloud transcription completed (fallback parse)", category: .transcription, context: LogContext(additionalInfo: ["preview": String(text.prefix(50))]))
                return response
            }
            // As last resort, just treat body as text
            let text = String(data: data, encoding: .utf8) ?? ""
            logger.info("Cloud transcription completed (raw text)", category: .transcription, context: LogContext(additionalInfo: ["preview": String(text.prefix(50))]))
            return TranscriptionResponse(text: text, detectedLanguage: nil, confidence: nil, avgLogProb: nil, duration: nil)
        }
    }
}
