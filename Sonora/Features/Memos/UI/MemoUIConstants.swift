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
    case clock

    /// Transcription action icon
    case transcribe = "text.quote"

    /// Retry action icon
    case retry = "arrow.clockwise"

    /// Delete action icon
    case delete = "trash"
}

// Legacy NotificationCenter names removed — migrated to EventBus

// Removed unused TranscriptionStateKey.
