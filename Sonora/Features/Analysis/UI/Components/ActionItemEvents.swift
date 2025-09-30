import Foundation

enum ActionItemEvent {
    case editToggle(id: UUID)
    case add(item: ActionItemDetectionUI)
    case dismiss(id: UUID)
}

enum ActionItemHostEvent {
    case item(ActionItemEvent)
    case openBatch(selected: Set<UUID>)
    case addSelected(items: [ActionItemDetectionUI], calendar: CalendarDTO?, reminderList: CalendarDTO?)
    case dismissSheet
}
