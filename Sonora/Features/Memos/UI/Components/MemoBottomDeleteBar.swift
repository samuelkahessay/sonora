import SwiftUI

struct MemoBottomDeleteBar: View {
    let selectedCount: Int
    let onDelete: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                Text("\(selectedCount) selected")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))

                Spacer()

                Button(role: .destructive) {
                    HapticManager.shared.playDeletionFeedback()
                    onDelete()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                        Text("Delete")
                    }
                    .font(.headline)
                    .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .tint(.semantic(.error))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.thinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}

#Preview { MemoBottomDeleteBar(selectedCount: 2) {} }

