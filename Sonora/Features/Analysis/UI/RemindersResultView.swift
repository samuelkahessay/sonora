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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(reminder.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                PriorityBadge(priority: reminder.priority)
                ConfidenceBadge(confidence: reminder.confidence)
            }
            
            if let dueDate = reminder.dueDate {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                    Text("Due: \(formatDate(dueDate))")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
            }
            
            Text(reminder.sourceText)
                .font(.caption2)
                .foregroundColor(.semantic(.textTertiary))
                .italic()
                .lineLimit(2)
                .padding(.top, 2)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.semantic(.bgPrimary))
        .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Priority level badge
private struct PriorityBadge: View {
    let priority: RemindersData.DetectedReminder.Priority
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: priorityIcon)
                .font(.caption2)
            Text(priority.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(priority.color).opacity(0.2))
        .foregroundColor(Color(priority.color))
        .cornerRadius(4)
    }
    
    private var priorityIcon: String {
        switch priority {
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "minus.circle.fill"
        case .low: return "arrow.down.circle.fill"
        }
    }
}

/// Confidence level badge (reused from EventsResultView but with different styling)
private struct ConfidenceBadge: View {
    let confidence: Float
    
    private var confidenceLevel: EventsData.DetectedEvent.ConfidenceLevel {
        switch confidence {
        case 0.8...1.0: return .high
        case 0.6..<0.8: return .medium
        default: return .low
        }
    }
    
    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(confidenceLevel.color).opacity(0.1))
            .foregroundColor(Color(confidenceLevel.color))
            .cornerRadius(4)
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
