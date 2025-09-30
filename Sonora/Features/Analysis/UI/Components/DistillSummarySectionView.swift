import SwiftUI

internal struct DistillSummarySectionView: View {
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.quote")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
            }

            Text(summary)
                .font(.body)
                .foregroundColor(.semantic(.textPrimary))
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
        }
    }
}
