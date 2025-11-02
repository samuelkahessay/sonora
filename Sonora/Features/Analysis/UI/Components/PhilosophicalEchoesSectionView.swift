import SwiftUI

/// Displays connections between user insights and ancient wisdom traditions
/// Links personal reflections to philosophical thought spanning 2,000+ years
/// Pro-tier feature
internal struct PhilosophicalEchoesSectionView: View {
    let echoes: [PhilosophicalEcho]

    @ScaledMetric private var sectionSpacing: CGFloat = 12
    @ScaledMetric private var headerSpacing: CGFloat = 6
    @ScaledMetric private var echoSpacing: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: "book.pages")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.brandSecondary))
                Text("Philosophical Echoes")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.textPrimary))

                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundColor(.semantic(.brandPrimary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Philosophical Echoes section, Pro feature, \(echoes.count) connections found")

            VStack(alignment: .leading, spacing: echoSpacing) {
                ForEach(echoes) { echo in
                    PhilosophicalEchoCard(echo: echo)
                }
            }
        }
    }
}

/// Individual philosophical echo card showing tradition, connection, and quote
private struct PhilosophicalEchoCard: View {
    let echo: PhilosophicalEcho

    @ScaledMetric private var cardPadding: CGFloat = 12
    @ScaledMetric private var contentSpacing: CGFloat = 8

    private var traditionColor: Color {
        switch echo.tradition.colorHint {
        case "green": return .semantic(.success)
        case "orange": return .semantic(.warning)
        case "purple": return .semantic(.accent)
        case "blue": return .semantic(.brandPrimary)
        default: return .semantic(.brandSecondary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            // Philosophical tradition with icon
            HStack(spacing: 6) {
                Image(systemName: echo.tradition.iconName)
                    .font(.caption)
                    .foregroundColor(traditionColor)

                Text(echo.tradition.displayName)
                    .font(SonoraDesignSystem.Typography.cardBody)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
            }

            // Connection to user's insight
            Text(echo.connection)
                .font(SonoraDesignSystem.Typography.cardBody)
                .foregroundColor(.semantic(.textPrimary))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)

            // Optional quote with source
            if let quote = echo.quote {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text(""\(quote)"")
                            .font(.caption)
                            .italic()
                            .foregroundColor(.semantic(.textSecondary))
                    }

                    if let source = echo.source {
                        Text("— \(source)")
                            .font(.caption2)
                            .foregroundColor(.semantic(.textSecondary))
                    }
                }
                .padding(8)
                .background(
                    traditionColor.opacity(0.08)
                )
                .cornerRadius(6)
            }
        }
        .padding(cardPadding)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    traditionColor.opacity(0.06),
                    traditionColor.opacity(0.03)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(SonoraDesignSystem.Spacing.cardRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Philosophical connection: \(echo.tradition.displayName). \(echo.connection)")
    }
}
