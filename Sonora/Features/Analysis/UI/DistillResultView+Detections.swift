import Foundation
import SwiftUI

// MARK: - Detections & EventKit Actions
extension DistillResultView {
    private var detectionItemsFiltered: [ActionItemDetectionUI] {
        detectionItems
            .filter { !dismissedDetections.contains($0.id) && !addedDetections.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.confidence != rhs.confidence {
                    return (lhs.confidence == .high ? 0 : lhs.confidence == .medium ? 1 : 2) <
                           (rhs.confidence == .high ? 0 : rhs.confidence == .medium ? 1 : 2)
                }
                if let ld = lhs.suggestedDate, let rd = rhs.suggestedDate {
                    return ld < rd
                }
                return false
            }
    }

    func prepareDetectionsIfNeeded() {
        let events = eventsForUI
        let reminders = remindersForUI
        let existingBySource = Dictionary(uniqueKeysWithValues: detectionItems.map { ($0.sourceId, $0) })

        var mergedItems: [ActionItemDetectionUI] = []
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

        for event in events {
            var baseUI = ActionItemDetectionUI.fromEvent(event)
            if baseUI.memoId == nil { baseUI.memoId = memoId ?? event.memoId }
            let merged = merge(base: baseUI, existing: existingBySource[event.id])
            mergedItems.append(merged)
            newEventSources[merged.id] = event
        }

        for reminder in reminders {
            var baseUI = ActionItemDetectionUI.fromReminder(reminder)
            if baseUI.memoId == nil { baseUI.memoId = memoId ?? reminder.memoId }
            let merged = merge(base: baseUI, existing: existingBySource[reminder.id])
            mergedItems.append(merged)
            newReminderSources[merged.id] = reminder
        }

        let filtered = mergedItems.filter { ui in
            guard let memoId = ui.memoId else { return true }
            let key = detectionKey(for: ui)
            return !handledStore.contains(key, for: memoId)
        }

        detectionItems = filtered
        eventSources = newEventSources
        reminderSources = newReminderSources
    }

    func toggleEdit(_ id: UUID) {
        if let idx = detectionItems.firstIndex(where: { $0.id == id }) {
            detectionItems[idx].isEditing.toggle()
        }
    }

    func dismiss(_ id: UUID) {
        dismissedDetections.insert(id)
        if let idx = detectionItems.firstIndex(where: { $0.id == id }) {
            detectionItems[idx].isDismissed = true
        }
    }

    func onAddSingle(_ updatedModel: ActionItemDetectionUI) {
        updateDetection(updatedModel)
        Task { @MainActor in await handleSingleAdd(updatedModel) }
    }

    private func undoAdd(_ id: UUID) {
        Task { @MainActor in await handleUndo(id: id) }
    }

    private func merge(base: ActionItemDetectionUI, existing: ActionItemDetectionUI?) -> ActionItemDetectionUI {
        guard let existing else { return base }
        return ActionItemDetectionUI(
            id: existing.id,
            sourceId: base.sourceId,
            kind: base.kind,
            confidence: base.confidence,
            sourceQuote: base.sourceQuote,
            title: existing.title,
            suggestedDate: existing.suggestedDate ?? base.suggestedDate,
            isAllDay: existing.isAllDay,
            location: existing.location ?? base.location,
            priorityLabel: existing.priorityLabel ?? base.priorityLabel,
            memoId: base.memoId,
            isEditing: existing.isEditing,
            isAdded: existing.isAdded,
            isDismissed: existing.isDismissed,
            isProcessing: existing.isProcessing
        )
    }

    @MainActor
    private func updateDetection(_ updated: ActionItemDetectionUI) {
        if let idx = detectionItems.firstIndex(where: { $0.id == updated.id }) {
            detectionItems[idx] = updated
        }
    }

    func detectionKey(for ui: ActionItemDetectionUI) -> String { ui.sourceId }

    @MainActor
    func setProcessing(_ id: UUID, to value: Bool) {
        if let idx = detectionItems.firstIndex(where: { $0.id == id }) {
            detectionItems[idx].isProcessing = value
        }
    }

