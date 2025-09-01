//
//  MemoUIConstants.swift
//  Sonora
//
//  Type-safe constants for memo UI components
//

import SwiftUI

// MARK: - System Icons

/// **Type-Safe System Icon Names**
/// Eliminates magic strings and provides compile-time safety for SF Symbols
enum MemoSystemIcons: String {
    /// Clock icon for duration display
    case clock = "clock"
    
    /// Transcription action icon
    case transcribe = "text.quote"
    
    /// Retry action icon
    case retry = "arrow.clockwise"
    
    /// Delete action icon
    case delete = "trash"
}

// MARK: - Notification Names

/// **Type-Safe Notification Names**
/// Centralized notification identifiers with compile-time safety
extension Notification.Name {
    /// Navigate to root of memos view
    static let popToRootMemos = Notification.Name("popToRootMemos")
    
    /// Open specific memo by ID
    static let openMemoByID = Notification.Name("openMemoByID")
}

// MARK: - Transcription State Keys

/// **Type-Safe State Keys for View Identity**
/// Ensures consistent key generation for SwiftUI view identity and animation
enum TranscriptionStateKey: String {
    /// State key for memos that haven't started transcription
    case notStarted = "notStarted"
    
    /// State key for memos currently being transcribed
    case inProgress = "inProgress"
    
    /// State key for successfully transcribed memos
    case completed = "completed"
    
    /// State key for failed transcription attempts
    case failed = "failed"
    
    /// Generate appropriate key for transcription state
    /// - Parameter state: Current transcription state
    /// - Returns: Type-safe string key for SwiftUI identity
    static func key(for state: TranscriptionState) -> String {
        switch state {
        case .notStarted:
            return TranscriptionStateKey.notStarted.rawValue
        case .inProgress:
            return TranscriptionStateKey.inProgress.rawValue
        case .completed:
            return TranscriptionStateKey.completed.rawValue
        case .failed:
            return TranscriptionStateKey.failed.rawValue
        }
    }
}