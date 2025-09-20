import SwiftUI
import EventKit

struct EventConfirmationView: View {
    let detectedEvents: [EventsData.DetectedEvent]
    init(detectedEvents: [EventsData.DetectedEvent]) {
        self.detectedEvents = detectedEvents
        // Precompute editable state so rows render immediately
        var map: [String: EditableEvent] = [:]
        var defaults = Set<String>()
        for ev in detectedEvents {
            map[ev.id] = EditableEvent(from: ev)
            if ev.confidence >= 0.8 { defaults.insert(ev.id) }
        }
        _editableEvents = State(initialValue: map)
        let initialSelection = !defaults.isEmpty ? defaults : Set(detectedEvents.map { $0.id })
        _selectedEventIds = State(initialValue: initialSelection)
    }

    @SwiftUI.Environment(\.diContainer) private var container: DIContainer
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    @State private var calendars: [EKCalendar] = []
    @State private var selectedCalendar: EKCalendar? = nil
    @State private var selectedEventIds: Set<String> = []
    @State private var editableEvents: [String: EditableEvent] = [:]
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var editingEventId: String? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Calendar selection
                CalendarSelectionView(selectedCalendar: $selectedCalendar, calendars: calendars)

                // Event list
                List {
                    ForEach(detectedEvents, id: \.id) { ev in
                        HStack(alignment: .top, spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { selectedEventIds.contains(ev.id) },
                                set: { newValue in
                                    if newValue { selectedEventIds.insert(ev.id) } else { selectedEventIds.remove(ev.id) }
                                }
                            ))
                            .labelsHidden()

                            VStack(alignment: .leading, spacing: 4) {
                                Text(editableEvents[ev.id]?.title ?? ev.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let date = (editableEvents[ev.id]?.startDate ?? ev.startDate) {
                                    Text(formatDate(date))
                                        .font(.caption)
                                        .foregroundColor(.semantic(.textSecondary))
                                }
                                if let loc = editableEvents[ev.id]?.location ?? ev.location, !loc.isEmpty {
                                    Text(loc)
                                        .font(.caption)
                                        .foregroundColor(.semantic(.textSecondary))
                                }
                            }
                            Spacer()
                            Button("Edit") {
                                editingEventId = ev.id
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // Primary action
                Button(action: addSelectedEvents) {
                    HStack {
                        if isLoading { ProgressView().progressViewStyle(.circular) }
                        Text("Add Selected Events")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || selectedEventIds.isEmpty || selectedCalendar == nil)
                .padding(.horizontal)
            }
            .navigationTitle("Add to Calendar")
            .liquidGlassNavigation(titleDisplayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { Task { await loadData() } }
        .sheet(isPresented: Binding<Bool>(
            get: { editingEventId != nil },
            set: { if !$0 { editingEventId = nil } }
        )) {
            if let id = editingEventId, let binding = bindingForEditableEvent(id: id) {
                EventEditView(event: binding)
            } else {
                EmptyView()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    // MARK: - Actions

    private func loadData() async {
        // Build editable copies and default selections
        // Already precomputed in init; retain in case of future changes
        // Ensure any UI mutations are on MainActor
        await MainActor.run {}

        do {
            // Refresh permission state and only request if needed
            let perm = container.eventKitPermissionService()
            await perm.checkCalendarPermission(ignoreCache: true)
            if perm.calendarPermissionState.canRequest {
                _ = try await perm.requestCalendarAccess()
                // Allow permission state to stabilize to prevent race condition
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
                // Re-check permission state after stabilization
                await perm.checkCalendarPermission(ignoreCache: true)
            }

            let cals = try await container.eventKitRepository().getCalendars()
            let def = try await container.eventKitRepository().getDefaultCalendar() ?? cals.first
            await MainActor.run {
                calendars = cals
                if selectedCalendar == nil { selectedCalendar = def }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func addSelectedEvents() {
        guard let calendar = selectedCalendar else { return }
        isLoading = true

        Task {
            do {
                // Build updated DetectedEvent models from editable state
                let selected = detectedEvents.compactMap { original -> EventsData.DetectedEvent? in
                    guard selectedEventIds.contains(original.id), let e = editableEvents[original.id] else { return nil }
                    return e.toDetectedEvent()
                }

                var mapping: [String: EKCalendar] = [:]
                for ev in selected { mapping[ev.id] = calendar }

                let results = try await container.createCalendarEventUseCase().execute(events: selected, calendarMapping: mapping)

                let failures = results.values.filter { if case .failure = $0 { true } else { false } }
                if failures.isEmpty {
                    HapticManager.shared.playSuccess()
                    dismiss()
                } else {
                    HapticManager.shared.playWarning()
                    errorMessage = "Some events could not be created (\(failures.count))."
                }
            } catch {
                HapticManager.shared.playError()
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func bindingForEditableEvent(id: String) -> Binding<EditableEvent>? {
        guard editableEvents[id] != nil else { return nil }
        return Binding<EditableEvent>(
            get: { editableEvents[id]! },
            set: { editableEvents[id] = $0 }
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Calendar Selection

struct CalendarSelectionView: View {
    @Binding var selectedCalendar: EKCalendar?
    let calendars: [EKCalendar]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calendar")
                .font(.subheadline)
                .fontWeight(.semibold)
            Picker("Calendar", selection: Binding(
                get: { selectedCalendar?.calendarIdentifier ?? "" },
                set: { newId in selectedCalendar = calendars.first(where: { $0.calendarIdentifier == newId }) }
            )) {
                ForEach(calendars, id: \.calendarIdentifier) { cal in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(cgColor: cal.cgColor))
                            .frame(width: 10, height: 10)
                        Text(cal.title)
                    }.tag(cal.calendarIdentifier)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal)
    }
}

// MARK: - Event Edit

struct EventEditView: View {
    @Binding var event: EditableEvent
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    @State private var hasDate: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Title", text: $event.title)
                    TextField("Location", text: Binding(
                        get: { event.location ?? "" },
                        set: { event.location = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section(header: Text("Date & Time")) {
                    Toggle("Specify start time", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Start", selection: Binding(
                            get: { event.startDate ?? Date() },
                            set: { event.startDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])

                        DatePicker("End", selection: Binding(
                            get: { event.endDate ?? (event.startDate ?? Date()).addingTimeInterval(3600) },
                            set: { event.endDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Edit Event")
            .liquidGlassNavigation(titleDisplayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .onAppear { hasDate = event.startDate != nil }
    }
}

// MARK: - Editable Model

struct EditableEvent: Identifiable, Equatable {
    var id: String
    var title: String
    var startDate: Date?
    var endDate: Date?
    var location: String?
    var participants: [String]
    var confidence: Float
    var sourceText: String
    var memoId: UUID?

    init(from ev: EventsData.DetectedEvent) {
        self.id = ev.id
        self.title = ev.title
        self.startDate = ev.startDate
        self.endDate = ev.endDate
        self.location = ev.location
        self.participants = ev.participants ?? []
        self.confidence = ev.confidence
        self.sourceText = ev.sourceText
        self.memoId = ev.memoId
    }

    func toDetectedEvent() -> EventsData.DetectedEvent {
        EventsData.DetectedEvent(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            participants: participants.isEmpty ? nil : participants,
            confidence: confidence,
            sourceText: sourceText,
            memoId: memoId
        )
    }
}
