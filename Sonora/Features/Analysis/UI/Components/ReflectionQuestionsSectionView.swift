import SwiftUI

internal struct ReflectionQuestionsSectionView: View {
    let questions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.warning))
                Text("Reflection Questions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.semantic(.textSecondary))
                            .frame(minWidth: 20)

                        Text(question)
                            .font(.callout)
                            .foregroundColor(.semantic(.textPrimary))
                            .lineSpacing(2)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.semantic(.warning).opacity(0.05),
                                Color.semantic(.warning).opacity(0.02)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                }
            }
        }
    }
}