    @MainActor
    private func handleSingleAdd(_ item: ActionItemDetectionUI) async {
        setProcessing(item.id, to: true)
        defer { setProcessing(item.id, to: false) }

        do {
            let identifier: String
            switch item.kind {
            case .event:
                identifier = try await addEvent(for: item)
                createdArtifacts[item.id] = DistillCreatedArtifact(kind: .event, identifier: identifier)
            case .reminder:
                identifier = try await addReminder(for: item)
                createdArtifacts[item.id] = DistillCreatedArtifact(kind: .reminder, identifier: identifier)
            }

            addedDetections.insert(item.id)
            if let idx = detectionItems.firstIndex(where: { $0.id == item.id }) {
                detectionItems[idx].isAdded = true
            }

            HapticManager.shared.playSuccess()
            appendAddedMessage(for: item)
        } catch {
            HapticManager.shared.playError()
        }
    }

    @MainActor
    private func handleUndo(id: UUID) async {
        guard let artifact = createdArtifacts[id] else {
            addedDetections.remove(id)
            createdArtifacts.removeValue(forKey: id)
            return
        }

        do {
            switch artifact.kind {
            case .event:
                try await container.eventKitRepository().deleteEvent(with: artifact.identifier)
            case .reminder:
                try await container.eventKitRepository().deleteReminder(with: artifact.identifier)
            }
            addedDetections.remove(id)
            createdArtifacts.removeValue(forKey: id)
            if let ui = detectionItems.first(where: { $0.id == id }) {
                let key = detectionKey(for: ui)
                addedRecords.removeAll { $0.id == key }
                if let memoId = ui.memoId ?? memoId {
                    handledStore.remove(key, for: memoId)
                }
            }
            HapticManager.shared.playSuccess()
        } catch {
            HapticManager.shared.playError()
        }
    }

    @MainActor
    func addEvent(for item: ActionItemDetectionUI) async throws -> String {
        guard let base = eventSources[item.id] else {
            throw EventKitError.invalidEventData(field: "event source missing")
        }
        let event = buildEventPayload(from: item, base: base)
        try await ensureCalendarPermission()
        try await loadDestinationsIfNeeded(for: [item])
        let repo = container.eventKitRepository()
        let suggested = try await repo.suggestCalendar(for: event)
        let calendar = suggested ?? defaultCalendar ?? availableCalendars.first
        guard let calendar else { throw EventKitError.calendarNotFound(identifier: "default") }
        return try await container.createCalendarEventUseCase().execute(event: event, calendar: calendar)
    }

    @MainActor
    func addReminder(for item: ActionItemDetectionUI) async throws -> String {
        guard let base = reminderSources[item.id] else {
            throw EventKitError.invalidEventData(field: "reminder source missing")
        }
        let reminder = buildReminderPayload(from: item, base: base)
        try await ensureReminderPermission()
        try await loadDestinationsIfNeeded(for: [item])
        let repo = container.eventKitRepository()
        let suggested = try await repo.suggestReminderList(for: reminder)
        let list = suggested ?? defaultReminderList ?? availableReminderLists.first
        guard let list else { throw EventKitError.reminderListNotFound(identifier: "default") }
        return try await container.createReminderUseCase().execute(reminder: reminder, list: list)
    }

