import Foundation

typealias TitleStreamingHandler = @Sendable (TitleStreamingUpdate) -> Void

struct TitleStreamingUpdate: Sendable, Equatable {
    let text: String
    let isFinal: Bool
}

protocol TitleServiceProtocol: Sendable {
    func generateTitle(
        transcript: String,
        languageHint: String?,
        progress: TitleStreamingHandler?
    ) async throws -> String?
}

enum TitleServiceError: Error {
    case invalidResponse
    case unexpectedStatus(Int, Data)
    case decodingFailed(Error)
    case validationFailed
    case networking(URLError)
    case encodingFailed(Error)
    case streamingUnsupported
}

extension TitleServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Title service returned an invalid response."
        case let .unexpectedStatus(status, _):
            return "Title service returned status code \(status)."
        case .decodingFailed:
            return "Title service response could not be decoded."
        case .validationFailed:
            return "Generated title failed validation."
        case let .networking(urlError):
            return urlError.localizedDescription
        case .encodingFailed:
            return "Unable to encode title request payload."
        case .streamingUnsupported:
            return "Streaming is not available for title generation."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .validationFailed:
            return false
        case let .unexpectedStatus(status, _):
            return status == 429 || (500...599).contains(status)
        default:
            return true
        }
    }
}

final class TitleService: TitleServiceProtocol, @unchecked Sendable {
    private let config: AppConfiguration
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let logger: any LoggerProtocol = Logger.shared

    private let maxAttempts: Int
    private let baseBackoff: TimeInterval
    private let maxJitter: TimeInterval

    struct TitleResponse: Codable { let title: String }

