import SwiftUI

/// Main onboarding flow container (native paging)
struct OnboardingView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel = DIContainer.shared.viewModelFactory().createOnboardingViewModel()
    @StateObject private var onboardingConfiguration = OnboardingConfiguration.shared

    // MARK: - State
    @SwiftUI.Environment(\.dismiss)
    private var dismiss
    @AccessibilityFocusState private var focusedElement: AccessibleElement?

    enum AccessibleElement { case pageContent }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $viewModel.currentPageIndex) {
                ForEach(Array(OnboardingPage.allCases.enumerated()), id: \.offset) { index, page in
                    pageView(for: page)
                        .tag(index)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Page \(index + 1) of \(viewModel.totalPages)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .automatic))
            .background(Color.semantic(.bgPrimary))
        }
        .errorAlert($viewModel.error) { viewModel.retryLastOperation() }
        .onChange(of: viewModel.currentPageIndex) { _, _ in
            FocusManager.shared.handleNavigationFocus { focusedElement = .pageContent }
        }
        .onReceive(onboardingConfiguration.$hasCompletedOnboarding) { completed in
            if completed { dismiss() }
        }
    }

    // MARK: - Page Views
    @ViewBuilder
    private func pageView(for page: OnboardingPage) -> some View {
        switch page {
        case .nameEntry:
            NameEntryView { name in
                    viewModel.saveUserName(name)
                    viewModel.goToNextPage()
            }
        case .howItWorks:
            HowItWorksView { viewModel.goToNextPage() }
        case .firstRecording:
            FirstRecordingPromptView(
                userName: viewModel.userName
            ) { viewModel.startFirstRecording() }
        }
    }
}

// MARK: - Previews

#Preview("Onboarding Flow") {
    OnboardingView()
}

#if DEBUG
#Preview("Onboarding - Name Entry") {
    struct PreviewWrapper: View {
        @StateObject private var viewModel = DIContainer.shared.viewModelFactory().createOnboardingViewModel()

        var body: some View {
            OnboardingView()
                .onAppear {
                    viewModel.goToPage(.nameEntry)
                }
        }
    }

    return PreviewWrapper()
}

#Preview("Onboarding - How It Works") {
    struct PreviewWrapper: View {
        @StateObject private var viewModel = DIContainer.shared.viewModelFactory().createOnboardingViewModel()

        var body: some View {
            OnboardingView()
                .onAppear {
                    viewModel.goToPage(.howItWorks)
                }
        }
    }

    return PreviewWrapper()
}

#Preview("Onboarding - First Recording") {
    struct PreviewWrapper: View {
        @StateObject private var viewModel = DIContainer.shared.viewModelFactory().createOnboardingViewModel()

        var body: some View {
            OnboardingView()
                .onAppear {
                    viewModel.goToPage(.firstRecording)
                }
        }
    }

    return PreviewWrapper()
}
#endif
