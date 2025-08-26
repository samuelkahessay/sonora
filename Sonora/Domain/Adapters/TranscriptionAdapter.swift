import Foundation

/// Adapter for converting between TranscriptionState (data layer) and DomainTranscriptionStatus (domain layer)
/// Provides backward compatibility during the transition to Clean Architecture
struct TranscriptionAdapter {
    
    // MARK: - TranscriptionState to DomainTranscriptionStatus Conversion
    
    /// Converts TranscriptionState to DomainTranscriptionStatus
    static func toDomain(_ state: TranscriptionState) -> DomainTranscriptionStatus {
        switch state {
        case .notStarted:
            return .notStarted
        case .inProgress:
            return .inProgress
        case .completed(let text):
            return .completed(text)
        case .failed(let error):
            return .failed(error)
        }
    }
    
    // MARK: - DomainTranscriptionStatus to TranscriptionState Conversion
    
    /// Converts DomainTranscriptionStatus to TranscriptionState
    static func fromDomain(_ status: DomainTranscriptionStatus) -> TranscriptionState {
        switch status {
        case .notStarted:
            return .notStarted
        case .inProgress:
            return .inProgress
        case .completed(let text):
            return .completed(text)
        case .failed(let error):
            return .failed(error)
        }
    }
}

// MARK: - TranscriptionState Extension for Domain Compatibility
extension TranscriptionState {
    
    /// Convenience method to convert to domain model
    func toDomain() -> DomainTranscriptionStatus {
        return TranscriptionAdapter.toDomain(self)
    }
}

// MARK: - DomainTranscriptionStatus Extension for Data Layer Compatibility
extension DomainTranscriptionStatus {
    
    /// Convenience method to convert to data model
    func toTranscriptionState() -> TranscriptionState {
        return TranscriptionAdapter.fromDomain(self)
    }
}