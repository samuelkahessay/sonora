import Foundation

/// App-wide events that can be published and subscribed to
/// Supports reactive programming patterns and loose coupling between components
public enum AppEvent: Equatable {
    
    // MARK: - Memo Lifecycle Events
    
    /// Published when a new memo is created and saved
    case memoCreated(DomainMemo)
    
    // MARK: - Recording Events
    
    /// Published when audio recording starts for a memo
    case recordingStarted(memoId: UUID)
    
    /// Published when audio recording completes successfully
    case recordingCompleted(memoId: UUID)
    
    // MARK: - Transcription Events
    
    /// Published when transcription completes successfully
    case transcriptionCompleted(memoId: UUID, text: String)
    
    // MARK: - Analysis Events
    
    /// Published when any analysis type completes successfully
    case analysisCompleted(memoId: UUID, type: AnalysisMode, result: String)
    
    // MARK: - Event Properties
    
    /// The memo ID associated with this event (if applicable)
    public var memoId: UUID? {
        switch self {
        case .memoCreated(let memo):
            return memo.id
        case .recordingStarted(let memoId), 
             .recordingCompleted(let memoId),
             .transcriptionCompleted(let memoId, _),
             .analysisCompleted(let memoId, _, _):
            return memoId
        }
    }
    
    /// Human-readable description of the event
    public var description: String {
        switch self {
        case .memoCreated(let memo):
            return "Memo created: \(memo.filename)"
        case .recordingStarted(let memoId):
            return "Recording started for memo: \(memoId)"
        case .recordingCompleted(let memoId):
            return "Recording completed for memo: \(memoId)"
        case .transcriptionCompleted(let memoId, _):
            return "Transcription completed for memo: \(memoId)"
        case .analysisCompleted(let memoId, let type, _):
            return "\(type.displayName) analysis completed for memo: \(memoId)"
        }
    }
    
    /// Event category for filtering or logging purposes
    public var category: EventCategory {
        switch self {
        case .memoCreated:
            return .memo
        case .recordingStarted, .recordingCompleted:
            return .recording
        case .transcriptionCompleted:
            return .transcription
        case .analysisCompleted:
            return .analysis
        }
    }
}

// MARK: - Event Categories

/// Categories for organizing and filtering events
public enum EventCategory: String, CaseIterable {
    case memo = "memo"
    case recording = "recording"
    case transcription = "transcription"
    case analysis = "analysis"
    
    public var displayName: String {
        switch self {
        case .memo: return "Memo"
        case .recording: return "Recording"
        case .transcription: return "Transcription"
        case .analysis: return "Analysis"
        }
    }
}

// MARK: - Event Type Identifiers

/// Protocol for type-safe event subscription
public protocol AppEventType {
    static var eventTypeIdentifier: ObjectIdentifier { get }
}

extension AppEvent: AppEventType {
    public static var eventTypeIdentifier: ObjectIdentifier {
        return ObjectIdentifier(AppEvent.self)
    }
}