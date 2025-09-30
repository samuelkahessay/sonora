import Foundation
import SwiftUI

// UI-only consolidated detection state for Distill results
struct ActionItemDetectionState {
    // Core
    var items: [ActionItemDetection] = []
    var dismissed: Set<UUID> = []
    var added: Set<UUID> = []
    var editing: Set<UUID> = []
    var processing: Set<UUID> = []
    var addedRecords: [DistillAddedRecord] = []

    // Memo context for persistence
    var currentMemoId: UUID?
    private var restoredAddedRecords = false

    // Sources/artifacts
    var eventSources: [UUID: EventsData.DetectedEvent] = [:]
    var reminderSources: [UUID: RemindersData.DetectedReminder] = [:]
    var createdArtifacts: [UUID: DistillCreatedArtifact] = [:]
    var handledStore = DistillHandledDetectionsStore()

    // Destinations/permissions (loaded lazily)
    var availableCalendars: [CalendarDTO] = []
    var availableReminderLists: [CalendarDTO] = []
    var defaultCalendar: CalendarDTO?
    var defaultReminderList: CalendarDTO?
    var calendarsLoaded = false
    var reminderListsLoaded = false

    // Batch UI
    var showBatchSheet: Bool = false
    var batchInclude: Set<UUID> = []

    // External pending indicator (set by host when streaming)
    var isPending: Bool = false

    // Mapping from stable sourceId to UI identity for SwiftUI/sets
    private var uiIdBySource: [String: UUID] = [:]

    // MARK: - Computed
    var visibleItems: [ActionItemDetectionUI] {
        // Build presentation models from domain + flags
        let uiModels: [ActionItemDetectionUI] = items.compactMap { det in
            guard let uiId = uiIdBySource[det.sourceId] else { return nil }
            let flags = (
                isEditing: editing.contains(uiId),
                isAdded: added.contains(uiId),
                isDismissed: dismissed.contains(uiId),
                isProcessing: processing.contains(uiId)
            )
            return ActionItemDetectionUI.fromDomain(det, id: uiId, flags: flags)
        }
        return uiModels
            .filter { !dismissed.contains($0.id) && !added.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.confidence != rhs.confidence { return order(lhs.confidence) < order(rhs.confidence) }
                if let ld = lhs.suggestedDate, let rd = rhs.suggestedDate { return ld < rd }
                return false
            }
    }

    var reviewCount: Int { visibleItems.count }

    private func order(_ c: ActionItemConfidence) -> Int { c == .high ? 0 : (c == .medium ? 1 : 2) }

    // MARK: - Mutators / Helpers
    mutating func mergeFrom(events: [EventsData.DetectedEvent], reminders: [RemindersData.DetectedReminder], memoId: UUID?) {
        currentMemoId = memoId

        let existingBySource = Dictionary(uniqueKeysWithValues: items.map { ($0.sourceId, $0) })

        var mergedItems: [ActionItemDetection] = []
        var newEventSources: [UUID: EventsData.DetectedEvent] = [:]
        var newReminderSources: [UUID: RemindersData.DetectedReminder] = [:]

        if !restoredAddedRecords {
            if let memoId {
                let stored = handledStore.messages(for: memoId)
                addedRecords = stored.map { DistillAddedRecord(id: $0.id, text: $0.message) }
            } else {
                addedRecords = []
            }
            restoredAddedRecords = true
        }

        var newUiIdBySource: [String: UUID] = uiIdBySource

        for event in events {
            var base = ActionItemDetection.fromEvent(event)
            if base.memoId == nil { base.memoId = memoId ?? event.memoId }
            let merged = merge(base: base, existing: existingBySource[event.id])
            mergedItems.append(merged)
            // assign or reuse UI id for this source
            let uiId = newUiIdBySource[merged.sourceId] ?? UUID()
            newUiIdBySource[merged.sourceId] = uiId
            newEventSources[uiId] = event
        }

        for reminder in reminders {
            var base = ActionItemDetection.fromReminder(reminder)
            if base.memoId == nil { base.memoId = memoId ?? reminder.memoId }
            let merged = merge(base: base, existing: existingBySource[reminder.id])
            mergedItems.append(merged)
            let uiId = newUiIdBySource[merged.sourceId] ?? UUID()
            newUiIdBySource[merged.sourceId] = uiId
            newReminderSources[uiId] = reminder
        }

        let filtered = mergedItems.filter { det in
            guard let memoId = det.memoId else { return true }
            return !handledStore.contains(det.sourceId, for: memoId)
        }

        items = filtered
        uiIdBySource = newUiIdBySource.filter { key, _ in filtered.contains { $0.sourceId == key } }
        eventSources = newEventSources
        reminderSources = newReminderSources
    }

