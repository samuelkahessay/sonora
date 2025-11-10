import Foundation

/// Comprehensive errors for analysis operations
/// Consolidates network, service, cache, and repository errors following Clean Architecture
enum AnalysisError: LocalizedError {
    // MARK: - Network & Service Errors
    case invalidURL
    case noData
    case decodingError(String)
    case serverError(Int)
    case timeout
    case networkError(String)
    case invalidResponse
    case serviceUnavailable
    case paymentRequired

    // MARK: - Business Logic Errors
    case emptyTranscript
    case transcriptTooShort
    case analysisServiceError(String)
    case systemBusy

    // MARK: - Repository & Cache Errors
    case cacheError(String)
    case repositoryError(String)
    case invalidMemoId

    var errorDescription: String? {
        switch self {
        // Network & Service Errors
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .serverError(let code):
            return "Server error (\(code))"
        case .timeout:
            return "Request timed out"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from analysis service"
        case .serviceUnavailable:
            return "Analysis service is currently unavailable"
        case .paymentRequired:
            return "This feature requires an active subscription"

        // Business Logic Errors
        case .emptyTranscript:
            return "Transcript is empty or contains only whitespace"
        case .transcriptTooShort:
            return "Transcript is too short for meaningful analysis"
        case .analysisServiceError(let message):
            return "Analysis service error: \(message)"
        case .systemBusy:
            return "System is busy - analysis queue is full"

        // Repository & Cache Errors
        case .cacheError(let message):
            return "Cache error: \(message)"
        case .repositoryError(let message):
            return "Repository error: \(message)"
        case .invalidMemoId:
            return "Invalid memo ID provided"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        // Network & Service Errors
        case .invalidURL:
            return "Please check the service configuration."
        case .noData:
            return "Please try again or check your network connection."
        case .decodingError:
            return "The service may have returned an unexpected response format."
        case .serverError:
            return "Please try again later. The analysis service may be experiencing issues."
        case .timeout:
            return "Please check your network connection and try again."
        case .networkError:
            return "Please check your network connection and try again."
        case .invalidResponse:
            return "The analysis service returned an unexpected response. Please try again."
        case .serviceUnavailable:
            return "Please try again later when the analysis service is available."
        case .paymentRequired:
            return "Please check your subscription status in Settings or upgrade to access this feature."

        // Business Logic Errors
        case .emptyTranscript:
            return "Please provide a valid transcript with content."
        case .transcriptTooShort:
            return "Please ensure the transcript has at least 10 characters for meaningful analysis."
        case .analysisServiceError:
            return "Please try again later or check your network connection."
        case .systemBusy:
            return "Please try again in a few moments when the system is less busy."

        // Repository & Cache Errors
        case .cacheError:
            return "The analysis will continue without caching."
        case .repositoryError:
            return "The analysis will continue but results may not be saved."
        case .invalidMemoId:
            return "Please ensure you're analyzing a valid memo."
        }
    }
}
