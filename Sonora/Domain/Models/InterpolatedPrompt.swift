import Foundation

public struct InterpolatedPrompt: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let text: String
    public let category: PromptCategory
    public let emotionalDepth: EmotionalDepth
    public let dayPart: DayPart
    public let weekPart: WeekPart

    public init(id: String, text: String, category: PromptCategory, emotionalDepth: EmotionalDepth, dayPart: DayPart, weekPart: WeekPart) {
        self.id = id
        self.text = text
        self.category = category
        self.emotionalDepth = emotionalDepth
        self.dayPart = dayPart
        self.weekPart = weekPart
    }
}

