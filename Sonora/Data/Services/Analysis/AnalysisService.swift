import Foundation

final class AnalysisService: AnalysisServiceProtocol, Sendable {
    private let config = AppConfiguration.shared

    func analyzeWithStreaming<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type,
        historicalContext: [HistoricalMemoContext]? = nil,
        progress: AnalysisStreamingHandler?
    ) async throws -> AnalyzeEnvelope<T> {
        let analyzeURL = config.apiBaseURL.appendingPathComponent("analyze")
        print("🔧 AnalysisService (Streaming): Using API URL: \(analyzeURL.absoluteString)")

        // Sanitize transcript
        let safeTranscript = AnalysisGuardrails.sanitizeTranscriptForLLM(transcript)

        var requestBody: [String: Any] = [
            "mode": mode.rawValue,
            "transcript": safeTranscript,
            "stream": true  // Enable streaming
        ]

        // Include historical context if provided
        if let historicalContext = historicalContext, !historicalContext.isEmpty {
            if let encoded = try? JSONEncoder().encode(historicalContext),
               let jsonArray = try? JSONSerialization.jsonObject(with: encoded) as? [[String: Any]] {
                requestBody["historicalContext"] = jsonArray
                print("🔧 AnalysisService (Streaming): Including \(historicalContext.count) historical memos")
            }
        }

        var request = URLRequest(url: analyzeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")  // Request SSE
        request.timeoutInterval = config.timeoutInterval(for: mode)

        print("🔧 AnalysisService (Streaming): Timeout: \(request.timeoutInterval)s for \(mode.displayName)")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AnalysisError.networkError("Failed to encode request: \(error.localizedDescription)")
        }

        // Use streaming if progress callback provided
        if let progress = progress {
            return try await performStreamingRequest(
                request: request,
                responseType: responseType,
                mode: mode,
                progress: progress
            )
        } else {
            // Fall back to non-streaming if no progress handler
            return try await analyze(
                mode: mode,
                transcript: transcript,
                responseType: responseType,
                historicalContext: historicalContext
            )
        }
    }

    private func performStreamingRequest<T: Codable & Sendable>(
        request: URLRequest,
        responseType: T.Type,
        mode: AnalysisMode,
        progress: @escaping AnalysisStreamingHandler
    ) async throws -> AnalyzeEnvelope<T> {
        return try await Task.detached(priority: .utility) { [config] in
            try Task.checkCancellation()

            let (stream, response) = try await URLSession.shared.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AnalysisError.networkError("Invalid response")
            }
            guard httpResponse.statusCode == 200 else {
                print("❌ AnalysisService (Streaming): Server error \(httpResponse.statusCode)")
                throw AnalysisError.serverError(httpResponse.statusCode)
            }

            var buffer = ""
            var aggregated = ""
            var finalEnvelope: AnalyzeEnvelope<T>?

            func handleEvent(_ rawEvent: String) throws {
                let trimmed = rawEvent.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }

                let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
                let dataPayload = lines
                    .filter { $0.hasPrefix("data:") }
                    .map { $0.dropFirst(5).trimmingCharacters(in: .whitespaces) }
                    .joined()

                guard !dataPayload.isEmpty else { return }

                // Check for event type
                let eventType = lines
                    .first(where: { $0.hasPrefix("event:") })?
                    .dropFirst(6)
                    .trimmingCharacters(in: .whitespaces) ?? "message"

                if eventType == "final" {
                    // Parse final complete response
                    guard let jsonData = dataPayload.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                          let dataObj = json["data"],
                          let dataJson = try? JSONSerialization.data(withJSONObject: dataObj) else {
                        throw AnalysisError.decodingError("Failed to parse final response")
                    }

                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let data = try decoder.decode(T.self, from: dataJson)

                    let tokens = json["tokens"] as? [String: Int]
                    let envelope = AnalyzeEnvelope<T>(
                        mode: mode,
                        data: data,
                        model: json["model"] as? String ?? config.apiBaseURL.absoluteString,
                        tokens: TokenUsage(
                            input: tokens?["input"] ?? 0,
                            output: tokens?["output"] ?? 0
                        ),
                        latency_ms: json["latency_ms"] as? Int ?? 0,
                        moderation: nil
                    )

                    finalEnvelope = envelope
                    progress(AnalysisStreamingUpdate(partialText: aggregated, isFinal: true))
                    return
                }

                // Handle interim streaming updates
                if eventType == "interim", let jsonData = dataPayload.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let partialText = json["partial_text"] as? String {
                    aggregated = partialText
                    progress(AnalysisStreamingUpdate(partialText: partialText, isFinal: false))
                }
            }

            for try await byte in stream {
                let scalar = String(decoding: [byte], as: UTF8.self)
                buffer.append(contentsOf: scalar)

                while let range = buffer.range(of: "\n\n") {
                    let rawEvent = String(buffer[..<range.lowerBound])
                    buffer.removeSubrange(..<range.upperBound)
                    try handleEvent(rawEvent)
                }
            }

            // Process any remaining buffer
            if !buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try handleEvent(buffer)
            }

            guard let envelope = finalEnvelope else {
                throw AnalysisError.networkError("No final response received from streaming")
            }

            print("✅ AnalysisService (Streaming): Analysis completed")
            return envelope
        }.value
    }

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

    // MARK: - Pro-Tier Analysis Methods for Parallel Processing

    func analyzeCognitiveClarityCBT(transcript: String) async throws -> AnalyzeEnvelope<CognitiveClarityData> {
        try await analyze(mode: .cognitiveClarityCBT, transcript: transcript, responseType: CognitiveClarityData.self, historicalContext: nil)
    }

    func analyzePhilosophicalEchoes(transcript: String) async throws -> AnalyzeEnvelope<PhilosophicalEchoesData> {
        try await analyze(mode: .philosophicalEchoes, transcript: transcript, responseType: PhilosophicalEchoesData.self, historicalContext: nil)
    }

    func analyzeValuesRecognition(transcript: String) async throws -> AnalyzeEnvelope<ValuesRecognitionData> {
        try await analyze(mode: .valuesRecognition, transcript: transcript, responseType: ValuesRecognitionData.self, historicalContext: nil)
    }

    // MARK: - Free Tier Analysis

    func analyzeLiteDistill(transcript: String) async throws -> AnalyzeEnvelope<LiteDistillData> {
        try await analyze(mode: .liteDistill, transcript: transcript, responseType: LiteDistillData.self, historicalContext: nil)
    }

    // MARK: - Streaming Wrapper Methods

    /// Streaming variant for Distill Summary
    func analyzeDistillSummaryStreaming(
        transcript: String,
        progress: AnalysisStreamingHandler?
    ) async throws -> AnalyzeEnvelope<DistillSummaryData> {
        try await analyzeWithStreaming(
            mode: .distillSummary,
            transcript: transcript,
            responseType: DistillSummaryData.self,
            historicalContext: nil,
            progress: progress
        )
    }

    /// Streaming variant for Distill Actions
    func analyzeDistillActionsStreaming(
        transcript: String,
        progress: AnalysisStreamingHandler?
    ) async throws -> AnalyzeEnvelope<DistillActionsData> {
        try await analyzeWithStreaming(
            mode: .distillActions,
            transcript: transcript,
            responseType: DistillActionsData.self,
            historicalContext: nil,
            progress: progress
        )
    }

    /// Streaming variant for Distill Reflection
    func analyzeDistillReflectionStreaming(
        transcript: String,
        progress: AnalysisStreamingHandler?
    ) async throws -> AnalyzeEnvelope<DistillReflectionData> {
        try await analyzeWithStreaming(
            mode: .distillReflection,
            transcript: transcript,
            responseType: DistillReflectionData.self,
            historicalContext: nil,
            progress: progress
        )
    }

    /// Streaming variant for Cognitive Clarity (CBT)
    func analyzeCognitiveClarityCBTStreaming(
        transcript: String,
        progress: AnalysisStreamingHandler?
    ) async throws -> AnalyzeEnvelope<CognitiveClarityData> {
        try await analyzeWithStreaming(
            mode: .cognitiveClarityCBT,
            transcript: transcript,
            responseType: CognitiveClarityData.self,
            historicalContext: nil,
            progress: progress
        )
    }

    /// Streaming variant for Philosophical Echoes
    func analyzePhilosophicalEchoesStreaming(
        transcript: String,
        progress: AnalysisStreamingHandler?
    ) async throws -> AnalyzeEnvelope<PhilosophicalEchoesData> {
        try await analyzeWithStreaming(
            mode: .philosophicalEchoes,
            transcript: transcript,
            responseType: PhilosophicalEchoesData.self,
            historicalContext: nil,
            progress: progress
        )
    }

    /// Streaming variant for Values Recognition
    func analyzeValuesRecognitionStreaming(
        transcript: String,
        progress: AnalysisStreamingHandler?
    ) async throws -> AnalyzeEnvelope<ValuesRecognitionData> {
        try await analyzeWithStreaming(
            mode: .valuesRecognition,
            transcript: transcript,
            responseType: ValuesRecognitionData.self,
            historicalContext: nil,
            progress: progress
        )
    }
}
