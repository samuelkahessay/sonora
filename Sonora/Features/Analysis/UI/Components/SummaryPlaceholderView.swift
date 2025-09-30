import SwiftUI

internal struct SummaryPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.quote")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
                Text("Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textSecondary))

                Spacer()

                LoadingIndicator(size: .small)
            }

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.semantic(.separator).opacity(0.3))
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.semantic(.separator).opacity(0.3))
                    .frame(height: 12)
                    .scaleEffect(x: 0.75, anchor: .leading)
            }
        }
        .redacted(reason: .placeholder)
        .frame(minHeight: 130)
    }
}

