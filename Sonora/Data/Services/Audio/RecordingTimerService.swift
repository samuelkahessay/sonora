//
//  RecordingTimerService.swift
//  Sonora
//
//  Recording timer and countdown service
//  Handles recording duration tracking, countdown display, and auto-stop functionality
//

import Foundation
import Combine

/// Protocol defining recording timer operations
@MainActor
protocol RecordingTimerServiceProtocol: ObservableObject {
    var recordingTime: TimeInterval { get }
    var isInCountdown: Bool { get }
    var remainingTime: TimeInterval { get }
    var recordingStoppedAutomatically: Bool { get }
    var autoStopMessage: String? { get }
    
    var recordingTimePublisher: AnyPublisher<TimeInterval, Never> { get }
    var countdownPublisher: AnyPublisher<(Bool, TimeInterval), Never> { get }
    
    func startTimer(with timeProvider: @escaping () -> TimeInterval, recordingCap: TimeInterval?)
    func stopTimer()
    func resetTimer()
    
    // Callbacks
    var onAutoStop: (() -> Void)? { get set }
}

/// Focused service for recording time tracking and countdown management
@MainActor
final class RecordingTimerService: RecordingTimerServiceProtocol, @unchecked Sendable {
    
    // MARK: - Published Properties
    @Published var recordingTime: TimeInterval = 0
    @Published var isInCountdown = false
    @Published var remainingTime: TimeInterval = 0
    @Published var recordingStoppedAutomatically = false
    @Published var autoStopMessage: String?
    
    // MARK: - Publishers
    var recordingTimePublisher: AnyPublisher<TimeInterval, Never> {
        $recordingTime.eraseToAnyPublisher()
    }
    
    var countdownPublisher: AnyPublisher<(Bool, TimeInterval), Never> {
        Publishers.CombineLatest($isInCountdown, $remainingTime)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    private var timerTask: Task<Void, Never>?
    private var currentTimeProvider: (() -> TimeInterval)?
    private var recordingCapSeconds: TimeInterval?
    
    // MARK: - Configuration
    private struct TimerConfiguration {
        static let updateInterval: TimeInterval = 0.1 // 100ms updates for smooth UI
        static let countdownThreshold: TimeInterval = 10.0 // Start countdown at 10 seconds
    }
    
    // MARK: - Callbacks
    var onAutoStop: (() -> Void)?
    
    // MARK: - Initialization
    init() {
        print("⏱️ RecordingTimerService: Initialized")
    }
    
    deinit {
        // Cleanup in deinit must be synchronous
        timerTask?.cancel()
        timerTask = nil
        print("⏱️ RecordingTimerService: Deinitialized")
    }
    
    // MARK: - Public Interface
    
    /// Starts the recording timer with a time provider and optional recording cap
    func startTimer(with timeProvider: @escaping () -> TimeInterval, recordingCap: TimeInterval?) {
        stopTimer() // Ensure no existing timer
        
        self.currentTimeProvider = timeProvider
        self.recordingCapSeconds = recordingCap
        self.recordingStoppedAutomatically = false
        self.autoStopMessage = nil
        
        timerTask = Task { [weak self] in
            await self?.runTimerLoop()
        }
        
        print("⏱️ RecordingTimerService: Timer started with cap: \(recordingCap?.description ?? "unlimited")")
    }
    
    /// Stops the recording timer
    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        currentTimeProvider = nil
        
        print("⏱️ RecordingTimerService: Timer stopped")
    }
    
    /// Resets timer state to initial values
    func resetTimer() {
        stopTimer()
        
        recordingTime = 0
        isInCountdown = false
        remainingTime = 0
        recordingStoppedAutomatically = false
        autoStopMessage = nil
        
        print("⏱️ RecordingTimerService: Timer reset")
    }
    
    /// Gets formatted recording time string
    func getFormattedRecordingTime() -> String {
        return formatDuration(recordingTime)
    }
    
    /// Gets formatted remaining time string
    func getFormattedRemainingTime() -> String {
        guard remainingTime > 0 else { return "" }
        return formatDuration(remainingTime)
    }
    
    /// Checks if recording should auto-stop based on cap
    func shouldAutoStop() -> Bool {
        guard let cap = recordingCapSeconds else { return false }
        return recordingTime >= cap
    }
    
    // MARK: - Private Methods
    
    /// Main timer loop that runs until cancelled
    private func runTimerLoop() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: UInt64(TimerConfiguration.updateInterval * 1_000_000_000))
            } catch {
                // Task was cancelled
                break
            }
            
            guard !Task.isCancelled else { break }
            
            await MainActor.run { [weak self] in
                self?.updateTimerState()
            }
        }
    }
    
    /// Updates timer state and handles countdown logic
    private func updateTimerState() {
        guard let timeProvider = currentTimeProvider else { return }
        
        let elapsed = timeProvider()
        let cap = recordingCapSeconds
        let remaining = cap != nil ? max(0, cap! - elapsed) : .infinity
        
        // Update elapsed time
        self.recordingTime = elapsed
        
        // Countdown behavior: only when a finite cap exists and remaining time is within threshold
        if let _ = cap, remaining.isFinite, remaining > 0 && remaining < TimerConfiguration.countdownThreshold {
            self.isInCountdown = true
            self.remainingTime = remaining
            print("⏱️ RecordingTimerService: Countdown active - \(remaining.formatted(.number.precision(.fractionLength(1)))) seconds remaining")
        } else {
            self.isInCountdown = false
            self.remainingTime = 0
        }
        
        // Auto-stop logic: only when a finite cap exists and time is exceeded
        if let recordingCap = cap, elapsed >= recordingCap {
            handleAutoStop(cap: recordingCap)
        }
    }
    
    /// Handles automatic stopping when recording cap is reached
    private func handleAutoStop(cap: TimeInterval) {
        self.recordingStoppedAutomatically = true
        self.autoStopMessage = "Recording stopped automatically after \(formatDuration(cap))"
        self.isInCountdown = false
        self.remainingTime = 0
        
        print("⏱️ RecordingTimerService: Auto-stop triggered at \(formatDuration(cap))")
        
        // Notify callback
        onAutoStop?()
        
        // Stop timer since recording should be stopped
        stopTimer()
    }
    
    /// Formats duration in MM:SS format
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Error Types

enum RecordingTimerError: LocalizedError {
    case timerAlreadyRunning
    case noTimeProvider
    case invalidTimeValue
    
    var errorDescription: String? {
        switch self {
        case .timerAlreadyRunning:
            return "Recording timer is already running"
        case .noTimeProvider:
            return "No time provider specified for recording timer"
        case .invalidTimeValue:
            return "Invalid time value received from time provider"
        }
    }
}