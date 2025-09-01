import Foundation

public enum AnalysisMode: String, Codable, CaseIterable {
    case distill, analysis, themes, todos
    
    var displayName: String {
        switch self {
        case .distill: return "Distill"
        case .analysis: return "Analysis"
        case .themes: return "Themes"
        case .todos: return "To Do"
        }
    }
    
    var iconName: String {
        switch self {
        case .distill: return "drop.fill"
        case .analysis: return "magnifyingglass.circle"
        case .themes: return "tag.circle"
        case .todos: return "checkmark.circle.fill"
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

public struct DistillData: Codable {
    public let summary: String
    public let action_items: [ActionItem]?
    public let key_themes: [String]
    public let reflection_questions: [String]
    
    public struct ActionItem: Codable {
        public let text: String
        public let priority: Priority
        
        public enum Priority: String, Codable {
            case high, medium, low
            
            var color: String {
                switch self {
                case .high: return "red"
                case .medium: return "orange"
                case .low: return "green"
                }
            }
        }
    }
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
