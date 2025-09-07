//
//  MemoListConstants.swift
//  Sonora
//
//  Shared configuration constants for memo list UI components
//

import SwiftUI

// MARK: - Color Management

/// **Unified Color Provider for Memo List Components**
/// Consolidates all color logic to eliminate duplication and provide consistent theming
enum MemoListColors {
    /// Row background color that adapts to color scheme
    /// - Parameter colorScheme: Current interface color scheme
    /// - Returns: Slightly grey background in dark mode, clear in light mode
    static func rowBackground(for colorScheme: ColorScheme) -> Color {
        // Avoid extra gutters/rounded backgrounds in both modes
        return .clear
    }
    
    /// Container background color that adapts to color scheme  
    /// - Parameter colorScheme: Current interface color scheme
    /// - Returns: Pure black in dark mode for OLED optimization, semantic background in light mode
    static func containerBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(UIColor.systemBackground) : Color.semantic(.bgSecondary)
    }
}

// MARK: - Configuration Constants

/// **MemoListConstants**
/// Centralized configuration for all memo list styling and behavior
/// 
/// **Usage:**
/// Modify these constants to adjust the entire memo list appearance
/// All values are documented for easy customization
enum MemoListConstants {
    
    /// **List Styling Configuration**
    /// Controls overall list appearance and behavior
    enum ListStyling {
        /// List style - affects visual presentation and grouping
        /// Options: .insetGrouped (modern cards), .grouped (traditional), .plain (minimal)
        static var preferredStyle: some ListStyle { InsetGroupedListStyle() }
        
        /// Background color for the list container
        /// Uses semantic color for automatic light/dark adaptation
        static let backgroundColor: Color = .semantic(.bgSecondary)
    }
    
    /// **Row Configuration**
    /// Fine-tune individual row appearance
    /// Proper insets that work with insetGrouped style
    static let rowInsets = EdgeInsets(
        top: 0,
        leading: 16,    // Standard iOS leading inset
        bottom: 0,
        trailing: 16    // Standard iOS trailing inset
    )
    
    /// Current list style setting
    /// List style - keep insetGrouped but ensure proper setup
    static var listStyle: some ListStyle { InsetGroupedListStyle() }
    
    /// **Swipe Actions Configuration**
    /// Text and icons for swipe gesture actions
    enum SwipeActions {
        // Transcription actions
        static let transcribeTitle = "Transcribe"
        static let transcribeIcon = MemoSystemIcons.transcribe.rawValue
        
        static let retryTitle = "Retry"
        static let retryIcon = MemoSystemIcons.retry.rawValue
        
        // Destructive actions
        static let deleteTitle = "Delete"
        static let deleteIcon = MemoSystemIcons.delete.rawValue
    }
    
    /// **Accessibility Configuration**
    /// VoiceOver labels and hints for better accessibility
    enum AccessibilityLabels {
        static let mainList = "Memos list"
        
        // Action hints
        static let transcribeHint = "Double tap to transcribe this memo using AI"
        static let retryHint = "Double tap to retry the failed transcription"
        static let deleteHint = "Double tap to permanently delete this memo"
    }
}

// MARK: - View Modifiers

/// **Unified Dark Mode Row Background Modifier**
/// Eliminates duplicate color scheme logic across components
struct DarkModeRowBackground: ViewModifier {
    let colorScheme: ColorScheme
    
    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content.listRowBackground(MemoListColors.rowBackground(for: colorScheme))
        } else {
            content
        }
    }
}

extension View {
    /// Apply dark mode row background styling
    func memoRowBackground(_ colorScheme: ColorScheme) -> some View {
        self.modifier(DarkModeRowBackground(colorScheme: colorScheme))
    }
}
