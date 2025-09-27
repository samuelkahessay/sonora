import Foundation

enum RecordingSessionState: Equatable {
    case idle
    case recording
    case paused

    var isRecording: Bool { self == .recording }
    var isPaused: Bool { self == .paused }
    var isActive: Bool { self == .recording || self == .paused }
}
