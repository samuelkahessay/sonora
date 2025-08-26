//
//  RecordView.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI

struct RecordView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @EnvironmentObject var memoStore: MemoStore
    
    private func setupRecordingCallback() {
        print("🔧 RecordView: Setting up callback function")
        audioRecorder.onRecordingFinished = { url in
            print("🎤 RecordView: Recording finished callback triggered for \(url.lastPathComponent)")
            DispatchQueue.main.async {
                print("🎤 RecordView: Calling memoStore.handleNewRecording")
                memoStore.handleNewRecording(at: url)
            }
        }
        print("🔧 RecordView: Callback function set successfully")
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Spacer()
                
                if !audioRecorder.hasPermission {
                    VStack(spacing: 16) {
                        Image(systemName: "mic.slash.circle")
                            .font(.system(size: 80))
                            .foregroundColor(.red)
                        
                        Text("Microphone Permission Required")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Please allow microphone access to record audio memos")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Request Permission") {
                            audioRecorder.checkPermissions()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 30) {
                        VStack(spacing: 8) {
                            if audioRecorder.isRecording {
                                if audioRecorder.isInCountdown {
                                    Text("Recording ends in")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)
                                    
                                    Text("\(Int(ceil(audioRecorder.remainingTime)))")
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundColor(.red)
                                        .monospacedDigit()
                                        .scaleEffect(audioRecorder.remainingTime.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 1.1 : 1.0)
                                        .animation(.easeInOut(duration: 0.5), value: Int(audioRecorder.remainingTime))
                                } else {
                                    Text("Recording...")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                    
                                    Text(formatTime(audioRecorder.recordingTime))
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
                            if audioRecorder.isRecording {
                                print("🛑 RecordView: Stopping recording")
                                audioRecorder.stopRecording()
                            } else {
                                print("▶️ RecordView: Starting recording")
                                // Ensure callback is set before starting
                                setupRecordingCallback()
                                audioRecorder.startRecording()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(audioRecorder.isRecording ? Color.red : Color.blue)
                                    .frame(width: 120, height: 120)
                                
                                if audioRecorder.isRecording {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white)
                                        .frame(width: 40, height: 40)
                                } else {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                }
                            }
                            .scaleEffect(audioRecorder.isRecording ? 0.9 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: audioRecorder.isRecording)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if audioRecorder.isRecording {
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .opacity(0.8)
                                    .scaleEffect(1.2)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(), value: audioRecorder.isRecording)
                                
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
                print("🎬 RecordView: Setting up recording callback on appear")
                setupRecordingCallback()
            }
            .alert("Recording Stopped", isPresented: $audioRecorder.recordingStoppedAutomatically) {
                Button("OK") {
                    audioRecorder.autoStopMessage = nil
                }
            } message: {
                Text(audioRecorder.autoStopMessage ?? "")
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
