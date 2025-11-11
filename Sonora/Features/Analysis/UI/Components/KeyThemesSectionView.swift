import SwiftUI

/// Section view for displaying key themes in Distill results
struct KeyThemesSectionView: View {
    let themes: [String]

    @ScaledMetric private var headerSpacing: CGFloat = 6
    @ScaledMetric private var contentSpacing: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: "tag.circle")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Key Themes")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.textPrimary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Key themes section")

            // Theme pills/tags
            FlowLayout(spacing: 8) {
                ForEach(themes, id: \.self) { theme in
                    Text(theme)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.semantic(.textPrimary))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.semantic(.brandPrimary).opacity(0.1))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.semantic(.brandPrimary).opacity(0.3), lineWidth: 1)
                        )
                        .accessibilityLabel("Theme: \(theme)")
                }
            }
        }
    }
}

// MARK: - FlowLayout Helper

/// Simple flow layout for wrapping theme tags
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview("Key Themes") {
    KeyThemesSectionView(themes: ["Work-life boundaries", "Self-advocacy", "Stress management", "Decision fatigue"])
        .padding()
}
