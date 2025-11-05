//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.

import SwiftUI

// Note: CircularRecordButton has been replaced by SonicBloomRecordButton
// The new button is defined in SonicBloomRecordButton.swift and embodies
// the Sonora brand identity with organic waveform animations

struct RecordingView: View {
    @StateObject private var viewModel = DIContainer.shared.viewModelFactory().createRecordingViewModel()
    @StateObject private var promptViewModel = DIContainer.shared.viewModelFactory().createPromptViewModel()
    @AccessibilityFocusState private var focusedElement: AccessibleElement?
    @SwiftUI.Environment(\.scenePhase)
    private var scenePhase: ScenePhase
    @SwiftUI.Environment(\.colorScheme)
    private var colorScheme: ColorScheme
    @SwiftUI.Environment(\.accessibilityReduceMotion)
    private var reduceMotion: Bool
    @AppStorage("hasSeenInspireMe") private var hasSeenInspireMe: Bool = false
    @AppStorage("settings.showGuidedPrompts") private var showGuidedPrompts: Bool = true
    @State private var idlePulseTask: Task<Void, Never>?
    @State private var inspireButtonScale: CGFloat = 1.0
    @State private var inspireButtonOpacity: Double = 1.0

    enum AccessibleElement {
        case recordButton
        case permissionButton
        case statusText
    }

    // Extracted background to help the compiler type-check faster
    private var backgroundView: some View {
        ZStack {
            // Base surface that adapts to light/dark via semantic token
            Color.semantic(.bgPrimary)
                .ignoresSafeArea()

            // In light mode, keep the brand gradient + gentle highlight.
            // In dark mode, avoid bright tints that create a gray wash and banding.
            if colorScheme == .light {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.whisperBlue.opacity(0.3),
                        Color.clarityWhite
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.insightGold.opacity(0.08),
                        .clear
                    ]),
                    center: .center,
                    startRadius: 60,
                    endRadius: 300
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
    }

