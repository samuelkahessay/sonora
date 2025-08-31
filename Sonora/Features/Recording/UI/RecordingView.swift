//
//  RecordingView.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI

struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @AccessibilityFocusState private var focusedElement: AccessibleElement?
    
    enum AccessibleElement {
        case recordButton
        case permissionButton
        case statusText
    }
    
    var body: some View {
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
                        // Status and timers
                        VStack(spacing: Spacing.sm) {
                            Text(viewModel.recordingStatusText)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(viewModel.isRecording ? .semantic(.error) : .semantic(.textPrimary))
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityFocused($focusedElement, equals: .statusText)
                            
                            Text(viewModel.formattedRecordingTime)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .accessibilityLabel("Recording duration")
                                .accessibilityValue(getTimeAccessibilityLabel())
                                .accessibilityAddTraits(.updatesFrequently)
                            
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
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Recording ends in \(Int(ceil(viewModel.remainingTime))) seconds")
                                .accessibilityAddTraits(.updatesFrequently)
                            }
                        }
                        .accessibilityElement(children: .contain)
                        
                        // Record/Stop button
                        Button(action: { 
                            // Add haptic feedback
                            HapticManager.shared.playRecordingFeedback(isStarting: !viewModel.isRecording)
                            viewModel.toggleRecording()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                Text(viewModel.isRecording ? "Stop" : "Record")
                            }
                            .font(.title2)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(viewModel.isRecording ? .semantic(.error) : .semantic(.brandPrimary))
                        .accessibilityLabel(getRecordButtonAccessibilityLabel())
                        .accessibilityHint(getRecordButtonAccessibilityHint())
                        .accessibilityFocused($focusedElement, equals: .recordButton)
                        .accessibilityAddTraits(viewModel.isRecording ? [.startsMediaSession] : [.startsMediaSession])
                        
                        if viewModel.shouldShowRecordingIndicator {
                            HStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.semantic(.error))
                                        .frame(width: IconSize.medium.rawValue, height: IconSize.medium.rawValue)
                                        .accessibilityHidden(true)
                                        .scaleEffect(1.0)
                                        .animation(.easeInOut(duration: 1.0).repeatForever(), value: viewModel.isRecording)
                                    
                                    Text("Recording in progress")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.semantic(.error))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.semantic(.error).opacity(0.1))
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.semantic(.error).opacity(0.3), lineWidth: 1)
                                )
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Recording is in progress in the background")
                            .accessibilityAddTraits(.updatesFrequently)
                        }
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
            .toolbarBackground(Color.semantic(.bgPrimary), for: .navigationBar)
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
