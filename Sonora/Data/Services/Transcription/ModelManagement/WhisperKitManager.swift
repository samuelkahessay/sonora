import Foundation
import WhisperKit

/// Manager for WhisperKit integration providing local speech-to-text capabilities
final class WhisperKitManager {
    
    // MARK: - Properties
    
    private var whisperKit: WhisperKit?
    private let logger = Logger.shared
    
    // MARK: - Initialization
    
    init() {
        logger.info("WhisperKitManager initialized")
    }
    
    // MARK: - Setup Methods
    
    /// Initializes WhisperKit with default configuration
    /// - Returns: True if initialization successful, false otherwise
    func initializeWhisperKit() async -> Bool {
        do {
            logger.info("Attempting to initialize WhisperKit...")
            
            // Initialize WhisperKit with default model
            whisperKit = try await WhisperKit()
            
            logger.info("WhisperKit initialized successfully")
            return true
            
        } catch {
            logger.error("Failed to initialize WhisperKit: \(error.localizedDescription)")
            whisperKit = nil
            return false
        }
    }
    
    // MARK: - Test Methods
    
    /// Simple test method to verify WhisperKit integration
    /// - Returns: Test result with status and details
    func performIntegrationTest() async -> WhisperKitTestResult {
        logger.info("Starting WhisperKit integration test...")
        
        // Check if WhisperKit is already initialized
        if whisperKit == nil {
            logger.info("WhisperKit not initialized, attempting initialization...")
            let initSuccess = await initializeWhisperKit()
            
            if !initSuccess {
                return WhisperKitTestResult(
                    success: false,
                    message: "Failed to initialize WhisperKit",
                    details: "WhisperKit could not be initialized. Check device compatibility and available models."
                )
            }
        }
        
        // Verify WhisperKit is ready
        guard whisperKit != nil else {
            return WhisperKitTestResult(
                success: false,
                message: "WhisperKit instance is nil",
                details: "WhisperKit instance is unexpectedly nil after initialization."
            )
        }
        
        // Basic functionality test
        do {
            // Check available models
            let availableModels = WhisperKit.recommendedModels()
            logger.info("Available WhisperKit models: \(availableModels)")
            
            return WhisperKitTestResult(
                success: true,
                message: "WhisperKit integration test passed",
                details: "WhisperKit is properly initialized and recommended models are available."
            )
            
        } catch {
            logger.error("WhisperKit integration test failed: \(error.localizedDescription)")
            return WhisperKitTestResult(
                success: false,
                message: "Integration test failed",
                details: error.localizedDescription
            )
        }
    }
    
    // MARK: - Status Methods
    
    /// Checks if WhisperKit is ready for use
    var isReady: Bool {
        return whisperKit != nil
    }
    
    /// Gets current WhisperKit status information
    var statusInfo: String {
        if let kit = whisperKit {
            return "WhisperKit ready with model loaded"
        } else {
            return "WhisperKit not initialized"
        }
    }
}

// MARK: - Supporting Types

/// Result structure for WhisperKit integration tests
struct WhisperKitTestResult {
    let success: Bool
    let message: String
    let details: String
    
    var description: String {
        return "\(message): \(details)"
    }
}

// MARK: - Error Types

enum WhisperKitError: LocalizedError {
    case notInitialized
    case initializationFailed(String)
    case modelLoadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "WhisperKit is not initialized"
        case .initializationFailed(let reason):
            return "WhisperKit initialization failed: \(reason)"
        case .modelLoadFailed(let reason):
            return "Failed to load WhisperKit model: \(reason)"
        }
    }
}