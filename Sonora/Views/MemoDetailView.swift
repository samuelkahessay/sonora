import SwiftUI
import AVFoundation
import UIKit

struct MemoDetailView: View {
    let memo: Memo
    @StateObject private var viewModel = MemoDetailViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(memo.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Label(memo.durationString, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(memo.filename)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Audio Controls
                VStack(spacing: 16) {
                    HStack {
                        Button(action: {
                            viewModel.playMemo()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: viewModel.playButtonIcon)
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(viewModel.isPlaying ? "Now Playing" : "Play Recording")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Text(memo.durationString)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                // Transcription Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Transcription")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if viewModel.transcriptionState.isInProgress {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if viewModel.transcriptionState.isFailed {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                        }
                    }
                    
                    switch viewModel.transcriptionState {
                    case .notStarted:
                        VStack(spacing: 12) {
                            Text("This memo hasn't been transcribed yet.")
                                .foregroundColor(.secondary)
                            
                            Button("Start Transcription") {
                                viewModel.startTranscription()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                        
                    case .inProgress:
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Transcribing your audio...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                        
                    case .completed(let text):
                        VStack(alignment: .leading, spacing: 12) {
                            ScrollView {
                                Text(text)
                                    .font(.body)
                                    .lineSpacing(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                            }
                            .frame(minHeight: 120)
                            
                            HStack {
                                Button("Share Text") {
                                    shareText(text)
                                }
                                .buttonStyle(.bordered)
                                
                                Spacer()
                                
                                Button("Copy") {
                                    copyText(text)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                    case .failed(let error):
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("Transcription Failed")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                            }
                            
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Try Again") {
                                viewModel.retryTranscription()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
                
                // Analysis Section
                if viewModel.isTranscriptionCompleted, let transcriptText = viewModel.transcriptionText {
                    AnalysisSectionView(
                        transcript: transcriptText,
                        viewModel: viewModel
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Memo Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.configure(with: memo)
            viewModel.onViewAppear()
        }
        .onDisappear {
            viewModel.onViewDisappear()
        }
    }
    
    // MARK: - UI Helper Methods
    
    private func shareText(_ text: String) {
        let activityController = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
    
    private func copyText(_ text: String) {
        UIPasteboard.general.string = text
    }
}