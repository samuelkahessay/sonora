import SwiftUI

struct AIBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
            Text("AI-generated")
        }
        .font(.caption2)
        .foregroundColor(.semantic(.brandPrimary))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.semantic(.brandPrimary).opacity(0.12))
        .clipShape(Capsule())
        .accessibilityLabel("AI generated content")
    }
}

