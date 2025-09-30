import SwiftUI

internal struct ActionItemsHostSectionView: View {
    @ObservedObject var permissionService: EventKitPermissionService

    @Binding var detectionItems: [ActionItemDetectionUI]
    @Binding var dismissedDetections: Set<UUID>
    @Binding var addedDetections: Set<UUID>

    let addedRecords: [DistillAddedRecord]
    let isPro: Bool
    let isDetectionPending: Bool

    @Binding var showBatchSheet: Bool
    @Binding var batchInclude: Set<UUID>

    let calendars: [CalendarDTO]
    let reminderLists: [CalendarDTO]
    let defaultCalendar: CalendarDTO?
    let defaultReminderList: CalendarDTO?

    let onOpenBatch: (Set<UUID>) -> Void
    let onEditToggle: (UUID) -> Void
    let onAdd: (ActionItemDetectionUI) -> Void
    let onDismissItem: (UUID) -> Void
    let onAddSelected: ([ActionItemDetectionUI], CalendarDTO?, CalendarDTO?) -> Void
    let onDismissSheet: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if shouldShowPermissionExplainer {
                PermissionExplainerCard(
                    permissions: permissionService
                ) { DIContainer.shared.systemNavigator().openSettings(completion: nil) }
            }

            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Action Items")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if reviewCount > 1 {
                    Button("Review & Add All (\(reviewCount))") { openBatchReview() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }

            if !addedRecords.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(addedRecords) { rec in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.semantic(.success))
                            Text(rec.text)
                                .font(.footnote)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                    }
                }
                .padding(10)
                .background(Color.semantic(.fillSecondary))
                .cornerRadius(8)
            }

            if !detectionItemsFiltered.isEmpty {
                VStack(spacing: 12) {
                    ForEach(detectionItemsFiltered) { m in
                        ActionItemDetectionCard(
                            model: m,
                            isPro: isPro,
                            onAdd: { updated in onAdd(updated) },
                            onEditToggle: { id in onEditToggle(id) },
                            onDismiss: { id in onDismissItem(id) }
                        )
                    }
                }
            } else if isDetectionPending {
                HStack(spacing: 8) {
                    LoadingIndicator(size: .small)
                    Text("Detecting events & reminders…")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
                .padding(.vertical, 4)
            } else if addedRecords.isEmpty {
                Text("No events or reminders detected")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
            }
        }
        .sheet(isPresented: $showBatchSheet) {
            BatchAddActionItemsSheet(
                items: $detectionItems,
                include: $batchInclude,
                isPro: isPro,
                calendars: calendars,
                reminderLists: reminderLists,
                defaultCalendar: defaultCalendar,
                defaultReminderList: defaultReminderList,
                onEdit: { id in onEditToggle(id) },
                onAddSelected: { selected, calendar, reminderList in
                    showBatchSheet = false
                    onAddSelected(selected, calendar, reminderList)
                },
                onDismiss: { showBatchSheet = false; onDismissSheet() }
            )
        }
    }

    private var shouldShowPermissionExplainer: Bool {
        let cal = permissionService.calendarPermissionState
        let rem = permissionService.reminderPermissionState
        return !(cal.isAuthorized && rem.isAuthorized)
    }

    private var detectionItemsFiltered: [ActionItemDetectionUI] {
        detectionItems
            .filter { !dismissedDetections.contains($0.id) && !addedDetections.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.confidence != rhs.confidence {
                    return order(lhs.confidence) < order(rhs.confidence)
                }
                if let ld = lhs.suggestedDate, let rd = rhs.suggestedDate {
                    return ld < rd
                }
                return false
            }
    }

    private func order(_ c: ActionItemConfidence) -> Int { c == .high ? 0 : (c == .medium ? 1 : 2) }
    private var reviewCount: Int { detectionItemsFiltered.count }

    private func openBatchReview() {
        let selected = Set(detectionItemsFiltered.map { $0.id })
        batchInclude = selected
        onOpenBatch(selected)
    }
}
