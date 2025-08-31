import SwiftUI

/// Main onboarding flow container
struct OnboardingView: View {
    
    // MARK: - ViewModel
    @StateObject private var viewModel = OnboardingViewModel()
    @StateObject private var onboardingConfiguration = OnboardingConfiguration.shared
    
    // MARK: - State
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var focusedElement: AccessibleElement?
    
    enum AccessibleElement {
        case pageContent
        case primaryButton
        case nextButton
        case backButton
        case skipButton
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Page content
                TabView(selection: $viewModel.currentPageIndex) {
                    ForEach(Array(OnboardingPage.allCases.enumerated()), id: \.offset) { pair in
                        let index = pair.offset
                        let page = pair.element
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
            .onChange(of: viewModel.currentPageIndex) { _, newIndex in
                FocusManager.shared.handleNavigationFocus {
                    focusedElement = .pageContent
                }
            }
            .onChange(of: viewModel.microphonePermissionStatus) { _, status in
                if status == .granted {
                    HapticManager.shared.playProcessingComplete()
                    FocusManager.shared.announceAndFocus(
                        "Microphone permission granted. You can now proceed to the final step.",
                        delay: FocusManager.standardDelay
                    ) {
                        focusedElement = .nextButton
                    }
                } else if status == .denied {
                    HapticManager.shared.playWarning()
                    FocusManager.shared.announceChange("Microphone permission was denied. You can still use the app with limited functionality.")
                }
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
                    .accessibilityHidden(true)
                Text("Microphone access granted")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.success))
            }
            .padding()
            .background(Color.semantic(.success).opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, Spacing.xl)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Success: Microphone access granted")
            .accessibilityAddTraits(.isStaticText)
            
        case .denied:
            VStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.semantic(.warning))
                        .accessibilityHidden(true)
                    Text("Microphone access denied")
                        .font(.subheadline)
                        .foregroundColor(.semantic(.warning))
                }
                
                Text("You can enable microphone access in Settings to unlock recording features.")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
                    .multilineTextAlignment(.center)
                
                Button("Open Settings") {
                    HapticManager.shared.playSelection()
                    viewModel.openSettings()
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(Color.semantic(.warning))
                .foregroundColor(.semantic(.textInverted))
                .cornerRadius(8)
                .accessibilityLabel("Open Settings")
                .accessibilityHint("Double tap to open Settings app where you can enable microphone access")
            }
            .padding()
            .background(Color.semantic(.warning).opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, Spacing.xl)
            .accessibilityElement(children: .contain)
            
        case .restricted:
            HStack(spacing: Spacing.sm) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.semantic(.textSecondary))
                    .accessibilityHidden(true)
                Text("Microphone access is restricted")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
            }
            .padding()
            .background(Color.semantic(.fillSecondary))
            .cornerRadius(12)
            .padding(.horizontal, Spacing.xl)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Warning: Microphone access is restricted on this device")
            .accessibilityAddTraits(.isStaticText)
            
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
                HapticManager.shared.playSelection()
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
            .accessibilityLabel("Go back to previous page")
            .accessibilityHint("Double tap to return to the previous onboarding step")
            .accessibilityFocused($focusedElement, equals: .backButton)
            // SwiftUI sets the 'dimmed' state automatically when disabled
            
            Spacer()
            
            // Next button (when applicable)
            if !viewModel.isLastPage && viewModel.canGoNext {
                Button("Next") {
                    HapticManager.shared.playSelection()
                    viewModel.goToNextPage()
                }
                .font(.body.weight(.medium))
                .foregroundColor(.semantic(.brandPrimary))
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .accessibilityLabel("Continue to next page")
                .accessibilityHint("Double tap to proceed to the next onboarding step")
                .accessibilityFocused($focusedElement, equals: .nextButton)
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
