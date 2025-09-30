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
    /// Show a subtle internal top hairline to separate stacked cards.
    /// Provided by the list container depending on item position.
    var showTopHairline: Bool = false
    /// For stacked group corner treatment
    var isFirstInSection: Bool = false
    var isLastInSection: Bool = false
    @State private var editedTitle: String = ""
    @FocusState private var isEditingFocused: Bool

    // Recomputed each render; drives color/animation
    private var transcriptionState: TranscriptionState {
        viewModel.getTranscriptionState(for: memo)
    }

    // MARK: - Design Constants

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

    /// Layout constants (retain only those in use)
    private enum Layout {
        /// Reserved gutter width when in edit mode for selection control
        static let editGutterWidth: CGFloat = 44
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
            SonoraMemocCard(
                memo: memo,
                viewModel: viewModel,
                showTopHairline: showTopHairline,
                isFirstInSection: isFirstInSection,
                isLastInSection: isLastInSection
            )
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
        // Clean rename flow via a small sheet (serif styling, no list layout shifts)
        .sheet(isPresented: Binding<Bool>(
            get: { viewModel.isEditing(memo: memo) },
            set: { newValue in if !newValue { viewModel.stopEditing() } }
        )) {
            NavigationStack {
                VStack(spacing: 16) {
                    TextField("Memo Title", text: $editedTitle)
                        .font(SonoraDesignSystem.Typography.headingSmall)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .focused($isEditingFocused)
                        .onAppear {
                            editedTitle = memo.displayName
                            DispatchQueue.main.async { isEditingFocused = true }
                        }
                    Spacer(minLength: 0)
                }
                .padding()
                .navigationTitle("Rename Memo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { viewModel.stopEditing() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { submitRename() }
                            .disabled(editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editedTitle.trimmingCharacters(in: .whitespacesAndNewlines) == memo.displayName)
                    }
                }
            }
            .presentationDetents([.fraction(0.25), .medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Content Views
    // All content now handled by SonoraMemocCard for brand consistency

    // MARK: - Helper Properties

    /// Formatted relative date string using system formatter
    /// Example outputs: "5 minutes ago", "2 hours ago", "yesterday"
    private var formattedRelativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated // More compact display
        let now = Date()
        let endDate = min(memo.recordingEndDate, now)
        return formatter.localizedString(for: endDate, relativeTo: now)
    }

    /// Comprehensive accessibility description for VoiceOver users
    /// Provides all essential information in logical reading order
    private var accessibilityDescription: String {
        let components = [
            memo.displayName,
            "Duration: \(memo.durationString)",
            "Recorded \(formattedRelativeDate)"
        ]
        return components.joined(separator: ", ")
    }

    // MARK: - Constants

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