    // Extracted main content to help the compiler
    private var contentView: some View {
        NavigationStack {
            VStack(spacing: SonoraDesignSystem.Spacing.xxl) {

                if !viewModel.hasPermission {
                    VStack(spacing: SonoraDesignSystem.Spacing.lg) {
                        Image(systemName: viewModel.permissionStatus.iconName)
                            .font(.system(size: SonoraDesignSystem.Layout.iconExtraLarge))
                            .fontWeight(.medium)
                            .foregroundColor(.sparkOrange)
                            .accessibilityHidden(true)

                        Text(viewModel.permissionStatus.displayName)
                            .headingStyle(.medium)
                            .accessibilityAddTraits(.isHeader)

                        Text(getPermissionDescription())
                            .bodyStyle(.regular)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, SonoraDesignSystem.Spacing.breathingRoom)
                            .accessibilityLabel(getPermissionAccessibilityLabel())

                        if viewModel.isRequestingPermission {
                            VStack(spacing: 8) {
                                LoadingIndicator(size: .regular)
                                Text("Requesting microphone permission")
                                    .font(.subheadline)
                                    .foregroundColor(.semantic(.textSecondary))
                            }
                            .accessibilityLabel("Requesting microphone permission")
                        } else {
                            getPermissionButton()
                                .accessibilityFocused($focusedElement, equals: .permissionButton)
                        }
                    }
                    .padding()
                    .accessibilityElement(children: .contain)
                } else {
                    VStack(spacing: SonoraDesignSystem.Spacing.xxl) {
                        if viewModel.quotaBlocked {
                            NotificationBanner(
                                type: .warning,
                                message: "You've reached your monthly recording limit. Upgrade to Pro to keep recording.",
                                compact: false,
                                onPrimaryAction: {
                                    viewModel.showingPaywall = true
                                },
                                primaryTitle: "Upgrade"
                            ) {
                                    viewModel.quotaBlocked = false
                            }
                        } else if viewModel.isQuotaLow {
                            NotificationBanner(
                                type: .warning,
                                message: "Only \(viewModel.quotaRemainingMinutes) minutes left this month. Upgrade to Pro for unlimited recording.",
                                compact: false,
                                onPrimaryAction: {
                                    viewModel.showingPaywall = true
                                },
                                primaryTitle: "Upgrade"
                            ) {
                                // Dismissible but will reappear while quota is low
                            }
                        }
                        promptContent
                        .padding(.top, SonoraDesignSystem.Spacing.lg) // breathing room below nav
                        .opacity(showGuidedPrompts ? 1 : 0)
                        .accessibilityHidden(!showGuidedPrompts)
                        .allowsHitTesting(showGuidedPrompts)

                        // Recording cluster: button(s), timer overlay, inspire me (tighter spacing)
                        VStack(spacing: SonoraDesignSystem.Spacing.md) {
                            if viewModel.recordingState == .idle {
                                // Sonic Bloom recording button with brand identity
                                SonicBloomRecordButton(
                                    progress: viewModel.recordingProgress,
                                    isRecording: viewModel.isRecording
                                ) {
                                        HapticManager.shared.playRecordingFeedback(isStarting: !viewModel.isRecording)
                                        viewModel.toggleRecording()
                                }
                                .disabled(viewModel.state.isRecordButtonDisabled)
                                .accessibilityLabel(getRecordButtonAccessibilityLabel())
                                .accessibilityHint(getRecordButtonAccessibilityHint())
                                .accessibilityFocused($focusedElement, equals: .recordButton)
                                .accessibilityAddTraits(viewModel.isRecording ? [.startsMediaSession] : [.startsMediaSession])
                            } else {
                                // Pause/Resume + Stop controls while active
                                RecordingControlsView(
                                    recordingState: viewModel.recordingState,
                                    onPause: { viewModel.pauseRecording() },
                                    onResume: { viewModel.resumeRecording() },
                                    onStop: { viewModel.stopRecording() }
                                )
                                .transition(.scale.combined(with: .opacity))
                            }

                            // Monthly usage meter (Free only) - Smart visibility
                            if viewModel.shouldShowQuotaIndicator && !viewModel.isQuotaLow {
                                Text("This month • \(viewModel.monthlyUsageMinutes) of 60 min used")
                                    .font(.caption)
                                    .foregroundColor(.semantic(.textSecondary))
                                    .accessibilityLabel("This month, \(viewModel.monthlyUsageMinutes) of 60 minutes used")
                            }

                            // Timer overlay area (fixed height to avoid layout shifts)
                            ZStack(alignment: .top) {
                                timerOverlayView
                                    .opacity(viewModel.recordingState.isActive ? 1 : 0)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                    .accessibilityHidden(!viewModel.recordingState.isActive)
                            }
                            .frame(height: 80)
                            .animation(
                                UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut(duration: 0.25),
                                value: viewModel.recordingState.isActive
                            )

                            if showGuidedPrompts {
                                Button(action: {
                                    HapticManager.shared.playSelection()
                                    promptViewModel.refresh(excludingCurrent: true)
                                    hasSeenInspireMe = true
                                    resetIdlePulse()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.system(size: 28, weight: .regular))
                                            .foregroundColor(.yellow)
                                            .scaleEffect(inspireButtonScale)
                                            .opacity(inspireButtonOpacity)
                                        Text("Inspire Me")
                                            .font(SonoraDesignSystem.Typography.insightSerif)
                                            .foregroundColor(colorScheme == .dark ? .white : .semantic(.textPrimary))
                                    }
                                    .minTouchTarget()
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Inspire Me")
                                .accessibilityHint(getInspireMeAccessibilityHint())
                                .onAppear { setupInspireMeAnimation() }
                                .onDisappear { cancelIdlePulse() }
                            }
                        }
                        .padding(.top, SonoraDesignSystem.Spacing.xl) // add extra separation from prompt card
                    }
                    // Rely on outer breathingRoom() for horizontal padding
                }

                Spacer()
            }
            .breathingRoom()
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 0)
            }
            .navigationTitle("Sonora")
            .navigationBarTitleDisplayMode(.large)

            .onAppear {
                viewModel.onViewAppear()
                if showGuidedPrompts {
                    promptViewModel.loadInitial()
                } else {
                    promptViewModel.clear()
                }
            }
            .initialFocus {
                if viewModel.hasPermission {
                    focusedElement = .recordButton
                } else {
                    focusedElement = .permissionButton
                }
            }
            .onChange(of: viewModel.hasPermission) { _, hasPermission in
                if hasPermission {
                    HapticManager.shared.playPermissionGranted()
                    FocusManager.shared.announceAndFocus(
                        "Microphone access granted. You can now record voice memos.",
                        delay: FocusManager.standardDelay
                    ) {
                        focusedElement = .recordButton
                    }
                } else {
                    HapticManager.shared.playPermissionDenied()
                    FocusManager.shared.announceChange("Microphone access is required to record voice memos.")
                    focusedElement = .permissionButton
                }
            }
            .onChange(of: viewModel.isRecording) { _, isRecording in
                if isRecording {
                    // Mark the current prompt as used when recording begins
                    promptViewModel.markUsed()
                    FocusManager.shared.delayedFocus(after: FocusManager.quickDelay) {
                        focusedElement = .statusText
                    }
                    cancelIdlePulse()
                } else {
                    FocusManager.shared.delayedFocus(after: FocusManager.quickDelay) {
                        focusedElement = .recordButton
                    }
                    resetIdlePulse()
                }
            }
            .onChange(of: viewModel.isInCountdown) { _, isInCountdown in
                if isInCountdown {
                    focusedElement = .statusText
                }
            }
            .onChange(of: showGuidedPrompts) { _, isEnabled in
                if isEnabled {
                    promptViewModel.loadInitial()
                } else {
                    promptViewModel.clear()
                }
            }
            .alert("Recording Stopped", isPresented: $viewModel.showAutoStopAlert) {
                Button("OK") { viewModel.dismissAutoStopAlert() }
            } message: {
                Text(viewModel.autoStopMessage ?? "")
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // Check if we should stop recording due to Live Activity stop button
                    let sharedDefaults = UserDefaults(suiteName: "group.sonora.shared") ?? UserDefaults.standard
                    if sharedDefaults.bool(forKey: "shouldStopRecordingOnActivation") {
                        // Clear the flag immediately to prevent duplicate stops
                        sharedDefaults.removeObject(forKey: "shouldStopRecordingOnActivation")
                        sharedDefaults.synchronize()

                        // Stop recording if currently recording
                        if viewModel.isRecording || viewModel.recordingState == .paused {
                            HapticManager.shared.playRecordingFeedback(isStarting: false)
                            viewModel.stopRecording()
                        }
                    }
                    // Resume idle pulse when returning active
                    resetIdlePulse()
                } else {
                    // Stop any attention animation when not active
                    cancelIdlePulse()
                }
            }
        }
    }
    var body: some View {
        AnyView(ZStack {
            backgroundView
            contentView
        })
        .sheet(isPresented: $viewModel.showingPaywall) {
            PaywallView()
        }
    }

    // MARK: - Permission UI Helpers

    private func getPermissionDescription() -> String {
        switch viewModel.permissionStatus {
        case .notDetermined:
            return "Sonora needs microphone access to capture your voice."
        case .denied:
            return "Enable microphone access in Settings to record voice memos."
        case .restricted:
            return "Microphone access is restricted. Check device settings."
        case .granted:
            return "Your voice is ready to be captured"
        }
    }

    @ViewBuilder
    private func getPermissionButton() -> some View {
        switch viewModel.permissionStatus {
        case .notDetermined:
            Button("Enable Voice Capture") {
                HapticManager.shared.playSelection()
                viewModel.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRequestingPermission)
            .accessibilityLabel("Enable voice capture")
            .accessibilityHint("Double tap to allow Sonora to listen and capture your thoughts")

        case .denied:
            Button("Open Settings") {
                HapticManager.shared.playSelection()
                viewModel.openSettings()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Open Settings app")
            .accessibilityHint("Double tap to open Settings where you can enable microphone access for voice capture")

        case .restricted:
            Button("Review Settings") {
                HapticManager.shared.playSelection()
                viewModel.openSettings()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Review device settings")
            .accessibilityHint("Double tap to open Settings to check device restrictions for voice recording")

        case .granted:
            EmptyView()
        }
    }

    // MARK: - Accessibility Helpers

    private func getPermissionAccessibilityLabel() -> String {
        switch viewModel.permissionStatus {
        case .notDetermined:
            return "Sonora needs microphone access to record voice memos for transcription and analysis. Allow microphone access to continue."
        case .denied:
            return "Microphone access was denied. Open Settings to enable microphone access for recording voice memos."
        case .restricted:
            return "Microphone access is restricted on this device. Check your device restrictions in Settings to enable recording."
        case .granted:
            return "Microphone access is enabled. You can now record voice memos."
        }
    }

    private func getRecordButtonAccessibilityLabel() -> String {
        if viewModel.isRecording {
            return "Stop capturing your thoughts"
        } else {
            return "Share your thoughts"
        }
    }

    private func getRecordButtonAccessibilityHint() -> String {
        if viewModel.isRecording {
            return "Double tap to stop recording and preserve your reflection"
        } else {
            return "Double tap to begin sharing your thoughts through voice"
        }
    }

    private func getTimeAccessibilityLabel() -> String {
        let timeComponents = viewModel.formattedRecordingTime.split(separator: ":")
        if timeComponents.count == 2 {
            let minutes = String(timeComponents[0])
            let seconds = String(timeComponents[1])
            return "Recording time: \(minutes) minutes and \(seconds) seconds"
        }
        return "Recording time: \(viewModel.formattedRecordingTime)"
    }
}

extension RecordingView {
    private var promptContent: some View {
        Group {
            if let prompt = promptViewModel.currentPrompt {
                DynamicPromptCard(prompt: prompt) {
                    promptViewModel.refresh(excludingCurrent: true)
                }
            } else if promptViewModel.isLoading {
                // Initial load only: show placeholder to reduce perceived latency
                PromptPlaceholderCard()
            } else {
                FallbackPromptCard {
                    promptViewModel.refresh(excludingCurrent: true)
                }
            }
        }
    }
}

// MARK: - Timer Overlay View

private extension RecordingView {
    @ViewBuilder
    var timerOverlayView: some View {
        VStack(spacing: Spacing.sm) {
            Text(viewModel.formattedRecordingTime)
                .font(SonoraDesignSystem.Typography.timerDisplay)
                .foregroundColor(timerTextColor)
                .contentTransition(.numericText())
                .accessibilityLabel("Recording duration")
                .accessibilityValue(getTimeAccessibilityLabel())
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityFocused($focusedElement, equals: .statusText)

            if viewModel.isInCountdown {
                VStack(spacing: 4) {
                    Text("Recording ends in")
                        .headingStyle(.small)
                        .foregroundColor(.warningState)
                    Text("\(Int(ceil(viewModel.remainingTime)))")
                        .font(SonoraDesignSystem.Typography.timerDisplay)
                        .foregroundColor(.errorState)
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Recording ends in \(Int(ceil(viewModel.remainingTime))) seconds")
                .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var timerTextColor: Color {
        switch viewModel.recordingState {
        case .recording: return .semantic(.textPrimary)
        case .paused: return .semantic(.warning)
        case .idle: return .semantic(.textSecondary)
        }
    }

    // MARK: - Inspire Me Animation & Accessibility

    func setupInspireMeAnimation() {
        // First-launch gentle pulse
        if !hasSeenInspireMe { animateInspireMe(cycles: 3) }
        resetIdlePulse()
    }

    func animateInspireMe(cycles: Int) {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.2).repeatCount(cycles, autoreverses: true)) {
            inspireButtonScale = 1.05
            inspireButtonOpacity = 0.85
        }
        let total = Double(cycles) * 1.2
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            withAnimation(.easeOut(duration: 0.3)) {
                inspireButtonScale = 1.0
                inspireButtonOpacity = 1.0
            }
        }
    }

    func resetIdlePulse() {
        cancelIdlePulse()
        idlePulseTask = Task { [isRecording = viewModel.isRecording] in
            // Wait 6s of inactivity, then a brief two-cycle pulse
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if Task.isCancelled { return }
            if isRecording { return }
            if reduceMotion { return }
            animateInspireMe(cycles: 2)
        }
    }

    func cancelIdlePulse() {
        idlePulseTask?.cancel()
        idlePulseTask = nil
    }

func getInspireMeAccessibilityHint() -> String {
        if !hasSeenInspireMe {
            return "Need inspiration? Double tap to get a conversation starter"
        } else if idlePulseTask != nil {
            return "Stuck for ideas? Double tap for a new prompt"
        } else {
            return "Double tap to shuffle a new prompt"
        }
    }
}
