//  RecordingView.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.

import SwiftUI

/// Large circular recording button component following modern iOS design patterns
struct CircularRecordButton: View {
    let isRecording: Bool
    let action: () -> Void
    private let buttonSize: CGFloat = 160
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.semantic(.error) : Color.semantic(.brandPrimary))
                    .frame(width: buttonSize, height: buttonSize)
                    .scaleEffect(isRecording ? 1.05 : 1.0)
                
                Label(isRecording ? "Stop" : "Record",
                      systemImage: isRecording ? "stop.fill" : "mic.fill")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 64, weight: .medium))
                    .foregroundColor(.semantic(.textOnColored))
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isRecording)
        .shadow(radius: 5, y: 3)
    }
}

struct RecordingView: View {
    @StateObject private var viewModel = DIContainer.shared.viewModelFactory().createRecordingViewModel()
    @AccessibilityFocusState private var focusedElement: AccessibleElement?
    
    enum AccessibleElement {
        case recordButton
        case permissionButton
        case statusText
    }
    
    var body: some View {
        ZStack {
            // Background: base fill + subtle gradients for Liquid Glass contrast
            Color.semantic(.bgPrimary)
                .ignoresSafeArea()

            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.08),
                    Color.blue.opacity(0.08)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.22),
                    .clear
                ]),
                center: .center,
                startRadius: 40,
                endRadius: 260
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Your existing content
            NavigationStack {
                VStack(spacing: Spacing.xxl) {
                    Spacer()
                    
                    if !viewModel.hasPermission {
                        VStack(spacing: Spacing.lg) {
                            Image(systemName: viewModel.permissionStatus.iconName)
                                .font(.largeTitle)
                                .fontWeight(.medium)
                                .foregroundColor(.semantic(.error))
                                .accessibilityHidden(true)
                            
                            Text(viewModel.permissionStatus.displayName)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .accessibilityAddTraits(.isHeader)
                            
                            Text(getPermissionDescription())
                                .font(.body)
                                .foregroundColor(.semantic(.textSecondary))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
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
                        VStack(spacing: Spacing.xl) {
                            
                            // Large circular recording button
                            CircularRecordButton(
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
                .padding()
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 0)
                }
                .navigationTitle("Sonora")
                .toolbarBackground(.clear, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
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
            }
        }
    }
    
    // MARK: - Permission UI Helpers
    
    private func getPermissionDescription() -> String {
        switch viewModel.permissionStatus {
        case .notDetermined:
            return "Sonora needs microphone access to record voice memos for transcription and analysis."
        case .denied:
            return "Microphone access was denied. Please enable it in Settings to record voice memos."
        case .restricted:
            return "Microphone access is restricted on this device. Check your device restrictions in Settings."
        case .granted:
            return "Microphone access is enabled"
        }
    }
    
    @ViewBuilder
    private func getPermissionButton() -> some View {
        switch viewModel.permissionStatus {
        case .notDetermined:
            Button("Allow Microphone Access") { 
                HapticManager.shared.playSelection()
                viewModel.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRequestingPermission)
            .accessibilityLabel("Allow microphone access")
            .accessibilityHint("Double tap to request microphone permission for recording voice memos")
            
        case .denied:
            Button("Open Settings") { 
                HapticManager.shared.playSelection()
                viewModel.openSettings()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Open Settings app")
            .accessibilityHint("Double tap to open Settings where you can enable microphone access")
            
        case .restricted:
            Button("Check Device Settings") { 
                HapticManager.shared.playSelection()
                viewModel.openSettings()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Check device settings")
            .accessibilityHint("Double tap to open Settings to check device restrictions")
            
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
            return "Stop recording"
        } else {
            return "Start recording"
        }
    }
    
    private func getRecordButtonAccessibilityHint() -> String {
        if viewModel.isRecording {
            return "Double tap to stop the current voice recording"
        } else {
            return "Double tap to start recording a 60-second voice memo"
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
                .font(.largeTitle)
                .fontWeight(.bold)
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("Recording duration")
                .accessibilityValue(getTimeAccessibilityLabel())
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityFocused($focusedElement, equals: .statusText)

            if viewModel.isInCountdown {
                VStack(spacing: 4) {
                    Text("Recording ends in")
                        .font(.headline)
                        .foregroundColor(.semantic(.warning))
                    Text("\(Int(ceil(viewModel.remainingTime)))")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.semantic(.error))
                        .monospacedDigit()
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
