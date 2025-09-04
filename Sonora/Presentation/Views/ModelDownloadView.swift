import SwiftUI

struct ModelDownloadView: View {
    @StateObject private var downloader = SimpleModelDownloader.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("LLaMA 3.2 3B")
                .font(.title2)
            
            Text("~2GB Download")
                .foregroundColor(.secondary)
            
            if downloader.isModelReady {
                // Model ready
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Model Ready")
                        .font(.headline)
                    
                    Button("Delete Model") {
                        downloader.deleteModel()
                    }
                    .foregroundColor(.red)
                }
                
            } else if downloader.isDownloading {
                // Downloading
                VStack(spacing: 12) {
                    ProgressView(value: downloader.downloadProgress)
                        .progressViewStyle(.linear)
                    
                    Text("\(Int(downloader.downloadProgress * 100))% Downloaded")
                    
                    Button("Cancel") {
                        downloader.cancelDownload()
                    }
                    .foregroundColor(.red)
                }
                .padding(.horizontal)
                
            } else {
                // Not downloaded
                Button(action: {
                    downloader.downloadModel()
                }) {
                    Label("Download Model", systemImage: "arrow.down.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationTitle("Local AI Model")
        .navigationBarTitleDisplayMode(.inline)
    }
}