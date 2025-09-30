import SwiftUI

struct BatchAddActionItemsSheet: View {
    @Binding var items: [ActionItemDetectionUI]
    @Binding var include: Set<UUID>
    let isPro: Bool
    let calendars: [CalendarDTO]
    let reminderLists: [CalendarDTO]
    let defaultCalendar: CalendarDTO?
    let defaultReminderList: CalendarDTO?
    let onEdit: (UUID) -> Void
    let onAddSelected: (_ selected: [ActionItemDetectionUI], _ calendar: CalendarDTO?, _ reminderList: CalendarDTO?) -> Void
    let onDismiss: () -> Void

    @State private var selectedCalendar: CalendarDTO?
    @State private var selectedReminderList: CalendarDTO?

    private var selectedItems: [ActionItemDetectionUI] {
        items.filter { include.contains($0.id) }
    }

    private var hasSelectedEvents: Bool {
        selectedItems.contains { $0.kind == .event }
    }

    private var hasSelectedReminders: Bool {
        selectedItems.contains { $0.kind == .reminder }
    }

    private var eventItemsExist: Bool {
        items.contains { $0.kind == .event }
    }

    private var reminderItemsExist: Bool {
        items.contains { $0.kind == .reminder }
    }

    init(
        items: Binding<[ActionItemDetectionUI]>,
        include: Binding<Set<UUID>>,
        isPro: Bool,
        calendars: [CalendarDTO],
        reminderLists: [CalendarDTO],
        defaultCalendar: CalendarDTO?,
        defaultReminderList: CalendarDTO?,
        onEdit: @escaping (UUID) -> Void,
        onAddSelected: @escaping (_ selected: [ActionItemDetectionUI], _ calendar: CalendarDTO?, _ reminderList: CalendarDTO?) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self._items = items
        self._include = include
        self.isPro = isPro
        self.calendars = calendars
        self.reminderLists = reminderLists
        self.defaultCalendar = defaultCalendar
        self.defaultReminderList = defaultReminderList
        self.onEdit = onEdit
        self.onAddSelected = onAddSelected
        self.onDismiss = onDismiss
        _selectedCalendar = State(initialValue: defaultCalendar ?? calendars.first)
        _selectedReminderList = State(initialValue: defaultReminderList ?? reminderLists.first)
    }

    var body: some View {
        NavigationView {
            List {
                if eventItemsExist {
                    Section(header: Text("Calendar")) {
                        if calendars.isEmpty {
                            Text("No calendars available. Enable calendar access in Settings.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        } else {
                            Picker("Calendar", selection: calendarSelectionBinding) {
                                ForEach(calendars, id: \.id) { calendar in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(hexString: calendar.colorHex ?? "#808080"))
                                            .frame(width: 10, height: 10)
                                        Text(calendar.title)
                                    }
                                    .tag(calendar.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }

                if reminderItemsExist {
                    Section(header: Text("Reminder List")) {
                        if reminderLists.isEmpty {
                            Text("No reminder lists available. Enable reminders access in Settings.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        } else {
                            Picker("Reminder List", selection: reminderSelectionBinding) {
                                ForEach(reminderLists, id: \.id) { list in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(hexString: list.colorHex ?? "#808080"))
                                            .frame(width: 10, height: 10)
                                        Text(list.title)
                                    }
                                    .tag(list.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }

                Section(header: Text("Detected Items")) {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { include.contains(item.id) },
                                set: { newVal in
                                    if newVal { include.insert(item.id) } else { include.remove(item.id) }
                                }
                            ))
                            .labelsHidden()

                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title)
                                    .font(.body.weight(.semibold))
                                if let date = item.suggestedDate {
                                    Text(DateFormatter.ai_short.string(from: date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                HStack(spacing: 8) {
                                    Button("Edit") { onEdit(item.id) }
                                        .buttonStyle(.bordered)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Review & Add All (\(items.count))")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Selected (\(selectedItems.count))") {
                        onAddSelected(selectedItems, selectedCalendar, selectedReminderList)
                    }
                    .disabled(addButtonDisabled)
                }
            }
        }
    }

    private var addButtonDisabled: Bool {
        let count = selectedItems.count
        if count == 0 { return true }
        if hasSelectedEvents && selectedCalendar == nil && calendars.isEmpty == false { return true }
        if hasSelectedReminders && selectedReminderList == nil && reminderLists.isEmpty == false { return true }
        if hasSelectedEvents && calendars.isEmpty { return true }
        if hasSelectedReminders && reminderLists.isEmpty { return true }
        return false
    }

    private var calendarSelectionBinding: Binding<String> {
        Binding(
            get: {
                selectedCalendar?.id ?? calendars.first?.id ?? ""
            },
            set: { newId in
                selectedCalendar = calendars.first { $0.id == newId }
            }
        )
    }

    private var reminderSelectionBinding: Binding<String> {
        Binding(
            get: {
                selectedReminderList?.id ?? reminderLists.first?.id ?? ""
            },
            set: { newId in
                selectedReminderList = reminderLists.first { $0.id == newId }
            }
        )
    }
}

// Local color helper to support both `hexString:` and `hex:` usages safely
private extension Color {
    init(hex: String?) {
        guard let hex = hex else { self = .gray; return }
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        var rgba: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgba)
        switch cleaned.count {
        case 6: // RRGGBB
            let red = Double((rgba & 0xFF0000) >> 16) / 255.0
            let green = Double((rgba & 0x00FF00) >> 8) / 255.0
            let blue = Double(rgba & 0x0000FF) / 255.0
            self = Color(red: red, green: green, blue: blue)
        case 8: // RRGGBBAA
            let red = Double((rgba & 0xFF000000) >> 24) / 255.0
            let green = Double((rgba & 0x00FF0000) >> 16) / 255.0
            let blue = Double((rgba & 0x0000FF00) >> 8) / 255.0
            let alpha = Double(rgba & 0x000000FF) / 255.0
            self = Color(red: red, green: green, blue: blue).opacity(alpha)
        default:
            self = .gray
        }
    }
}
