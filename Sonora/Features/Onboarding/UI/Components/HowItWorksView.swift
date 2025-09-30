import SwiftUI

/// How It Works visual demo component for onboarding
struct HowItWorksView: View {

    // MARK: - Properties
    let onContinue: () -> Void

    // MARK: - State
    @State private var currentIndex: Int = 0

    // MARK: - Constants
    private let steps = HowItWorksStep.allCases

    // MARK: - Body
    var body: some View {
        VStack(spacing: Spacing.md) {
            headerSection

            TabView(selection: $currentIndex) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HowItWorksCard(step: step)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .indexViewStyle(.page(backgroundDisplayMode: .automatic))
            .frame(height: 360)
            .padding(.bottom, Spacing.md)
            .padding(.horizontal, Spacing.lg)

            privacySection

            actionButtons
        }
        .padding(.top, Spacing.lg)
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, 160)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.semantic(.bgPrimary).ignoresSafeArea())
        .fontDesign(.serif)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: Spacing.xs) {
            Text("How It Works")
                .font(.system(.title, design: .serif))
                .fontWeight(.bold)
                .foregroundColor(.semantic(.textPrimary))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("Transform your voice into actionable insights.")
                .font(.system(.subheadline, design: .serif))
                .foregroundColor(.semantic(.textSecondary))
                .multilineTextAlignment(.center)
        }
    }

    private var privacySection: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "lock.shield")
                .font(.title3)
                .foregroundColor(.semantic(.success))
                .accessibilityHidden(true)

            Text("All processing respects your privacy")
                .font(.subheadline)
                .fontDesign(.default)
                .fontWeight(.medium)
                .foregroundColor(.semantic(.success))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.semantic(.success).opacity(0.1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Privacy guarantee: All processing respects your privacy")
    }

    private var actionButtons: some View {
        VStack(spacing: Spacing.md) {
            Button(action: handleContinue) {
                HStack(spacing: Spacing.sm) {
                    Text(buttonTitle)
                    Image(systemName: "arrow.right.circle.fill")
                }
                .font(.system(.body, design: .serif))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            .accessibilityLabel(buttonTitle)
        }
    }

    // MARK: - Helpers

    private var buttonTitle: String {
        currentIndex < steps.count - 1 ? "Continue" : "Get Started"
    }

    private func handleContinue() {
        HapticManager.shared.playSelection()
        if currentIndex < steps.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex += 1
            }
        } else {
            onContinue()
        }
    }
}

// MARK: - How It Works Card

private struct HowItWorksCard: View {
    let step: HowItWorksStep
    @State private var isAnimating: Bool = false
    private let barHeights: [CGFloat] = [28, 36, 24]

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: step.iconName)
                .font(.system(size: 36, weight: .medium))
                .symbolRenderingMode(.multicolor)
                .frame(height: 60)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.sm) {
                Text(step.title)
                    .font(.system(.headline, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
                    .multilineTextAlignment(.center)

                Text(step.description)
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.semantic(.textSecondary))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            stepVisualContent
        }
        .padding(.vertical, Spacing.lg)
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.semantic(.fillSecondary))
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isAnimating = true
            }
        }
        .onDisappear {
            isAnimating = false
        }
    }

    @ViewBuilder private var stepVisualContent: some View {
        switch step {
        case .record:
            HStack(spacing: Spacing.sm) {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .foregroundColor(.semantic(.brandPrimary))

                ForEach(Array(barHeights.enumerated()), id: \.offset) { index, height in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.semantic(.brandPrimary))
                        .frame(width: 4, height: height)
                        .scaleEffect(y: isAnimating ? 1.4 : 0.6, anchor: .bottom)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.9)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            .accessibilityLabel("Recording voice memo")

        case .transcribe:
            GeometryReader { proxy in
                let fullWidth = max(proxy.size.width, 1)
                VStack(spacing: Spacing.xs) {
                    ForEach(0..<3, id: \.self) { index in
                        let width = index == 2 ? fullWidth * 0.7 : fullWidth
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.semantic(.textSecondary))
                            .frame(width: width, height: 4, alignment: .leading)
                            .opacity(isAnimating ? 1.0 : 0.3)
                            .scaleEffect(x: isAnimating ? 1.0 : 0.1, anchor: .leading)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.9)
                                    .delay(Double(index) * 0.25),
                                value: isAnimating
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 28)
            .padding(.horizontal, Spacing.md)
            .accessibilityLabel("Converting speech to text")

        case .analyze:
            HStack(spacing: Spacing.lg) {
                InsightPill(color: .semantic(.info), label: "Summary")
                InsightPill(color: .semantic(.warning), label: "Action Items")
                InsightPill(color: .semantic(.success), label: "Reflection")
            }
            .scaleEffect(isAnimating ? 1.05 : 0.95)
            .animation(
                .spring(response: 0.8, dampingFraction: 0.8)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .accessibilityLabel("Analyzing and extracting insights")
        }
    }
}

private struct InsightPill: View {
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundColor(.semantic(.textSecondary))
        }
    }
}

// MARK: - How It Works Steps

enum HowItWorksStep: CaseIterable {
    case record
    case transcribe
    case analyze

    var title: String {
        switch self {
        case .record:
            return "1. Tap Record & Speak"
        case .transcribe:
            return "2. Automatic Transcription"
        case .analyze:
            return "3. Get Distilled Insights"
        }
    }

    var description: String {
        switch self {
        case .record:
            return "Simply tap the record button and speak naturally about anything on your mind."
        case .transcribe:
            return "Your voice is automatically converted to text with high accuracy."
        case .analyze:
            return "Distill gives you a concise summary, action items, and a reflection from your memo."
        }
    }

    var iconName: String {
        switch self {
        case .record:
            return "mic.badge.plus"
        case .transcribe:
            return "text.badge.checkmark"
        case .analyze:
            return "sparkles"
        }
    }
}

// MARK: - Previews

#Preview("How It Works - Step 1") {
    HowItWorksView(
        onContinue: {
            print("Continue tapped")
        }
    )
}

#Preview("How It Works - Interactive") {
    struct PreviewWrapper: View {
        @State private var isPresented = true

        var body: some View {
            if isPresented {
                HowItWorksView(
                    onContinue: {
                        print("Continue tapped")
                        isPresented = false
                    }
                )
            } else {
                Text("Demo completed")
                    .font(.title)
                    .foregroundColor(.semantic(.textPrimary))
            }
        }
    }

    return PreviewWrapper()
}