    init(
        config: AppConfiguration = .shared,
        session: URLSession? = nil,
        maxAttempts: Int = 3,
        baseBackoff: TimeInterval = 1.5,
        maxJitter: TimeInterval = 0.35
    ) {
        self.config = config
        self.maxAttempts = max(1, maxAttempts)
        self.baseBackoff = max(0.1, baseBackoff)
        self.maxJitter = max(0.0, maxJitter)

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = config.analysisTimeoutInterval
            configuration.timeoutIntervalForResource = config.analysisTimeoutInterval + 5.0
            configuration.waitsForConnectivity = true
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    func generateTitle(
        transcript: String,
        languageHint: String?,
        progress: TitleStreamingHandler?
    ) async throws -> String? {
        logger.debug("━━━━━━━━━━ TITLE GENERATION START ━━━━━━━━━━", category: .network, context: nil)
        logger.debug("🏷️ Language hint: \(languageHint ?? "auto")", category: .network, context: nil)
        logger.debug("🏷️ Streaming: \(progress != nil ? "YES" : "NO")", category: .network, context: nil)
        logger.debug("🏷️ Max attempts: \(maxAttempts)", category: .network, context: nil)

        let safeTranscript = AnalysisGuardrails.sanitizeTranscriptForLLM(transcript)
        logger.debug("🏷️ Transcript length: \(transcript.count) chars (sanitized: \(safeTranscript.count))", category: .network, context: nil)

        var lastError: TitleServiceError?

        for attempt in 1...maxAttempts {
            try Task.checkCancellation()

            logger.debug("━━━━━━━━━━ TITLE REQUEST ATTEMPT \(attempt)/\(maxAttempts) ━━━━━━━━━━", category: .network, context: nil)

            let streamingRequest: URLRequest
            let legacyRequest: URLRequest
            do {
                streamingRequest = try buildRequest(transcript: safeTranscript, languageHint: languageHint, streaming: progress != nil)
                legacyRequest = try buildRequest(transcript: safeTranscript, languageHint: languageHint, streaming: false)
            } catch {
                logger.error("❌ Failed to build title request", category: .network, context: nil, error: error)
                throw TitleServiceError.encodingFailed(error)
            }

            do {
                if let progress {
                    do {
                        logger.debug("🌐 Attempting streaming title generation", category: .network, context: nil)
                        let result = try await performStreamingRequest(
                            request: streamingRequest,
                            languageHint: languageHint,
                            progress: progress
                        )
                        logger.info("✅ Title generation completed (streaming)", category: .network, context: LogContext(additionalInfo: ["title": result ?? "nil"]))
                        logger.debug("━━━━━━━━━━ TITLE GENERATION END ━━━━━━━━━━", category: .network, context: nil)
                        return result
                    } catch let streamingError as TitleServiceError {
                        guard case .streamingUnsupported = streamingError else {
                            logger.error("❌ Streaming title generation failed", category: .network, context: nil, error: streamingError)
                            throw streamingError
                        }
                        logger.debug("⚠️ Streaming unsupported, falling back to legacy request", category: .network, context: nil)
                        // Fall back to legacy request
                    }
                }

                logger.debug("🌐 Attempting legacy title generation", category: .network, context: nil)
                let title = try await performLegacyRequest(request: legacyRequest, languageHint: languageHint)
                logger.info("✅ Title generation completed (legacy)", category: .network, context: LogContext(additionalInfo: ["title": title ?? "nil"]))
                logger.debug("━━━━━━━━━━ TITLE GENERATION END ━━━━━━━━━━", category: .network, context: nil)
                return title
            } catch {
                let normalized = normalize(error)
                lastError = normalized

                logger.error("❌ Title request attempt \(attempt) failed", category: .network, context: nil, error: normalized)
                logger.debug("❌ Error type: \(type(of: normalized))", category: .network, context: nil)
                logger.debug("❌ Is retryable: \(normalized.isRetryable)", category: .network, context: nil)

                if attempt == maxAttempts || !normalized.isRetryable {
                    logger.error("❌ Title generation failed after \(attempt) attempt(s)", category: .network, context: nil, error: normalized)
                    logger.debug("━━━━━━━━━━ TITLE GENERATION END ━━━━━━━━━━", category: .network, context: nil)
                    throw normalized
                }

                let delay = backoffDelay(for: attempt)
                let jitter = maxJitter == 0 ? 0 : Double.random(in: 0...maxJitter)
                let totalDelay = delay + jitter
                logger.debug("⏳ Retrying after \(String(format: "%.2f", totalDelay))s backoff...", category: .network, context: nil)
                let nanos = UInt64(totalDelay * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanos)
            }
        }

        if let lastError {
            logger.error("❌ Title generation exhausted all attempts", category: .network, context: nil, error: lastError)
            logger.debug("━━━━━━━━━━ TITLE GENERATION END ━━━━━━━━━━", category: .network, context: nil)
            throw lastError
        }
        logger.debug("━━━━━━━━━━ TITLE GENERATION END ━━━━━━━━━━", category: .network, context: nil)
        return nil
    }

    private func buildRequest(
        transcript: String,
        languageHint: String?,
        streaming: Bool
    ) throws -> URLRequest {
        let url = config.apiBaseURL.appendingPathComponent("title")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.analysisTimeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if streaming {
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        }

        var body: [String: Any] = [
            "transcript": transcript,
            "rules": [
                "words": "3-5",
                "titleCase": true,
                "noPunctuation": true,
                "maxChars": 32
            ]
        ]
        if let lang = languageHint, !lang.isEmpty {
            body["language"] = lang
        }
        if streaming {
            body["stream"] = true
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        logger.debug("━━━━━━━━━━ TITLE REQUEST ━━━━━━━━━━", category: .network, context: nil)
        logger.debug("🌐 Method: POST", category: .network, context: nil)
        logger.debug("🌐 URL: \(url.absoluteString)", category: .network, context: nil)
        logger.debug("🌐 Timeout: \(request.timeoutInterval)s", category: .network, context: nil)
        logger.debug("🌐 Streaming: \(streaming ? "YES" : "NO")", category: .network, context: nil)
        logger.debug("━━━━━━━━━━ REQUEST HEADERS ━━━━━━━━━━", category: .network, context: nil)
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                logger.debug("  \(key): \(value)", category: .network, context: nil)
            }
        }
        logger.debug("━━━━━━━━━━ REQUEST BODY ━━━━━━━━━━", category: .network, context: nil)
        logger.debug("📝 Transcript length: \(transcript.count) chars", category: .network, context: nil)
        logger.debug("📝 Language: \(languageHint ?? "auto")", category: .network, context: nil)
        if let bodySize = request.httpBody?.count {
            logger.debug("📝 Body size: \(bodySize) bytes", category: .network, context: nil)
        }

        return request
    }

