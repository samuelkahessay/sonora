import SwiftUI

internal struct DistillSummarySectionView: View {
    let summary: String

    @ScaledMetric private var sectionSpacing: CGFloat = 8
    @ScaledMetric private var headerSpacing: CGFloat = 6
    @ScaledMetric private var lineSpacing: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: "text.quote")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Summary")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.textPrimary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Summary section")

            Text(summary)
                .font(SonoraDesignSystem.Typography.bodyRegular)
                .foregroundColor(.semantic(.textPrimary))
                .lineSpacing(lineSpacing)
                .multilineTextAlignment(.leading)
        }
    }
}
