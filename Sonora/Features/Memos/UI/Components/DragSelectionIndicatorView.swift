import SwiftUI

struct DragSelectionIndicatorView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.draw")
                .font(.title2)
                .foregroundColor(.semantic(.brandPrimary))

            Text("Drag to select")
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .shadow(radius: 4, y: 2)
        .padding(.top, 8)
        .padding(.trailing, 16)
    }
}

#Preview { DragSelectionIndicatorView() }

