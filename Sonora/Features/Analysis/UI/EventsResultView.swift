import SwiftUI

/// View for displaying detected events analysis results
struct EventsResultView: View {
    let data: EventsData
    @State private var showingEventConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Detected Events")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(data.events.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.semantic(.brandPrimary).opacity(0.1))
                    .cornerRadius(8)
            }

            // Add to Calendar action
            if !data.events.isEmpty {
                Button {
                    HapticManager.shared.playSelection()
                    showingEventConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add to Calendar")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Add detected events to Calendar")
                .sheet(isPresented: $showingEventConfirmation) {
                    EventConfirmationView(detectedEvents: data.events)
                        .withDIContainer()
                }
            }

            if data.events.isEmpty {
                Text("No events detected in this memo")
                    .font(.body)
                    .foregroundColor(.semantic(.textSecondary))
                    .italic()
            } else {
                LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(data.events) { event in
                        EventItemView(event: event)
                    }
                }
            }
        }
        .padding()
        .background(Color.semantic(.bgSecondary))
        .cornerRadius(12)
    }
}

/// Individual event item view
private struct EventItemView: View {
    let event: EventsData.DetectedEvent

    private var confidenceColor: Color {
        switch event.confidenceCategory {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }

    private var confidenceOpacity: Double {
        // Reduce opacity for low-confidence items
        switch event.confidence {
        case 0.8...1.0: return 1.0
        case 0.6..<0.8: return 0.9
        default: return 0.75
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Confidence border on left
            Rectangle()
                .fill(confidenceColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.semantic(.textPrimary))
                    .lineLimit(2)

                if let startDate = event.startDate {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(.semantic(.textSecondary))
                        Text(formatDate(startDate))
                            .font(.system(size: 13))
                            .foregroundColor(.semantic(.textSecondary))
                    }
                }

                if let location = event.location {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.semantic(.textSecondary))
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundColor(.semantic(.textSecondary))
                            .lineLimit(1)
                    }
                }

                Text(event.sourceText)
                    .font(.system(size: 11))
                    .foregroundColor(.semantic(.textTertiary))
                    .italic()
                    .lineLimit(2)
                    .lineSpacing(2)
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
        var description = "\(event.title). Event."
        if let startDate = event.startDate {
            description += " Starting \(formatDate(startDate))."
        }
        if let location = event.location {
            description += " At \(location)."
        }
        let confidencePercent = Int(event.confidence * 100)
        description += " Detected with \(confidencePercent)% confidence."
        return description
    }
}

#Preview {
    EventsResultView(
        data: EventsData(
            events: [
                EventsData.DetectedEvent(
                    title: "Team Meeting",
                    startDate: Date(),
                    location: "Conference Room A",
                    confidence: 0.9,
                    sourceText: "We have a team meeting tomorrow at 2 PM in conference room A"
                ),
                EventsData.DetectedEvent(
                    title: "Doctor Appointment",
                    startDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
                    confidence: 0.7,
                    sourceText: "Don't forget the doctor appointment on Thursday"
                )
            ]
        )
    )
    .padding()
}
