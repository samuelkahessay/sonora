import Foundation
import SwiftUI

@MainActor
final class ActionItemViewModel: ObservableObject {
    // External
    @Published private(set) var visibleItems: [ActionItemDetectionUI] = []
    @Published private(set) var addedRecords: [DistillAddedRecord] = []
    @Published var showBatchSheet: Bool = false
    @Published var batchInclude: Set<UUID> = []

    @Published private(set) var availableCalendars: [CalendarDTO] = []
    @Published private(set) var availableReminderLists: [CalendarDTO] = []
    @Published private(set) var defaultCalendar: CalendarDTO?
    @Published private(set) var defaultReminderList: CalendarDTO?

    // Permission surface (forwarded from coordinator)
    let permissionService: EventKitPermissionService

    // Undo/Redo
    private var undoStack: [ReversibleCommand] = []
    private var redoStack: [ReversibleCommand] = []
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false

    // Conflict handling (duplicates)
    @Published var showConflictSheet: Bool = false
    @Published private(set) var conflictDuplicates: [ExistingEventDTO] = []
    private var conflictItem: ActionItemDetectionUI?
    private var conflictBaseEvent: EventsData.DetectedEvent?
    private var conflictDestination: CalendarDTO?
    private var conflictBatchItems: [ActionItemDetectionUI]?

    // Internals
    private var detection = ActionItemDetectionState()
    private let coordinator = ActionItemCoordinator()
    private let memoId: UUID?

    init(memoId: UUID?, initialEvents: [EventsData.DetectedEvent], initialReminders: [RemindersData.DetectedReminder]) {
        self.memoId = memoId
        self.permissionService = coordinator.permissionService
        detection.mergeFrom(events: initialEvents, reminders: initialReminders, memoId: memoId)
        coordinator.restoreHandled(for: memoId)
        syncOutputs()
    }

    // MARK: - Intents

    func handleEditToggle(_ id: UUID) {
        detection.toggleEdit(id)
        syncOutputs()
    }

    func handleDismiss(_ id: UUID) {
        detection.dismiss(id)
        syncOutputs()
    }

    func handleOpenBatch(selected: Set<UUID>) async {
        batchInclude = selected
        let reviewItems = detection.visibleItems
        do {
            let res = try await coordinator.loadDestinationsIfNeeded(for: reviewItems, calendarsLoaded: detection.calendarsLoaded, reminderListsLoaded: detection.reminderListsLoaded)
            if res.didLoadCalendars { detection.availableCalendars = coordinator.availableCalendars; detection.defaultCalendar = coordinator.defaultCalendar; detection.calendarsLoaded = true }
            if res.didLoadReminderLists { detection.availableReminderLists = coordinator.availableReminderLists; detection.defaultReminderList = coordinator.defaultReminderList; detection.reminderListsLoaded = true }
            showBatchSheet = true
            syncOutputs()
        } catch { }
    }

