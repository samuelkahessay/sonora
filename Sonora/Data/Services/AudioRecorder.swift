//
//  AudioRecorder.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import Foundation
import AVFoundation
import Combine

@MainActor
class AudioRecorder: NSObject, ObservableObject, AudioRecordingService {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var hasPermission = false
    @Published var recordingStoppedAutomatically = false
    @Published var autoStopMessage: String?
    @Published var isInCountdown = false
    @Published var remainingTime: TimeInterval = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let config = AppConfiguration.shared
    private let countdownThreshold: TimeInterval = 10.0
    
    /// Get maximum recording duration from configuration
    private var maxRecordingDuration: TimeInterval {
        return config.maxRecordingDuration
    }
    
    var onRecordingFinished: ((URL) -> Void)?
    
    override init() {
        super.init()
        checkPermissions()
        print("🎬 AudioRecorder: Initialized")
        print("🔧 AudioRecorder: Max recording duration: \(config.formattedMaxDuration)")
        print("🔧 AudioRecorder: Max file size: \(config.formattedMaxFileSize)")
        print("🔧 AudioRecorder: Recording quality: \(config.recordingQuality)")
    }
    
    private func requestMicPermission(_ completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { allowed in
                completion(allowed)
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                completion(allowed)
            }
        }
    }
    
    func checkPermissions() {
        requestMicPermission { [weak self] allowed in
            DispatchQueue.main.async {
                self?.hasPermission = allowed
            }
        }
    }
    
    func startRecording() {
        guard hasPermission else {
            checkPermissions()
            return
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
            return
        }
        
        let filename = generateFilename()
        let url = documentsPath.appendingPathComponent(filename)
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            
            recordingTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateRecordingTime()
                }
            }
            RunLoop.main.add(recordingTimer!, forMode: .common)
            print("🕐 AudioRecorder: Timer started on main RunLoop")
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    func stopRecording() {
        print("🛑 AudioRecorder: stopRecording() called")
        print("🛑 AudioRecorder: onRecordingFinished callback is \(onRecordingFinished != nil ? "SET" : "NIL")")
        
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false)
        
        print("🛑 AudioRecorder: Recording stopped, delegate should be called")
    }
    
    private func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "memo_\(timestamp).m4a"
    }
    
    private func updateRecordingTime() {
        if let recorder = audioRecorder {
            recordingTime = recorder.currentTime
            print("🕐 AudioRecorder: Timer update - recordingTime: \(String(format: "%.1f", recordingTime))s")
            
            let timeUntilLimit = maxRecordingDuration - recordingTime
            
            if timeUntilLimit <= countdownThreshold && timeUntilLimit > 0 {
                isInCountdown = true
                remainingTime = timeUntilLimit
            } else {
                isInCountdown = false
                remainingTime = 0
            }
            
            if recordingTime >= maxRecordingDuration {
                print("⏰ AudioRecorder: Maximum recording duration reached, stopping automatically")
                recordingStoppedAutomatically = true
                autoStopMessage = "Recording stopped automatically after 1 minute"
                isInCountdown = false
                stopRecording()
            }
        }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("🎬 AudioRecorder: Recording finished successfully: \(flag)")
        if flag {
            print("🎬 AudioRecorder: Calling onRecordingFinished callback for \(recorder.url.lastPathComponent)")
            onRecordingFinished?(recorder.url)
        } else {
            print("Recording failed")
        }
    }
}
