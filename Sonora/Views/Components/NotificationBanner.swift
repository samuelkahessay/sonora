import SwiftUI

/// Unified notification banner component for inline dismissible notifications
struct NotificationBanner: View {
    let type: BannerType
    let message: String
    let onPrimaryAction: (() -> Void)?
    let onDismiss: () -> Void
    
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
        onPrimaryAction: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.type = type
        self.message = message
        self.onPrimaryAction = onPrimaryAction
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            Image(systemName: type.icon)
                .font(.title3.weight(.medium))
                .foregroundColor(type.iconColor)
                .accessibilityHidden(true)
            
            // Message content
            Text(message)
                .font(.subheadline)
                .foregroundColor(.semantic(.textPrimary))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(message)
                .accessibilityAddTraits(.isStaticText)
            
            // Action buttons
            HStack(spacing: Spacing.xs) {
                // Primary action button (if provided)
                if let primaryAction = onPrimaryAction {
                    Button("Retry", action: {
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
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(type.backgroundColor)
                .stroke(type.borderColor, lineWidth: 1)
        )
        .padding(.horizontal, Spacing.md)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Convenience Initializers

extension NotificationBanner {
    /// Language detection banner
    static func languageDetection(
        message: String,
        onDismiss: @escaping () -> Void
    ) -> NotificationBanner {
        NotificationBanner(
            type: .language,
            message: message,
            onDismiss: onDismiss
        )
    }
    
    /// Error banner with retry option
    static func error(
        _ error: SonoraError,
        onRetry: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) -> NotificationBanner {
        NotificationBanner(
            type: .error,
            message: error.errorDescription ?? "An error occurred",
            onPrimaryAction: error.isRetryable ? onRetry : nil,
            onDismiss: onDismiss
        )
    }
    
    /// Network error banner
    static func networkError(
        onRetry: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> NotificationBanner {
        NotificationBanner(
            type: .warning,
            message: "Check your internet connection and try again",
            onPrimaryAction: onRetry,
            onDismiss: onDismiss
        )
    }
    
    /// Success banner
    static func success(
        message: String,
        onDismiss: @escaping () -> Void
    ) -> NotificationBanner {
        NotificationBanner(
            type: .success,
            message: message,
            onDismiss: onDismiss
        )
    }
    
    /// Info banner
    static func info(
        message: String,
        onDismiss: @escaping () -> Void
    ) -> NotificationBanner {
        NotificationBanner(
            type: .info,
            message: message,
            onDismiss: onDismiss
        )
    }
}

// MARK: - Compact Banner Variant

/// Compact banner for minimal space usage
struct CompactNotificationBanner: View {
    let type: NotificationBanner.BannerType
    let message: String
    let onDismiss: () -> Void
    
    init(
        type: NotificationBanner.BannerType,
        message: String,
        onDismiss: @escaping () -> Void
    ) {
        self.type = type
        self.message = message
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Icon
            Image(systemName: type.icon)
                .font(.caption.weight(.medium))
                .foregroundColor(type.iconColor)
                .accessibilityHidden(true)
            
            // Message
            Text(message)
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Dismiss button
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
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(type.backgroundColor)
                .stroke(type.borderColor, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

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
        CompactNotificationBanner(
            type: .warning,
            message: "Low battery may affect recording quality"
        ) {
            print("Compact warning dismissed")
        }
        
        CompactNotificationBanner(
            type: .success,
            message: "Saved to Files"
        ) {
            print("Compact success dismissed")
        }
    }
    .padding()
    .background(Color.semantic(.bgPrimary))
}