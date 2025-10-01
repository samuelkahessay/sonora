import SwiftUI

internal struct ReflectionQuestionsSectionView: View {
    let questions: [String]

    @ScaledMetric private var sectionSpacing: CGFloat = 12
    @ScaledMetric private var headerSpacing: CGFloat = 6
    @ScaledMetric private var questionSpacing: CGFloat = 10
    @ScaledMetric private var lineSpacing: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: "questionmark.circle")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.warning))
                Text("Reflection Questions")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.textPrimary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Reflection Questions section, \(questions.count) questions")

            VStack(alignment: .leading, spacing: sectionSpacing) {
                ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                    HStack(alignment: .top, spacing: questionSpacing) {
                        Text("\(index + 1).")
                            .font(SonoraDesignSystem.Typography.cardBody)
                            .fontWeight(.medium)
                            .foregroundColor(.semantic(.textSecondary))
                            .frame(minWidth: 20)

                        Text(question)
                            .font(SonoraDesignSystem.Typography.cardBody)
                            .foregroundColor(.semantic(.textPrimary))
                            .lineSpacing(lineSpacing)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(SonoraDesignSystem.Spacing.md_sm)
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
                    .cornerRadius(SonoraDesignSystem.Spacing.cardRadius)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Question \(index + 1): \(question)")
                }
            }
        }
    }
}
