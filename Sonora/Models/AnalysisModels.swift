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
    public let moderation: ModerationResult?
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
