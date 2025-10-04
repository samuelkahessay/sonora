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
            let key = DetectionKeyBuilder.forDomain(det)
            return !handledStore.contains(key, for: memoId)
        }

        items = filtered
        uiIdBySource = newUiIdBySource.filter { key, _ in filtered.contains { $0.sourceId == key } }
        eventSources = newEventSources
        reminderSources = newReminderSources

        // Diagnostics: log merge outcome and filtering effects
        let removedByHandled = mergedItems.count - filtered.count
        let info: [String: Any] = [
            "memoId": (memoId?.uuidString ?? "nil"),
            "incomingEvents": events.count,
            "incomingReminders": reminders.count,
            "merged": mergedItems.count,
            "removedByHandled": max(0, removedByHandled),
            "resultItems": items.count,
            "visible": visibleItems.count
        ]
        Logger.shared.info("ActionItems.State.MergeFrom", category: .viewModel, context: LogContext(additionalInfo: info))
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
            let previousKind = items[idx].kind
            items[idx].kind = updated.kind
            items[idx].title = updated.title
            items[idx].suggestedDate = updated.suggestedDate
            items[idx].isAllDay = updated.isAllDay
            items[idx].location = updated.location
            items[idx].priorityLabel = updated.priorityLabel

            // Clear stale source caches when the type flips
            if previousKind != updated.kind {
                switch previousKind {
                case .event:
                    eventSources.removeValue(forKey: updated.id)
                case .reminder:
                    reminderSources.removeValue(forKey: updated.id)
                }
            }
        }
    }

    mutating func setProcessing(_ id: UUID, to value: Bool) {
        if value { processing.insert(id) } else { processing.remove(id) }
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
                let date: Date? = {
                    if let d = ui.suggestedDate { return d }
                    switch ui.kind {
                    case .event:
                        return eventSources[ui.id]?.startDate ?? items.first { $0.sourceId == ui.sourceId }?.suggestedDate
                    case .reminder:
                        return reminderSources[ui.id]?.dueDate ?? items.first { $0.sourceId == ui.sourceId }?.suggestedDate
                    }
                }()
                let key = DetectionKeyBuilder.forUI(kind: ui.kind, sourceQuote: ui.sourceQuote, fallbackTitle: ui.title, date: date)
                addedRecords.removeAll { $0.id == key }
                if let memoId = ui.memoId ?? currentMemoId { handledStore.remove(key, for: memoId) }
            }
            HapticManager.shared.playSuccess()
        } catch {
            HapticManager.shared.playError()
        }
    }

    // MARK: - EventKit operations
    // PR A cleanup: EventKit interactions have moved into ActionItemCoordinator.
    // This state remains a pure UI/state container.

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

    mutating func appendAddedMessage(for item: ActionItemDetectionUI) {
        let date: Date? = {
            if let d = item.suggestedDate { return d }
            switch item.kind {
            case .event:
                if let cached = eventSources[item.id]?.startDate { return cached }
                return items.first { $0.sourceId == item.sourceId }?.suggestedDate
            case .reminder:
                if let cached = reminderSources[item.id]?.dueDate { return cached }
                return items.first { $0.sourceId == item.sourceId }?.suggestedDate
            }
        }()
        let dateText = date.map { formatShortDate($0) }
        let prefix = item.kind == .event ? "Added event to calendar" : "Added reminder"
        let quotedTitle = "“\(item.title)”"
        let msg: String = dateText.map { "\(prefix) \(quotedTitle) for \($0)" } ?? "\(prefix) \(quotedTitle)"
        let key = DetectionKeyBuilder.forUI(kind: item.kind, sourceQuote: item.sourceQuote, fallbackTitle: item.title, date: date)
        addedRecords.removeAll { $0.id == key }
        addedRecords.append(DistillAddedRecord(id: key, text: msg))
        if let memoId = item.memoId ?? currentMemoId { handledStore.add(key, message: msg, for: memoId) }
    }
}
