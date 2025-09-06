//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.

import SwiftUI

// Note: CircularRecordButton has been replaced by SonicBloomRecordButton
// The new button is defined in SonicBloomRecordButton.swift and embodies
// the Sonora brand identity with organic waveform animations

struct RecordingView: View {
    @StateObject private var viewModel = DIContainer.shared.viewModelFactory().createRecordingViewModel()
    @AccessibilityFocusState private var focusedElement: AccessibleElement?
    @SwiftUI.Environment(\.scenePhase) private var scenePhase: ScenePhase
    
    enum AccessibleElement {
        case recordButton
        case permissionButton
        case statusText
    }
    
    // Extracted background to help the compiler type-check faster
    private var backgroundView: some View {
        ZStack {
            // Background: base fill + subtle gradients for Liquid Glass contrast
            Color.semantic(.bgPrimary)
                .ignoresSafeArea()

            // Sonora brand background with purposeful minimalism
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.whisperBlue.opacity(0.3),
                    Color.clarityWhite
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle radial highlight for depth
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
    
    // Extracted main content to help the compiler
    private var contentView: some View {
        NavigationStack {
            VStack(spacing: SonoraDesignSystem.Spacing.xxl) {
                Spacer()
                
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
                    VStack(spacing: SonoraDesignSystem.Spacing.xl) {
                        
                        // Sonic Bloom recording button with brand identity
                        SonicBloomRecordButton(
                            progress: viewModel.recordingProgress,
                            isRecording: viewModel.isRecording,
                            action: {
                                HapticManager.shared.playRecordingFeedback(isStarting: !viewModel.isRecording)
                                viewModel.toggleRecording()
                            }
                        )
                        .accessibilityLabel(getRecordButtonAccessibilityLabel())
                        .accessibilityHint(getRecordButtonAccessibilityHint())
                        .accessibilityFocused($focusedElement, equals: .recordButton)
                        .accessibilityAddTraits(viewModel.isRecording ? [.startsMediaSession] : [.startsMediaSession])
                        
                        // Timer overlay area (fixed height to avoid layout shifts)
                        ZStack(alignment: .top) {
                            timerOverlayView
                                .opacity(viewModel.isRecording ? 1 : 0)
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .accessibilityHidden(!viewModel.isRecording)
                        }
                        .frame(height: 80)
                        .animation(.easeInOut(duration: 0.25), value: viewModel.isRecording)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .breathingRoom()
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 0)
            }
            .navigationTitle("Sonora")
            .navigationBarTitleDisplayMode(.large)
            .brandThemed()
            .onAppear {
                viewModel.onViewAppear()
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
                    FocusManager.shared.delayedFocus(after: FocusManager.quickDelay) {
                        focusedElement = .statusText
                    }
                } else {
                    FocusManager.shared.delayedFocus(after: FocusManager.quickDelay) {
                        focusedElement = .recordButton
                    }
                }
            }
            .onChange(of: viewModel.isInCountdown) { _, isInCountdown in
                if isInCountdown {
                    focusedElement = .statusText
                }
            }
            .alert("Recording Stopped", isPresented: $viewModel.showAutoStopAlert) {
                Button("OK") { viewModel.dismissAutoStopAlert() }
            } message: {
                Text(viewModel.autoStopMessage ?? "")
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    // Check if we should stop recording due to Live Activity stop button
                    let sharedDefaults = UserDefaults(suiteName: "group.sonora.shared") ?? UserDefaults.standard
                    if sharedDefaults.bool(forKey: "shouldStopRecordingOnActivation") {
                        // Clear the flag immediately to prevent duplicate stops
                        sharedDefaults.removeObject(forKey: "shouldStopRecordingOnActivation")
                        sharedDefaults.synchronize()
                        
                        // Stop recording if currently recording
                        if viewModel.isRecording {
                            HapticManager.shared.playRecordingFeedback(isStarting: false)
                            viewModel.toggleRecording()
                        }
                    }
                }
            }
        }
    }
    var body: some View {
        AnyView(ZStack {
            backgroundView
            contentView
        })
    }
    
    // MARK: - Permission UI Helpers
    
    private func getPermissionDescription() -> String {
        switch viewModel.permissionStatus {
        case .notDetermined:
            return SonoraBrandVoice.Permissions.microphoneDescription
        case .denied:
            return SonoraBrandVoice.Permissions.microphoneDeniedDescription
        case .restricted:
            return SonoraBrandVoice.Permissions.restrictedDescription
        case .granted:
            return "Your voice is ready to be captured"
        }
    }
    
    @ViewBuilder
    private func getPermissionButton() -> some View {
        switch viewModel.permissionStatus {
        case .notDetermined:
            Button(SonoraBrandVoice.Permissions.allowMicrophone) { 
                HapticManager.shared.playSelection()
                viewModel.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRequestingPermission)
            .accessibilityLabel("Enable voice capture")
            .accessibilityHint("Double tap to allow Sonora to listen and capture your thoughts")
            
        case .denied:
            Button(SonoraBrandVoice.Permissions.openSettings) { 
                HapticManager.shared.playSelection()
                viewModel.openSettings()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Open Settings app")
            .accessibilityHint("Double tap to open Settings where you can enable microphone access for voice capture")
            
        case .restricted:
            Button(SonoraBrandVoice.Permissions.checkRestrictions) { 
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
            return SonoraBrandVoice.Recording.readyToRecord
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

// MARK: - Timer Overlay View

private extension RecordingView {
    @ViewBuilder
    var timerOverlayView: some View {
        VStack(spacing: Spacing.sm) {
            Text(viewModel.formattedRecordingTime)
                .font(SonoraDesignSystem.Typography.timerDisplay)
                .foregroundColor(.textPrimary)
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
}
