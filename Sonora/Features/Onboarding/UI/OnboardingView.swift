import SwiftUI

/// Main onboarding flow container
struct OnboardingView: View {
    
    // MARK: - ViewModel
    @StateObject private var viewModel = OnboardingViewModel()
    @StateObject private var onboardingConfiguration = OnboardingConfiguration.shared
    
    // MARK: - State
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Page content
                TabView(selection: $viewModel.currentPageIndex) {
                    ForEach(Array(OnboardingPage.allCases.enumerated()), id: \.element) { pair in
                        let (index, page) = pair
                        pageView(for: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentPageIndex)
                
                // Navigation controls
                navigationControls
            }
            .background(Color.semantic(.bgPrimary))
            .navigationBarHidden(true)
            .errorAlert($viewModel.error) {
                viewModel.retryLastOperation()
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
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.lg)
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentPageIndex)
    }
    
    // MARK: - Page Views
    
    @ViewBuilder
    private func pageView(for page: OnboardingPage) -> some View {
        switch page {
        case .welcome:
            welcomePageView
        case .privacy:
            privacyPageView
        case .microphone:
            microphonePageView
        case .features:
            featuresPageView
        }
    }
    
    @ViewBuilder
    private var welcomePageView: some View {
        OnboardingPageView(
            page: .welcome,
            onPrimaryAction: {
                viewModel.goToNextPage()
            },
            onSkip: {
                viewModel.skipOnboarding()
            }
        )
    }
    
    @ViewBuilder
    private var privacyPageView: some View {
        OnboardingPageView(
            page: .privacy,
            onPrimaryAction: {
                viewModel.goToNextPage()
            },
            onSkip: {
                viewModel.skipOnboarding()
            }
        )
    }
    
    @ViewBuilder
    private var microphonePageView: some View {
        let showPrimaryButton = viewModel.microphonePermissionStatus == .notDetermined
        let showSettingsButton = viewModel.microphonePermissionStatus == .denied
        
        VStack(spacing: Spacing.xl) {
            OnboardingPageView(
                page: .microphone,
                onPrimaryAction: showPrimaryButton ? {
                    viewModel.requestMicrophonePermission()
                } : nil,
                onSkip: {
                    viewModel.skipOnboarding()
                },
                isLoading: viewModel.isRequestingPermission,
                primaryButtonStyle: showSettingsButton ? .warning : .primary
            )
            
            // Permission status feedback
            permissionStatusView
        }
    }
    
    @ViewBuilder
    private var featuresPageView: some View {
        OnboardingPageView(
            page: .features,
            onPrimaryAction: {
                viewModel.completeOnboarding()
            },
            onSkip: {
                viewModel.skipOnboarding()
            }
        )
    }
    
    // MARK: - Permission Status View
    
    @ViewBuilder
    private var permissionStatusView: some View {
        switch viewModel.microphonePermissionStatus {
        case .granted:
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.semantic(.success))
                Text("Microphone access granted")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.success))
            }
            .padding()
            .background(Color.semantic(.success).opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, Spacing.xl)
            
        case .denied:
            VStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.semantic(.warning))
                    Text("Microphone access denied")
                        .font(.subheadline)
                        .foregroundColor(.semantic(.warning))
                }
                
                Text("You can enable microphone access in Settings to unlock recording features.")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
                    .multilineTextAlignment(.center)
                
                Button("Open Settings") {
                    viewModel.openSettings()
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(Color.semantic(.warning))
                .foregroundColor(.semantic(.textInverted))
                .cornerRadius(8)
            }
            .padding()
            .background(Color.semantic(.warning).opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, Spacing.xl)
            
        case .restricted:
            HStack(spacing: Spacing.sm) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.semantic(.textSecondary))
                Text("Microphone access is restricted")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
            }
            .padding()
            .background(Color.semantic(.fillSecondary))
            .cornerRadius(12)
            .padding(.horizontal, Spacing.xl)
            
        case .notDetermined:
            // Show nothing, let the primary button handle the request
            EmptyView()
        }
    }
    
    // MARK: - Navigation Controls
    
    @ViewBuilder
    private var navigationControls: some View {
        HStack {
            // Back button
            Button(action: {
                viewModel.goToPreviousPage()
            }) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                    Text("Back")
                        .font(.body)
                }
                .foregroundColor(.semantic(.textSecondary))
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
            }
            .opacity(viewModel.isFirstPage ? 0 : 1)
            .disabled(viewModel.isFirstPage)
            
            Spacer()
            
            // Next button (when applicable)
            if !viewModel.isLastPage && viewModel.canGoNext {
                Button("Next") {
                    viewModel.goToNextPage()
                }
                .font(.body.weight(.medium))
                .foregroundColor(.semantic(.brandPrimary))
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.lg)
    }
}

// MARK: - Previews

#Preview("Onboarding Flow") {
    OnboardingView()
}

#if DEBUG
#Preview("Onboarding - Welcome") {
    struct PreviewWrapper: View {
        @StateObject private var viewModel = OnboardingViewModel()
        
        var body: some View {
            OnboardingView()
                .onAppear {
                    viewModel.goToPage(.welcome)
                }
        }
    }
    
    return PreviewWrapper()
}

#Preview("Onboarding - Privacy") {
    struct PreviewWrapper: View {
        @StateObject private var viewModel = OnboardingViewModel()
        
        var body: some View {
            OnboardingView()
                .onAppear {
                    viewModel.goToPage(.privacy)
                }
        }
    }
    
    return PreviewWrapper()
}

#Preview("Onboarding - Microphone") {
    struct PreviewWrapper: View {
        @StateObject private var viewModel = OnboardingViewModel()
        
        var body: some View {
            OnboardingView()
                .onAppear {
                    viewModel.goToPage(.microphone)
                }
        }
    }
    
    return PreviewWrapper()
}

#Preview("Onboarding - Features") {
    struct PreviewWrapper: View {
        @StateObject private var viewModel = OnboardingViewModel()
        
        var body: some View {
            OnboardingView()
                .onAppear {
                    viewModel.goToPage(.features)
                }
        }
    }
    
    return PreviewWrapper()
}
#endif
