//
//  RecordingTimerService.swift
//  Sonora
//
//  Recording timer and countdown service
//  Handles recording duration tracking, countdown display, and auto-stop functionality
//

import Combine
import Foundation

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
        static let normalUpdateInterval: TimeInterval = 1.0 // 1 second for normal recording
        static let countdownUpdateInterval: TimeInterval = 0.1 // 100ms for smooth countdown
        static let countdownThreshold: TimeInterval = 10.0 // Start countdown at 10 seconds
    }

    /// Dynamic update interval based on countdown state (Swift 6 compliant)
    private var updateInterval: TimeInterval {
        isInCountdown ? TimerConfiguration.countdownUpdateInterval : TimerConfiguration.normalUpdateInterval
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

        let initialInterval = recordingCap != nil ? "adaptive (1.0s normal, 0.1s countdown)" : "1.0s"
        print("⏱️ RecordingTimerService: Timer started with cap: \(recordingCap?.description ?? "unlimited"), interval: \(initialInterval)")
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

    /// Resume timer from interruption with accumulated time
    func resumeFromInterruption(accumulatedTime: TimeInterval) {
        // Set the accumulated time as the starting point
        recordingTime = accumulatedTime

        // If we have a time provider and recording cap, restart the timer
        if currentTimeProvider != nil {
            timerTask = Task { [weak self] in
                await self?.runTimerLoop()
            }

            print("⏱️ RecordingTimerService: Timer resumed from interruption with \(accumulatedTime)s accumulated time")
        } else {
            print("⚠️ RecordingTimerService: Cannot resume - no time provider available")
        }
    }

    /// Gets formatted recording time string
    func getFormattedRecordingTime() -> String {
        formatDuration(recordingTime)
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

    /// Main timer loop with adaptive frequency (Swift 6 compliant)
    private func runTimerLoop() async {
        while !Task.isCancelled {
            // Get current update interval on MainActor (since isInCountdown is @Published)
            let currentInterval = await MainActor.run { [weak self] in
                self?.updateInterval ?? TimerConfiguration.normalUpdateInterval
            }

            do {
                try await Task.sleep(nanoseconds: UInt64(currentInterval * 1_000_000_000))
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

    /// Updates timer state and handles countdown logic with adaptive frequency
    private func updateTimerState() {
        guard let timeProvider = currentTimeProvider else { return }

        let elapsed = timeProvider()
        let cap = recordingCapSeconds
        let remaining = cap != nil ? max(0, cap! - elapsed) : .infinity

        // Track previous countdown state for frequency transition logging
        let wasInCountdown = isInCountdown

        // Update elapsed time
        self.recordingTime = elapsed

        // Countdown behavior: only when a finite cap exists and remaining time is within threshold
        if cap != nil, remaining.isFinite, remaining > 0 && remaining < TimerConfiguration.countdownThreshold {
            if !wasInCountdown {
                print("⏱️ RecordingTimerService: Entering countdown mode - switching to \(TimerConfiguration.countdownUpdateInterval)s intervals")
            }
            self.isInCountdown = true
            self.remainingTime = remaining
            print("⏱️ RecordingTimerService: Countdown active - \(remaining.formatted(.number.precision(.fractionLength(1)))) seconds remaining")
        } else {
            if wasInCountdown {
                print("⏱️ RecordingTimerService: Exiting countdown mode - switching to \(TimerConfiguration.normalUpdateInterval)s intervals")
            }
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