    mutating func toggleEdit(_ id: UUID) {
        if editing.contains(id) { editing.remove(id) } else { editing.insert(id) }
    }

    mutating func dismiss(_ id: UUID) {
        dismissed.insert(id)
    }

    mutating func update(_ updated: ActionItemDetectionUI) {
        // Map back to domain by sourceId
        if let idx = items.firstIndex(where: { $0.sourceId == updated.sourceId }) {
            items[idx].kind = updated.kind
            items[idx].title = updated.title
            items[idx].suggestedDate = updated.suggestedDate
            items[idx].isAllDay = updated.isAllDay
            items[idx].location = updated.location
            items[idx].priorityLabel = updated.priorityLabel
        }
    }

    mutating func setProcessing(_ id: UUID, to value: Bool) {
        if value { processing.insert(id) } else { processing.remove(id) }
    }

    

    @MainActor
    mutating func handleSingleAdd(_ item: ActionItemDetectionUI, permissionService: EventKitPermissionService) async {
        update(item)
        setProcessing(item.id, to: true)
        defer { setProcessing(item.id, to: false) }

        do {
            let createdId: String
            switch item.kind {
            case .event:
                createdId = try await addEvent(for: item, permissionService: permissionService)
                createdArtifacts[item.id] = DistillCreatedArtifact(kind: .event, identifier: createdId)
            case .reminder:
                createdId = try await addReminder(for: item, permissionService: permissionService)
                createdArtifacts[item.id] = DistillCreatedArtifact(kind: .reminder, identifier: createdId)
            }
            added.insert(item.id)
            HapticManager.shared.playSuccess()
            appendAddedMessage(for: item)
        } catch {
            HapticManager.shared.playError()
        }
    }

    @MainActor
    mutating func undoAdd(id: UUID) async {
        guard let artifact = createdArtifacts[id] else {
            added.remove(id)
            createdArtifacts.removeValue(forKey: id)
            return
        }
        do {
            switch artifact.kind {
            case .event:
                try await DIContainer.shared.eventKitRepository().deleteEvent(with: artifact.identifier)
            case .reminder:
                try await DIContainer.shared.eventKitRepository().deleteReminder(with: artifact.identifier)
            }
            added.remove(id)
            createdArtifacts.removeValue(forKey: id)
            if let ui = visibleItems.first(where: { $0.id == id }) {
                let key = ui.sourceId
                addedRecords.removeAll { $0.id == key }
                if let memoId = ui.memoId ?? currentMemoId { handledStore.remove(key, for: memoId) }
            }
            HapticManager.shared.playSuccess()
        } catch {
            HapticManager.shared.playError()
        }
    }

