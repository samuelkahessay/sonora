import SwiftUI

struct TranscriptionTestView: View {
    @State private var testResult = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Transcription Test")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Endpoint: \(AppConfiguration.shared.apiBaseURL.absoluteString)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isLoading {
                ProgressView("Testing connection...")
            } else {
                VStack(spacing: 12) {
                    Button("Test Health") {
                        testHealthEndpoint()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Test Key Check") {
                        testKeyCheckEndpoint()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if !testResult.isEmpty {
                ScrollView {
                    Text(testResult)
                        .font(.caption)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
    }
    
    private func testHealthEndpoint() {
        isLoading = true
        testResult = ""
        
        Task {
            do {
                let config = AppConfiguration.shared
                var request = URLRequest(url: config.apiBaseURL.appendingPathComponent("health"))
                request.timeoutInterval = config.healthCheckTimeoutInterval
                
                let (data, response) = try await URLSession.shared.data(for: request)
                let result = String(data: data, encoding: .utf8) ?? "No data"
                
                await MainActor.run {
                    if let httpResponse = response as? HTTPURLResponse {
                        testResult = "✅ Health Check Success!\nStatus: \(httpResponse.statusCode)\nResponse: \(result)"
                    } else {
                        testResult = "✅ Health response: \(result)"
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ Health check failed: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func testKeyCheckEndpoint() {
        isLoading = true
        testResult = ""
        
        Task {
            do {
                let config = AppConfiguration.shared
                var request = URLRequest(url: config.apiBaseURL.appendingPathComponent("keycheck"))
                request.timeoutInterval = config.healthCheckTimeoutInterval
                
                let (data, response) = try await URLSession.shared.data(for: request)
                let result = String(data: data, encoding: .utf8) ?? "No data"
                
                await MainActor.run {
                    if let httpResponse = response as? HTTPURLResponse {
                        testResult = "✅ Key Check Success!\nStatus: \(httpResponse.statusCode)\nResponse: \(result)"
                    } else {
                        testResult = "✅ Key check response: \(result)"
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ Key check failed: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    TranscriptionTestView()
}