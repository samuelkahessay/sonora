import Foundation

final class AnalysisService: AnalysisServiceProtocol, Sendable {
    private let config = AppConfiguration.shared

    func analyze<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type,
        historicalContext: [HistoricalMemoContext]? = nil,
        isPro: Bool = false
    ) async throws -> AnalyzeEnvelope<T> {
        let analyzeURL = config.apiBaseURL.appendingPathComponent("analyze")
        print("🔧 AnalysisService: Using API URL: \(analyzeURL.absoluteString)")

        // Sanitize transcript to reduce prompt injection surface area on server
        let safeTranscript = AnalysisGuardrails.sanitizeTranscriptForLLM(transcript)

        var requestBody: [String: Any] = [
            "mode": mode.rawValue,
            "transcript": safeTranscript
        ]

        // Include isPro flag for pro modes aggregation on server
        requestBody["isPro"] = isPro
        if isPro {
            print("🔧 AnalysisService: Pro subscription active - server will include pro modes")
        } else {
            print("⚠️ AnalysisService: Free tier - Pro modes will NOT be included")
        }

        // Include historical context if provided (for pattern detection)
        if let historicalContext = historicalContext, !historicalContext.isEmpty {
            // Encode historical context to JSON-compatible array
            if let encoded = try? JSONEncoder().encode(historicalContext),
               let jsonArray = try? JSONSerialization.jsonObject(with: encoded) as? [[String: Any]] {
                requestBody["historicalContext"] = jsonArray
                print("🔧 AnalysisService: Including \(historicalContext.count) historical memos for pattern detection")
            }
        }

        var request = URLRequest(url: analyzeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = config.timeoutInterval(for: mode)

        print("🔧 AnalysisService: Using timeout: \(request.timeoutInterval)s for \(mode.displayName)")
        print("🔧 AnalysisService: Transcript length: \(transcript.count) characters (sanitized: \(safeTranscript.count))")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            // Log the actual JSON being sent for debugging
            if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                print("🔍 [DEBUG] Request JSON being sent:")
                print(jsonString)
            }
        } catch {
            throw AnalysisError.networkError("Failed to encode request: \(error.localizedDescription)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnalysisError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ AnalysisService: Server error \(httpResponse.statusCode)")
            if let body = String(data: data, encoding: .utf8) {
                print("❌ AnalysisService: Response body: \(body)")
            }
            throw AnalysisError.serverError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(AnalyzeEnvelope<T>.self, from: data)
            print("✅ AnalysisService: Analysis completed")
            print("✅ AnalysisService: Model: \(envelope.model)")
            print("✅ AnalysisService: Tokens: \(envelope.tokens.input) in, \(envelope.tokens.output) out")
            print("✅ AnalysisService: Latency: \(envelope.latency_ms)ms")
            return envelope
        } catch {
            print("❌ AnalysisService: JSON decode error: \(error)")
            if let body = String(data: data, encoding: .utf8) {
                print("❌ AnalysisService: Raw response: \(body)")
            }
            throw AnalysisError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Convenience Methods

    /// Analyze distill with historical context and pro flag
    func analyzeDistill(
        transcript: String,
        historicalContext: [HistoricalMemoContext]?,
        isPro: Bool
    ) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyze(
            mode: .distill,
            transcript: transcript,
            responseType: DistillData.self,
            historicalContext: historicalContext,
            isPro: isPro
        )
    }

    /// Analyze distill without historical context
    func analyzeDistill(transcript: String, isPro: Bool) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyzeDistill(transcript: transcript, historicalContext: nil, isPro: isPro)
    }

    /// Free tier lite distill analysis
    func analyzeLiteDistill(transcript: String) async throws -> AnalyzeEnvelope<LiteDistillData> {
        try await analyze(mode: .liteDistill, transcript: transcript, responseType: LiteDistillData.self, historicalContext: nil, isPro: false)
    }
}
