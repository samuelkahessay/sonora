import SwiftUI

internal struct DistillProgressSectionView: View {
    let progress: DistillProgressUpdate

    @ScaledMetric private var sectionSpacing: CGFloat = 8
    @ScaledMetric private var headerSpacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: "clock.fill")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.accentColor)
                Text("Processing Components (\(progress.completedComponents)/\(progress.totalComponents))")
                    .font(SonoraDesignSystem.Typography.sectionHeading)

                Spacer()

                if let latestComponent = progress.latestComponent {
                    Text(latestComponent.displayName)
                        .font(SonoraDesignSystem.Typography.metadata)
                        .foregroundColor(.semantic(.success))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.semantic(.success).opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Processing \(progress.completedComponents) of \(progress.totalComponents) components\(progress.latestComponent.map { ", currently processing \($0.displayName)" } ?? "")")

            ProgressView(value: progress.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                .accessibilityLabel("Progress: \(Int(progress.progress * 100))%")
        }
        .padding(SonoraDesignSystem.Spacing.md_sm)
        .background(Color.semantic(.fillSecondary))
        .cornerRadius(SonoraDesignSystem.Spacing.cardRadius)
        .animation(SonoraDesignSystem.Animation.progressUpdate, value: progress.completedComponents)
    }
}
