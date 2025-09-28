import SwiftUI

struct DebugSectionView: View {
    init() {}
    @SwiftUI.Environment(\.diContainer) private var container: DIContainer
    @State private var showEventsSheet = false
    @State private var showRemindersSheet = false
    @State private var sampleEvents: [EventsData.DetectedEvent] = []
    @State private var sampleReminders: [RemindersData.DetectedReminder] = []
    @State private var alertMessage: String? = nil

    var body: some View {
        SettingsCard {
            Text("Debug Tools")
                .font(SonoraDesignSystem.Typography.headingSmall)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Button {
                    OnboardingConfiguration.shared.forceShowOnboardingForTesting()
                } label: {
                    HStack { Label("Show Onboarding Again", systemImage: "rectangle.on.rectangle"); Spacer() }
                }
                .buttonStyle(.bordered)
                .tint(.semantic(.brandPrimary))

                Button {
                    prepareSampleEvents()
                    showEventsSheet = true
                } label: {
                    HStack { Label("Open Event Confirmation (Sample)", systemImage: "calendar.badge.plus"); Spacer(); Image(systemName: "chevron.right").foregroundColor(.semantic(.textTertiary)).font(.caption.weight(.semibold)) }
                }
                .buttonStyle(.plain)

                Button {
                    prepareSampleReminders()
                    showRemindersSheet = true
                } label: {
                    HStack { Label("Open Reminder Confirmation (Sample)", systemImage: "bell.badge"); Spacer(); Image(systemName: "chevron.right").foregroundColor(.semantic(.textTertiary)).font(.caption.weight(.semibold)) }
                }
                .buttonStyle(.plain)

                Button {
                    Task { await runAutoDetectionSample() }
                } label: {
                    HStack { Label("Run Auto-Detection (Sample Transcript)", systemImage: "wand.and.stars"); Spacer() }
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $showEventsSheet) {
            EventConfirmationView(detectedEvents: sampleEvents).withDIContainer()
        }
        .sheet(isPresented: $showRemindersSheet) {
            ReminderConfirmationView(detectedReminders: sampleReminders).withDIContainer()
        }
        .alert("Auto-Detection", isPresented: Binding(get: { alertMessage != nil }, set: { _ in alertMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func prepareSampleEvents() {
        sampleEvents = [
            EventsData.DetectedEvent(
                title: "Meet John Doe",
                startDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                location: "Conference Room A",
                participants: ["John Doe", "You"],
                confidence: 0.92,
                sourceText: "Let's meet John tomorrow at 3 PM in Conference Room A"
            ),
            EventsData.DetectedEvent(
                title: "Project Sync",
                startDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
                location: "Zoom",
                participants: ["Team"],
                confidence: 0.85,
                sourceText: "Schedule a project sync Friday at 10am via Zoom"
            )
        ]
    }

    private func prepareSampleReminders() {
        sampleReminders = [
            RemindersData.DetectedReminder(
                title: "Buy groceries",
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                priority: .medium,
                confidence: 0.9,
                sourceText: "Don't forget to buy groceries tomorrow"
            ),
            RemindersData.DetectedReminder(
                title: "Send report",
                dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
                priority: .high,
                confidence: 0.82,
                sourceText: "Remember to send the quarterly report this week"
            )
        ]
    }

    private func runAutoDetectionSample() async {
        let sample = "Meet John tomorrow at 3pm about the project. Also remember to send the report this week."
        let memoId = UUID()
        do {
            let result = try await container.detectEventsAndRemindersUseCase().execute(transcript: sample, memoId: memoId)
            let eCount = result.events?.events.count ?? 0
            let rCount = result.reminders?.reminders.count ?? 0
            alertMessage = "Detected: \(eCount) event(s), \(rCount) reminder(s)."
        } catch {
            alertMessage = "Detection failed: \(error.localizedDescription)"
        }
    }
}

// Preview intentionally omitted to avoid build issues in some environments
