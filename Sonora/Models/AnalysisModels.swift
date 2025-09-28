import Foundation

public enum AnalysisMode: String, Codable, CaseIterable, Sendable {
    case distill, analysis, themes, todos, events, reminders
    
    // Individual Distill Components (used internally for parallel processing)
    case distillSummary = "distill-summary"
    case distillActions = "distill-actions" 
    case distillThemes = "distill-themes"
    case distillReflection = "distill-reflection"
    
    // UI-visible analysis modes (excludes internal component modes)
    public static var uiVisibleCases: [AnalysisMode] {
        return [.distill, .analysis, .themes, .todos, .events, .reminders]
    }
    
    var displayName: String {
        switch self {
        case .distill: return "Distill"
        case .analysis: return "Analysis"
        case .themes: return "Themes"
        case .todos: return "To Do"
        case .events: return "Events"
        case .reminders: return "Reminders"
        case .distillSummary: return "Summary"
        case .distillActions: return "Actions"
        case .distillThemes: return "Themes"
        case .distillReflection: return "Reflection"
        }
    }
    
    var iconName: String {
        switch self {
        case .distill: return "sparkles"
        case .analysis: return "magnifyingglass.circle"
        case .themes: return "tag.circle"
        case .todos: return "checkmark.circle.fill"
        case .events: return "calendar.badge.plus"
        case .reminders: return "bell.badge"
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
    public let reflection_questions: [String]
    public let events: [EventsData.DetectedEvent]?
    public let reminders: [RemindersData.DetectedReminder]?
    
    public struct ActionItem: Codable, Sendable, Equatable {
        public let text: String
        public let priority: Priority
        
        public enum Priority: String, Codable, Sendable, Equatable {
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
    public init(summary: String, action_items: [ActionItem]?, reflection_questions: [String], events: [EventsData.DetectedEvent]? = nil, reminders: [RemindersData.DetectedReminder]? = nil) {
        self.summary = summary
        self.action_items = action_items
        self.reflection_questions = reflection_questions
        self.events = events
        self.reminders = reminders
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

// MARK: - EventKit Data Models

public struct EventsData: Codable, Sendable {
    public struct DetectedEvent: Codable, Sendable, Identifiable {
        public let id: String
        public let title: String
        public let startDate: Date?
        public let endDate: Date?
        public let location: String?
        public let participants: [String]?
        public let confidence: Float
        public let sourceText: String
        public let memoId: UUID?
        
        public init(
            id: String = UUID().uuidString,
            title: String,
            startDate: Date? = nil,
            endDate: Date? = nil,
            location: String? = nil,
            participants: [String]? = nil,
            confidence: Float,
            sourceText: String,
            memoId: UUID? = nil
        ) {
            self.id = id
            self.title = title
            self.startDate = startDate
            self.endDate = endDate
            self.location = location
            self.participants = participants
            self.confidence = confidence
            self.sourceText = sourceText
            self.memoId = memoId
        }
        
        // Confidence categories for UI
        public var confidenceCategory: ConfidenceLevel {
            switch confidence {
            case 0.8...1.0: return .high
            case 0.6..<0.8: return .medium
            default: return .low
            }
        }
        
        public enum ConfidenceLevel: String, CaseIterable {
            case high = "High"
            case medium = "Medium" 
            case low = "Low"
            
            var color: String {
                switch self {
                case .high: return "green"
                case .medium: return "orange"
                case .low: return "red"
                }
            }
        }
    }
    
    public let events: [DetectedEvent]
    
    public init(events: [DetectedEvent]) {
        self.events = events
    }
}

public struct RemindersData: Codable, Sendable {
    public struct DetectedReminder: Codable, Sendable, Identifiable {
        public let id: String
        public let title: String
        public let dueDate: Date?
        public let priority: Priority
        public let confidence: Float
        public let sourceText: String
        public let memoId: UUID?
        
        public init(
            id: String = UUID().uuidString,
            title: String,
            dueDate: Date? = nil,
            priority: Priority = .medium,
            confidence: Float,
            sourceText: String,
            memoId: UUID? = nil
        ) {
            self.id = id
            self.title = title
            self.dueDate = dueDate
            self.priority = priority
            self.confidence = confidence
            self.sourceText = sourceText
            self.memoId = memoId
        }
        
        public enum Priority: String, Codable, Sendable, CaseIterable {
            case high = "High"
            case medium = "Medium"
            case low = "Low"
            
            var color: String {
                switch self {
                case .high: return "red"
                case .medium: return "orange"
                case .low: return "green"
                }
            }
            
            var sortOrder: Int {
                switch self {
                case .high: return 0
                case .medium: return 1
                case .low: return 2
                }
            }
        }
        
        // Convenience computed property for confidence level
        public var confidenceCategory: EventsData.DetectedEvent.ConfidenceLevel {
            switch confidence {
            case 0.8...1.0: return .high
            case 0.6..<0.8: return .medium
            default: return .low
            }
        }
    }
    
    public let reminders: [DetectedReminder]
    
    public init(reminders: [DetectedReminder]) {
        self.reminders = reminders
    }
}
