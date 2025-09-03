import SwiftUI

struct MemoEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 44))
                .foregroundColor(.semantic(.textSecondary))
                .padding(.bottom, 4)
            Text("No memos yet")
                .font(.headline)
            Text("Start recording to see your audio memos here.")
                .font(.subheadline)
                .foregroundColor(.semantic(.textSecondary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No memos yet. Start recording to see your audio memos here.")
    }
}

#Preview {
    MemoEmptyStateView()
}

