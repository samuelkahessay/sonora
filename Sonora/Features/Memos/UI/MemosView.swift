//
//  MemosView.swift (moved to Features/Memos/UI)
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI

extension Notification.Name {
    static let popToRootMemos = Notification.Name("popToRootMemos")
    static let openMemoByID = Notification.Name("openMemoByID")
}

struct MemosView: View {
    @StateObject private var viewModel = MemoListViewModel()
    let popToRoot: (() -> Void)?
    
    init(popToRoot: (() -> Void)? = nil) {
        self.popToRoot = popToRoot
    }
    
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            Group {
                if viewModel.isEmpty {
                    UnifiedStateView.noMemos()
                    .accessibilityLabel("No memos yet. Start recording to see your audio memos here.")
                } else {
                    // MARK: - Memos List
                    /// **Polished List Configuration**
                    /// Optimized for readability, navigation, and modern iOS appearance
                    List {
                        ForEach(Array(viewModel.memos.enumerated()), id: \.element.id) { index, memo in
                            // MARK: Navigation Row Configuration
                            let separatorConfig = separatorConfiguration(at: index, total: viewModel.memos.count)
                            NavigationLink(value: memo) {
                                MemoRowView(memo: memo, viewModel: viewModel)
                            }
                            // **Row Visual Configuration**
                            // Adjust these modifiers to fine-tune row appearance
                            .listRowSeparator(separatorConfig.visibility, edges: separatorConfig.edges)
                            .listRowInsets(MemoListConstants.rowInsets) // Zero insets for full-width content
                            
                            // MARK: - Swipe Actions Configuration
                            /// Secondary actions accessible via swipe gestures
                            /// Design principle: Keep primary UI clean, secondary actions discoverable
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                // Put delete first so full-swipe reliably deletes
                                deleteButton(for: memo)
                                // Contextual actions next (transcribe/retry)
                                contextualTranscriptionActions(for: memo)
                            }
                        }
                        // **Bulk Operations**
                        // Traditional iOS delete gesture support
                        .onDelete { offsets in
                            HapticManager.shared.playDeletionFeedback()
                            viewModel.deleteMemos(at: offsets)
                        }
                    }
                    // **List Styling Configuration**
                    .accessibilityLabel(MemoListConstants.AccessibilityLabels.mainList)
                    .listStyle(MemoListConstants.listStyle) // Modern grouped appearance
                    .scrollContentBackground(.hidden) // ADDED: Clean background
                    .background(MemoListConstants.ListStyling.backgroundColor) // ADDED: Consistent bg
                    // Add a small top inset so first row doesn't touch nav bar hairline
                    .safeAreaInset(edge: .top) {
                        Color.clear.frame(height: 8)
                    }
                    .refreshable { viewModel.refreshMemos() } // Pull-to-refresh support
                }
            }
            .navigationTitle("Memos")
            .navigationDestination(for: Memo.self) { memo in
                MemoDetailView(memo: memo)
            }
            .errorAlert($viewModel.error) {
                viewModel.retryLastOperation()
            }
            .loadingState(
                isLoading: viewModel.isLoading,
                message: "Loading memos...",
                error: $viewModel.error
            ) {
                viewModel.retryLastOperation()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openMemoByID)) { note in
                guard let idStr = note.userInfo?["memoId"] as? String, let id = UUID(uuidString: idStr) else { return }
                if let memo = DIContainer.shared.memoRepository().getMemo(by: id) {
                    viewModel.navigationPath.append(memo)
                }
            }
        }
    }
    
    /// Position-specific separator configuration for clean design
    /// Handles edge cases: first memo (no separators), middle memos (top & bottom), last memo (top only)
    private func separatorConfiguration(at index: Int, total count: Int) -> (visibility: Visibility, edges: VerticalEdge.Set) {
        guard count > 1 else { return (.hidden, []) }
        
        switch index {
        case 0: // First memo - no separators (navigation spacing sufficient)
            return (.hidden, [])
        case count - 1: // Last memo - only top separator (no trailing separator)
            return (.visible, .top)
        default: // Middle memos - both top and bottom separators
            return (.visible, .all)
        }
    }
}

