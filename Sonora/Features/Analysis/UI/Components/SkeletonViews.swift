import SwiftUI

// MARK: - Summary Skeleton

/// Skeleton loading view for summary section during parallel distill processing
struct SummarySkeleton: View {
    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header skeleton (icon + "Summary" text)
            HStack(spacing: 6) {
                Circle()
                    .fill(shimmerGradient)
                    .frame(width: 16, height: 16)

                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: 80, height: 16)
            }

            // Content lines (simulating 3-4 lines of summary text)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(height: 14)
                }
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: UIScreen.main.bounds.width * 0.6, height: 14)
            }
        }
        .onAppear {
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.semantic(.fillSecondary), location: max(0, shimmerPhase - 0.3)),
                .init(color: Color.semantic(.fillSecondary).opacity(0.6), location: shimmerPhase),
                .init(color: Color.semantic(.fillSecondary), location: min(1, shimmerPhase + 0.3))
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Reflection Questions Skeleton

/// Skeleton loading view for reflection questions section during parallel distill processing
struct ReflectionQuestionsSkeleton: View {
    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header skeleton (icon + "Reflection Questions" text)
            HStack(spacing: 6) {
                Circle()
                    .fill(shimmerGradient)
                    .frame(width: 16, height: 16)

                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: 160, height: 16)
            }

            // Question cards (3 placeholder cards)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<3) { index in
                    questionCardSkeleton(width: questionWidth(for: index))
                }
            }
        }
        .onAppear {
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
    }

    @ViewBuilder
    private func questionCardSkeleton(width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Question number placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerGradient)
                .frame(width: 20, height: 14)

            // Question text placeholder (2 lines)
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: width, height: 14)
            }
        }
        .padding(SonoraDesignSystem.Spacing.md_sm)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.semantic(.fillSecondary).opacity(0.3),
                    Color.semantic(.fillSecondary).opacity(0.1)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(SonoraDesignSystem.Spacing.cardRadius)
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.semantic(.fillSecondary), location: max(0, shimmerPhase - 0.3)),
                .init(color: Color.semantic(.fillSecondary).opacity(0.6), location: shimmerPhase),
                .init(color: Color.semantic(.fillSecondary), location: min(1, shimmerPhase + 0.3))
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Vary question width for more natural appearance
    private func questionWidth(for index: Int) -> CGFloat {
        let baseWidth = UIScreen.main.bounds.width * 0.7
        let variations: [CGFloat] = [1.0, 0.85, 0.92]
        return baseWidth * variations[index % variations.count]
    }
}

// MARK: - Generic Skeleton Line

/// Reusable skeleton line component for custom skeleton views
struct SkeletonLine: View {
    let width: CGFloat?
    let height: CGFloat
    @State private var shimmerPhase: CGFloat = 0

    init(width: CGFloat? = nil, height: CGFloat = 14) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(shimmerGradient)
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.semantic(.fillSecondary), location: max(0, shimmerPhase - 0.3)),
                .init(color: Color.semantic(.fillSecondary).opacity(0.6), location: shimmerPhase),
                .init(color: Color.semantic(.fillSecondary), location: min(1, shimmerPhase + 0.3))
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
