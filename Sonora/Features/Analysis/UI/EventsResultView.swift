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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                ConfidenceBadge(confidence: event.confidence)
            }
            
            if let startDate = event.startDate {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                    Text(formatDate(startDate))
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
            }
            
            if let location = event.location {
                HStack {
                    Image(systemName: "location")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                        .lineLimit(1)
                }
            }
            
            Text(event.sourceText)
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

/// Confidence level badge
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
            .background(Color(confidenceLevel.color).opacity(0.2))
            .foregroundColor(Color(confidenceLevel.color))
            .cornerRadius(4)
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