// MARK: - MemoRowView

/// Polished memo row component optimized for navigation and readability
/// sep
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
    let viewModel: MemoListViewModel
    
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
    
    /// **Layout Configuration - FIXED VALUES**
    /// These follow iOS Human Interface Guidelines spacing standards
    private enum Layout {
        /// Vertical padding - 1.75x size increase (8 × 1.75 = 14)
        /// Larger padding for more generous card appearance
        static let verticalPadding: CGFloat = 14
        
        /// Horizontal padding - REMOVED (let list handle it)
        /// List row insets will handle horizontal spacing properly
        // static let horizontalPadding: CGFloat = 16 // REMOVED
        
        /// Title to metadata spacing - 1.75x size increase (4 × 1.75 = 7)
        /// Proportional spacing for larger typography
        static let titleToMetadataSpacing: CGFloat = 7
        
        /// Metadata spacing - 1.75x size increase (12 × 1.75 = 21)
        /// Generous horizontal spacing for larger cards
        static let metadataElementSpacing: CGFloat = 21
        
        /// Icon to text spacing - 1.75x size increase (3 × 1.75 = 5)
        /// Proportional spacing for larger icons and text
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
    
    // MARK: - Accent Line Component
    
    /// **Accent Line View**
    /// Color-coded status indicator with smooth animations
    @ViewBuilder
    private var accentLineView: some View {
        let transcriptionState = viewModel.getTranscriptionState(for: memo)
        
        RoundedRectangle(cornerRadius: Layout.accentLineCornerRadius)
            .fill(Colors.accentColor(for: transcriptionState))
            .frame(width: Layout.accentLineWidth)
            .animation(.easeInOut(duration: 0.3), value: transcriptionState)
            .accessibilityHidden(true) // Visual indicator only
    }
    
    // MARK: - View Body
    
    var body: some View {
        HStack(spacing: Layout.accentLineSpacing) { // Color-coded accent line spacing
            // Color-coded accent line
            accentLineView
            
            // Main content container
            primaryContentView
            
            // Natural spacer - let system handle chevron positioning
            Spacer()
        }
        .padding(.vertical, Layout.verticalPadding) // ONLY vertical padding
        // .padding(.horizontal, Layout.horizontalPadding) // REMOVED - let list handle it
        .contentShape(Rectangle()) // Ensures entire row area is tappable
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(AccessibilityStrings.rowHint)
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
    @ViewBuilder
    private var titleView: some View {
        Text(memo.displayName)
            .font(Typography.titleFont)
            .foregroundColor(Colors.titleText)
            .lineLimit(Layout.titleLineLimit)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
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
    
    // MARK: - Constants
    
    /// **System Icon Names**
    /// Centralized SF Symbols names for consistency
    private enum SystemIconNames {
        static let clock = "clock"
    }
    
    /// **Accessibility Strings**
    /// Localization-ready accessibility strings
    private enum AccessibilityStrings {
        static let rowHint = "Double tap to view memo details"
    }
}


// MARK: - MemosView Extensions

/// **Swipe Actions Configuration**
extension MemosView {
    
    /// **Contextual Transcription Actions**
    /// Contextual actions based on memo transcription state (excluding delete)
    /// 
    /// **Design Philosophy:**
    /// - Progressive disclosure: Show relevant actions only
    /// - Visual hierarchy: Primary action (transcribe) vs secondary (delete)
    /// - Accessibility: Full VoiceOver support with descriptive labels
    @ViewBuilder
    private func contextualTranscriptionActions(for memo: Memo) -> some View {
        let transcriptionState = viewModel.getTranscriptionState(for: memo)
        
        // **Transcription Actions**
        // Show transcription-related actions based on current state
        if transcriptionState.isNotStarted {
            transcribeButton(for: memo)
        } else if transcriptionState.isFailed {
            retryTranscriptionButton(for: memo)
        }
    }
    
    /// **Transcribe Button**
    /// Primary action for unprocessed memos
    @ViewBuilder
    private func transcribeButton(for memo: Memo) -> some View {
        Button {
            HapticManager.shared.playSelection()
            viewModel.startTranscription(for: memo)
        } label: {
            Label(MemoListConstants.SwipeActions.transcribeTitle, 
                  systemImage: MemoListConstants.SwipeActions.transcribeIcon)
        }
        .tint(.semantic(.brandPrimary))
        .accessibilityLabel("Transcribe \(memo.displayName)")
        .accessibilityHint(MemoListConstants.AccessibilityLabels.transcribeHint)
    }
    
    /// **Retry Transcription Button**
    /// Recovery action for failed transcriptions
    @ViewBuilder
    private func retryTranscriptionButton(for memo: Memo) -> some View {
        Button {
            HapticManager.shared.playSelection()
            viewModel.retryTranscription(for: memo)
        } label: {
            Label(MemoListConstants.SwipeActions.retryTitle,
                  systemImage: MemoListConstants.SwipeActions.retryIcon)
        }
        .tint(.semantic(.warning))
        .accessibilityLabel("Retry transcription for \(memo.displayName)")
        .accessibilityHint(MemoListConstants.AccessibilityLabels.retryHint)
    }
    
    /// **Delete Button**
    /// Destructive action with appropriate styling and feedback
    @ViewBuilder
    private func deleteButton(for memo: Memo) -> some View {
        Button(role: .destructive) {
            HapticManager.shared.playDeletionFeedback()
            if let idx = viewModel.memos.firstIndex(where: { $0.id == memo.id }) {
                viewModel.deleteMemo(at: idx)
            }
        } label: {
            Label(MemoListConstants.SwipeActions.deleteTitle,
                  systemImage: MemoListConstants.SwipeActions.deleteIcon)
        }
        .accessibilityLabel("Delete \(memo.displayName)")
        .accessibilityHint(MemoListConstants.AccessibilityLabels.deleteHint)
    }
}


// MARK: - Configuration Constants

/// **MemoListConstants**
/// Centralized configuration for all memo list styling and behavior
/// 
/// **Usage:**
/// Modify these constants to adjust the entire memo list appearance
/// All values are documented for easy customization
private enum MemoListConstants {
    
    /// **List Styling Configuration**
    /// Controls overall list appearance and behavior
    enum ListStyling {
        /// List style - affects visual presentation and grouping
        /// Options: .insetGrouped (modern cards), .grouped (traditional), .plain (minimal)
        static let preferredStyle = InsetGroupedListStyle()
        
        /// Background color for the list container
        /// Uses semantic color for automatic light/dark adaptation
        static let backgroundColor: Color = .semantic(.bgSecondary)
    }
    
    /// **Row Configuration**
    /// Fine-tune individual row appearance
    /// **FIXED Row Configuration** 
    /// Proper insets that work with insetGrouped style
    static let rowInsets = EdgeInsets(
        top: 0,
        leading: 16,    // CHANGED: Restore proper leading inset
        bottom: 0,
        trailing: 16    // CHANGED: Restore proper trailing inset
    )
    
    /// Current list style setting
    /// List style - keep insetGrouped but ensure proper setup
    static let listStyle = InsetGroupedListStyle()
    
    /// **Swipe Actions Configuration**
    /// Text and icons for swipe gesture actions
    enum SwipeActions {
        // Transcription actions
        static let transcribeTitle = "Transcribe"
        static let transcribeIcon = "text.quote"
        
        static let retryTitle = "Retry"
        static let retryIcon = "arrow.clockwise"
        
        // Destructive actions
        static let deleteTitle = "Delete"
        static let deleteIcon = "trash"
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

#Preview { MemosView(popToRoot: nil) }
