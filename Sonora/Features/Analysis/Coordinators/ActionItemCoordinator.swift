import Foundation
import SwiftUI

@MainActor
final class ActionItemCoordinator: ObservableObject {
    // Permission service
    @Published var permissionService: EventKitPermissionService

    // Destination caches
    @Published var availableCalendars: [CalendarDTO] = []
    @Published var defaultCalendar: CalendarDTO?
    @Published var availableReminderLists: [CalendarDTO] = []
    @Published var defaultReminderList: CalendarDTO?
    // UI records for "Added" confirmations
    @Published var addedRecords: [DistillAddedRecord] = []

    // Handled persistence
    private var handledStore = DistillHandledDetectionsStore()

    init() {
        if let concrete = DIContainer.shared.eventKitPermissionService() as? EventKitPermissionService {
            self.permissionService = concrete
        } else {
            self.permissionService = EventKitPermissionService()
        }
    }

    struct DestinationsResult {
        let didLoadCalendars: Bool
        let didLoadReminderLists: Bool
    }

    func ensureCalendarPermission() async throws {
        await permissionService.checkCalendarPermission(ignoreCache: true)
        if permissionService.calendarPermissionState.isAuthorized { return }
        if permissionService.calendarPermissionState.canRequest { _ = try await permissionService.requestCalendarAccess() }
        if !permissionService.calendarPermissionState.isAuthorized { throw EventKitError.permissionDenied(type: .calendar) }
    }

    func ensureReminderPermission() async throws {
        await permissionService.checkReminderPermission(ignoreCache: true)
        if permissionService.reminderPermissionState.isAuthorized { return }
        if permissionService.reminderPermissionState.canRequest { _ = try await permissionService.requestReminderAccess() }
        if !permissionService.reminderPermissionState.isAuthorized { throw EventKitError.permissionDenied(type: .reminder) }
    }

    func loadDestinationsIfNeeded(for items: [ActionItemDetectionUI], calendarsLoaded: Bool, reminderListsLoaded: Bool) async throws -> DestinationsResult {
        var didLoadCal = false
        var didLoadRem = false
        if items.contains(where: { $0.kind == .event }) && !calendarsLoaded {
            let repo = DIContainer.shared.eventKitRepository()
            availableCalendars = try await repo.getCalendars()
            defaultCalendar = try await repo.getDefaultCalendar() ?? availableCalendars.first
            didLoadCal = true
        }
        if items.contains(where: { $0.kind == .reminder }) && !reminderListsLoaded {
            let repo = DIContainer.shared.eventKitRepository()
            availableReminderLists = try await repo.getReminderLists()
            defaultReminderList = try await repo.getDefaultReminderList() ?? availableReminderLists.first
            didLoadRem = true
        }
        return DestinationsResult(didLoadCalendars: didLoadCal, didLoadReminderLists: didLoadRem)
    }

    func createEvent(for item: ActionItemDetectionUI, base: EventsData.DetectedEvent, in calendar: CalendarDTO?) async throws -> String {
        let event = buildEventPayload(from: item, base: base)
        let repo = DIContainer.shared.eventKitRepository()
        let suggested = try await repo.suggestCalendar(for: event)
        let cal = calendar ?? suggested ?? defaultCalendar ?? availableCalendars.first
        guard let cal else { throw EventKitError.calendarNotFound(identifier: "default") }
        return try await DIContainer.shared.createCalendarEventUseCase().execute(event: event, calendar: cal)
    }

    func createReminder(for item: ActionItemDetectionUI, base: RemindersData.DetectedReminder, in list: CalendarDTO?) async throws -> String {
        let reminder = buildReminderPayload(from: item, base: base)
        let repo = DIContainer.shared.eventKitRepository()
        let suggested = try await repo.suggestReminderList(for: reminder)
        let dest = list ?? suggested ?? defaultReminderList ?? availableReminderLists.first
        guard let dest else { throw EventKitError.reminderListNotFound(identifier: "default") }
        return try await DIContainer.shared.createReminderUseCase().execute(reminder: reminder, list: dest)
    }

    func makeAddedRecord(for item: ActionItemDetectionUI, date: Date?) -> DistillAddedRecord {
        let dateText = date.map { formatShortDate($0) }
        let prefix = item.kind == .event ? "Added event to calendar" : "Added reminder"
        let quotedTitle = "“\(item.title)”"
        let text: String = dateText.map { "\(prefix) \(quotedTitle) for \($0)" } ?? "\(prefix) \(quotedTitle)"
        let key = DetectionKeyBuilder.forUI(kind: item.kind, sourceQuote: item.sourceQuote, fallbackTitle: item.title, date: date)
        return DistillAddedRecord(id: key, text: text)
    }

    func recordHandled(_ record: DistillAddedRecord, for memoId: UUID?) {
        guard let memoId else { return }
        handledStore.add(record.id, message: record.text, for: memoId)
    }

    func removeHandled(for item: ActionItemDetectionUI, memoId: UUID?) {
        guard let memoId else { return }
        let key = DetectionKeyBuilder.forUI(kind: item.kind, sourceQuote: item.sourceQuote, fallbackTitle: item.title, date: item.suggestedDate)
        handledStore.remove(key, for: memoId)
    }

    func restoreHandled(for memoId: UUID?) {
        guard let memoId else { addedRecords = []; return }
        let entries = handledStore.messages(for: memoId)
        addedRecords = entries.map { DistillAddedRecord(id: $0.id, text: $0.message) }
    }

    func upsertAndPersist(record: DistillAddedRecord, memoId: UUID?) {
        addedRecords.removeAll { $0.id == record.id }
        addedRecords.append(record)
        recordHandled(record, for: memoId)
    }

    func removeRecord(for item: ActionItemDetectionUI, memoId: UUID?) {
        let date: Date? = {
            if let d = item.suggestedDate { return d }
            switch item.kind {
            case .event:
                return nil // Caller may not have base here; this path is rarely used.
            case .reminder:
                return nil
            }
        }()
        let key = DetectionKeyBuilder.forUI(kind: item.kind, sourceQuote: item.sourceQuote, fallbackTitle: item.title, date: date)
        addedRecords.removeAll { $0.id == key }
        removeHandled(for: item, memoId: memoId)
    }
}
