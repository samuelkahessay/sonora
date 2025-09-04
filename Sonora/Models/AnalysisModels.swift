import Foundation

public enum AnalysisMode: String, Codable, CaseIterable, Sendable {
    case distill, analysis, themes, todos
    
    // Individual Distill Components (used internally for parallel processing)
    case distillSummary = "distill-summary"
    case distillActions = "distill-actions" 
    case distillThemes = "distill-themes"
    case distillReflection = "distill-reflection"
    
    // UI-visible analysis modes (excludes internal component modes)
    public static var uiVisibleCases: [AnalysisMode] {
        return [.distill, .analysis, .themes, .todos]
    }
    
    var displayName: String {
        switch self {
        case .distill: return "Distill"
        case .analysis: return "Analysis"
        case .themes: return "Themes"
        case .todos: return "To Do"
        case .distillSummary: return "Summary"
        case .distillActions: return "Actions"
        case .distillThemes: return "Themes"
        case .distillReflection: return "Reflection"
        }
    }
    
    var iconName: String {
        switch self {
        case .distill: return "drop.fill"
        case .analysis: return "magnifyingglass.circle"
        case .themes: return "tag.circle"
        case .todos: return "checkmark.circle.fill"
        case .distillSummary: return "text.quote"
        case .distillActions: return "checkmark.circle.fill"
        case .distillThemes: return "tag.circle"
        case .distillReflection: return "questionmark.circle"
        }
    }
    
    // Helper to check if this is a distill component mode
    var isDistillComponent: Bool {
        switch self {
        case .distillSummary, .distillActions, .distillThemes, .distillReflection:
            return true
        default:
            return false
        }
    }
}

public struct AnalyzeEnvelope<T: Codable & Sendable>: Codable, Sendable {
    public let mode: AnalysisMode
    public let data: T
    public let model: String
    public let tokens: TokenUsage
    public let latency_ms: Int
    public let moderation: ModerationResult?
}

public struct TokenUsage: Codable, Sendable {
    public let input: Int
    public let output: Int
}

public struct DistillData: Codable, Sendable {
    public let summary: String
    public let action_items: [ActionItem]?
    public let key_themes: [String]
    public let reflection_questions: [String]
    
    public struct ActionItem: Codable, Sendable {
        public let text: String
        public let priority: Priority
        
        public enum Priority: String, Codable, Sendable {
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

// Individual Distill Component Data Models for Parallel Processing
public struct DistillSummaryData: Codable, Sendable {
    public let summary: String
}

public struct DistillActionsData: Codable, Sendable {
    public let action_items: [DistillData.ActionItem]
}

public struct DistillThemesData: Codable, Sendable {
    public let key_themes: [String]
}

public struct DistillReflectionData: Codable, Sendable {
    public let reflection_questions: [String]
}


public struct AnalysisData: Codable, Sendable {
    public let summary: String
    public let key_points: [String]
}

public struct ThemesData: Codable, Sendable {
    public struct Theme: Codable, Sendable {
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

public struct TodosData: Codable, Sendable {
    public struct Todo: Codable, Sendable {
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
