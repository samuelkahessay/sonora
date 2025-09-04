import Foundation

@MainActor
final class SimpleModelDownloader: ObservableObject {
    static let shared = SimpleModelDownloader()
    
    @Published var isDownloading = false
    @Published var downloadProgress: Float = 0.0
    @Published var isModelReady = false
    
    private var downloadTask: URLSessionDownloadTask?
    private var progressObservation: NSKeyValueObservation?
    
    private let modelURL = URL(string: "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf")!
    private let modelFileName = "Llama-3.2-3B-Instruct-Q4_K_M.gguf"
    
    var modelPath: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelPath = documentsPath.appendingPathComponent(modelFileName)
        return FileManager.default.fileExists(atPath: modelPath.path) ? modelPath : nil
    }
    
    init() {
        checkForExistingModel()
    }
    
    private func checkForExistingModel() {
        isModelReady = (modelPath != nil)
    }
    
    func downloadModel() {
        guard !isDownloading, modelPath == nil else { return }
        
        isDownloading = true
        downloadProgress = 0.0
        
        downloadTask = URLSession.shared.downloadTask(with: modelURL) { [weak self] tempURL, response, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    print("Download error: \(error)")
                    self.isDownloading = false
                    return
                }
                
                guard let tempURL = tempURL else {
                    print("No temp URL")
                    self.isDownloading = false
                    return
                }
                
                do {
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let finalPath = documentsPath.appendingPathComponent(self.modelFileName)
                    
                    // Remove existing file if present
                    try? FileManager.default.removeItem(at: finalPath)
                    
                    // Move downloaded file
                    try FileManager.default.moveItem(at: tempURL, to: finalPath)
                    
                    self.isModelReady = true
                    self.isDownloading = false
                    self.downloadProgress = 1.0
                    print("Model downloaded successfully")
                    
                } catch {
                    print("Failed to save model: \(error)")
                    self.isDownloading = false
                }
            }
        }
        
        // Observe download progress
        progressObservation = downloadTask?.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor in
                self?.downloadProgress = Float(progress.fractionCompleted)
            }
        }
        
        downloadTask?.resume()
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        progressObservation?.invalidate()
        progressObservation = nil
        isDownloading = false
        downloadProgress = 0.0
    }
    
    func deleteModel() {
        guard let modelPath = modelPath else { return }
        try? FileManager.default.removeItem(at: modelPath)
        isModelReady = false
        checkForExistingModel()
    }
}