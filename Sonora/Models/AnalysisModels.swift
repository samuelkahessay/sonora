import Foundation

public enum AnalysisMode: String, Codable, CaseIterable {
    case tldr, analysis, themes, todos
    
    var displayName: String {
        switch self {
        case .tldr: return "TLDR"
        case .analysis: return "Analysis"
        case .themes: return "Themes"
        case .todos: return "Todos"
        }
    }
    
    var iconName: String {
        switch self {
        case .tldr: return "text.quote"
        case .analysis: return "magnifyingglass.circle"
        case .themes: return "tag.circle"
        case .todos: return "checkmark.circle"
        }
    }
}

public struct AnalyzeEnvelope<T: Codable>: Codable {
    public let mode: AnalysisMode
    public let data: T
    public let model: String
    public let tokens: TokenUsage
    public let latency_ms: Int
}

public struct TokenUsage: Codable {
    public let input: Int
    public let output: Int
}

public struct TLDRData: Codable {
    public let summary: String
    public let key_points: [String]
}

public struct AnalysisData: Codable {
    public let summary: String
    public let key_points: [String]
}

public struct ThemesData: Codable {
    public struct Theme: Codable {
        public let name: String
        public let evidence: [String]
    }
    public let themes: [Theme]
    public let sentiment: String
    
    var sentimentColor: String {
        switch sentiment.lowercased() {
        case "positive": return "green"
        case "negative": return "red" 
        case "mixed": return "orange"
        default: return "gray"
        }
    }
}

public struct TodosData: Codable {
    public struct Todo: Codable {
        public let text: String
        public let due: String?
        
        var dueDate: Date? {
            guard let due = due else { return nil }
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: due)
        }
    }
    public let todos: [Todo]
}

enum AnalysisError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(String)
    case serverError(Int)
    case timeout
    case networkError(String)
    case emptyTranscript
    case transcriptTooShort
    case analysisServiceError(String)
    case invalidResponse
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .serverError(let code):
            return "Server error (\(code))"
        case .timeout:
            return "Request timed out"
        case .networkError(let message):
            return "Network error: \(message)"
        case .emptyTranscript:
            return "Transcript is empty or contains only whitespace"
        case .transcriptTooShort:
            return "Transcript is too short for meaningful analysis"
        case .analysisServiceError(let message):
            return "Analysis service error: \(message)"
        case .invalidResponse:
            return "Invalid response from analysis service"
        case .serviceUnavailable:
            return "Analysis service is currently unavailable"
        }
    }
}