//
//  RecordView.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI

struct RecordView: View {
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var viewModel = RecordingViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Beautiful glass background with gradient
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.1),
                        Color.teal.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    if !viewModel.hasPermission {
                        VStack(spacing: 20) {
                            // Glass icon container with shimmer
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        Circle()
                                            .fill(theme.activeTheme.palette.backgroundGlass)
                                    }
                                    .overlay {
                                        Circle()
                                            .strokeBorder(theme.activeTheme.palette.glassBorder, lineWidth: 1)
                                    }
                                    .frame(width: 120, height: 120)
                                    .shadow(color: theme.activeTheme.palette.glassShadow, radius: 20, x: 0, y: 10)
                                
                                Image(systemName: viewModel.permissionStatus.iconName)
                                    .font(.system(size: 50, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: viewModel.permissionStatus == .restricted ? 
                                                [.orange, .yellow] : [.red, .pink],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                            .shimmerEffect(palette: theme.activeTheme.palette)
                            
                            VStack(spacing: 12) {
                                Text(viewModel.permissionStatus.displayName)
                                    .glassTextStyle(.title2, palette: theme.activeTheme.palette)
                                    .foregroundStyle(theme.activeTheme.palette.textOnGlass)
                                
                                Text(getPermissionDescription())
                                    .glassTextStyle(.body, palette: theme.activeTheme.palette)
                                    .foregroundColor(theme.activeTheme.palette.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                            }
                            
                            if viewModel.isRequestingPermission {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: theme.activeTheme.palette.primary))
                                    .scaleEffect(1.2)
                            } else {
                                getPermissionButton()
                            }
                        }
                        .frostedGlassCard(palette: theme.activeTheme.palette, elevation: .high)
                } else {
                    VStack(spacing: 35) {
                        // Status display with glass styling
                        VStack(spacing: 16) {
                            if viewModel.isRecording {
                                if viewModel.isInCountdown {
                                    Text("Recording ends in")
                                        .glassTextStyle(.title2, typography: theme.effectiveTypography, palette: theme.activeTheme.palette)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.orange, .yellow],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    
                                    Text(viewModel.formattedRemainingTime)
                                        .glassTextStyle(.monospaceLarge, typography: theme.effectiveTypography, palette: theme.activeTheme.palette)
                                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.red, .orange],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .scaleEffect(viewModel.countdownScale)
                                        .animation(.easeInOut(duration: 0.5), value: Int(viewModel.remainingTime))
                                        .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
                                } else {
                                    Text("Recording...")
                                        .glassTextStyle(.title2, typography: theme.effectiveTypography, palette: theme.activeTheme.palette)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.red, .pink],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    
                                    Text(viewModel.formattedRecordingTime)
                                        .glassTextStyle(.monospaceLarge, typography: theme.effectiveTypography, palette: theme.activeTheme.palette)
                                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                                        .foregroundStyle(theme.activeTheme.palette.textOnGlass)
                                }
                            } else {
                                Text("Ready to Record")
                                    .glassTextStyle(.title2, typography: theme.effectiveTypography, palette: theme.activeTheme.palette)
                                    .foregroundStyle(theme.activeTheme.palette.primary)
                            }
                        }
                        .frostedGlassCard(palette: theme.activeTheme.palette, elevation: .low)
                        
                        // Glass recording button with advanced effects
                        Button(action: {
                            viewModel.toggleRecording()
                        }) {
                            ZStack {
                                // Outer glow ring
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        Circle()
                                            .fill(theme.activeTheme.palette.backgroundGlass)
                                    }
                                    .frame(width: 140, height: 140)
                                    .overlay {
                                        Circle()
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: viewModel.isRecording ? 
                                                        [.red, .pink, .orange] : 
                                                        [theme.activeTheme.palette.primary, theme.activeTheme.palette.secondary],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 3
                                            )
                                    }
                                    .shadow(color: theme.activeTheme.palette.glassShadow, radius: 25, x: 0, y: 12)
                                
                                // Inner button
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: viewModel.isRecording ? 
                                                    [.red, .red.opacity(0.8)] : 
                                                    [theme.activeTheme.palette.primary, theme.activeTheme.palette.primary.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 110, height: 110)
                                        .overlay {
                                            Circle()
                                                .fill(theme.activeTheme.palette.glassHighlight.opacity(0.2))
                                                .frame(width: 110, height: 110)
                                        }
                                    
                                    if viewModel.isRecording {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(.white)
                                            .frame(width: 45, height: 45)
                                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                                    } else {
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 45, weight: .medium))
                                            .foregroundStyle(.white)
                                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                                    }
                                }
                            }
                            .scaleEffect(viewModel.recordingButtonScale)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isRecording)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Recording indicator with glass styling
                        if viewModel.shouldShowRecordingIndicator {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.red, .pink],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 10, height: 10)
                                    .scaleEffect(1.2)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(), value: viewModel.isRecording)
                                    .shadow(color: .red.opacity(0.5), radius: 8, x: 0, y: 2)
                                
                                Text("Recording in progress")
                                    .glassTextStyle(.caption, typography: theme.effectiveTypography, palette: theme.activeTheme.palette)
                                    .foregroundColor(theme.activeTheme.palette.textSecondary)
                            }
                            .frostedGlassCard(palette: theme.activeTheme.palette, elevation: .low)
                        }
                    }
                }
                
                Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle("Sonora")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                viewModel.onViewAppear()
            }
            .alert("Recording Stopped", isPresented: $viewModel.showAutoStopAlert) {
                Button("OK") {
                    viewModel.dismissAutoStopAlert()
                }
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
                viewModel.requestPermission()
            }
            .glassButton(palette: theme.activeTheme.palette)
            .disabled(viewModel.isRequestingPermission)
            
        case .denied:
            Button("Open Settings") {
                viewModel.openSettings()
            }
            .glassButton(palette: theme.activeTheme.palette)
            
        case .restricted:
            Button("Check Device Settings") {
                viewModel.openSettings()
            }
            .glassButton(palette: theme.activeTheme.palette)
            
        case .granted:
            EmptyView()
        }
    }
}
