import AVFoundation
import Foundation
import UIKit

final class TranscriptionService: TranscriptionAPI, @unchecked Sendable {
    private let config = AppConfiguration.shared
    private let logger: any LoggerProtocol = Logger.shared
    private let uploadTracker: UploadTracker
    private lazy var backgroundDelegate: BackgroundSessionDelegate = {
        BackgroundSessionDelegate(tracker: uploadTracker, logger: logger)
    }()
    private lazy var backgroundSession: URLSession = {
        let identifier: String
        if let bundleId = Bundle.main.bundleIdentifier {
            identifier = "\(bundleId).transcription.background"
        } else {
            identifier = "com.sonora.transcription.background"
        }
        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        configuration.allowsCellularAccess = true
        configuration.shouldUseExtendedBackgroundIdleMode = true
        configuration.timeoutIntervalForRequest = config.transcriptionTimeoutInterval
        configuration.timeoutIntervalForResource = config.transcriptionTimeoutInterval
        configuration.networkServiceType = .responsiveData
        return URLSession(configuration: configuration, delegate: backgroundDelegate, delegateQueue: nil)
    }()

    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    init() {
        self.uploadTracker = UploadTracker(logger: logger)
    }

    // MARK: - Single-file Transcription
    func transcribe(url: URL) async throws -> String {
        let response = try await transcribe(
            url: url,
            language: config.preferredTranscriptionLanguage,
            context: nil
        )
        return response.text
    }

