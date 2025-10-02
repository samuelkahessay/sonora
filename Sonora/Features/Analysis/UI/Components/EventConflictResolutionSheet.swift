import SwiftUI

struct EventConflictResolutionSheet: View {
    let duplicates: [ExistingEventDTO]
    let onProceed: () -> Void
    let onSkip: () -> Void

    @ScaledMetric private var spacing: CGFloat = 10

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: spacing) {
                Text("Possible duplicate found")
                    .font(.headline)
                Text("We found existing events near this time with a matching title or source. Create anyway?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                List(duplicates, id: \.identifier) { ev in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ev.title ?? "Untitled")
                            .font(.body.weight(.semibold))
                        Text(dateLine(ev))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .listStyle(.plain)

                HStack(spacing: spacing) {
                    Button("Skip") { onSkip() }
                        .buttonStyle(.bordered)
                    Button("Create Anyway") { onProceed() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, spacing)
            }
            .padding()
            .navigationTitle("Confirm Event")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func dateLine(_ ev: ExistingEventDTO) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return "\(df.string(from: ev.startDate)) – \(df.string(from: ev.endDate))\(ev.isAllDay ? " • All day" : "")"
    }
}

