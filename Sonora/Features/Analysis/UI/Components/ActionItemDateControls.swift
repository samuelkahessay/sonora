import SwiftUI

// MARK: - Event Date Control

/// Date picker with all-day toggle for event action items
/// Automatically initializes date to current if nil
struct EventDateControl: View {
    @Binding var date: Date?
    @Binding var isAllDay: Bool

    @ScaledMetric private var controlSpacing: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: controlSpacing) {
            DatePicker(
                "Event Date",
                selection: dateBinding,
                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)

            Toggle("All-day", isOn: $isAllDay)
        }
        .onAppear {
            if date == nil {
                date = Date()
            }
        }
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { date ?? Date() },
            set: { date = $0 }
        )
    }
}

// MARK: - Reminder Date Control

/// Optional date picker with all-day toggle for reminder action items
/// Allows toggling date inclusion on/off
struct ReminderDateControl: View {
    @Binding var date: Date?
    @Binding var isAllDay: Bool

    @ScaledMetric private var controlSpacing: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: controlSpacing) {
            Toggle("Include date", isOn: hasDateBinding)

            if date != nil {
                DatePicker(
                    "Reminder Date",
                    selection: dateBinding,
                    displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)

                Toggle("All-day", isOn: $isAllDay)
            }
        }
    }

    private var hasDateBinding: Binding<Bool> {
        Binding(
            get: { date != nil },
            set: { include in
                if include {
                    if date == nil { date = Date() }
                } else {
                    date = nil
                    isAllDay = false
                }
            }
        )
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { date ?? Date() },
            set: { date = $0 }
        )
    }
}
