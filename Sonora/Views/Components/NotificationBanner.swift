import SwiftUI

/// Unified notification banner component for inline dismissible notifications
struct NotificationBanner: View {
    let type: BannerType
    let message: String
    let onPrimaryAction: (() -> Void)?
    let primaryTitle: String?
    let onDismiss: () -> Void
    let compact: Bool

    /// Banner types with consistent styling
    enum BannerType {
        case info
        case warning
        case error
        case success
        case language

        var icon: String {
            switch self {
            case .info:
                return "info.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .error:
                return "xmark.circle.fill"
            case .success:
                return "checkmark.circle.fill"
            case .language:
                return "globe"
            }
        }

        var iconColor: Color {
            switch self {
            case .info:
                return .semantic(.info)
            case .warning:
                return .semantic(.warning)
            case .error:
                return .semantic(.error)
            case .success:
                return .semantic(.success)
            case .language:
                return .semantic(.warning) // Using warning color for language notices
            }
        }

        var backgroundColor: Color {
            iconColor.opacity(0.1)
        }

        var borderColor: Color {
            iconColor.opacity(0.3)
        }
    }

    init(
        type: BannerType,
        message: String,
        compact: Bool = false,
        onPrimaryAction: (() -> Void)? = nil,
        primaryTitle: String? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.type = type
        self.message = message
        self.compact = compact
        self.onPrimaryAction = onPrimaryAction
        self.primaryTitle = primaryTitle
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(spacing: compact ? Spacing.sm : Spacing.md) {
            // Icon
            Image(systemName: type.icon)
                .font(compact ? .caption.weight(.medium) : .title3.weight(.medium))
                .foregroundColor(type.iconColor)
                .accessibilityHidden(true)

            // Message content
            Text(message)
                .font(compact ? .caption : .subheadline)
                .foregroundColor(compact ? .semantic(.textSecondary) : .semantic(.textPrimary))
                .lineLimit(compact ? 2 : 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(message)
                .accessibilityAddTraits(.isStaticText)

            // Action buttons
            if !compact {
                HStack(spacing: Spacing.xs) {
                    // Primary action button (if provided)
                    if let primaryAction = onPrimaryAction {
                        Button(primaryTitle ?? "Retry", action: {
                            HapticManager.shared.playSelection()
                            primaryAction()
                        })
                        .font(.caption.weight(.medium))
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .accessibilityLabel("Retry")
                        .accessibilityHint("Double tap to retry the action")
                    }

                    // Dismiss button
                    Button(action: {
                        HapticManager.shared.playSelection()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .foregroundColor(.semantic(.textSecondary))
                    .accessibilityLabel("Dismiss")
                    .accessibilityHint("Double tap to dismiss this notification")
                }
            } else {
                // Compact dismiss button
                Button(action: {
                    HapticManager.shared.playSelection()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.medium))
                }
                .foregroundColor(.semantic(.textSecondary))
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(.horizontal, compact ? Spacing.md : Spacing.md)
        .padding(.vertical, compact ? Spacing.sm : Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: compact ? 8 : 12)
                .fill(type.backgroundColor)
                .stroke(type.borderColor, lineWidth: compact ? 0.5 : 1)
        )
        .padding(.horizontal, compact ? 0 : Spacing.md)
        .accessibilityElement(children: compact ? .combine : .contain)
        .accessibilityLabel(compact ? message : "")
    }
}

// MARK: - Convenience Initializers

extension NotificationBanner {
    /// Language detection banner
    static func languageDetection(
        message: String,
        compact: Bool = false,
        onDismiss: @escaping () -> Void
    ) -> NotificationBanner {
        NotificationBanner(
            type: .language,
            message: message,
            compact: compact,
            onDismiss: onDismiss
        )
    }

    /// Error banner with retry option
    static func error(
        _ error: SonoraError,
        compact: Bool = false,
        onRetry: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) -> NotificationBanner {
        NotificationBanner(
            type: .error,
            message: error.errorDescription ?? "An error occurred",
            compact: compact,
            onPrimaryAction: error.isRetryable ? onRetry : nil,
            primaryTitle: error.isRetryable ? "Retry" : nil,
            onDismiss: onDismiss
        )
    }

    /// Network error banner
    static func networkError(
        compact: Bool = false,
        onRetry: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> NotificationBanner {
        NotificationBanner(
            type: .warning,
            message: "Check your internet connection and try again",
            compact: compact,
            onPrimaryAction: onRetry,
            primaryTitle: "Retry",
            onDismiss: onDismiss
        )
    }

    /// Success banner
    static func success(
        message: String,
        compact: Bool = false,
        onDismiss: @escaping () -> Void
    ) -> NotificationBanner {
        NotificationBanner(
            type: .success,
            message: message,
            compact: compact,
            onDismiss: onDismiss
        )
    }

    /// Info banner
    static func info(
        message: String,
        compact: Bool = false,
        onDismiss: @escaping () -> Void
    ) -> NotificationBanner {
        NotificationBanner(
            type: .info,
            message: message,
            compact: compact,
            onDismiss: onDismiss
        )
    }
}

// MARK: - Component Consolidation Complete
// CompactNotificationBanner has been successfully merged into NotificationBanner

// MARK: - Previews

#Preview("Banner Types") {
    VStack(spacing: Spacing.lg) {
        NotificationBanner.languageDetection(
            message: "This memo appears to be in Spanish. Transcription quality may be affected."
        ) {
            print("Language banner dismissed")
        }

        NotificationBanner.error(
            .networkTimeout,
            onRetry: { print("Retry network") },
            onDismiss: { print("Dismiss error") }
        )

        NotificationBanner.success(
            message: "Your memo has been successfully transcribed!"
        ) {
            print("Success dismissed")
        }

        NotificationBanner.info(
            message: "This is an informational message with some helpful details."
        ) {
            print("Info dismissed")
        }
    }
    .padding()
    .background(Color.semantic(.bgPrimary))
}

#Preview("Compact Banners") {
    VStack(spacing: Spacing.md) {
        NotificationBanner(
            type: .warning,
            message: "Low battery may affect recording quality",
            compact: true
        ) {
            print("Compact warning dismissed")
        }

        NotificationBanner(
            type: .success,
            message: "Saved to Files",
            compact: true
        ) {
            print("Compact success dismissed")
        }
    }
    .padding()
    .background(Color.semantic(.bgPrimary))
}
