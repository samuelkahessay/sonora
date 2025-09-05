import SwiftUI

struct AutoDetectionSectionView: View {
    @AppStorage("autoDetectEvents") private var autoDetectEvents: Bool = true
    @AppStorage("autoDetectReminders") private var autoDetectReminders: Bool = true
    @AppStorage("eventConfidenceThreshold") private var eventThreshold: Double = 0.7
    @AppStorage("reminderConfidenceThreshold") private var reminderThreshold: Double = 0.7

    var body: some View {
        SettingsCard {
            Text("Auto-Detection")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Toggle("Auto-detect Calendar Events", isOn: $autoDetectEvents)
                .accessibilityLabel("Auto-detect events in transcriptions")

            Toggle("Auto-detect Reminders", isOn: $autoDetectReminders)
                .accessibilityLabel("Auto-detect reminders in transcriptions")

            if autoDetectEvents || autoDetectReminders {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text("Event Confidence Threshold")
                            Spacer()
                            Text(String(format: "%.2f", eventThreshold))
                                .font(.caption)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                        Slider(value: $eventThreshold, in: 0.5...0.95)
                            .accessibilityLabel("Event detection confidence threshold")
                    }
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text("Reminder Confidence Threshold")
                            Spacer()
                            Text(String(format: "%.2f", reminderThreshold))
                                .font(.caption)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                        Slider(value: $reminderThreshold, in: 0.5...0.95)
                            .accessibilityLabel("Reminder detection confidence threshold")
                    }
                }
            }
        }
    }
}

#Preview {
    AutoDetectionSectionView()
        .padding()
}
