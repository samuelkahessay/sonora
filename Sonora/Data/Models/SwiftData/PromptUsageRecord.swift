import Foundation
import SwiftData

@Model
final class PromptUsageRecord {
    // Unique prompt identifier
    @Attribute(.unique)
    var promptId: String

    // Telemetry fields
    var lastShownAt: Date?
    var lastUsedAt: Date?
    var useCount: Int
    var isFavorite: Bool

    // Admin/migration
    var createdAt: Date
    var updatedAt: Date
    var version: Int

    init(
        promptId: String,
        lastShownAt: Date? = nil,
        lastUsedAt: Date? = nil,
        useCount: Int = 0,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1
    ) {
        self.promptId = promptId
        self.lastShownAt = lastShownAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }
}
