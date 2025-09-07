//
//  MemoRowView.swift
//  Sonora
//
//  Individual memo row component with optimized animation logic
//

import SwiftUI

// MARK: - MemoRowView

/// Polished memo row component optimized for navigation and readability
/// 
/// **Design Philosophy:**
/// - Primary action: Navigation to memo details (entire row tappable)
/// - Information hierarchy: Title prominence > Metadata clarity
/// - Visual simplicity: Minimal UI chrome, maximum content focus
/// - Accessibility first: Full VoiceOver support with logical reading order
///
/// **Customization Points:**
/// All sizing, spacing, and styling constants are documented below for easy adjustment
struct MemoRowView: View {
    
    // MARK: - Properties
    
    let memo: Memo
    @ObservedObject var viewModel: MemoListViewModel
    @State private var pulsePhase = false
    @State private var editedTitle: String = ""
    @FocusState private var isEditingFocused: Bool

    // Recomputed each render; drives color/animation
    private var transcriptionState: TranscriptionState {
        viewModel.getTranscriptionState(for: memo)
    }
    
    // MARK: - Design Constants
    
    /// **Typography Configuration**
    /// Adjust these values to fine-tune text appearance and hierarchy
    private enum Typography {
        /// Primary title font - prominent but not overwhelming
        /// 1.75x size: .title3 with semibold weight for strong hierarchy
        static let titleFont: Font = .system(.title3, design: .default, weight: .semibold)
        
        /// Metadata font for duration and date information
        /// 1.75x size: .subheadline for better readability
        static let metadataFont: Font = .system(.subheadline, design: .default, weight: .regular)
        
        /// Clock icon font size - should complement metadata text
        /// 1.75x size: .footnote with medium weight for better visibility
        static let iconFont: Font = .system(.footnote, design: .default, weight: .medium)
    }
    
    /// **Color Configuration**
    /// Semantic colors ensure proper light/dark mode adaptation
    private enum Colors {
        /// Primary text color for memo titles - maximum contrast
        static let titleText: Color = .semantic(.textPrimary)
        
        /// Secondary text color for metadata - reduced emphasis
        static let metadataText: Color = .semantic(.textSecondary)
        
        /// Icon tint color - should match or complement metadata text
        static let iconTint: Color = .semantic(.textSecondary)
        
        /// Accent line color based on transcription state
        /// Follows semantic color patterns for accessibility and theming
        static func accentColor(for state: TranscriptionState) -> Color {
            switch state {
            case .completed:
                return .semantic(.success)      // Green - transcription complete
            case .inProgress:
                return .semantic(.info)         // Blue - actively transcribing
            case .failed:
                return .semantic(.error)        // Red - transcription failed
            case .notStarted:
                return .semantic(.textSecondary) // Gray - default/not started
            }
        }
    }
    
    /// **Layout Configuration**
    /// These follow iOS Human Interface Guidelines spacing standards
    private enum Layout {
        /// Vertical padding for generous card appearance
        static let verticalPadding: CGFloat = 14
        
        /// Spacing between title and metadata sections
        static let titleToMetadataSpacing: CGFloat = 7
        
        /// Horizontal spacing between metadata elements
        static let metadataElementSpacing: CGFloat = 21
        
        /// Spacing between icons and their associated text
        static let iconToTextSpacing: CGFloat = 5
        
        /// Line limit stays the same
        static let titleLineLimit: Int = 2
        
        /// **Accent Line Configuration - Proportional to 1.75x Design**
        /// Color-coded status indicators following iOS design principles
        
        /// Accent line width - prominent but not overwhelming
        static let accentLineWidth: CGFloat = 4
        
        /// Accent line corner radius - subtle rounding for modern appearance
        static let accentLineCornerRadius: CGFloat = 2
        
        /// Accent line spacing - proportional to iconToTextSpacing for visual balance
        static let accentLineSpacing: CGFloat = 8

        /// Reserved gutter width when in edit mode for selection control
        static let editGutterWidth: CGFloat = 44
    }
    
    // MARK: - Animation Configuration
    
