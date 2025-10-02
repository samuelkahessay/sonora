import SwiftUI

/// View for displaying detected reminders analysis results
struct RemindersResultView: View {
    let data: RemindersData
    @State private var showingReminderConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Detected Reminders")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(data.reminders.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.semantic(.brandPrimary).opacity(0.1))
                    .cornerRadius(8)
            }

            // Add to Reminders action
            if !data.reminders.isEmpty {
                Button {
                    HapticManager.shared.playSelection()
                    showingReminderConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add to Reminders")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Add detected items to Reminders")
                .sheet(isPresented: $showingReminderConfirmation) {
                    ReminderConfirmationView(detectedReminders: data.reminders)
                        .withDIContainer()
                }
            }

            if data.reminders.isEmpty {
                Text("No reminders detected in this memo")
                    .font(.body)
                    .foregroundColor(.semantic(.textSecondary))
                    .italic()
            } else {
                LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(data.reminders) { reminder in
                        ReminderItemView(reminder: reminder)
                    }
                }
            }
        }
        .padding()
        .background(Color.semantic(.bgSecondary))
        .cornerRadius(12)
    }
}

/// Individual reminder item view
private struct ReminderItemView: View {
    let reminder: RemindersData.DetectedReminder

    private var priorityColor: Color {
        switch reminder.priority {
        case .high: return Color(reminder.priority.color)
        case .medium: return Color(reminder.priority.color)
        case .low: return Color(reminder.priority.color)
        }
    }

    private var confidenceOpacity: Double {
        // Reduce opacity for low-confidence items
        switch reminder.confidence {
        case 0.8...1.0: return 1.0
        case 0.6..<0.8: return 0.9
        default: return 0.75
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Priority border on left
            Rectangle()
                .fill(priorityColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(reminder.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.semantic(.textPrimary))
                        .lineLimit(2)
                    Spacer()
                    PriorityBadge(priority: reminder.priority)
                        .accessibilityLabel("\(reminder.priority.rawValue) priority")
                }

                if let dueDate = reminder.dueDate {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.semantic(.textSecondary))
                        Text("Due \(formatDate(dueDate))")
                            .font(.system(size: 13))
                            .foregroundColor(.semantic(.textSecondary))
                    }
                    .accessibilityLabel("Due \(formatDate(dueDate))")
                }

                Text(reminder.sourceText)
                    .font(.system(size: 11))
                    .foregroundColor(.semantic(.textTertiary))
                    .italic()
                    .lineLimit(2)
                    .lineSpacing(2)
                    .accessibilityLabel("Source: \(reminder.sourceText)")
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
        }
        .background(Color.semantic(.bgPrimary))
        .cornerRadius(8)
        .opacity(confidenceOpacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private func formatDate(_ date: Date) -> String {
        date.mediumDateTimeString
    }

    private var accessibilityDescription: String {
        var description = "\(reminder.title). \(reminder.priority.rawValue) priority reminder."
        if let dueDate = reminder.dueDate {
            description += " Due \(formatDate(dueDate))."
        }
        let confidencePercent = Int(reminder.confidence * 100)
        description += " Detected with \(confidencePercent)% confidence."
        return description
    }
}

/// Priority level badge
private struct PriorityBadge: View {
    let priority: RemindersData.DetectedReminder.Priority

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: priorityIcon)
                .font(.system(size: 10, weight: .semibold))
            Text(priority.rawValue)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(priority.color).opacity(0.15))
        .foregroundColor(Color(priority.color))
        .cornerRadius(6)
    }

    private var priorityIcon: String {
        switch priority {
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "minus.circle.fill"
        case .low: return "checkmark.circle.fill"
        }
    }
}

#Preview {
    RemindersResultView(
        data: RemindersData(
            reminders: [
                RemindersData.DetectedReminder(
                    title: "Call dentist for appointment",
                    dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                    priority: .high,
                    confidence: 0.9,
                    sourceText: "I need to remember to call the dentist tomorrow to schedule my cleaning"
                ),
                RemindersData.DetectedReminder(
                    title: "Buy groceries",
                    dueDate: nil,
                    priority: .medium,
                    confidence: 0.8,
                    sourceText: "Don't forget to pick up groceries this week"
                ),
                RemindersData.DetectedReminder(
                    title: "Review quarterly report",
                    dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
                    priority: .low,
                    confidence: 0.6,
                    sourceText: "Maybe I should review the quarterly report sometime next week"
                )
            ]
        )
    )
    .padding()
}
