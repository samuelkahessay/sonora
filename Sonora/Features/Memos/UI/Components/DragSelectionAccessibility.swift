//
//  DragSelectionAccessibility.swift
//  Sonora
//
//  Accessibility support for drag-to-select functionality
//  Provides VoiceOver, reduced motion, and assistive technology support
//

import SwiftUI
import UIKit

/// Accessibility coordinator for drag-to-select functionality
/// Handles VoiceOver announcements, reduced motion support, and alternative selection methods
@MainActor
struct DragSelectionAccessibility {
    
    // MARK: - Accessibility State Tracking
    
    /// Check if VoiceOver is currently running
    static var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }
    
    /// Check if reduced motion is enabled
    static var isReducedMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    
    /// Check if the user prefers alternative selection methods
    static var prefersAlternativeSelection: Bool {
        isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
    }
    
    // MARK: - VoiceOver Announcements
    
    /// Announce the start of drag selection
    static func announceSelectionStart() {
        guard isVoiceOverRunning else { return }
        
        let announcement = NSAttributedString(
            string: "Drag selection started. Move your finger to select multiple memos.",
            attributes: [.accessibilitySpeechQueueAnnouncement: true]
        )
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    /// Announce selection progress (throttled to avoid overwhelming)
    static func announceSelectionProgress(count: Int, total: Int) {
        guard isVoiceOverRunning && count % 5 == 0 else { return }
        
        let announcement = NSAttributedString(
            string: "\(count) of \(total) memos selected",
            attributes: [.accessibilitySpeechQueueAnnouncement: true]
        )
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    /// Announce completion of drag selection
    static func announceSelectionComplete(count: Int) {
        guard isVoiceOverRunning else { return }
        
        let message = count == 1 ? "1 memo selected" : "\(count) memos selected"
        let announcement = NSAttributedString(
            string: "Selection complete. \(message)",
            attributes: [.accessibilitySpeechQueueAnnouncement: true]
        )
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    /// Announce selection cancellation
    static func announceSelectionCancelled() {
        guard isVoiceOverRunning else { return }
        
        let announcement = NSAttributedString(
            string: "Drag selection cancelled",
            attributes: [.accessibilitySpeechQueueAnnouncement: true]
        )
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    // MARK: - Alternative Selection Methods
    
    // Intentionally removed array-based accessibility actions to avoid ViewBuilder issues.
    
    /// Select a range of memos (accessibility helper)
    @MainActor
    static func selectRange(from startIndex: Int, to endIndex: Int, viewModel: MemoListViewModel) {
        let range = min(startIndex, endIndex)...max(startIndex, endIndex)
        let memosInRange = Array(viewModel.memos[range])
        
        withAnimation(.easeOut(duration: isReducedMotionEnabled ? 0.0 : 0.2)) {
            for memo in memosInRange {
                viewModel.selectMemo(memo)
            }
        }
        
        HapticManager.shared.playSelection()
        announceSelectionComplete(count: range.count)
    }
}

// MARK: - Accessibility View Modifiers

extension View {
    
    /// Add accessibility support for drag selection
    @MainActor
    func dragSelectionAccessibility(
        memo: Memo,
        viewModel: MemoListViewModel,
        isSelected: Bool
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(for: memo, isSelected: isSelected))
            .accessibilityHint(accessibilityHint(for: viewModel.isEditMode, isSelected: isSelected))
            .accessibilityValue(accessibilityValue(for: memo))
            // Keep simple toggle action; remove range/drag affordances
            .accessibilityAction(named: Text(isSelected ? "Deselect" : "Select")) {
                if viewModel.isEditMode { viewModel.toggleMemoSelection(memo) }
            }
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
    
    /// Generate accessibility label for memo row
    private func accessibilityLabel(for memo: Memo, isSelected: Bool) -> String {
        var components = [memo.displayName]
        
        if isSelected {
            components.append("Selected")
        }
        
        components.append("Duration: \(memo.durationString)")

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let now = Date()
        let endDate = min(memo.recordingEndDate, now)
        let relativeDate = formatter.localizedString(for: endDate, relativeTo: now)
        components.append("Recorded \(relativeDate)")
        
        return components.joined(separator: ", ")
    }
    
    /// Generate accessibility hint
    private func accessibilityHint(for isEditMode: Bool, isSelected: Bool) -> String {
        if isEditMode {
            return isSelected ? "Double tap to deselect" : "Double tap to select"
        } else {
            return "Double tap to view memo details"
        }
    }
    
    /// Generate accessibility value
    private func accessibilityValue(for memo: Memo) -> String {
        // Could include transcription status or other dynamic information
        return ""
    }
}

// MARK: - Reduced Motion Support

extension View {
    
    /// Apply appropriate animation based on reduced motion preference
    @MainActor
    func adaptiveAnimation<V: Equatable>(
        _ animation: Animation?,
        value: V
    ) -> some View {
        if DragSelectionAccessibility.isReducedMotionEnabled {
            return self.animation(.none, value: value)
        } else {
            return self.animation(animation, value: value)
        }
    }
    
    /// Apply selection animation with reduced motion support
    @MainActor
    func selectionAnimation<V: Equatable>(value: V) -> some View {
        adaptiveAnimation(
            DragSelectionAccessibility.isReducedMotionEnabled
                ? .none
                : .easeOut(duration: 0.2),
            value: value
        )
    }
}

// MARK: - Alternative Selection UI

struct AlternativeSelectionControls: View {
    @ObservedObject var viewModel: MemoListViewModel
    
    var body: some View {
        if DragSelectionAccessibility.prefersAlternativeSelection && viewModel.isEditMode {
            VStack(spacing: 8) {
                HStack {
                    Button("Select All") {
                        viewModel.selectAll()
                        DragSelectionAccessibility.announceSelectionComplete(count: viewModel.memos.count)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Deselect All") {
                        viewModel.deselectAll()
                        DragSelectionAccessibility.announceSelectionComplete(count: 0)
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                if viewModel.hasSelection {
                    Text("\(viewModel.selectedCount) memos selected")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
            }
            .padding(.top, 8)
            .background(Color.semantic(.fillSecondary))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Accessibility Action View (Helper)

// Removed custom AccessibilityActionView in favor of direct AccessibilityAction calls

#if DEBUG
// MARK: - Preview Helpers for Accessibility Testing

struct DragSelectionAccessibilityPreview: View {
    @StateObject private var viewModel = DIContainer.shared.viewModelFactory().createMemoListViewModel()
    
    var body: some View {
        VStack {
            AlternativeSelectionControls(viewModel: viewModel)
            
            List {
                ForEach(viewModel.memos) { memo in
                    MemoRowView(memo: memo, viewModel: viewModel)
                        .dragSelectionAccessibility(
                            memo: memo,
                            viewModel: viewModel,
                            isSelected: viewModel.isMemoSelected(memo)
                        )
                }
            }
        }
        .onAppear {
            if !viewModel.isEditMode {
                viewModel.toggleEditMode()
            }
        }
    }
}

#Preview {
    DragSelectionAccessibilityPreview()
}
#endif
