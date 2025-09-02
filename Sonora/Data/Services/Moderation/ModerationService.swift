import Foundation

@MainActor
final class ModerationService: ObservableObject, ModerationServiceProtocol {
    private let config = AppConfiguration.shared
    
    func moderate(text: String) async throws -> ModerationResult {
        let url = config.apiBaseURL.appendingPathComponent("moderate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        let body: [String: Any] = ["text": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AnalysisError.serverError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let result = try JSONDecoder().decode(ModerationResult.self, from: data)
        return result
    }
}

