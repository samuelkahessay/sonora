import Foundation

class AnalysisService: ObservableObject, AnalysisServiceProtocol, @unchecked Sendable {
    private let config = AppConfiguration.shared

    func analyze<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type,
        historicalContext: [HistoricalMemoContext]? = nil
    ) async throws -> AnalyzeEnvelope<T> {
        let analyzeURL = config.apiBaseURL.appendingPathComponent("analyze")
        print("🔧 AnalysisService: Using API URL: \(analyzeURL.absoluteString)")

        // Sanitize transcript to reduce prompt injection surface area on server
        let safeTranscript = AnalysisGuardrails.sanitizeTranscriptForLLM(transcript)

        var requestBody: [String: Any] = [
            "mode": mode.rawValue,
            "transcript": safeTranscript
        ]

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

    // Convenience methods for each analysis type
    func analyzeDistill(
        transcript: String,
        historicalContext: [HistoricalMemoContext]?
    ) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyze(
            mode: .distill,
            transcript: transcript,
            responseType: DistillData.self,
            historicalContext: historicalContext
        )
    }

    // Backward-compatible method without historical context
    func analyzeDistill(transcript: String) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyzeDistill(transcript: transcript, historicalContext: nil)
    }

    // MARK: - Distill Component Methods for Parallel Processing

    func analyzeDistillSummary(transcript: String) async throws -> AnalyzeEnvelope<DistillSummaryData> {
        try await analyze(mode: .distillSummary, transcript: transcript, responseType: DistillSummaryData.self, historicalContext: nil)
    }

    func analyzeDistillActions(transcript: String) async throws -> AnalyzeEnvelope<DistillActionsData> {
        try await analyze(mode: .distillActions, transcript: transcript, responseType: DistillActionsData.self, historicalContext: nil)
    }

    func analyzeDistillThemes(transcript: String) async throws -> AnalyzeEnvelope<DistillThemesData> {
        try await analyze(mode: .distillThemes, transcript: transcript, responseType: DistillThemesData.self, historicalContext: nil)
    }

    func analyzeDistillReflection(transcript: String) async throws -> AnalyzeEnvelope<DistillReflectionData> {
        try await analyze(mode: .distillReflection, transcript: transcript, responseType: DistillReflectionData.self, historicalContext: nil)
    }

    func analyzeLiteDistill(transcript: String) async throws -> AnalyzeEnvelope<LiteDistillData> {
        try await analyze(mode: .liteDistill, transcript: transcript, responseType: LiteDistillData.self, historicalContext: nil)
    }
}
