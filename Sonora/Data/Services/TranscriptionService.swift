import Foundation

final class TranscriptionService: TranscriptionAPI {
    private let config = AppConfiguration.shared
    
    struct APIError: LocalizedError { 
        let message: String
        var errorDescription: String? { message }
    }

    func transcribe(url: URL) async throws -> String {
        print("🎙️ Starting transcription for: \(url.lastPathComponent)")
        
        var form = MultipartForm()
        try form.addFileField(name: "file", filename: url.lastPathComponent, mimeType: "audio/m4a", fileURL: url)
        let body = form.finalize()

        let transcribeURL = config.apiBaseURL.appendingPathComponent("transcribe")
        var req = URLRequest(url: transcribeURL)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(form.boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = config.transcriptionTimeoutInterval
        
        print("🔧 TranscriptionService: Using API URL: \(transcribeURL.absoluteString)")
        print("🔧 TranscriptionService: Using timeout: \(req.timeoutInterval)s")
        print("🌐 Making request to: \(req.url?.absoluteString ?? "unknown")")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { 
            throw APIError(message: "No HTTP response") 
        }
        
        print("📡 Response status: \(http.statusCode)")
        
        if !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            print("❌ Server error: \(text)")
            throw APIError(message: "Server error \(http.statusCode): \(text)")
        }
        
        struct Payload: Decodable { let text: String? }
        let out = try JSONDecoder().decode(Payload.self, from: data)
        let transcription = out.text ?? ""
        print("✅ Transcription completed: \(transcription.prefix(50))...")
        return transcription
    }
}