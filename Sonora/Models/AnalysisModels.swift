import Foundation

public enum AnalysisMode: String, Codable, CaseIterable, Sendable {
    case distill, events, reminders

    // Free tier analysis mode
    case liteDistill = "lite-distill"

    // Individual Distill Components (used internally for parallel processing)
    case distillSummary = "distill-summary"
    case distillActions = "distill-actions"
    case distillThemes = "distill-themes"
    case distillReflection = "distill-reflection"

    // UI-visible analysis modes (excludes internal component modes)
    public static var uiVisibleCases: [Self] {
        [.distill, .events, .reminders]
    }

    // Free tier modes (visible to free users)
    public static var freeTierCases: [Self] {
        [.liteDistill]
    }

    // Pro tier modes (requires subscription)
    public static var proTierCases: [Self] {
        [.distill, .events, .reminders]
    }

    var displayName: String {
        switch self {
        case .distill: return "Distill"
        case .liteDistill: return "Clarity"
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
        case .liteDistill: return "lightbulb.fill"
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
    // Core fields (all tiers)
    public let summary: String
    public let action_items: [ActionItem]?
    public let reflection_questions: [String]
    public let patterns: [Pattern]?
    public let events: [EventsData.DetectedEvent]?
    public let reminders: [RemindersData.DetectedReminder]?

    public struct ActionItem: Codable, Sendable, Equatable {
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
        public let text: String
        public let priority: Priority
    }

    public struct Pattern: Codable, Sendable, Identifiable, Equatable {
        public let id: String
        public let theme: String
        public let description: String
        public let relatedMemos: [RelatedMemo]?
        public let confidence: Float

        public struct RelatedMemo: Codable, Sendable, Equatable {
            public let memoId: String?
            public let title: String
            public let daysAgo: Int?
            public let snippet: String?

            public init(memoId: String? = nil, title: String, daysAgo: Int? = nil, snippet: String? = nil) {
                self.memoId = memoId
                self.title = title
                self.daysAgo = daysAgo
                self.snippet = snippet
            }
        }

        public init(id: String = UUID().uuidString, theme: String, description: String, relatedMemos: [RelatedMemo]? = nil, confidence: Float = 0.8) {
            self.id = id
            self.theme = theme
            self.description = description
            self.relatedMemos = relatedMemos
            self.confidence = confidence
        }
    }

    public init(
        summary: String,
        action_items: [ActionItem]?,
        reflection_questions: [String],
        patterns: [Pattern]? = nil,
        events: [EventsData.DetectedEvent]? = nil,
        reminders: [RemindersData.DetectedReminder]? = nil
    ) {
        self.summary = summary
        self.action_items = action_items
        self.reflection_questions = reflection_questions
        self.patterns = patterns
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

// MARK: - EventKit Data Models

public struct EventsData: Codable, Sendable {
    public struct DetectedEvent: Codable, Sendable, Identifiable {
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
        public struct Recurrence: Codable, Sendable, Equatable {
            public struct End: Codable, Sendable, Equatable {
                public let until: Date?
                public let count: Int?

                public init(until: Date? = nil, count: Int? = nil) {
                    self.until = until
                    self.count = count
                }
            }

            public let frequency: String       // daily|weekly|monthly|yearly
            public let interval: Int?          // default 1
            public let byWeekday: [String]?    // Mon..Sun (weekly only)
            public let end: End?

            public init(
                frequency: String,
                interval: Int? = nil,
                byWeekday: [String]? = nil,
                end: End? = nil
            ) {
                self.frequency = frequency
                self.interval = interval
                self.byWeekday = byWeekday
                self.end = end
            }
        }

        public let id: String
        public let title: String
        public let startDate: Date?
        public let endDate: Date?
        public let location: String?
        public let participants: [String]?
        public let confidence: Float
        public let sourceText: String
        public let memoId: UUID?
        public let recurrence: Recurrence?

        public init(
            id: String = UUID().uuidString,
            title: String,
            startDate: Date? = nil,
            endDate: Date? = nil,
            location: String? = nil,
            participants: [String]? = nil,
            confidence: Float,
            sourceText: String,
            memoId: UUID? = nil,
            recurrence: Recurrence? = nil
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
            self.recurrence = recurrence
        }

        // Confidence categories for UI
        public var confidenceCategory: ConfidenceLevel {
            switch confidence {
            case 0.8...1.0: return .high
            case 0.6..<0.8: return .medium
            default: return .low
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

// MARK: - Free Tier Analysis Models

/// Personal insight for free tier - creates the "aha moment"
/// One insight per session, rotated across different types for variety
public struct PersonalInsight: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let type: InsightType
    public let observation: String
    public let invitation: String?

    public enum InsightType: String, Codable, Sendable, Equatable {
        case emotionalTone      // "Your tone suggests curiosity mixed with concern"
        case wordPattern        // "You mentioned 'should' 4 times—notice that?"
        case valueGlimpse       // "Authenticity seems important to you here"
        case energyShift        // "Your energy shifted when talking about family"
        case stoicMoment        // "You worried about others' opinions—that's outside your control"
        case recurringPhrase    // "You said 'I don't know' three times"

        var displayName: String {
            switch self {
            case .emotionalTone: return "Emotional Tone"
            case .wordPattern: return "Word Pattern"
            case .valueGlimpse: return "Value Glimpse"
            case .energyShift: return "Energy Shift"
            case .stoicMoment: return "Stoic Moment"
            case .recurringPhrase: return "Recurring Phrase"
            }
        }

        var iconName: String {
            switch self {
            case .emotionalTone: return "heart.text.square"
            case .wordPattern: return "text.magnifyingglass"
            case .valueGlimpse: return "sparkles"
            case .energyShift: return "waveform.path.ecg"
            case .stoicMoment: return "laurel.leading"
            case .recurringPhrase: return "arrow.triangle.2.circlepath"
            }
        }

        var colorHint: String {
            switch self {
            case .emotionalTone: return "pink"
            case .wordPattern: return "blue"
            case .valueGlimpse: return "purple"
            case .energyShift: return "orange"
            case .stoicMoment: return "green"
            case .recurringPhrase: return "indigo"
            }
        }
    }

    public init(
        id: String = UUID().uuidString,
        type: InsightType,
        observation: String,
        invitation: String? = nil
    ) {
        self.id = id
        self.type = type
        self.observation = observation
        self.invitation = invitation
    }
}

/// Simple to-do for free tier (no EventKit integration)
public struct SimpleTodo: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let text: String
    public let priority: Priority

    public enum Priority: String, Codable, Sendable, Equatable {
        case high = "high"
        case medium = "medium"
        case low = "low"

        var color: String {
            switch self {
            case .high: return "red"
            case .medium: return "orange"
            case .low: return "green"
            }
        }

        var iconName: String {
            switch self {
            case .high: return "exclamationmark.circle.fill"
            case .medium: return "circle.fill"
            case .low: return "circle"
            }
        }
    }

    public init(
        id: String = UUID().uuidString,
        text: String,
        priority: Priority
    ) {
        self.id = id
        self.text = text
        self.priority = priority
    }
}

/// Free tier Lite Distill response - focused clarity
/// Single API call optimized for cost efficiency
public struct LiteDistillData: Codable, Sendable, Equatable {
    public let summary: String
    public let keyThemes: [String]
    public let personalInsight: PersonalInsight
    public let simpleTodos: [SimpleTodo]
    public let reflectionQuestion: String
    public let closingNote: String

    public init(
        summary: String,
        keyThemes: [String],
        personalInsight: PersonalInsight,
        simpleTodos: [SimpleTodo],
        reflectionQuestion: String,
        closingNote: String
    ) {
        self.summary = summary
        self.keyThemes = keyThemes
        self.personalInsight = personalInsight
        self.simpleTodos = simpleTodos
        self.reflectionQuestion = reflectionQuestion
        self.closingNote = closingNote
    }
}
