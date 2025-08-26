import Foundation

@MainActor
class AnalysisService: ObservableObject, AnalysisServiceProtocol {
    private let baseURL = "https://sonora.fly.dev"
    
    func analyze<T: Codable>(mode: AnalysisMode, transcript: String, responseType: T.Type) async throws -> AnalyzeEnvelope<T> {
        guard let url = URL(string: "\(baseURL)/analyze") else {
            throw AnalysisError.invalidURL
        }
        
        let requestBody = [
            "mode": mode.rawValue,
            "transcript": transcript
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12.0
        
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
    func analyzeTLDR(transcript: String) async throws -> AnalyzeEnvelope<TLDRData> {
        return try await analyze(mode: .tldr, transcript: transcript, responseType: TLDRData.self)
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
}