import SwiftUI
// Uses CalendarDTO for selection

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

    @SwiftUI.Environment(\.diContainer)
    private var container: DIContainer
    @SwiftUI.Environment(\.dismiss)
    private var dismiss: DismissAction

    @State private var calendars: [CalendarDTO] = []
    @State private var selectedCalendar: CalendarDTO?
    @State private var selectedEventIds: Set<String> = []
    @State private var editableEvents: [String: EditableEvent] = [:]
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var editingEventId: String?

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
                            .accessibilityLabel("Include event: \(editableEvents[ev.id]?.title ?? ev.title)")
                            .accessibilityHint(selectedEventIds.contains(ev.id) ? "Selected" : "Not selected")

                            VStack(alignment: .leading, spacing: 4) {
                                Text(editableEvents[ev.id]?.title ?? ev.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let date = (editableEvents[ev.id]?.startDate ?? ev.startDate) {
                                    Text(formatDate(date))
                                        .font(.caption)
                                        .foregroundColor(.semantic(.textSecondary))
                                        .accessibilityLabel("Start date: \(formatDate(date))")
                                }
                                if let loc = editableEvents[ev.id]?.location ?? ev.location, !loc.isEmpty {
                                    Text(loc)
                                        .font(.caption)
                                        .foregroundColor(.semantic(.textSecondary))
                                        .accessibilityLabel("Location: \(loc)")
                                }
                            }
                            Spacer()
                            Button("Edit") {
                                editingEventId = ev.id
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Edit event: \(editableEvents[ev.id]?.title ?? ev.title)")
                        }
                        .accessibilityElement(children: .combine)
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
            .navigationBarTitleDisplayMode(.inline)
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

                var mapping: [String: CalendarDTO] = [:]
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
            get: { editableEvents[id] ?? { fatalError("Missing editable event for id: \(id)") }() },
            set: { editableEvents[id] = $0 }
        )
    }

    private func formatDate(_ date: Date) -> String {
        date.mediumDateTimeString
    }
}

// MARK: - Calendar Selection

struct CalendarSelectionView: View {
    @Binding var selectedCalendar: CalendarDTO?
    let calendars: [CalendarDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calendar")
                .font(.subheadline)
                .fontWeight(.semibold)
            Picker("Calendar", selection: Binding(
                get: { selectedCalendar?.id ?? "" },
                set: { newId in selectedCalendar = calendars.first { $0.id == newId } }
            )) {
                ForEach(calendars, id: \.id) { cal in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: cal.colorHex))
                            .frame(width: 10, height: 10)
                        Text(cal.title)
                    }.tag(cal.id)
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

    private var validationErrors: [ValidationError] {
        event.validate()
    }

    private var canSave: Bool {
        validationErrors.isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Title", text: $event.title)
                        .textInputAutocapitalization(.words)
                    TextField("Location", text: Binding(
                        get: { event.location ?? "" },
                        set: { event.location = $0.isEmpty ? nil : $0 }
                    ))
                }

                // Show validation errors if any
                if !validationErrors.isEmpty {
                    Section {
                        ForEach(validationErrors, id: \.self) { error in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.semantic(.warning))
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(error.localizedDescription)
                                        .font(.caption)
                                        .foregroundColor(.semantic(.warning))
                                    if let suggestion = error.recoverySuggestion {
                                        Text(suggestion)
                                            .font(.caption2)
                                            .foregroundColor(.semantic(.textSecondary))
                                    }
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Date & Time")) {
                    Toggle("Specify start time", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Start", selection: Binding(
                            get: { event.startDate ?? Date() },
                            set: { event.startDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])

                        DatePicker("End", selection: Binding(
                            get: { event.endDate ?? (event.startDate ?? Date()).addingTimeInterval(3_600) },
                            set: { event.endDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(!canSave)
                }
            }
        }
        .onAppear { hasDate = event.startDate != nil }
    }
}

// MARK: - Color helper
private extension Color {
    init(hex: String?) {
        guard let hex = hex else { self = .gray; return }
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        var rgba: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgba)
        switch cleaned.count {
        case 6: // RRGGBB
            let r = Double((rgba & 0xFF0000) >> 16) / 255.0
            let g = Double((rgba & 0x00FF00) >> 8) / 255.0
            let b = Double(rgba & 0x0000FF) / 255.0
            self = Color(red: r, green: g, blue: b)
        case 8: // RRGGBBAA
            let r = Double((rgba & 0xFF000000) >> 24) / 255.0
            let g = Double((rgba & 0x00FF0000) >> 16) / 255.0
            let b = Double((rgba & 0x0000FF00) >> 8) / 255.0
            let a = Double(rgba & 0x000000FF) / 255.0
            self = Color(red: r, green: g, blue: b).opacity(a)
        default:
            self = .gray
        }
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

    // MARK: - Validation

    /// Validates the event and returns any errors found
    func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        // Title validation
        if title.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(.emptyTitle)
        } else if title.count > 500 {
            errors.append(.titleTooLong(maxLength: 500))
        }

        // Location validation
        if let loc = location, loc.count > 500 {
            errors.append(.locationTooLong(maxLength: 500))
        }

        // Date range validation - only validate if both dates are set
        if let start = startDate, let end = endDate, end <= start {
            errors.append(.invalidDateRange)
        }

        return errors
    }

    /// Returns true if the event passes all validation checks
    var isValid: Bool {
        validate().isEmpty
    }
}
