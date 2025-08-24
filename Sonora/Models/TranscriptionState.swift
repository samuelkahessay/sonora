import Foundation

enum TranscriptionState: Codable, Equatable {
    case notStarted
    case inProgress
    case completed(String)
    case failed(String)
    
    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }
    
    var isInProgress: Bool {
        if case .inProgress = self { return true }
        return false
    }
    
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
    
    var isNotStarted: Bool {
        if case .notStarted = self { return true }
        return false
    }
    
    var text: String? {
        if case .completed(let text) = self { return text }
        return nil
    }
    
    var errorMessage: String? {
        if case .failed(let error) = self { return error }
        return nil
    }
    
    var statusText: String {
        switch self {
        case .notStarted:
            return "Not transcribed"
        case .inProgress:
            return "Transcribing..."
        case .completed:
            return "Transcribed"
        case .failed:
            return "Transcription failed"
        }
    }
    
    var iconName: String {
        switch self {
        case .notStarted:
            return "doc.text.below.ecg"
        case .inProgress:
            return "waveform.path"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var iconColor: String {
        switch self {
        case .notStarted:
            return "secondary"
        case .inProgress:
            return "blue"
        case .completed:
            return "green"
        case .failed:
            return "red"
        }
    }
}