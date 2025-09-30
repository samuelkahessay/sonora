import SwiftUI

/// Unified state view component that handles empty, error, and offline states
struct UnifiedStateView: View {
    let state: ViewState
    let onPrimaryAction: (() -> Void)?
    let onSecondaryAction: (() -> Void)?

    /// View state types that can be displayed
    enum ViewState {
        case empty(icon: String, title: String, subtitle: String, actionTitle: String? = nil)
        case error(SonoraError, retryable: Bool = true)
        case offline(retryable: Bool = true)
        case loading(message: String = "Loading...")

        var icon: String {
            switch self {
            case let .empty(icon, _, _, _):
                return icon
            case let .error(error, _):
                return error.severity.iconName
            case .offline:
                return "wifi.slash"
            case .loading:
                return ""
            }
        }

        var title: String {
            switch self {
            case let .empty(_, title, _, _):
                return title
            case let .error(error, _):
                return error.category.displayName + " Error"
            case .offline:
                return "No Internet Connection"
            case .loading(let message):
                return message
            }
        }

        var subtitle: String? {
            switch self {
            case let .empty(_, _, subtitle, _):
                return subtitle
            case let .error(error, _):
                return error.errorDescription
            case .offline:
                return "Check your internet connection and try again"
            case .loading:
                return nil
            }
        }

        var primaryActionTitle: String? {
            switch self {
            case let .empty(_, _, _, actionTitle):
                return actionTitle
            case let .error(_, retryable):
                return retryable ? "Try Again" : nil
            case let .offline(retryable):
                return retryable ? "Retry" : nil
            case .loading:
                return nil
            }
        }

        var secondaryActionTitle: String? {
            switch self {
            case .empty, .loading:
                return nil
            case .error, .offline:
                return "Dismiss"
            }
        }

        var iconColor: Color {
            switch self {
            case .empty:
                return .semantic(.textSecondary)
            case let .error(error, _):
                return severityColor(for: error.severity)
            case .offline:
                return .semantic(.warning)
            case .loading:
                return .semantic(.brandPrimary)
            }
        }

        private func severityColor(for severity: SonoraErrorSeverity) -> Color {
            switch severity {
            case .info:
                return .semantic(.info)
            case .warning:
                return .semantic(.warning)
            case .error, .critical:
                return .semantic(.error)
            }
        }
    }

    init(
        state: ViewState,
        onPrimaryAction: (() -> Void)? = nil,
        onSecondaryAction: (() -> Void)? = nil
    ) {
        self.state = state
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            if case .loading = state {
                loadingView
            } else {
                contentView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            LoadingIndicator(size: .large)

            Text(state.title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.semantic(.textPrimary))
                .accessibilityLabel(state.title)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        // Icon
        Image(systemName: state.icon)
            .font(.system(size: 48, weight: .medium))
            .foregroundColor(state.iconColor)
            .accessibilityHidden(true)

        // Text content
        VStack(spacing: Spacing.sm) {
            Text(state.title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.semantic(.textPrimary))
                .accessibilityAddTraits(.isHeader)

            if let subtitle = state.subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.semantic(.textSecondary))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
        }
        .padding(.horizontal, Spacing.lg)

        // Action buttons
        if state.primaryActionTitle != nil || state.secondaryActionTitle != nil {
            VStack(spacing: Spacing.sm) {
                // Primary action button
                if let primaryTitle = state.primaryActionTitle,
                   let primaryAction = onPrimaryAction {
                    Button(action: {
                        HapticManager.shared.playSelection()
                        primaryAction()
                    }) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "arrow.clockwise")
                                .font(.body.weight(.medium))
                            Text(primaryTitle)
                                .font(.body.weight(.medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.semantic(.brandPrimary))
                    .accessibilityLabel(primaryTitle)
                    .accessibilityHint("Double tap to \(primaryTitle.lowercased())")
                }

                // Secondary action button
                if let secondaryTitle = state.secondaryActionTitle,
                   let secondaryAction = onSecondaryAction {
                    Button(secondaryTitle) {
                        HapticManager.shared.playSelection()
                        secondaryAction()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.semantic(.textSecondary))
                    .accessibilityLabel(secondaryTitle)
                    .accessibilityHint("Double tap to \(secondaryTitle.lowercased())")
                }
            }
        }
    }
}

