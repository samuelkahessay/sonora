import Foundation

public struct TranscriptionMetadata: Codable, Sendable {
    // Identification and state (fallback fields)
    public var memoId: UUID?
    public var state: String?
    public var text: String?
    public var originalText: String?
    public var lastUpdated: Date?

    // Quality and language
    public var detectedLanguage: String?
    public var qualityScore: Double?

    // Source and model
    public var transcriptionService: TranscriptionServiceType?
    public var timestamp: Date?

    // Moderation/flags
    public var aiGenerated: Bool?
    public var moderationFlagged: Bool?
    public var moderationCategories: [String: Bool]?
    public var isPrivate: Bool?
    public var lastOpenedAt: Date?

    public init(
        memoId: UUID? = nil,
        state: String? = nil,
        text: String? = nil,
        originalText: String? = nil,
        lastUpdated: Date? = nil,
        detectedLanguage: String? = nil,
        qualityScore: Double? = nil,
        transcriptionService: TranscriptionServiceType? = nil,
        timestamp: Date? = nil,
        aiGenerated: Bool? = nil,
        moderationFlagged: Bool? = nil,
        moderationCategories: [String: Bool]? = nil,
        isPrivate: Bool? = nil,
        lastOpenedAt: Date? = nil
    ) {
        self.memoId = memoId
        self.state = state
        self.text = text
        self.originalText = originalText
        self.lastUpdated = lastUpdated
        self.detectedLanguage = detectedLanguage
        self.qualityScore = qualityScore
        self.transcriptionService = transcriptionService
        self.timestamp = timestamp
        self.aiGenerated = aiGenerated
        self.moderationFlagged = moderationFlagged
        self.moderationCategories = moderationCategories
        self.isPrivate = isPrivate
        self.lastOpenedAt = lastOpenedAt
    }
}

public extension TranscriptionMetadata {
    func merging(_ other: TranscriptionMetadata) -> TranscriptionMetadata {
        return TranscriptionMetadata(
            memoId: other.memoId ?? memoId,
            state: other.state ?? state,
            text: other.text ?? text,
            originalText: other.originalText ?? originalText,
            lastUpdated: other.lastUpdated ?? lastUpdated,
            detectedLanguage: other.detectedLanguage ?? detectedLanguage,
            qualityScore: other.qualityScore ?? qualityScore,
            transcriptionService: other.transcriptionService ?? transcriptionService,
            timestamp: other.timestamp ?? timestamp,
            aiGenerated: other.aiGenerated ?? aiGenerated,
            moderationFlagged: other.moderationFlagged ?? moderationFlagged,
            moderationCategories: other.moderationCategories ?? moderationCategories,
            isPrivate: other.isPrivate ?? isPrivate,
            lastOpenedAt: other.lastOpenedAt ?? lastOpenedAt
        )
    }
}