    /// **Centralized Animation Logic**
    /// Eliminates duplication and provides consistent animation behavior
    private func configurePulseAnimation(for isInProgress: Bool) {
        if isInProgress {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulsePhase.toggle()
            }
            print("🎨 MemoRow: Starting pulse animation for \(memo.displayName)")
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                pulsePhase = false
            }
            print("🎨 MemoRow: Stopping pulse animation for \(memo.displayName)")
        }
    }
    
    // MARK: - Selection & Accent Components
    
    /// **Selection Indicator**
    /// Shows selection state in edit mode
    @ViewBuilder
    private var selectionIndicator: some View {
        Button(action: {
            viewModel.toggleMemoSelection(memo)
        }) {
            Image(systemName: viewModel.isMemoSelected(memo) 
                ? "checkmark.circle.fill" 
                : "circle")
                .foregroundColor(viewModel.isMemoSelected(memo)
                    ? .semantic(.brandPrimary)
                    : .semantic(.textSecondary))
                .imageScale(.large)
                .font(.title2)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: viewModel.isMemoSelected(memo))
        .accessibilityLabel(viewModel.isMemoSelected(memo) 
            ? "Selected \(memo.displayName)" 
            : "Select \(memo.displayName)")
        .accessibilityHint("Tap to toggle selection")
    }
    
    /// **Accent Line View**
    /// Color-coded status indicator with animated pulse for in-progress states
    @ViewBuilder
    private var accentLineView: some View {
        RoundedRectangle(cornerRadius: MemoRowView.Layout.accentLineCornerRadius)
            .fill(MemoRowView.Colors.accentColor(for: transcriptionState))
            .frame(width: MemoRowView.Layout.accentLineWidth)
            .opacity(transcriptionState.isInProgress ? (pulsePhase ? 0.4 : 1.0) : 1.0)
            // Force view recreation when state case changes (e.g., inProgress → completed)
            .id(accentStateKey)
            .onAppear {
                configurePulseAnimation(for: transcriptionState.isInProgress)
            }
            .onChange(of: transcriptionState.isInProgress) { _, isInProgress in
                configurePulseAnimation(for: isInProgress)
            }
            .onChange(of: transcriptionState) { old, new in
                if old != new {
                    print("🎨 MemoRow: State changed for \(memo.displayName): \(old.statusText) → \(new.statusText)")
                    configurePulseAnimation(for: new.isInProgress)
                }
            }
            .onDisappear {
                // Stop animations when cell goes off-screen
                pulsePhase = false
            }
            .accessibilityHidden(true)
    }
    
    // MARK: - View Body
    
    var body: some View {
        HStack(spacing: 0) {
            // Single reserved gutter for the selection control.
            // Using an overlay avoids adding extra width beyond the gutter itself.
            ZStack(alignment: .leading) {
                Color.clear
                if viewModel.isEditMode {
                    selectionIndicator
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .frame(width: viewModel.isEditMode ? Layout.editGutterWidth : 0)
            .animation(.spring(response: 0.25), value: viewModel.isEditMode)

            // Main card content
            SonoraMemocCard(memo: memo, viewModel: viewModel)
                .contentShape(Rectangle())
        }
        .contentShape(Rectangle())
        .contextMenu {
                Button {
                    startRename()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                
                Button {
                    shareMemo()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Button(role: .destructive) {
                    deleteMemo()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        .scaleEffect(viewModel.isEditMode && viewModel.isMemoSelected(memo) ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isMemoSelected(memo))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(AccessibilityStrings.rowHint)
    }
    
    // MARK: - Content Views
    // All content now handled by SonoraMemocCard for brand consistency
    
    // MARK: - Helper Properties
    
    /// Formatted relative date string using system formatter
    /// Example outputs: "5 minutes ago", "2 hours ago", "yesterday"
    private var formattedRelativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated // More compact display
        return formatter.localizedString(for: memo.creationDate, relativeTo: Date())
    }
    
    /// Comprehensive accessibility description for VoiceOver users
    /// Provides all essential information in logical reading order
    private var accessibilityDescription: String {
        let components = [
            memo.displayName,
            "Duration: \(memo.durationString)",
            "Created \(formattedRelativeDate)"
        ]
        return components.joined(separator: ", ")
    }
    
    /// Key for forcing view recreation when the transcription state changes case
    private var accentStateKey: String {
        TranscriptionStateKey.key(for: transcriptionState)
    }
    
    // MARK: - Constants
    
    /// **System Icon Names**
    /// Type-safe SF Symbols names for consistency
    private enum SystemIconNames {
        static let clock = MemoSystemIcons.clock.rawValue
    }
    
    /// **Accessibility Strings**
    /// Localization-ready accessibility strings
    private enum AccessibilityStrings {
        static let rowHint = "Double tap to view memo details"
    }
    
    // MARK: - Helper Methods
    
    /// Start renaming the memo
    private func startRename() {
        Task { @MainActor in
            HapticManager.shared.playSelection()
        }
        viewModel.startEditing(memo: memo)
    }
    
    /// Share the memo using native iOS share sheet
    private func shareMemo() {
        Task { @MainActor in
            HapticManager.shared.playSelection()
        }
        viewModel.shareMemo(memo)
    }
    
    /// Delete the memo with haptic feedback
    private func deleteMemo() {
        Task { @MainActor in
            HapticManager.shared.playDeletionFeedback()
        }
        if let index = viewModel.memos.firstIndex(where: { $0.id == memo.id }) {
            viewModel.deleteMemo(at: index)
        }
    }
    
    /// Submit the rename operation
    private func submitRename() {
        let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Revert to original if empty
        if trimmedTitle.isEmpty {
            editedTitle = memo.displayName
            viewModel.stopEditing()
            return
        }
        
        // Only rename if changed
        if trimmedTitle != memo.displayName {
            Task {
                await viewModel.renameMemo(memo, newTitle: trimmedTitle)
            }
        } else {
            viewModel.stopEditing()
        }
    }
}
