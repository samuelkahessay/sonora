import Foundation

public struct ModerationResult: Codable, Sendable {
    public let flagged: Bool
    public let categories: [String: Bool]?
    public let category_scores: [String: Double]?
}