    func transcribe(
        url: URL,
        language: String?,
        context: TranscriptionRequestContext?
    ) async throws -> TranscriptionResponse {
        let effectiveContext = context ?? TranscriptionRequestContext(
            correlationId: UUID().uuidString,
            memoId: nil,
            chunkIndex: nil,
            chunkCount: nil
        )
        let logContext = LogContext(
            correlationId: effectiveContext.correlationId,
            additionalInfo: ["file": url.lastPathComponent, "language": language ?? "auto"]
        )
        logger.debug("Starting cloud transcription", category: .transcription, context: logContext)

        // Validate language code if provided (Whisper-supported code)
        if let language = language, !language.isEmpty {
            guard Self.isValidLanguageCode(language) else {
                throw APIError(message: "Invalid language code: \(language)")
            }
        }

        // First attempt: include language if present
        do {
            return try await sendTranscriptionRequest(url: url, language: language, context: effectiveContext)
        } catch {
            // If the server rejects language hint, fallback once without it
            if let apiErr = error as? APIError,
               let language = language, !language.isEmpty,
               Self.shouldFallbackWithoutLanguage(apiError: apiErr) {
                logger.debug("Fallback: retrying without language hint", category: .transcription, context: logContext)
                return try await sendTranscriptionRequest(url: url, language: nil, context: effectiveContext)
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

    private func sendTranscriptionRequest(
        url: URL,
        language: String?,
        context: TranscriptionRequestContext?
    ) async throws -> TranscriptionResponse {
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

        // Comprehensive request logging
        logger.debug("━━━━━━━━━━ TRANSCRIPTION REQUEST START ━━━━━━━━━━", category: .network, context: nil)
        logger.debug("🌐 Method: \(req.httpMethod ?? "UNKNOWN")", category: .network, context: nil)
        logger.debug("🌐 URL: \(transcribeURL.absoluteString)", category: .network, context: nil)
        logger.debug("🌐 Timeout: \(req.timeoutInterval)s", category: .network, context: nil)
        logger.debug("🌐 Content-Type: multipart/form-data; boundary=\(form.boundary)", category: .network, context: nil)
        if let contentLength {
            logger.debug("🌐 Content-Length: \(contentLength) bytes", category: .network, context: nil)
        }
        logger.debug("🌐 File: \(url.lastPathComponent)", category: .network, context: nil)
        logger.debug("🌐 MIME Type: \(mimeType(for: url))", category: .network, context: nil)
        logger.debug("🌐 Language: \(language ?? "auto-detect")", category: .network, context: nil)
        logger.debug("🌐 Response Format: verbose_json", category: .network, context: nil)
        logger.debug("━━━━━━━━━━ REQUEST HEADERS ━━━━━━━━━━", category: .network, context: nil)
        if let headers = req.allHTTPHeaderFields {
            for (key, value) in headers {
                logger.debug("  \(key): \(value)", category: .network, context: nil)
            }
        }

        if let context {
            req.setValue(context.correlationId, forHTTPHeaderField: "X-Correlation-ID")
            if let memoId = context.memoId {
                req.setValue(memoId.uuidString, forHTTPHeaderField: "X-Memo-ID")
            }
            if let chunkIndex = context.chunkIndex {
                req.setValue(String(chunkIndex), forHTTPHeaderField: "X-Chunk-Index")
            }
            if let chunkCount = context.chunkCount {
                req.setValue(String(chunkCount), forHTTPHeaderField: "X-Chunk-Count")
            }
        }

        let uploadTask = backgroundSession.uploadTask(with: req, fromFile: bodyURL)
        logger.debug("🚀 Starting upload task (ID: \(uploadTask.taskIdentifier))...", category: .network, context: nil)

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await withCheckedThrowingContinuation { continuation in
                Task {
                    await uploadTracker.register(task: uploadTask, continuation: continuation)
                    uploadTask.resume()
                }
            }
        } catch {
            logger.error("❌ Upload task failed", category: .network, context: nil, error: error)
            logger.debug("❌ Error details: \(error.localizedDescription)", category: .network, context: nil)
            if let urlError = error as? URLError {
                logger.debug("❌ URLError code: \(urlError.code.rawValue)", category: .network, context: nil)
                logger.debug("❌ URLError domain: \(urlError.errorCode)", category: .network, context: nil)
            }
            throw APIError(message: error.localizedDescription)
        }

        guard let http = resp as? HTTPURLResponse else {
            logger.error("❌ Invalid response type: \(type(of: resp))", category: .network, context: nil, error: APIError(message: "No HTTP response"))
            throw APIError(message: "No HTTP response")
        }

        // Comprehensive response logging
        logger.debug("━━━━━━━━━━ TRANSCRIPTION RESPONSE START ━━━━━━━━━━", category: .network, context: nil)
        logger.debug("📥 Status Code: \(http.statusCode)", category: .network, context: nil)
        logger.debug("📥 Status Description: \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))", category: .network, context: nil)
        logger.debug("📥 Response URL: \(http.url?.absoluteString ?? "unknown")", category: .network, context: nil)
        logger.debug("━━━━━━━━━━ RESPONSE HEADERS ━━━━━━━━━━", category: .network, context: nil)
        for (key, value) in http.allHeaderFields {
            logger.debug("  \(key): \(value)", category: .network, context: nil)
        }
        logger.debug("━━━━━━━━━━ RESPONSE BODY ━━━━━━━━━━", category: .network, context: nil)
        logger.debug("📥 Body Size: \(data.count) bytes", category: .network, context: nil)

        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            logger.error("━━━━━━━━━━ SERVER ERROR ━━━━━━━━━━", category: .network, context: nil, error: APIError(message: text))
            logger.error("❌ Status Code: \(http.statusCode)", category: .network, context: nil, error: nil)
            logger.error("❌ Response Body: \(text)", category: .network, context: nil, error: nil)
            logger.error("❌ Full URL: \(transcribeURL.absoluteString)", category: .network, context: nil, error: nil)
            logger.error("❌ Language: \(language ?? "auto-detect")", category: .network, context: nil, error: nil)
            logger.error("━━━━━━━━━━ SERVER ERROR END ━━━━━━━━━━", category: .network, context: nil, error: nil)
            throw APIError(message: "Server error \(http.statusCode): \(text)")
        }

        logger.debug("✅ Transcription request succeeded", category: .network, context: nil)

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

        // Log raw response body for debugging
        if let bodyString = String(data: data, encoding: .utf8) {
            let preview = String(bodyString.prefix(500))
            logger.debug("📥 Response Body Preview: \(preview)", category: .network, context: nil)
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
            logger.info("✅ Cloud transcription completed successfully", category: .transcription, context: LogContext(additionalInfo: [
                "preview": String(text.prefix(50)),
                "detectedLanguage": payload.detectedLanguage ?? "unknown",
                "confidence": String(format: "%.2f", payload.confidence ?? 0.0),
                "duration": String(format: "%.2fs", payload.duration ?? 0.0)
            ]))
            logger.debug("━━━━━━━━━━ TRANSCRIPTION RESPONSE END ━━━━━━━━━━", category: .network, context: nil)
            return response
        } catch {
            logger.debug("⚠️ Primary JSON decode failed, attempting fallback parsing", category: .transcription, context: nil)
            logger.debug("⚠️ Decode error: \(error.localizedDescription)", category: .transcription, context: nil)

            // Fallback to permissive JSON parsing if structure changes
            if let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                logger.debug("📝 Fallback JSON object keys: \(obj.keys.joined(separator: ", "))", category: .transcription, context: nil)
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
                logger.info("✅ Cloud transcription completed (fallback parse)", category: .transcription, context: LogContext(additionalInfo: ["preview": String(text.prefix(50))]))
                logger.debug("━━━━━━━━━━ TRANSCRIPTION RESPONSE END ━━━━━━━━━━", category: .network, context: nil)
                return response
            }
            // As last resort, just treat body as text
            logger.debug("⚠️ Fallback JSON parse failed, treating response as raw text", category: .transcription, context: nil)
            let text = String(data: data, encoding: .utf8) ?? ""
            logger.info("✅ Cloud transcription completed (raw text)", category: .transcription, context: LogContext(additionalInfo: ["preview": String(text.prefix(50))]))
            logger.debug("━━━━━━━━━━ TRANSCRIPTION RESPONSE END ━━━━━━━━━━", category: .network, context: nil)
            return TranscriptionResponse(text: text, detectedLanguage: nil, confidence: nil, avgLogProb: nil, duration: nil)
        }
    }
}

