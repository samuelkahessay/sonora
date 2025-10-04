import Foundation

// Typed analysis payload used by Presentation and ViewModels
// Replaces Any-based result/envelope passing in the UI layer.
enum AnalysisResultPayload: Sendable {
    case distill(DistillData, AnalyzeEnvelope<DistillData>)
    case liteDistill(LiteDistillData, AnalyzeEnvelope<LiteDistillData>)
    // Event/Reminder detection paths are data-only (no AnalyzeEnvelope)
    case events(EventsData)
    case reminders(RemindersData)

    var mode: AnalysisMode {
        switch self {
        case .distill: return .distill
        case .liteDistill: return .distill  // Map to .distill mode for UI consistency
        case .events: return .events
        case .reminders: return .reminders
        }
    }

    // Whether the underlying envelope was moderation flagged (if available)
    var isModerationFlagged: Bool {
        switch self {
        case .distill(_, let env):
            return env.moderation?.flagged ?? false
        case .liteDistill(_, let env):
            return env.moderation?.flagged ?? false
        case .events, .reminders:
            return false
        }
    }
}
