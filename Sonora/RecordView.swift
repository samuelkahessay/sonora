//
//  RecordView.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI

struct RecordView: View {
    @StateObject private var viewModel = RecordingViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Spacer()
                
                if !viewModel.hasPermission {
                    VStack(spacing: 16) {
                        Image(systemName: viewModel.permissionStatus.iconName)
                            .font(.system(size: 80))
                            .foregroundColor(viewModel.permissionStatus == .restricted ? .orange : .red)
                        
                        Text(viewModel.permissionStatus.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(getPermissionDescription())
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        if viewModel.isRequestingPermission {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            getPermissionButton()
                        }
                    }
                } else {
                    VStack(spacing: 30) {
                        VStack(spacing: 8) {
                            if viewModel.isRecording {
                                if viewModel.isInCountdown {
                                    Text("Recording ends in")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)
                                    
                                    Text(viewModel.formattedRemainingTime)
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundColor(.red)
                                        .monospacedDigit()
                                        .scaleEffect(viewModel.countdownScale)
                                        .animation(.easeInOut(duration: 0.5), value: Int(viewModel.remainingTime))
                                } else {
                                    Text("Recording...")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                    
                                    Text(viewModel.formattedRecordingTime)
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                        .monospacedDigit()
                                }
                            } else {
                                Text("Ready to Record")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Button(action: {
                            viewModel.toggleRecording()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(viewModel.recordingButtonColor)
                                    .frame(width: 120, height: 120)
                                
                                if viewModel.isRecording {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white)
                                        .frame(width: 40, height: 40)
                                } else {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                }
                            }
                            .scaleEffect(viewModel.recordingButtonScale)
                            .animation(.easeInOut(duration: 0.1), value: viewModel.isRecording)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if viewModel.shouldShowRecordingIndicator {
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .opacity(0.8)
                                    .scaleEffect(1.2)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(), value: viewModel.isRecording)
                                
                                Text("Recording in progress")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sonora")
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
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRequestingPermission)
            
        case .denied:
            Button("Open Settings") {
                viewModel.openSettings()
            }
            .buttonStyle(.borderedProminent)
            
        case .restricted:
            Button("Check Device Settings") {
                viewModel.openSettings()
            }
            .buttonStyle(.bordered)
            
        case .granted:
            EmptyView()
        }
    }
}