    @MainActor
    mutating func handleBatchAdd(selected: [ActionItemDetectionUI], calendar: CalendarDTO?, reminderList: CalendarDTO?, permissionService: EventKitPermissionService) async {
        guard !selected.isEmpty else { return }

        selected.forEach { update($0) }
        let ids = selected.map { $0.id }
        ids.forEach { setProcessing($0, to: true) }
        defer { ids.forEach { setProcessing($0, to: false) } }

        let eventItems = selected.filter { $0.kind == .event }
        let reminderItems = selected.filter { $0.kind == .reminder }

        do {
            if !eventItems.isEmpty {
                try await ensureCalendarPermission(permissionService: permissionService)
                try await loadDestinationsIfNeeded(for: eventItems)
                let destination = calendar ?? defaultCalendar ?? availableCalendars.first
                guard let destination else { throw EventKitError.calendarNotFound(identifier: "default") }
                let tuples = try eventItems.map { item -> (ActionItemDetectionUI, EventsData.DetectedEvent) in
                    guard let base = eventSources[item.id] else { throw EventKitError.invalidEventData(field: "event source missing") }
                    return (item, buildEventPayload(from: item, base: base))
                }
                _ = try await batchAddEvents(tuples, calendar: destination)
            }

            if !reminderItems.isEmpty {
                try await ensureReminderPermission(permissionService: permissionService)
                try await loadDestinationsIfNeeded(for: reminderItems)
                let destination = reminderList ?? defaultReminderList ?? availableReminderLists.first
                guard let destination else { throw EventKitError.reminderListNotFound(identifier: "default") }
                let tuples = try reminderItems.map { item -> (ActionItemDetectionUI, RemindersData.DetectedReminder) in
                    guard let base = reminderSources[item.id] else { throw EventKitError.invalidEventData(field: "reminder source missing") }
                    return (item, buildReminderPayload(from: item, base: base))
                }
                _ = try await batchAddReminders(tuples, list: destination)
            }
        } catch {
            HapticManager.shared.playError()
        }
    }

    // MARK: - EventKit operations
    @MainActor
    mutating func loadDestinationsIfNeeded(for items: [ActionItemDetectionUI]) async throws {
        if items.contains(where: { $0.kind == .event }) && !calendarsLoaded {
            let repo = DIContainer.shared.eventKitRepository()
            availableCalendars = try await repo.getCalendars()
            defaultCalendar = try await repo.getDefaultCalendar() ?? availableCalendars.first
            calendarsLoaded = true
        }
        if items.contains(where: { $0.kind == .reminder }) && !reminderListsLoaded {
            let repo = DIContainer.shared.eventKitRepository()
            availableReminderLists = try await repo.getReminderLists()
            defaultReminderList = try await repo.getDefaultReminderList() ?? availableReminderLists.first
            reminderListsLoaded = true
        }
    }

    @MainActor
    func ensureCalendarPermission(permissionService: EventKitPermissionService) async throws {
        await permissionService.checkCalendarPermission(ignoreCache: true)
        if permissionService.calendarPermissionState.isAuthorized { return }
        if permissionService.calendarPermissionState.canRequest { _ = try await permissionService.requestCalendarAccess() }
        if !permissionService.calendarPermissionState.isAuthorized { throw EventKitError.permissionDenied(type: .calendar) }
    }

    @MainActor
    func ensureReminderPermission(permissionService: EventKitPermissionService) async throws {
        await permissionService.checkReminderPermission(ignoreCache: true)
        if permissionService.reminderPermissionState.isAuthorized { return }
        if permissionService.reminderPermissionState.canRequest { _ = try await permissionService.requestReminderAccess() }
        if !permissionService.reminderPermissionState.isAuthorized { throw EventKitError.permissionDenied(type: .reminder) }
    }

    @MainActor
    private mutating func batchAddEvents(_ items: [(ActionItemDetectionUI, EventsData.DetectedEvent)], calendar: CalendarDTO) async throws -> (success: Int, failures: [String]) {
        let useCase = DIContainer.shared.createCalendarEventUseCase()
        let events = items.map { $0.1 }
        var mapping: [String: CalendarDTO] = [:]
        for event in events { mapping[event.id] = calendar }
        let results = try await useCase.execute(events: events, calendarMapping: mapping)
        var successCount = 0
        var failures: [String] = []
        for (ui, event) in items {
            switch results[event.id] {
            case .success(let createdId):
                successCount += 1
                createdArtifacts[ui.id] = DistillCreatedArtifact(kind: .event, identifier: createdId)
                added.insert(ui.id)
                if let idx = self.items.firstIndex(where: { $0.id == ui.id }) { self.items[idx].isAdded = true }
                appendAddedMessage(for: ui)
            case .failure(let error):
                failures.append(error.localizedDescription)
            case .none:
                failures.append("Failed to create \(ui.title)")
            }
        }
        return (successCount, failures)
    }

