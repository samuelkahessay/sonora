//
//  AudioPermissionService.swift
//  Sonora
//
//  Audio permission management service
//  Handles microphone permission requests and status monitoring
//

import Foundation
import AVFoundation
import Combine

// MicrophonePermissionStatus is defined in Core/Permissions/MicrophonePermissionStatus.swift

/// Protocol defining audio permission management operations
@MainActor
protocol AudioPermissionServiceProtocol: ObservableObject {
    var hasPermission: Bool { get }
    var permissionStatus: MicrophonePermissionStatus { get }
    var permissionStatusPublisher: AnyPublisher<MicrophonePermissionStatus, Never> { get }
    
    func checkPermissions()
    func requestPermission() async -> Bool
    func getCurrentPermissionStatus() -> MicrophonePermissionStatus
}

/// Focused service for microphone permission management
@MainActor
final class AudioPermissionService: AudioPermissionServiceProtocol, @unchecked Sendable {
    
    // MARK: - Published Properties
    @Published var hasPermission = false
    @Published var permissionStatus: MicrophonePermissionStatus = .notDetermined
    
    // MARK: - Publishers
    var permissionStatusPublisher: AnyPublisher<MicrophonePermissionStatus, Never> {
        $permissionStatus.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init() {
        print("🔑 AudioPermissionService: Initialized")
        checkPermissions()
    }
    
    // MARK: - Public Interface
    
    /// Checks current microphone permissions and updates state
    func checkPermissions() {
        let status = getCurrentPermissionStatus()
        updatePermissionState(status)
        
        print("🔑 AudioPermissionService: Permission check - \(status)")
    }
    
    /// Requests microphone permission from the user
    func requestPermission() async -> Bool {
        let status = await requestMicrophonePermission()
        updatePermissionState(status)
        return status.allowsRecording
    }
    
    /// Gets the current permission status without updating state
    func getCurrentPermissionStatus() -> MicrophonePermissionStatus {
        return MicrophonePermissionStatus.current()
    }
    
    /// Requests permission if needed, returns current status
    func ensurePermission() async -> MicrophonePermissionStatus {
        let currentStatus = getCurrentPermissionStatus()
        
        switch currentStatus {
        case .notDetermined:
            let granted = await requestPermission()
            return granted ? .granted : .denied
        case .granted, .denied, .restricted:
            return currentStatus
        }
    }
    
    /// Checks if permission is available for recording
    func canRecord() -> Bool {
        return getCurrentPermissionStatus().allowsRecording
    }
    
    // MARK: - Private Methods
    
    /// Updates the permission state and publishes changes
    private func updatePermissionState(_ status: MicrophonePermissionStatus) {
        let hasPermissionValue = status.allowsRecording
        
        // Only update if values have changed to avoid unnecessary notifications
        if self.permissionStatus != status {
            self.permissionStatus = status
        }
        
        if self.hasPermission != hasPermissionValue {
            self.hasPermission = hasPermissionValue
        }
        
        print("🔑 AudioPermissionService: State updated - hasPermission: \(hasPermissionValue), status: \(status)")
    }
    
}
