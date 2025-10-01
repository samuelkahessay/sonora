import SwiftUI

internal struct ActionItemsHostSectionView: View {
    @ObservedObject var permissionService: EventKitPermissionService

    // Visible items after filtering/sorting (provided by parent state)
    let visibleItems: [ActionItemDetectionUI]

    let addedRecords: [DistillAddedRecord]
    let isPro: Bool
    let isDetectionPending: Bool

    @Binding var showBatchSheet: Bool
    @Binding var batchInclude: Set<UUID>

    let calendars: [CalendarDTO]
    let reminderLists: [CalendarDTO]
    let defaultCalendar: CalendarDTO?
    let defaultReminderList: CalendarDTO?

    // Unified event handler
    let onEvent: (ActionItemHostEvent) -> Void

    @ScaledMetric private var sectionSpacing: CGFloat = 12
    @ScaledMetric private var headerSpacing: CGFloat = 10
    @ScaledMetric private var recordSpacing: CGFloat = 6
    @ScaledMetric private var itemSpacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            if shouldShowPermissionExplainer {
                PermissionExplainerCard(
                    permissions: permissionService
                ) { DIContainer.shared.systemNavigator().openSettings(completion: nil) }
            }

            HStack(spacing: headerSpacing) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Action Items")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                Spacer()
                if reviewCount > 1 {
                    Button("Review & Add All (\(reviewCount))") { openBatchReview() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Action Items section, \(reviewCount) items detected")

            if !addedRecords.isEmpty {
                VStack(alignment: .leading, spacing: recordSpacing) {
                    ForEach(addedRecords) { rec in
                        HStack(alignment: .top, spacing: itemSpacing) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.semantic(.success))
                            Text(rec.text)
                                .font(SonoraDesignSystem.Typography.metadata)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Added: \(rec.text)")
                    }
                }
                .padding(SonoraDesignSystem.Spacing.sm)
                .background(Color.semantic(.fillSecondary))
                .cornerRadius(SonoraDesignSystem.Spacing.cardRadius)
                .animation(.easeInOut(duration: 0.25), value: addedRecords.count)
            }

            if !visibleItems.isEmpty {
                LazyVStack(spacing: sectionSpacing) {
                    ForEach(visibleItems) { m in
                        ActionItemDetectionCard(
                            model: m,
                            isPro: isPro,
                            onEvent: { itemEvent in onEvent(.item(itemEvent)) }
                        )
                        .id(m.id)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: visibleItems.count)
            } else if isDetectionPending {
                HStack(spacing: itemSpacing) {
                    LoadingIndicator(size: .small)
                    Text("Detecting events & reminders…")
                        .font(SonoraDesignSystem.Typography.metadata)
                        .foregroundColor(.semantic(.textSecondary))
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Detecting events and reminders")
            } else if addedRecords.isEmpty {
                Text("No events or reminders detected")
                    .font(SonoraDesignSystem.Typography.metadata)
                    .foregroundColor(.semantic(.textSecondary))
            }
        }
        .sheet(isPresented: $showBatchSheet) {
            BatchAddActionItemsSheet(
                items: .constant(visibleItems),
                include: $batchInclude,
                isPro: isPro,
                calendars: calendars,
                reminderLists: reminderLists,
                defaultCalendar: defaultCalendar,
                defaultReminderList: defaultReminderList,
                onEdit: { id in onEvent(.item(.editToggle(id: id))) },
                onAddSelected: { selected, calendar, reminderList in
                    showBatchSheet = false
                    onEvent(.addSelected(items: selected, calendar: calendar, reminderList: reminderList))
                },
                onDismiss: { showBatchSheet = false; onEvent(.dismissSheet) }
            )
        }
    }

    private var shouldShowPermissionExplainer: Bool {
        let cal = permissionService.calendarPermissionState
        let rem = permissionService.reminderPermissionState
        return !(cal.isAuthorized && rem.isAuthorized)
    }

    private var reviewCount: Int { visibleItems.count }

    private func openBatchReview() {
        let selected = Set(visibleItems.map { $0.id })
        batchInclude = selected
        onEvent(.openBatch(selected: selected))
    }
}
