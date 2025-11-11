import SwiftUI

/// Section view for displaying closing note in Distill results
struct ClosingNoteSectionView: View {
    let note: String

    var body: some View {
        Text(note)
            .font(.caption)
            .foregroundColor(.semantic(.textSecondary))
            .lineSpacing(2)
            .multilineTextAlignment(.leading)
            .padding(.top, 4)
            .accessibilityLabel("Closing note: \(note)")
    }
}

// MARK: - Preview

#Preview("Closing Note") {
    ClosingNoteSectionView(note: "You're developing awareness of your needs—that's wisdom in practice.")
        .padding()
}
