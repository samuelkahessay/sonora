import SwiftUI

/// Main onboarding flow container
struct OnboardingView: View {
    
    // MARK: - ViewModel
    @StateObject private var viewModel = DIContainer.shared.viewModelFactory().createOnboardingViewModel()
    @StateObject private var onboardingConfiguration = OnboardingConfiguration.shared
    
    // MARK: - State
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var focusedElement: AccessibleElement?
    @State private var navigationDirection: NavigationDirection = .forward
    @State private var lastPageIndex: Int = 0
    
    enum AccessibleElement {
        case pageContent
        case primaryButton
        case nextButton
        case backButton
        case skipButton
    }
    
    private enum NavigationDirection { case forward, backward }
    
    private var pageTransition: AnyTransition {
        switch navigationDirection {
        case .forward:
            return .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                               removal: .move(edge: .leading).combined(with: .opacity))
        case .backward:
            return .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                               removal: .move(edge: .trailing).combined(with: .opacity))
        }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Page content (manual, swipe disabled; transitions via buttons)
                ZStack {
                    pageView(for: viewModel.currentPage)
                        .id(viewModel.currentPage)
                        .transition(pageTransition)
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentPage)
                // No global navigation controls needed - each page has its own buttons
            }
            .background(Color.semantic(.bgPrimary))
            .navigationBarHidden(true)
            .errorAlert($viewModel.error) {
                viewModel.retryLastOperation()
            }
            .onChange(of: viewModel.currentPageIndex) { oldIndex, newIndex in
                navigationDirection = newIndex >= oldIndex ? .forward : .backward
                lastPageIndex = newIndex
                FocusManager.shared.handleNavigationFocus { focusedElement = .pageContent }
            }

            .onReceive(onboardingConfiguration.$hasCompletedOnboarding) { completed in
                if completed {
                    dismiss()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Progress Indicator
    
    @ViewBuilder
    private var progressIndicator: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<viewModel.totalPages, id: \.self) { index in
                Capsule()
                    .fill(index <= viewModel.currentPageIndex ? 
                          Color.semantic(.brandPrimary) : 
                          Color.semantic(.separator))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.lg)
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentPageIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("Page \(viewModel.currentPageIndex + 1) of \(viewModel.totalPages)")
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    // MARK: - Page Views
    
    @ViewBuilder
    private func pageView(for page: OnboardingPage) -> some View {
        switch page {
        case .nameEntry:
            nameEntryPageView
        case .howItWorks:
            howItWorksPageView
        case .firstRecording:
            firstRecordingPageView
        }
    }
    
    @ViewBuilder
    private var nameEntryPageView: some View {
        NameEntryView(
            onContinue: { name in
                print("➡️ Onboarding: Continue tapped (Name Entry)")
                viewModel.saveUserName(name)
                viewModel.goToNextPage()
            },
            onSkip: {
                print("⏭️ Onboarding: Skip tapped (Name Entry)")
                viewModel.skipOnboarding()
            }
        )
    }
    
    @ViewBuilder
    private var howItWorksPageView: some View {
        HowItWorksView(
            onContinue: {
                print("➡️ Onboarding: Continue tapped (How It Works)")
                viewModel.goToNextPage()
            },
            onSkip: {
                print("⏭️ Onboarding: Skip tapped (How It Works)")
                viewModel.skipOnboarding()
            }
        )
    }
    
    @ViewBuilder
    private var firstRecordingPageView: some View {
        FirstRecordingPromptView(
            userName: viewModel.userName,
            onStartRecording: {
                print("🎙️ Onboarding: Start Recording tapped")
                viewModel.startFirstRecording()
            },
            onSkip: {
                print("✅ Onboarding: Complete Setup tapped")
                viewModel.completeOnboarding()
            }
        )
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