    func handleAddSingle(_ item: ActionItemDetectionUI) async {
        detection.update(item)
        detection.setProcessing(item.id, to: true)
        syncOutputs()
        defer { detection.setProcessing(item.id, to: false); syncOutputs() }

        do {
            switch item.kind {
            case .event:
                try await coordinator.ensureCalendarPermission()
                let res = try await coordinator.loadDestinationsIfNeeded(for: [item], calendarsLoaded: detection.calendarsLoaded, reminderListsLoaded: detection.reminderListsLoaded)
                if res.didLoadCalendars { detection.availableCalendars = coordinator.availableCalendars; detection.defaultCalendar = coordinator.defaultCalendar; detection.calendarsLoaded = true }
                guard let base = detection.eventSources[item.id] else { throw EventKitError.invalidEventData(field: "event source missing") }
                // Duplicate check before creation
                let payload = buildEventPayload(from: item, base: base)
                let repo = DIContainer.shared.eventKitRepository()
                let dups = try await repo.findDuplicates(similarTo: payload)
                if !dups.isEmpty {
                    // Present conflict sheet and return; user will decide
                    conflictDuplicates = dups
                    conflictItem = item
                    conflictBaseEvent = base
                    conflictDestination = detection.defaultCalendar ?? detection.availableCalendars.first
                    detection.setProcessing(item.id, to: false)
                    showConflictSheet = true
                    syncOutputs()
                    return
                }

                let create: AddEventCommand.CreateClosure = { [weak self] in
                    guard let self else { throw EventKitError.invalidEventData(field: "vm deallocated") }
                    let id = try await self.coordinator.createEvent(for: item, base: base, in: self.detection.defaultCalendar ?? self.detection.availableCalendars.first)
                    return id
                }
                let del: AddEventCommand.DeleteClosure = { id in
                    try await DIContainer.shared.eventKitRepository().deleteEvent(with: id)
                }
                let cmd = AddEventCommand(create: create, delete: del)
                try await cmd.execute()
                if let createdId = cmd.createdId {
                    detection.createdArtifacts[item.id] = DistillCreatedArtifact(kind: .event, identifier: createdId)
                }
            case .reminder:
                try await coordinator.ensureReminderPermission()
                let res = try await coordinator.loadDestinationsIfNeeded(for: [item], calendarsLoaded: detection.calendarsLoaded, reminderListsLoaded: detection.reminderListsLoaded)
                if res.didLoadReminderLists { detection.availableReminderLists = coordinator.availableReminderLists; detection.defaultReminderList = coordinator.defaultReminderList; detection.reminderListsLoaded = true }

                guard let base = detection.reminderSources[item.id] else { throw EventKitError.invalidEventData(field: "reminder source missing") }
                let create: AddReminderCommand.CreateClosure = { [weak self] in
                    guard let self else { throw EventKitError.invalidEventData(field: "vm deallocated") }
                    let id = try await coordinator.createReminder(for: item, base: base, in: self.detection.defaultReminderList ?? self.detection.availableReminderLists.first)
                    return id
                }
                let del: AddReminderCommand.DeleteClosure = { id in
                    try await DIContainer.shared.eventKitRepository().deleteReminder(with: id)
                }
                let cmd = AddReminderCommand(create: create, delete: del)
                try await cmd.execute()
                if let createdId = cmd.createdId {
                    detection.createdArtifacts[item.id] = DistillCreatedArtifact(kind: .reminder, identifier: createdId)
                }
            }

            detection.added.insert(item.id)
            let date: Date? = {
                if let d = item.suggestedDate { return d }
                switch item.kind {
                case .event: return detection.eventSources[item.id]?.startDate
                case .reminder: return detection.reminderSources[item.id]?.dueDate
                }
            }()
            let rec = coordinator.makeAddedRecord(for: item, date: date)
            coordinator.upsertAndPersist(record: rec, memoId: item.memoId ?? memoId)

            // Push to undo stack
            if let artifact = detection.createdArtifacts[item.id] {
                switch artifact.kind {
                case .event:
                    let delete: AddEventCommand.DeleteClosure = { id in try await DIContainer.shared.eventKitRepository().deleteEvent(with: id) }
                    let create: AddEventCommand.CreateClosure = { [weak self] in
                        guard let self, let base = self.detection.eventSources[item.id] else { throw EventKitError.invalidEventData(field: "event source missing") }
                        return try await self.coordinator.createEvent(for: item, base: base, in: self.detection.defaultCalendar ?? self.detection.availableCalendars.first)
                    }
                    let cmd = AddEventCommand(create: create, delete: delete)
                    cmd.seedCreatedId(artifact.identifier)
                    undoStack.append(cmd)
                case .reminder:
                    let delete: AddReminderCommand.DeleteClosure = { id in try await DIContainer.shared.eventKitRepository().deleteReminder(with: id) }
                    let create: AddReminderCommand.CreateClosure = { [weak self] in
                        guard let self, let base = self.detection.reminderSources[item.id] else { throw EventKitError.invalidEventData(field: "reminder source missing") }
                        return try await self.coordinator.createReminder(for: item, base: base, in: self.detection.defaultReminderList ?? self.detection.availableReminderLists.first)
                    }
                    let cmd = AddReminderCommand(create: create, delete: delete)
                    cmd.seedCreatedId(artifact.identifier)
                    undoStack.append(cmd)
                }
                redoStack.removeAll()
                updateUndoRedoAvailability()
            }

            HapticManager.shared.playSuccess()
        } catch {
            HapticManager.shared.playError()
        }
        syncOutputs()
    }