    @MainActor
    func handleBatchAdd(selected: [ActionItemDetectionUI], calendar: CalendarDTO?, reminderList: CalendarDTO?) async {
        guard !selected.isEmpty else { return }

        selected.forEach { updateDetection($0) }
        let ids = selected.map { $0.id }
        ids.forEach { setProcessing($0, to: true) }
        defer { ids.forEach { setProcessing($0, to: false) } }

        let eventItems = selected.filter { $0.kind == .event }
        let reminderItems = selected.filter { $0.kind == .reminder }

        do {
            if !eventItems.isEmpty {
                try await ensureCalendarPermission()
                try await loadDestinationsIfNeeded(for: eventItems)
                let destination = calendar ?? defaultCalendar ?? availableCalendars.first
                guard let destination else { throw EventKitError.calendarNotFound(identifier: "default") }
                let tuples = try eventItems.map { item -> (ActionItemDetectionUI, EventsData.DetectedEvent) in
                    guard let base = eventSources[item.id] else {
                        throw EventKitError.invalidEventData(field: "event source missing")
                    }
                    return (item, buildEventPayload(from: item, base: base))
                }
                _ = try await batchAddEvents(tuples, calendar: destination)
            }

            if !reminderItems.isEmpty {
                try await ensureReminderPermission()
                try await loadDestinationsIfNeeded(for: reminderItems)
                let destination = reminderList ?? defaultReminderList ?? availableReminderLists.first
                guard let destination else { throw EventKitError.reminderListNotFound(identifier: "default") }
                let tuples = try reminderItems.map { item -> (ActionItemDetectionUI, RemindersData.DetectedReminder) in
                    guard let base = reminderSources[item.id] else {
                        throw EventKitError.invalidEventData(field: "reminder source missing")
                    }
                    return (item, buildReminderPayload(from: item, base: base))
                }
                _ = try await batchAddReminders(tuples, list: destination)
            }

        } catch {
            HapticManager.shared.playError()
        }
    }

    @MainActor
    private func batchAddEvents(_ items: [(ActionItemDetectionUI, EventsData.DetectedEvent)], calendar: CalendarDTO) async throws -> (success: Int, failures: [String]) {
        let useCase = container.createCalendarEventUseCase()
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
                addedDetections.insert(ui.id)
                if let idx = detectionItems.firstIndex(where: { $0.id == ui.id }) {
                    detectionItems[idx].isAdded = true
                }
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
    private func batchAddReminders(_ items: [(ActionItemDetectionUI, RemindersData.DetectedReminder)], list: CalendarDTO) async throws -> (success: Int, failures: [String]) {
        let useCase = container.createReminderUseCase()
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
                addedDetections.insert(ui.id)
                if let idx = detectionItems.firstIndex(where: { $0.id == ui.id }) {
                    detectionItems[idx].isAdded = true
                }
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
    func loadDestinationsIfNeeded(for items: [ActionItemDetectionUI]) async throws {
        if items.contains(where: { $0.kind == .event }) && !calendarsLoaded {
            let repo = container.eventKitRepository()
            availableCalendars = try await repo.getCalendars()
            defaultCalendar = try await repo.getDefaultCalendar() ?? availableCalendars.first
            calendarsLoaded = true
        }

        if items.contains(where: { $0.kind == .reminder }) && !reminderListsLoaded {
            let repo = container.eventKitRepository()
            availableReminderLists = try await repo.getReminderLists()
            defaultReminderList = try await repo.getDefaultReminderList() ?? availableReminderLists.first
            reminderListsLoaded = true
        }
    }

    @MainActor
    func ensureCalendarPermission() async throws {
        await permissionService.checkCalendarPermission(ignoreCache: true)
        if permissionService.calendarPermissionState.isAuthorized { return }
        if permissionService.calendarPermissionState.canRequest {
            _ = try await permissionService.requestCalendarAccess()
        }
        if !permissionService.calendarPermissionState.isAuthorized {
            throw EventKitError.permissionDenied(type: .calendar)
        }
    }

    @MainActor
    func ensureReminderPermission() async throws {
        await permissionService.checkReminderPermission(ignoreCache: true)
        if permissionService.reminderPermissionState.isAuthorized { return }
        if permissionService.reminderPermissionState.canRequest {
            _ = try await permissionService.requestReminderAccess()
        }
        if !permissionService.reminderPermissionState.isAuthorized {
            throw EventKitError.permissionDenied(type: .reminder)
        }
    }

    @MainActor
    func appendAddedMessage(for item: ActionItemDetectionUI) {
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
        let msg: String
        if let dateText { msg = "\(prefix) \(quotedTitle) for \(dateText)" } else { msg = "\(prefix) \(quotedTitle)" }
        let key = detectionKey(for: item)
        addedRecords.removeAll { $0.id == key }
        addedRecords.append(DistillAddedRecord(id: key, text: msg))
        if let memoId = item.memoId ?? memoId {
            handledStore.add(key, message: msg, for: memoId)
        }
    }
}
