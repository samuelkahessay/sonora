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
            VStack(spacing: 32) {
                Spacer()
                
                if !viewModel.hasPermission {
                    VStack(spacing: 16) {
                        Image(systemName: viewModel.permissionStatus.iconName)
                            .font(.system(size: 60, weight: .medium))
                            .foregroundColor(.red)
                        
                        Text(viewModel.permissionStatus.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(getPermissionDescription())
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if viewModel.isRequestingPermission {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            getPermissionButton()
                        }
                    }
                    .padding()
                } else {
                    VStack(spacing: 24) {
                        // Status and timers
                        VStack(spacing: 8) {
                            Text(viewModel.recordingStatusText)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(viewModel.isRecording ? .red : .primary)
                            
                            Text(viewModel.formattedRecordingTime)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .monospacedDigit()
                            
                            if viewModel.isInCountdown {
                                Text("Recording ends in")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                Text("\(Int(ceil(viewModel.remainingTime)))")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(.red)
                                    .monospacedDigit()
                            }
                        }
                        
                        // Record/Stop button
                        Button(action: { viewModel.toggleRecording() }) {
                            HStack(spacing: 8) {
                                Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                Text(viewModel.isRecording ? "Stop" : "Record")
                            }
                            .font(.title2)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(viewModel.isRecording ? .red : .blue)
                        
                        if viewModel.shouldShowRecordingIndicator {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("Recording in progress")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sonora")
            .onAppear { viewModel.onViewAppear() }
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
            Button("Allow Microphone Access") { viewModel.requestPermission() }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRequestingPermission)
            
        case .denied:
            Button("Open Settings") { viewModel.openSettings() }
                .buttonStyle(.bordered)
            
        case .restricted:
            Button("Check Device Settings") { viewModel.openSettings() }
                .buttonStyle(.bordered)
            
        case .granted:
            EmptyView()
        }
    }
}

