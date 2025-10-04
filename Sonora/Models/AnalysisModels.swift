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

    // Pro-tier analysis modes (CBT, wisdom, values)
    case cognitiveClarityCBT = "cognitive-clarity"
    case philosophicalEchoes = "philosophical-echoes"
    case valuesRecognition = "values-recognition"

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
        case .cognitiveClarityCBT: return "Cognitive Clarity"
        case .philosophicalEchoes: return "Philosophical Echoes"
        case .valuesRecognition: return "Values Recognition"
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
        case .cognitiveClarityCBT: return "brain.head.profile"
        case .philosophicalEchoes: return "book.closed"
        case .valuesRecognition: return "heart.circle"
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

    // Pro-tier fields (parallel API calls for enhanced analysis)
    public let cognitivePatterns: [CognitivePattern]?
    public let philosophicalEchoes: [PhilosophicalEcho]?
    public let valuesInsights: ValuesInsight?

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
        reminders: [RemindersData.DetectedReminder]? = nil,
        cognitivePatterns: [CognitivePattern]? = nil,
        philosophicalEchoes: [PhilosophicalEcho]? = nil,
        valuesInsights: ValuesInsight? = nil
    ) {
        self.summary = summary
        self.action_items = action_items
        self.reflection_questions = reflection_questions
        self.patterns = patterns
        self.events = events
        self.reminders = reminders
        self.cognitivePatterns = cognitivePatterns
        self.philosophicalEchoes = philosophicalEchoes
        self.valuesInsights = valuesInsights
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

// MARK: - Pro-Tier Analysis Response Data Models

/// Response wrapper for cognitive-clarity analysis (Beck/Ellis CBT patterns)
public struct CognitiveClarityData: Codable, Sendable {
    public let cognitivePatterns: [CognitivePattern]
}

/// Response wrapper for philosophical-echoes analysis (wisdom connections)
public struct PhilosophicalEchoesData: Codable, Sendable {
    public let philosophicalEchoes: [PhilosophicalEcho]
}

/// Response wrapper for values-recognition analysis (core values + tensions)
public struct ValuesRecognitionData: Codable, Sendable {
    public let coreValues: [ValuesInsight.DetectedValue]
    public let tensions: [ValuesInsight.ValueTension]?
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

// MARK: - Pro Tier Analysis Models

/// Cognitive pattern detection based on Beck/Ellis CBT framework
/// Helps users identify thinking distortions with optional reframes
/// Pro-tier feature: parallel API call for cognitive clarity
public struct CognitivePattern: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let type: CognitiveDistortion
    public let observation: String
    public let reframe: String?

    public enum CognitiveDistortion: String, Codable, Sendable, Equatable {
        case allOrNothing = "all-or-nothing"
        case catastrophizing = "catastrophizing"
        case mindReading = "mind-reading"
        case overgeneralization = "overgeneralization"
        case shouldStatements = "should-statements"
        case emotionalReasoning = "emotional-reasoning"

        var displayName: String {
            switch self {
            case .allOrNothing: return "All-or-Nothing"
            case .catastrophizing: return "Catastrophizing"
            case .mindReading: return "Mind Reading"
            case .overgeneralization: return "Overgeneralization"
            case .shouldStatements: return "Should Statements"
            case .emotionalReasoning: return "Emotional Reasoning"
            }
        }

        var iconName: String {
            switch self {
            case .allOrNothing: return "line.diagonal"
            case .catastrophizing: return "exclamationmark.triangle"
            case .mindReading: return "bubble.left.and.bubble.right"
            case .overgeneralization: return "arrow.triangle.branch"
            case .shouldStatements: return "hand.raised"
            case .emotionalReasoning: return "heart.circle"
            }
        }

        var description: String {
            switch self {
            case .allOrNothing:
                return "Seeing things in black-and-white categories"
            case .catastrophizing:
                return "Expecting the worst-case scenario"
            case .mindReading:
                return "Assuming you know what others think"
            case .overgeneralization:
                return "Drawing broad conclusions from single events"
            case .shouldStatements:
                return "Using 'should', 'must', 'ought' creates pressure"
            case .emotionalReasoning:
                return "Believing feelings reflect reality"
            }
        }
    }

    public init(
        id: String = UUID().uuidString,
        type: CognitiveDistortion,
        observation: String,
        reframe: String? = nil
    ) {
        self.id = id
        self.type = type
        self.observation = observation
        self.reframe = reframe
    }
}

/// Connection between user insights and ancient wisdom traditions
/// Links personal reflections to 2,000+ years of philosophical thought
/// Pro-tier feature: parallel API call for philosophical echoes
public struct PhilosophicalEcho: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let tradition: PhilosophicalTradition
    public let connection: String
    public let quote: String?
    public let source: String?

    public enum PhilosophicalTradition: String, Codable, Sendable, Equatable {
        case stoicism = "stoicism"
        case buddhism = "buddhism"
        case existentialism = "existentialism"
        case socratic = "socratic"

        var displayName: String {
            switch self {
            case .stoicism: return "Stoicism"
            case .buddhism: return "Buddhism"
            case .existentialism: return "Existentialism"
            case .socratic: return "Socratic Inquiry"
            }
        }

        var iconName: String {
            switch self {
            case .stoicism: return "laurel.leading"
            case .buddhism: return "leaf"
            case .existentialism: return "figure.walk"
            case .socratic: return "questionmark.bubble"
            }
        }

        var colorHint: String {
            switch self {
            case .stoicism: return "green"
            case .buddhism: return "orange"
            case .existentialism: return "purple"
            case .socratic: return "blue"
            }
        }
    }

    public init(
        id: String = UUID().uuidString,
        tradition: PhilosophicalTradition,
        connection: String,
        quote: String? = nil,
        source: String? = nil
    ) {
        self.id = id
        self.tradition = tradition
        self.connection = connection
        self.quote = quote
        self.source = source
    }
}

/// Values recognition - identifies what matters to the user
/// Detects core values and tensions between competing priorities
/// Pro-tier feature: parallel API call for values analysis
public struct ValuesInsight: Codable, Sendable, Equatable {
    public let coreValues: [DetectedValue]
    public let tensions: [ValueTension]?

    /// A value that matters to the user, detected from their voice memo
    public struct DetectedValue: Codable, Sendable, Identifiable, Equatable {
        public let id: String
        public let name: String           // e.g., "Authenticity", "Family", "Achievement"
        public let evidence: String       // What in the memo revealed this value
        public let confidence: Float      // 0.0-1.0

        public init(
            id: String = UUID().uuidString,
            name: String,
            evidence: String,
            confidence: Float
        ) {
            self.id = id
            self.name = name
            self.evidence = evidence
            self.confidence = confidence
        }

        // Confidence categories for UI
        public var confidenceCategory: String {
            switch confidence {
            case 0.8...1.0: return "High"
            case 0.6..<0.8: return "Medium"
            default: return "Low"
            }
        }
    }

    /// A tension between two competing values
    public struct ValueTension: Codable, Sendable, Identifiable, Equatable {
        public let id: String
        public let value1: String         // e.g., "Achievement"
        public let value2: String         // e.g., "Rest"
        public let observation: String    // How this tension manifests

        public init(
            id: String = UUID().uuidString,
            value1: String,
            value2: String,
            observation: String
        ) {
            self.id = id
            self.value1 = value1
            self.value2 = value2
            self.observation = observation
        }
    }

    public init(
        coreValues: [DetectedValue],
        tensions: [ValueTension]? = nil
    ) {
        self.coreValues = coreValues
        self.tensions = tensions
    }
}
