import Foundation

class AnalysisService: ObservableObject, AnalysisServiceProtocol, @unchecked Sendable {
    private let config = AppConfiguration.shared
    
    func analyze<T: Codable & Sendable>(mode: AnalysisMode, transcript: String, responseType: T.Type) async throws -> AnalyzeEnvelope<T> {
        let analyzeURL = config.apiBaseURL.appendingPathComponent("analyze")
        print("🔧 AnalysisService: Using API URL: \(analyzeURL.absoluteString)")
        
        // Sanitize transcript to reduce prompt injection surface area on server
        let safeTranscript = AnalysisGuardrails.sanitizeTranscriptForLLM(transcript)
        
        let requestBody = [
            "mode": mode.rawValue,
            "transcript": safeTranscript
        ]
        
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
            let envelope = try JSONDecoder().decode(AnalyzeEnvelope<T>.self, from: data)
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
    func analyzeDistill(transcript: String) async throws -> AnalyzeEnvelope<DistillData> {
        return try await analyze(mode: .distill, transcript: transcript, responseType: DistillData.self)
    }
    
    func analyzeAnalysis(transcript: String) async throws -> AnalyzeEnvelope<AnalysisData> {
        return try await analyze(mode: .analysis, transcript: transcript, responseType: AnalysisData.self)
    }
    
    func analyzeThemes(transcript: String) async throws -> AnalyzeEnvelope<ThemesData> {
        return try await analyze(mode: .themes, transcript: transcript, responseType: ThemesData.self)
    }
    
    func analyzeTodos(transcript: String) async throws -> AnalyzeEnvelope<TodosData> {
        return try await analyze(mode: .todos, transcript: transcript, responseType: TodosData.self)
    }
    
    // MARK: - Distill Component Methods for Parallel Processing
    
    func analyzeDistillSummary(transcript: String) async throws -> AnalyzeEnvelope<DistillSummaryData> {
        return try await analyze(mode: .distillSummary, transcript: transcript, responseType: DistillSummaryData.self)
    }
    
    func analyzeDistillActions(transcript: String) async throws -> AnalyzeEnvelope<DistillActionsData> {
        return try await analyze(mode: .distillActions, transcript: transcript, responseType: DistillActionsData.self)
    }
    
    func analyzeDistillThemes(transcript: String) async throws -> AnalyzeEnvelope<DistillThemesData> {
        return try await analyze(mode: .distillThemes, transcript: transcript, responseType: DistillThemesData.self)
    }
    
    func analyzeDistillReflection(transcript: String) async throws -> AnalyzeEnvelope<DistillReflectionData> {
        return try await analyze(mode: .distillReflection, transcript: transcript, responseType: DistillReflectionData.self)
    }
}
