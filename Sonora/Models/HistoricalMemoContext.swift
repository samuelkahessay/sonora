import Foundation

/// Lightweight historical memo context for pattern detection
/// Sent to server to enable cross-memo pattern analysis
public struct HistoricalMemoContext: Codable, Sendable, Equatable {
    public let memoId: String
    public let title: String
    public let daysAgo: Int
    public let summary: String?
    public let themes: [String]?

    public init(
        memoId: String,
        title: String,
        daysAgo: Int,
        summary: String? = nil,
        themes: [String]? = nil
    ) {
        self.memoId = memoId
        self.title = title
        self.daysAgo = daysAgo
        self.summary = summary
        self.themes = themes
    }
}