    @MainActor
    private mutating func batchAddReminders(_ items: [(ActionItemDetectionUI, RemindersData.DetectedReminder)], list: CalendarDTO) async throws -> (success: Int, failures: [String]) {
        let useCase = DIContainer.shared.createReminderUseCase()
        let reminders = items.map { $0.1 }
        var mapping: [String: CalendarDTO] = [:]
        for reminder in reminders { mapping[reminder.id] = list }
        let results = try await useCase.execute(reminders: reminders, listMapping: mapping)
        var successCount = 0
        var failures: [String] = []
        for (ui, reminder) in items {
            switch results[reminder.id] {
            case .success(let createdId):
                successCount += 1
                createdArtifacts[ui.id] = DistillCreatedArtifact(kind: .reminder, identifier: createdId)
                added.insert(ui.id)
                if let idx = self.items.firstIndex(where: { $0.id == ui.id }) { self.items[idx].isAdded = true }
                appendAddedMessage(for: ui)
            case .failure(let error):
                failures.append(error.localizedDescription)
            case .none:
                failures.append("Failed to create \(ui.title)")
            }
        }
        return (successCount, failures)
    }

    @MainActor
    private mutating func addEvent(for item: ActionItemDetectionUI, permissionService: EventKitPermissionService) async throws -> String {
        guard let base = eventSources[item.id] else { throw EventKitError.invalidEventData(field: "event source missing") }
        let event = buildEventPayload(from: item, base: base)
        try await ensureCalendarPermission(permissionService: permissionService)
        try await loadDestinationsIfNeeded(for: [item])
        let repo = DIContainer.shared.eventKitRepository()
        let suggested = try await repo.suggestCalendar(for: event)
        let calendar = suggested ?? defaultCalendar ?? availableCalendars.first
        guard let calendar else { throw EventKitError.calendarNotFound(identifier: "default") }
        return try await DIContainer.shared.createCalendarEventUseCase().execute(event: event, calendar: calendar)
    }

    @MainActor
    private mutating func addReminder(for item: ActionItemDetectionUI, permissionService: EventKitPermissionService) async throws -> String {
        guard let base = reminderSources[item.id] else { throw EventKitError.invalidEventData(field: "reminder source missing") }
        let reminder = buildReminderPayload(from: item, base: base)
        try await ensureReminderPermission(permissionService: permissionService)
        try await loadDestinationsIfNeeded(for: [item])
        let repo = DIContainer.shared.eventKitRepository()
        let suggested = try await repo.suggestReminderList(for: reminder)
        let list = suggested ?? defaultReminderList ?? availableReminderLists.first
        guard let list else { throw EventKitError.reminderListNotFound(identifier: "default") }
        return try await DIContainer.shared.createReminderUseCase().execute(reminder: reminder, list: list)
    }

    // MARK: - Internal helpers
    private func merge(base: ActionItemDetection, existing: ActionItemDetection?) -> ActionItemDetection {
        guard let existing else { return base }
        return ActionItemDetection(
            sourceId: base.sourceId,
            kind: base.kind,
            confidence: base.confidence,
            sourceQuote: base.sourceQuote,
            title: existing.title,
            suggestedDate: existing.suggestedDate ?? base.suggestedDate,
            isAllDay: existing.isAllDay,
            location: existing.location ?? base.location,
            priorityLabel: existing.priorityLabel ?? base.priorityLabel,
            memoId: base.memoId
        )
    }

    private mutating func appendAddedMessage(for item: ActionItemDetectionUI) {
        let date: Date? = {
            if let d = item.suggestedDate { return d }
            switch item.kind {
            case .event: return eventSources[item.id]?.startDate
            case .reminder: return reminderSources[item.id]?.dueDate
            }
        }()
        let dateText = date.map { formatShortDate($0) }
        let prefix = item.kind == .event ? "Added event to calendar" : "Added reminder"
        let quotedTitle = "“\(item.title)”"
        let msg: String = dateText.map { "\(prefix) \(quotedTitle) for \($0)" } ?? "\(prefix) \(quotedTitle)"
        let key = item.sourceId
        addedRecords.removeAll { $0.id == key }
        addedRecords.append(DistillAddedRecord(id: key, text: msg))
        if let memoId = item.memoId ?? currentMemoId { handledStore.add(key, message: msg, for: memoId) }
    }
}
