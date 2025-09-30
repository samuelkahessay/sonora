import SwiftUI

internal struct ReflectionQuestionsPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
                Text("Reflection Questions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textSecondary))

                Spacer()

                LoadingIndicator(size: .small)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.semantic(.textSecondary))
                            .frame(minWidth: 20)

                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.semantic(.separator).opacity(0.3))
                                .frame(height: 12)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.semantic(.separator).opacity(0.3))
                                .frame(height: 12)
                                .scaleEffect(x: 0.6, anchor: .leading)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(Color.semantic(.separator).opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .redacted(reason: .placeholder)
        .frame(minHeight: 180)
    }
}

