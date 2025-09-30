import SwiftUI

/// Reusable onboarding page template component
struct OnboardingPageView: View {

    // MARK: - Properties
    let page: OnboardingPage
    let onPrimaryAction: (() -> Void)?
    let onSkip: () -> Void
    let isLoading: Bool

    // MARK: - Optional customization
    let showDetailedPoints: Bool
    let primaryButtonStyle: OnboardingButtonStyle

    // MARK: - Accessibility
    @AccessibilityFocusState private var focusedElement: AccessibleElement?

    enum AccessibleElement {
        case pageContent
        case primaryButton
        case skipButton
    }

    // MARK: - Button styles
    enum OnboardingButtonStyle {
        case primary
        case secondary
        case warning

        var backgroundColor: Color {
            switch self {
            case .primary:
                return .semantic(.brandPrimary)
            case .secondary:
                return .semantic(.fillSecondary)
            case .warning:
                return .semantic(.warning)
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary:
                return .semantic(.textInverted)
            case .secondary:
                return .semantic(.textPrimary)
            case .warning:
                return .semantic(.textInverted)
            }
        }
    }

    // MARK: - Initialization
    init(
        page: OnboardingPage,
        onPrimaryAction: (() -> Void)? = nil,
        onSkip: @escaping () -> Void,
        isLoading: Bool = false,
        showDetailedPoints: Bool = true,
        primaryButtonStyle: OnboardingButtonStyle = .primary
    ) {
        self.page = page
        self.onPrimaryAction = onPrimaryAction
        self.onSkip = onSkip
        self.isLoading = isLoading
        self.showDetailedPoints = showDetailedPoints
        self.primaryButtonStyle = primaryButtonStyle
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Header section
                VStack(spacing: Spacing.lg) {
                    // Icon
                    Image(systemName: page.iconName)
                        .font(.system(size: 64, weight: .medium))
                        .foregroundColor(.semantic(.brandPrimary))
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)

                    // Title and description
                    VStack(spacing: Spacing.md) {
                        Text(page.title)
                            .font(.system(.largeTitle, design: .serif))
                            .fontWeight(.bold)
                            .foregroundColor(.semantic(.textPrimary))
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)

                        Text(page.description)
                            .font(.system(.body, design: .serif))
                            .foregroundColor(.semantic(.textSecondary))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }
                .padding(.top, Spacing.xl)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(page.title). \(page.description)")
                .accessibilityFocused($focusedElement, equals: .pageContent)

                // Detailed points section
                if showDetailedPoints && !page.detailedPoints.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        ForEach(page.detailedPoints, id: \.self) { point in
                            OnboardingFeatureRow(text: point)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }

                Spacer(minLength: Spacing.xxl)

                // Action buttons
                VStack(spacing: Spacing.md) {
                    // Primary action button
                    if let primaryTitle = page.primaryButtonTitle,
                       let primaryAction = onPrimaryAction {
                        Button(action: {
                            HapticManager.shared.playSelection()
                            primaryAction()
                        }) {
                            HStack(spacing: Spacing.sm) {
                                if isLoading {
                                    LoadingIndicator(size: .small)
                                        .tint(.white)
                                        .accessibilityLabel("Loading")
                                }

                                Text(primaryTitle)
                                    .font(.system(.body, design: .serif))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.large)
                        .buttonBorderShape(.roundedRectangle)
                        .disabled(isLoading)
                        .opacity(isLoading ? 0.8 : 1.0)
                        .accessibilityLabel(primaryTitle)
                        .accessibilityHint(getPrimaryButtonHint())
                        .accessibilityFocused($focusedElement, equals: .primaryButton)
                        .accessibilityAddTraits(isLoading ? [.updatesFrequently] : [])
                    }

                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.semantic(.bgPrimary))
        .fontDesign(.serif)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedElement = .pageContent
            }
        }
    }

    // MARK: - Helper Methods

    private func getPrimaryButtonHint() -> String {
        switch page {
        case .nameEntry:
            return "Double tap to continue with your name"
        case .howItWorks:
            return "Double tap to continue to the recording prompt"
        case .firstRecording:
            return "Double tap to start your first voice memo"
        }
    }
}

// MARK: - Feature Row Component

/// Individual feature point display row
struct OnboardingFeatureRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            // Checkmark icon
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.semantic(.success))
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            // Feature text
            Text(text)
                .font(.system(.body, design: .serif))
                .foregroundColor(.semantic(.textPrimary))
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Feature: \(text)")
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Previews

#Preview("Name Entry Page") {
    OnboardingPageView(
        page: .nameEntry,
        onPrimaryAction: {
            print("Name entry primary action")
        },
        onSkip: {
            print("Skip tapped")
        }
    )
}

#Preview("How It Works Page") {
    OnboardingPageView(
        page: .howItWorks,
        onPrimaryAction: {
            print("How it works primary action")
        },
        onSkip: {
            print("Skip tapped")
        }
    )
}

#Preview("First Recording Page") {
    OnboardingPageView(
        page: .firstRecording,
        onPrimaryAction: {
            print("First recording primary action")
        },
        onSkip: {
            print("Skip tapped")
        }
    )
}

#Preview("Feature Row") {
    VStack(spacing: Spacing.sm) {
        OnboardingFeatureRow(text: "Privacy-first voice memos")
        OnboardingFeatureRow(text: "AI transcription & analysis")
        OnboardingFeatureRow(text: "Background recording support")
        OnboardingFeatureRow(text: "Beautiful native iOS design")
    }
    .padding()
    .background(Color.semantic(.bgPrimary))
}
