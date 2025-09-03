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
        RoundedRectangle(cornerRadius: Layout.accentLineCornerRadius)
            .fill(Colors.accentColor(for: transcriptionState))
            .frame(width: Layout.accentLineWidth)
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
        // When editing, wrap in a different container that blocks navigation
        Group {
            if viewModel.isEditing(memo: memo) {
                // Editing mode: disable navigation, allow text editing
                editingContent
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Tapping outside the TextField stops editing
                        viewModel.stopEditing()
                    }
            } else {
                // Normal mode: full navigation and context menu
                normalContent
                    .contentShape(Rectangle()) // Ensures entire row area is tappable
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
            }
        }
        .padding(.vertical, Layout.verticalPadding)
        // Selection background is now applied at the List row level for full-width coverage
        .scaleEffect(viewModel.isEditMode && viewModel.isMemoSelected(memo) ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isMemoSelected(memo))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(AccessibilityStrings.rowHint)
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var normalContent: some View {
        HStack(spacing: Layout.accentLineSpacing) {
            // Selection indicator (only visible in edit mode)
            if viewModel.isEditMode {
                selectionIndicator
            }
            
            // Color-coded accent line
            accentLineView
            
            // Main content container
            primaryContentView
            
            // Natural spacer - let system handle chevron positioning
            Spacer()
        }
    }
    
    @ViewBuilder
    private var editingContent: some View {
        HStack(spacing: Layout.accentLineSpacing) {
            // Selection indicator (only visible in edit mode)
            if viewModel.isEditMode {
                selectionIndicator
            }
            
            // Color-coded accent line
            accentLineView
            
            // Main content container (with inline editing)
            primaryContentView
            
            // Natural spacer
            Spacer()
        }
    }
    
    // MARK: - Subviews
    
    /// **Primary Content View**
    /// Contains the main information hierarchy: title and metadata
    @ViewBuilder
    private var primaryContentView: some View {
        VStack(alignment: .leading, spacing: Layout.titleToMetadataSpacing) {
            // Memo title - primary information
            titleView
            
            // Metadata row - secondary information (duration and date)
            metadataRowView
        }
    }
    
    /// **Title View**
    /// Displays the memo name with prominence and proper line handling
    /// Shows inline TextField when editing
    @ViewBuilder
    private var titleView: some View {
        if viewModel.isEditing(memo: memo) {
            // Inline editing mode
            TextField("Memo Title", text: $editedTitle, onCommit: {
                submitRename()
            })
            .font(Typography.titleFont)
            .foregroundColor(Colors.titleText)
            .textFieldStyle(PlainTextFieldStyle())
            .focused($isEditingFocused)
            .onAppear {
                // Auto-focus and select text when editing starts
                editedTitle = memo.displayName
                isEditingFocused = true
            }
            .onDisappear {
                // Clean up when view disappears
                if viewModel.isEditing(memo: memo) {
                    viewModel.stopEditing()
                }
            }
        } else {
            // Normal display mode
            Text(memo.displayName)
                .font(Typography.titleFont)
                .foregroundColor(Colors.titleText)
                .lineLimit(Layout.titleLineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    /// **Metadata Row View**
    /// Horizontal layout containing duration and creation date information
    @ViewBuilder
    private var metadataRowView: some View {
        HStack(spacing: Layout.metadataElementSpacing) {
            // Duration with clock icon
            durationView
            
            // Creation date (relative format)
            dateView
            
            // Spacer pushes content left and leaves room for system chevron
            Spacer()
        }
    }
    
    /// **Duration View**
    /// Clock icon + duration text with optimal spacing and styling
    @ViewBuilder
    private var durationView: some View {
        HStack(spacing: Layout.iconToTextSpacing) {
            Image(systemName: SystemIconNames.clock)
                .font(Typography.iconFont)
                .foregroundColor(Colors.iconTint)
            
            Text(memo.durationString)
                .font(Typography.metadataFont)
                .foregroundColor(Colors.metadataText)
                .monospacedDigit() // Ensures consistent width for time display
        }
    }
    
    /// **Date View**
    /// Relative date display ("7 hours ago", "yesterday", etc.)
    @ViewBuilder
    private var dateView: some View {
        Text(formattedRelativeDate)
            .font(Typography.metadataFont)
            .foregroundColor(Colors.metadataText)
    }
    
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
        HapticManager.shared.playSelection()
        viewModel.startEditing(memo: memo)
    }
    
    /// Share the memo using native iOS share sheet
    private func shareMemo() {
        HapticManager.shared.playSelection()
        viewModel.shareMemo(memo)
    }
    
    /// Delete the memo with haptic feedback
    private func deleteMemo() {
        HapticManager.shared.playDeletionFeedback()
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
