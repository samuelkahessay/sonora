import Foundation

// Typed analysis payload used by Presentation and ViewModels
// Replaces Any-based result/envelope passing in the UI layer.
enum AnalysisResultPayload: Sendable {
    case distill(DistillData, AnalyzeEnvelope<DistillData>)
    case analysis(AnalysisData, AnalyzeEnvelope<AnalysisData>)
    case themes(ThemesData, AnalyzeEnvelope<ThemesData>)
    case todos(TodosData, AnalyzeEnvelope<TodosData>)
    // Event/Reminder detection paths are data-only (no AnalyzeEnvelope)
    case events(EventsData)
    case reminders(RemindersData)

    var mode: AnalysisMode {
        switch self {
        case .distill: return .distill
        case .analysis: return .analysis
        case .themes: return .themes
        case .todos: return .todos
        case .events: return .events
        case .reminders: return .reminders
        }
    }

    // Whether the underlying envelope was moderation flagged (if available)
    var isModerationFlagged: Bool {
        switch self {
        case .distill(_, let env):
            return env.moderation?.flagged ?? false
        case .analysis(_, let env):
            return env.moderation?.flagged ?? false
        case .themes(_, let env):
            return env.moderation?.flagged ?? false
        case .todos(_, let env):
            return env.moderation?.flagged ?? false
        case .events, .reminders:
            return false
        }
    }
}