    func resolveConflictProceed() async {
        // Batch proceed
        if let batch = conflictBatchItems, let destination = conflictDestination {
            showConflictSheet = false
            do {
                for item in batch where item.kind == .event {
                    guard let base = detection.eventSources[item.id] else { continue }
                    let id = try await coordinator.createEvent(for: item, base: base, in: destination)
                    detection.createdArtifacts[item.id] = DistillCreatedArtifact(kind: .event, identifier: id)
                    detection.added.insert(item.id)
                    let date = item.suggestedDate ?? base.startDate
                    let rec = coordinator.makeAddedRecord(for: item, date: date)
                    coordinator.upsertAndPersist(record: rec, memoId: item.memoId ?? memoId)
                }
                HapticManager.shared.playSuccess()
            } catch {
                HapticManager.shared.playError()
            }
            conflictBatchItems = nil
            conflictDestination = nil
            conflictDuplicates = []
            syncOutputs()
            return
        }

        // Single proceed
        guard let item = conflictItem, let base = conflictBaseEvent else { showConflictSheet = false; return }
        showConflictSheet = false
        detection.setProcessing(item.id, to: true)
        syncOutputs()
        defer { detection.setProcessing(item.id, to: false); syncOutputs() }
        do {
            let id = try await coordinator.createEvent(for: item, base: base, in: conflictDestination ?? detection.defaultCalendar ?? detection.availableCalendars.first)
            detection.createdArtifacts[item.id] = DistillCreatedArtifact(kind: .event, identifier: id)
            detection.added.insert(item.id)
            let date = item.suggestedDate ?? base.startDate
            let rec = coordinator.makeAddedRecord(for: item, date: date)
            coordinator.upsertAndPersist(record: rec, memoId: item.memoId ?? memoId)
            // seed undo
            let delete: AddEventCommand.DeleteClosure = { id in try await DIContainer.shared.eventKitRepository().deleteEvent(with: id) }
            let create: AddEventCommand.CreateClosure = { [weak self] in
                guard let self else { throw EventKitError.invalidEventData(field: "vm deallocated") }
                return try await self.coordinator.createEvent(for: item, base: base, in: self.detection.defaultCalendar ?? self.detection.availableCalendars.first)
            }
            let cmd = AddEventCommand(create: create, delete: delete)
            cmd.seedCreatedId(id)
            undoStack.append(cmd)
            redoStack.removeAll()
            updateUndoRedoAvailability()
            HapticManager.shared.playSuccess()
        } catch {
            HapticManager.shared.playError()
        }
        conflictItem = nil
        conflictBaseEvent = nil
        conflictDestination = nil
    }

    func resolveConflictSkip() {
        showConflictSheet = false
        if conflictBatchItems != nil {
            conflictBatchItems = nil
            conflictDestination = nil
            conflictDuplicates = []
        } else {
            conflictItem = nil
            conflictBaseEvent = nil
            conflictDestination = nil
        }
    }

