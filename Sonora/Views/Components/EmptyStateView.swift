import SwiftUI

/// Reusable empty state view component
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: EmptyStateAction?
    
    /// Action configuration for empty state
    struct EmptyStateAction {
        let title: String
        let systemImage: String?
        let handler: () -> Void
        
        init(title: String, systemImage: String? = nil, handler: @escaping () -> Void) {
            self.title = title
            self.systemImage = systemImage
            self.handler = handler
        }
    }
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        action: EmptyStateAction? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(.semantic(.textSecondary))
            
            // Text content
            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
                
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.semantic(.textSecondary))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.horizontal, Spacing.lg)
            
            // Optional action button
            if let action = action {
                Button(action: action.handler) {
                    HStack(spacing: Spacing.sm) {
                        if let systemImage = action.systemImage {
                            Image(systemName: systemImage)
                                .font(.body.weight(.medium))
                        }
                        Text(action.title)
                            .font(.body.weight(.medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.semantic(.brandPrimary))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }
}

// MARK: - Convenience Initializers

extension EmptyStateView {
    /// Empty state for memos list
    static func noMemos(onStartRecording: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon: "mic.slash",
            title: "No Memos Yet",
            subtitle: "Start recording to see your audio memos here",
            action: onStartRecording.map { handler in
                EmptyStateAction(
                    title: "Start Recording",
                    systemImage: "mic",
                    handler: handler
                )
            }
        )
    }
    
    /// Empty state for transcription
    static func noTranscription() -> EmptyStateView {
        EmptyStateView(
            icon: "text.quote",
            title: "No Transcription",
            subtitle: "Tap 'Transcribe' to convert your audio to text using AI"
        )
    }
    
    /// Empty state for analysis results
    static func noAnalysis() -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Analysis Available",
            subtitle: "Transcribe your memo first to unlock AI-powered insights and analysis"
        )
    }
    
    /// Empty state for search results
    static func noSearchResults(query: String) -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results Found",
            subtitle: "No memos match '\(query)'. Try adjusting your search terms."
        )
    }
}

// MARK: - Previews

#Preview("No Memos") {
    EmptyStateView.noMemos {
        print("Start recording tapped")
    }
    .background(Color.semantic(.bgPrimary))
}

#Preview("No Transcription") {
    EmptyStateView.noTranscription()
        .background(Color.semantic(.bgPrimary))
}

#Preview("No Analysis") {
    EmptyStateView.noAnalysis()
        .background(Color.semantic(.bgPrimary))
}

#Preview("Search Results") {
    EmptyStateView.noSearchResults(query: "meeting")
        .background(Color.semantic(.bgPrimary))
}