    private func performLegacyRequest(request: URLRequest, languageHint: String?) async throws -> String {
        try await Task.detached(priority: .utility) { [session, decoder, logger] in
            try Task.checkCancellation()

            logger.debug("🌐 Sending legacy title request to \(request.url?.absoluteString ?? "<unknown>")", category: .network, context: nil)

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    logger.error("❌ Invalid response type for title request", category: .network, context: nil, error: TitleServiceError.invalidResponse)
                    throw TitleServiceError.invalidResponse
                }

                logger.debug("━━━━━━━━━━ TITLE RESPONSE ━━━━━━━━━━", category: .network, context: nil)
                logger.debug("📥 Status Code: \(http.statusCode)", category: .network, context: nil)
                logger.debug("📥 Status Description: \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))", category: .network, context: nil)
                logger.debug("━━━━━━━━━━ RESPONSE HEADERS ━━━━━━━━━━", category: .network, context: nil)
                for (key, value) in http.allHeaderFields {
                    logger.debug("  \(key): \(value)", category: .network, context: nil)
                }
                logger.debug("📥 Body Size: \(data.count) bytes", category: .network, context: nil)

                guard http.statusCode == 200 else {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    logger.error("━━━━━━━━━━ TITLE SERVER ERROR ━━━━━━━━━━", category: .network, context: nil, error: TitleServiceError.unexpectedStatus(http.statusCode, data))
                    logger.error("❌ Status Code: \(http.statusCode)", category: .network, context: nil, error: nil)
                    logger.error("❌ Response Body: \(body)", category: .network, context: nil, error: nil)
                    logger.error("❌ Language Hint: \(languageHint ?? "auto")", category: .network, context: nil, error: nil)
                    logger.error("━━━━━━━━━━ TITLE SERVER ERROR END ━━━━━━━━━━", category: .network, context: nil, error: nil)
                    throw TitleServiceError.unexpectedStatus(http.statusCode, data)
                }

                if let bodyString = String(data: data, encoding: .utf8) {
                    logger.debug("📥 Response Body: \(bodyString)", category: .network, context: nil)
                }

                do {
                    let decoded = try decoder.decode(TitleResponse.self, from: data)
                    guard let validated = Self.validate(decoded.title) else {
                        logger.error("❌ Title validation failed for: \(decoded.title)", category: .network, context: nil, error: TitleServiceError.validationFailed)
                        throw TitleServiceError.validationFailed
                    }
                    logger.debug("✅ Title decoded and validated: \(validated)", category: .network, context: nil)
                    return validated
                } catch {
                    logger.error("❌ Failed to decode title response", category: .network, context: nil, error: error)
                    if let body = String(data: data, encoding: .utf8) {
                        logger.debug("❌ Raw response: \(body)", category: .network, context: nil)
                    }
                    throw TitleServiceError.decodingFailed(error)
                }
            } catch {
                if let urlError = error as? URLError {
                    logger.error("❌ Network error in title request", category: .network, context: nil, error: urlError)
                    logger.debug("❌ URLError code: \(urlError.code.rawValue)", category: .network, context: nil)
                    throw TitleServiceError.networking(urlError)
                }
                throw error
            }
        }.value
    }

    private func performStreamingRequest(
        request: URLRequest,
        languageHint: String?,
        progress: @escaping TitleStreamingHandler
    ) async throws -> String {
        try await Task.detached(priority: .utility) { [session, logger] in
            try Task.checkCancellation()

            logger.debug("🌐 Starting streaming title request to \(request.url?.absoluteString ?? "<unknown>")", category: .network, context: nil)

            let (stream, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else {
                logger.error("❌ Invalid response type for streaming title request", category: .network, context: nil, error: TitleServiceError.invalidResponse)
                throw TitleServiceError.invalidResponse
            }

            logger.debug("━━━━━━━━━━ STREAMING TITLE RESPONSE ━━━━━━━━━━", category: .network, context: nil)
            logger.debug("📥 Status Code: \(http.statusCode)", category: .network, context: nil)
            logger.debug("📥 Status Description: \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))", category: .network, context: nil)

            guard http.statusCode == 200 else {
                logger.error("❌ Streaming unsupported, status code: \(http.statusCode)", category: .network, context: nil, error: TitleServiceError.streamingUnsupported)
                throw TitleServiceError.streamingUnsupported
            }

            logger.debug("📡 Starting SSE stream processing", category: .network, context: nil)
            var buffer = ""
            var aggregated = ""
            var eventCount = 0

            func handleEvent(_ rawEvent: String) throws -> String? {
                let trimmed = rawEvent.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }

                eventCount += 1
                logger.debug("📡 Processing SSE event #\(eventCount)", category: .network, context: nil)

                let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
                let dataPayload = lines
                    .filter { $0.hasPrefix("data:") }
                    .map { $0.dropFirst(5).trimmingCharacters(in: .whitespaces) }
                    .joined()

                guard !dataPayload.isEmpty else {
                    logger.debug("⚠️ Empty data payload in event #\(eventCount)", category: .network, context: nil)
                    return nil
                }

                if dataPayload == "[DONE]" {
                    logger.debug("✅ Received [DONE] marker, finalizing title", category: .network, context: nil)
                    let candidate = Self.normalizeText(aggregated)
                    logger.debug("📝 Final aggregated text: \(candidate)", category: .network, context: nil)
                    guard let validated = Self.validate(candidate) else {
                        logger.error("❌ Final title validation failed: \(candidate)", category: .network, context: nil, error: TitleServiceError.validationFailed)
                        throw TitleServiceError.validationFailed
                    }
                    progress(TitleStreamingUpdate(text: validated, isFinal: true))
                    logger.debug("✅ Streaming title generation complete: \(validated)", category: .network, context: nil)
                    return validated
                }

                guard let jsonData = dataPayload.data(using: .utf8) else {
                    logger.debug("⚠️ Could not convert data payload to UTF-8", category: .network, context: nil)
                    return nil
                }
                guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    logger.debug("⚠️ Could not parse JSON from data payload", category: .network, context: nil)
                    return nil
                }
                guard
                    let choices = json["choices"] as? [[String: Any]],
                    let first = choices.first,
                    let delta = first["delta"] as? [String: Any],
                    let content = delta["content"] as? String,
                    !content.isEmpty
                else {
                    logger.debug("⚠️ Could not extract content from SSE event", category: .network, context: nil)
                    return nil
                }

                aggregated += content
                let partial = Self.normalizeText(aggregated)
                if !partial.isEmpty {
                    logger.debug("📡 Streaming partial update: \(partial)", category: .network, context: nil)
                    progress(TitleStreamingUpdate(text: partial, isFinal: false))
                }

                return nil
            }

            logger.debug("📡 Starting byte stream iteration", category: .network, context: nil)
            var byteCount = 0
            for try await byte in stream {
                byteCount += 1
                let scalar = String(decoding: [byte], as: UTF8.self)
                buffer.append(contentsOf: scalar)

                while let range = buffer.range(of: "\n\n") {
                    let rawEvent = String(buffer[..<range.lowerBound])
                    buffer.removeSubrange(..<range.upperBound)
                    if let final = try handleEvent(rawEvent) {
                        logger.debug("📡 Stream complete after \(byteCount) bytes, \(eventCount) events", category: .network, context: nil)
                        return final
                    }
                }
            }

            logger.debug("📡 Stream ended, processing remaining buffer", category: .network, context: nil)
            if !buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let final = try handleEvent(buffer) {
                    logger.debug("📡 Final event processed successfully", category: .network, context: nil)
                    return final
                }
            }

            logger.error("❌ Streaming ended without [DONE] marker", category: .network, context: nil, error: TitleServiceError.streamingUnsupported)
            throw TitleServiceError.streamingUnsupported
        }.value
    }

    private func backoffDelay(for attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return baseBackoff }
        return pow(2.0, Double(attempt - 1)) * baseBackoff
    }

    private func normalize(_ error: Error) -> TitleServiceError {
        if let serviceError = error as? TitleServiceError {
            return serviceError
        }
        if let urlError = error as? URLError {
            return .networking(urlError)
        }
        return .decodingFailed(error)
    }

    private static func normalizeText(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func validate(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let words = trimmed.split(separator: " ").map(String.init)
        guard (3...5).contains(words.count) else { return nil }
        guard trimmed.count <= 32 else { return nil }
        if trimmed.range(of: #"[\p{P}\p{Emoji_Presentation}]"#, options: .regularExpression) != nil { return nil }
        return trimmed
    }
}