private actor UploadTracker {
    enum UploadTrackerError: Error {
        case missingResponse
    }

    private var continuations: [Int: CheckedContinuation<(Data, URLResponse), Error>] = [:]
    private var buffers: [Int: Data] = [:]
    private let logger: any LoggerProtocol

    init(logger: any LoggerProtocol) {
        self.logger = logger
    }

    func register(task: URLSessionTask, continuation: CheckedContinuation<(Data, URLResponse), Error>) {
        continuations[task.taskIdentifier] = continuation
        buffers[task.taskIdentifier] = Data()
    }

    func appendData(taskIdentifier: Int, data: Data) {
        if buffers[taskIdentifier] != nil {
            buffers[taskIdentifier]?.append(data)
        } else {
            buffers[taskIdentifier] = data
        }
    }

    func complete(task: URLSessionTask, error: Error?) {
        let identifier = task.taskIdentifier
        let continuation = continuations.removeValue(forKey: identifier)
        let collectedData = buffers.removeValue(forKey: identifier) ?? Data()

        guard let continuation else {
            logger.debug("UploadTracker: No continuation for task \(identifier)", category: .network, context: nil)
            return
        }

        if let error {
            continuation.resume(throwing: error)
            return
        }

        guard let response = task.response else {
            continuation.resume(throwing: UploadTrackerError.missingResponse)
            return
        }

        continuation.resume(returning: (collectedData, response))
    }
}

extension UploadTracker.UploadTrackerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingResponse:
            return "Upload finished without a server response"
        }
    }
}

private final class BackgroundSessionDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let tracker: UploadTracker
    private let logger: any LoggerProtocol

    init(tracker: UploadTracker, logger: any LoggerProtocol) {
        self.tracker = tracker
        self.logger = logger
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        logger.debug("📦 BackgroundSessionDelegate: Received \(data.count) bytes for task \(dataTask.taskIdentifier)", category: .network, context: nil)
        Task {
            await tracker.appendData(taskIdentifier: dataTask.taskIdentifier, data: data)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            logger.error("❌ BackgroundSessionDelegate: Task \(task.taskIdentifier) completed with error", category: .network, context: nil, error: error)
            logger.debug("❌ Error details: \(error.localizedDescription)", category: .network, context: nil)
            if let urlError = error as? URLError {
                logger.debug("❌ URLError code: \(urlError.code.rawValue)", category: .network, context: nil)
            }
        } else {
            logger.debug("✅ BackgroundSessionDelegate: Task \(task.taskIdentifier) completed successfully", category: .network, context: nil)
            if let httpResponse = task.response as? HTTPURLResponse {
                logger.debug("✅ Final status code: \(httpResponse.statusCode)", category: .network, context: nil)
            }
        }
        Task {
            await tracker.complete(task: task, error: error)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        logger.debug("BackgroundSessionDelegate: finished events for background session", category: .network, context: nil)

        // Notify AppDelegate that this session has completed
        if let identifier = session.configuration.identifier {
            Task { @MainActor in
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.notifyBackgroundSessionCompleted(identifier: identifier)
                }
            }
        }
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error {
            logger.error("BackgroundSessionDelegate: session invalidated", category: .network, context: nil, error: error)
        } else {
            logger.debug("BackgroundSessionDelegate: session invalidated without error", category: .network, context: nil)
        }
    }
}
