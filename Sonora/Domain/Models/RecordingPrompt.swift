import Foundation

// MARK: - Prompt Taxonomy

public enum PromptCategory: String, CaseIterable, Sendable {
    case growth
    case work
    case relationships
    case creative
    case goals
    case mindfulness
}

public enum EmotionalDepth: Int, CaseIterable, Sendable {
    case light = 1
    case medium = 2
    case deep = 3
}

public enum DayPart: String, CaseIterable, Sendable, Hashable {
    case morning
    case afternoon
    case evening
    case night
}

public enum WeekPart: String, CaseIterable, Sendable, Hashable {
    case startOfWeek
    case midWeek
    case endOfWeek
}

public extension DayPart {
    static let any: Set<DayPart> = Set(DayPart.allCases)
}

public extension WeekPart {
    static let any: Set<WeekPart> = Set(WeekPart.allCases)
}

// MARK: - Domain Model

/// Domain model for user-facing recording prompts.
/// Pure Swift type; localization and token interpolation occur outside this layer.
public struct RecordingPrompt: Identifiable, Equatable, Hashable, Sendable {
    public let id: String               // stable, non-localized identifier
    public let localizationKey: String  // e.g., "prompt.growth.micro-win-today"
    public let category: PromptCategory
    public let emotionalDepth: EmotionalDepth
    public let allowedDayParts: Set<DayPart>
    public let allowedWeekParts: Set<WeekPart>
    public let weight: Int              // analytics/selection weighting (>=1)
    public let metadata: [String: String]

    public init(
        id: String,
        localizationKey: String,
        category: PromptCategory,
        emotionalDepth: EmotionalDepth,
        allowedDayParts: Set<DayPart> = DayPart.any,
        allowedWeekParts: Set<WeekPart> = WeekPart.any,
        weight: Int = 1,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.localizationKey = localizationKey
        self.category = category
        self.emotionalDepth = emotionalDepth
        self.allowedDayParts = allowedDayParts
        self.allowedWeekParts = allowedWeekParts
        self.weight = max(1, weight)
        self.metadata = metadata
    }
}