// MARK: - Convenience Initializers

extension UnifiedStateView {
    /// Empty state for memos list
    static func noMemos() -> UnifiedStateView {
        UnifiedStateView(
            state: .empty(
                icon: "mic.slash",
                title: "No Memos Yet",
                subtitle: "Start recording to see your audio memos here"
            )
        )
    }

    /// Empty state for transcription
    static func noTranscription() -> UnifiedStateView {
        UnifiedStateView(
            state: .empty(
                icon: "text.quote",
                title: "No Transcription",
                subtitle: "Tap 'Transcribe' to convert your audio to text using AI"
            )
        )
    }

    /// Empty state for analysis results
    static func noAnalysis() -> UnifiedStateView {
        UnifiedStateView(
            state: .empty(
                icon: "magnifyingglass",
                title: "No Analysis Available",
                subtitle: "Transcribe your memo first to unlock AI-powered insights and analysis"
            )
        )
    }

    /// Empty state for search results
    static func noSearchResults(query: String) -> UnifiedStateView {
        UnifiedStateView(
            state: .empty(
                icon: "magnifyingglass",
                title: "No Results Found",
                subtitle: "No memos match '\(query)'. Try adjusting your search terms."
            )
        )
    }

    /// Error state with retry
    static func error(
        _ error: SonoraError,
        onRetry: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil
    ) -> UnifiedStateView {
        UnifiedStateView(
            state: .error(error, retryable: error.isRetryable),
            onPrimaryAction: error.isRetryable ? onRetry : nil,
            onSecondaryAction: onDismiss
        )
    }

    /// Offline state with retry
    static func offline(onRetry: @escaping () -> Void) -> UnifiedStateView {
        UnifiedStateView(
            state: .offline(retryable: true),
            onPrimaryAction: onRetry
        )
    }

    /// Loading state
    static func loading(message: String = "Loading...") -> UnifiedStateView {
        UnifiedStateView(
            state: .loading(message: message)
        )
    }
}

// MARK: - LoadingIndicator Component

/// Standardized loading indicator with consistent sizing
struct LoadingIndicator: View {
    let size: Size

    enum Size {
        case small, regular, large

        var scale: CGFloat {
            switch self {
            case .small: return 0.8
            case .regular: return 1.0
            case .large: return 1.2
            }
        }
    }

    init(size: Size = .regular) {
        self.size = size
    }

    var body: some View {
        ProgressView()
            .scaleEffect(size.scale)
            .tint(.semantic(.brandPrimary))
            .accessibilityLabel("Loading")
    }
}

// MARK: - Previews

#Preview("No Memos") {
    UnifiedStateView.noMemos()
        .background(Color.semantic(.bgPrimary))
}

#Preview("Error State") {
    UnifiedStateView.error(.networkUnavailable, onRetry: {
        print("Retry network")
    }, onDismiss: {
        print("Dismiss error")
    })
    .background(Color.semantic(.bgPrimary))
}

#Preview("Offline State") {
    UnifiedStateView.offline {
        print("Retry connection")
    }
    .background(Color.semantic(.bgPrimary))
}

#Preview("Loading State") {
    UnifiedStateView.loading(message: "Transcribing audio...")
        .background(Color.semantic(.bgPrimary))
}

#Preview("Loading Indicators") {
    VStack(spacing: Spacing.lg) {
        LoadingIndicator(size: .small)
        LoadingIndicator(size: .regular)
        LoadingIndicator(size: .large)
    }
    .padding()
    .background(Color.semantic(.bgPrimary))
}