    func handleAddSelected(_ items: [ActionItemDetectionUI], calendar: CalendarDTO?, reminderList: CalendarDTO?) async {
        guard !items.isEmpty else { return }
        items.forEach { detection.update($0) }
        let ids = items.map { $0.id }
        ids.forEach { detection.setProcessing($0, to: true) }
        syncOutputs()
        defer { ids.forEach { detection.setProcessing($0, to: false) }; syncOutputs() }

        let eventItems = items.filter { $0.kind == .event }
        let reminderItems = items.filter { $0.kind == .reminder }
        do {
            if !eventItems.isEmpty {
                try await coordinator.ensureCalendarPermission()
                let res = try await coordinator.loadDestinationsIfNeeded(for: eventItems, calendarsLoaded: detection.calendarsLoaded, reminderListsLoaded: detection.reminderListsLoaded)
                if res.didLoadCalendars { detection.availableCalendars = coordinator.availableCalendars; detection.defaultCalendar = coordinator.defaultCalendar; detection.calendarsLoaded = true }
                let destination = calendar ?? detection.defaultCalendar ?? detection.availableCalendars.first
                guard let destination else { throw EventKitError.calendarNotFound(identifier: "default") }

                // Duplicate detection across batch; if any duplicates, present sheet to choose
                var itemsWithDupes: [(ActionItemDetectionUI, [ExistingEventDTO])] = []
                for item in eventItems {
                    guard let base = detection.eventSources[item.id] else { continue }
                    let payload = buildEventPayload(from: item, base: base)
                    let dups = try await DIContainer.shared.eventKitRepository().findDuplicates(similarTo: payload)
                    if !dups.isEmpty { itemsWithDupes.append((item, dups)) }
                }
                if !itemsWithDupes.isEmpty {
                    // Aggregate duplicates and show a single confirmation
                    conflictDuplicates = itemsWithDupes.flatMap { $0.1 }
                    conflictBatchItems = eventItems
                    conflictDestination = destination
                    showConflictSheet = true
                    return
                }

                for item in eventItems {
                    guard let base = detection.eventSources[item.id] else { continue }
                    let id = try await coordinator.createEvent(for: item, base: base, in: destination)
                    detection.createdArtifacts[item.id] = DistillCreatedArtifact(kind: .event, identifier: id)
                    detection.added.insert(item.id)
                    let date = item.suggestedDate ?? base.startDate
                    let rec = coordinator.makeAddedRecord(for: item, date: date)
                    coordinator.upsertAndPersist(record: rec, memoId: item.memoId ?? memoId)
                }
            }
            if !reminderItems.isEmpty {
                try await coordinator.ensureReminderPermission()
                let res = try await coordinator.loadDestinationsIfNeeded(for: reminderItems, calendarsLoaded: detection.calendarsLoaded, reminderListsLoaded: detection.reminderListsLoaded)
                if res.didLoadReminderLists { detection.availableReminderLists = coordinator.availableReminderLists; detection.defaultReminderList = coordinator.defaultReminderList; detection.reminderListsLoaded = true }
                let destination = reminderList ?? detection.defaultReminderList ?? detection.availableReminderLists.first
                guard let destination else { throw EventKitError.reminderListNotFound(identifier: "default") }
                for item in reminderItems {
                    guard let base = detection.reminderSources[item.id] else { continue }
                    let id = try await coordinator.createReminder(for: item, base: base, in: destination)
                    detection.createdArtifacts[item.id] = DistillCreatedArtifact(kind: .reminder, identifier: id)
                    detection.added.insert(item.id)
                    let date = item.suggestedDate ?? base.dueDate
                    let rec = coordinator.makeAddedRecord(for: item, date: date)
                    coordinator.upsertAndPersist(record: rec, memoId: item.memoId ?? memoId)
                }
            }
            HapticManager.shared.playSuccess()
        } catch {
            HapticManager.shared.playError()
        }
        syncOutputs()
    }

    // MARK: - Undo / Redo
    func undo() async {
        guard let cmd = undoStack.popLast() else { return }
        do { try await cmd.undo(); redoStack.append(cmd) } catch { }
        updateUndoRedoAvailability()
    }

    func redo() async {
        guard let cmd = redoStack.popLast() else { return }
        do { try await cmd.execute(); undoStack.append(cmd) } catch { }
        updateUndoRedoAvailability()
    }

    // MARK: - Stream updates
    func mergeIncoming(events: [EventsData.DetectedEvent], reminders: [RemindersData.DetectedReminder]) {
        detection.mergeFrom(events: events, reminders: reminders, memoId: memoId)
        syncOutputs()
    }

    // MARK: - Outputs sync
    private func syncOutputs() {
        visibleItems = detection.visibleItems
        addedRecords = coordinator.addedRecords.isEmpty ? detection.addedRecords : coordinator.addedRecords
        availableCalendars = detection.availableCalendars
        availableReminderLists = detection.availableReminderLists
        defaultCalendar = detection.defaultCalendar
        defaultReminderList = detection.defaultReminderList
    }

    private func updateUndoRedoAvailability() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}
