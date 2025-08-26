import Foundation
import Combine

protocol AudioRecordingService: ObservableObject {
    var isRecording: Bool { get set }
    var recordingTime: TimeInterval { get set }
    var hasPermission: Bool { get set }
    var recordingStoppedAutomatically: Bool { get set }
    var autoStopMessage: String? { get set }
    var isInCountdown: Bool { get set }
    var remainingTime: TimeInterval { get set }
    
    var onRecordingFinished: ((URL) -> Void)? { get set }
    
    func checkPermissions()
    func startRecording()
    func stopRecording()
}