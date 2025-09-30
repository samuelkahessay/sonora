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
        let safeTranscript = AnalysisGuardrails.sanitizeTranscriptForLLM(transcript)
        var lastError: TitleServiceError?

        for attempt in 1...maxAttempts {
            try Task.checkCancellation()

            let streamingRequest: URLRequest
            let legacyRequest: URLRequest
            do {
                streamingRequest = try buildRequest(transcript: safeTranscript, languageHint: languageHint, streaming: progress != nil)
                legacyRequest = try buildRequest(transcript: safeTranscript, languageHint: languageHint, streaming: false)
            } catch {
                throw TitleServiceError.encodingFailed(error)
            }

            do {
                if let progress {
                    do {
                        let result = try await performStreamingRequest(
                            request: streamingRequest,
                            languageHint: languageHint,
                            progress: progress
                        )
                        return result
                    } catch let streamingError as TitleServiceError {
                        guard case .streamingUnsupported = streamingError else { throw streamingError }
                        // Fall back to legacy request
                    }
                }

                let title = try await performLegacyRequest(request: legacyRequest, languageHint: languageHint)
                return title
            } catch {
                let normalized = normalize(error)
                lastError = normalized

                if attempt == maxAttempts || !normalized.isRetryable {
                    throw normalized
                }

                let delay = backoffDelay(for: attempt)
                let jitter = maxJitter == 0 ? 0 : Double.random(in: 0...maxJitter)
                let nanos = UInt64((delay + jitter) * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanos)
            }
        }

        if let lastError {
            throw lastError
        }
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
        return request
    }

    private func performLegacyRequest(request: URLRequest, languageHint: String?) async throws -> String {
        try await Task.detached(priority: .utility) { [session, decoder] in
            try Task.checkCancellation()

            print("🧠 TitleService: POST /title lang=\(languageHint ?? "auto") url=\(request.url?.absoluteString ?? "<unknown>")")

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw TitleServiceError.invalidResponse
                }
                guard http.statusCode == 200 else {
                    throw TitleServiceError.unexpectedStatus(http.statusCode, data)
                }

                do {
                    let decoded = try decoder.decode(TitleResponse.self, from: data)
                    guard let validated = Self.validate(decoded.title) else {
                        throw TitleServiceError.validationFailed
                    }
                    print("🧠 TitleService: /title decoded=\(validated)")
                    return validated
                } catch {
                    throw TitleServiceError.decodingFailed(error)
                }
            } catch {
                if let urlError = error as? URLError {
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
        try await Task.detached(priority: .utility) { [session] in
            try Task.checkCancellation()

            let (stream, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw TitleServiceError.invalidResponse
            }
            guard http.statusCode == 200 else {
                throw TitleServiceError.streamingUnsupported
            }

            var buffer = ""
            var aggregated = ""

            func handleEvent(_ rawEvent: String) throws -> String? {
                let trimmed = rawEvent.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }

                let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
                let dataPayload = lines
                    .filter { $0.hasPrefix("data:") }
                    .map { $0.dropFirst(5).trimmingCharacters(in: .whitespaces) }
                    .joined()

                guard !dataPayload.isEmpty else { return nil }

                if dataPayload == "[DONE]" {
                    let candidate = Self.normalizeText(aggregated)
                    guard let validated = Self.validate(candidate) else {
                        throw TitleServiceError.validationFailed
                    }
                    progress(TitleStreamingUpdate(text: validated, isFinal: true))
                    return validated
                }

                guard let jsonData = dataPayload.data(using: .utf8) else { return nil }
                guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return nil }
                guard
                    let choices = json["choices"] as? [[String: Any]],
                    let first = choices.first,
                    let delta = first["delta"] as? [String: Any],
                    let content = delta["content"] as? String,
                    !content.isEmpty
                else { return nil }

                aggregated += content
                let partial = Self.normalizeText(aggregated)
                if !partial.isEmpty {
                    progress(TitleStreamingUpdate(text: partial, isFinal: false))
                }

                return nil
            }

            for try await byte in stream {
                let scalar = String(decoding: [byte], as: UTF8.self)
                buffer.append(contentsOf: scalar)

                while let range = buffer.range(of: "\n\n") {
                    let rawEvent = String(buffer[..<range.lowerBound])
                    buffer.removeSubrange(..<range.upperBound)
                    if let final = try handleEvent(rawEvent) {
                        return final
                    }
                }
            }

            if !buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let final = try handleEvent(buffer) {
                    return final
                }
            }

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
