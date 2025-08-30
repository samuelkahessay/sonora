import SwiftUI

/// Reusable error state view component that displays SonoraError with recovery options
struct ErrorStateView: View {
    let error: SonoraError
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    init(
        error: SonoraError,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Error icon with severity color
            Image(systemName: error.severity.iconName)
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(severityColor)
            
            // Error content
            VStack(spacing: Spacing.md) {
                // Error title
                Text(error.category.displayName + " Error")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
                
                // Error description
                if let description = error.errorDescription {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.semantic(.textPrimary))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                }
                
                // Recovery suggestion
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.callout)
                        .foregroundColor(.semantic(.textSecondary))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.top, Spacing.xs)
                }
            }
            .padding(.horizontal, Spacing.lg)
            
            // Action buttons
            VStack(spacing: Spacing.sm) {
                // Retry button (if error is retryable)
                if error.isRetryable, let onRetry = onRetry {
                    Button(action: onRetry) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "arrow.clockwise")
                                .font(.body.weight(.medium))
                            Text("Try Again")
                                .font(.body.weight(.medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.semantic(.brandPrimary))
                }
                
                // Dismiss button
                if let onDismiss = onDismiss {
                    Button("Dismiss", action: onDismiss)
                        .buttonStyle(.bordered)
                        .foregroundColor(.semantic(.textSecondary))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }
    
    private var severityColor: Color {
        switch error.severity {
        case .info:
            return .semantic(.info)
        case .warning:
            return .semantic(.warning)
        case .error:
            return .semantic(.error)
        case .critical:
            return .semantic(.error) // Use error color for critical as well
        }
    }
}

// MARK: - Convenience Views

extension ErrorStateView {
    /// Error state for network unavailable
    static func networkUnavailable(onRetry: @escaping () -> Void) -> ErrorStateView {
        ErrorStateView(
            error: .networkUnavailable,
            onRetry: onRetry
        )
    }
    
    /// Error state for transcription failures
    static func transcriptionFailed(_ reason: String, onRetry: @escaping () -> Void) -> ErrorStateView {
        ErrorStateView(
            error: .transcriptionFailed(reason),
            onRetry: onRetry
        )
    }
    
    /// Error state for storage issues
    static func storageError(_ error: SonoraError, onDismiss: @escaping () -> Void) -> ErrorStateView {
        ErrorStateView(
            error: error,
            onDismiss: onDismiss
        )
    }
}

// MARK: - Compact Error Banner

/// Compact error banner for inline display
struct ErrorBannerView: View {
    let error: SonoraError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    init(
        error: SonoraError,
        onRetry: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Error icon
            Image(systemName: error.severity.iconName)
                .font(.title3.weight(.medium))
                .foregroundColor(iconColor)
            
            // Error message
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let description = error.errorDescription {
                    Text(description)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.semantic(.textPrimary))
                        .lineLimit(2)
                }
                
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: Spacing.xs) {
                // Retry button
                if error.isRetryable, let onRetry = onRetry {
                    Button("Retry", action: onRetry)
                        .font(.caption.weight(.medium))
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
                
                // Dismiss button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .foregroundColor(.semantic(.textSecondary))
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.horizontal, Spacing.md)
    }
    
    private var iconColor: Color {
        switch error.severity {
        case .info: return .semantic(.info)
        case .warning: return .semantic(.warning)
        case .error, .critical: return .semantic(.error)
        }
    }
    
    private var backgroundColor: Color {
        switch error.severity {
        case .info: return .semantic(.info).opacity(0.1)
        case .warning: return .semantic(.warning).opacity(0.1)
        case .error, .critical: return .semantic(.error).opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        switch error.severity {
        case .info: return .semantic(.info).opacity(0.3)
        case .warning: return .semantic(.warning).opacity(0.3)
        case .error, .critical: return .semantic(.error).opacity(0.3)
        }
    }
}

// MARK: - Previews

#Preview("Network Error") {
    ErrorStateView.networkUnavailable {
        print("Retry network connection")
    }
    .background(Color.semantic(.bgPrimary))
}

#Preview("Transcription Error") {
    ErrorStateView.transcriptionFailed("Service temporarily unavailable") {
        print("Retry transcription")
    }
    .background(Color.semantic(.bgPrimary))
}

#Preview("Storage Error") {
    ErrorStateView.storageError(.storageSpaceInsufficient) {
        print("Dismiss storage error")
    }
    .background(Color.semantic(.bgPrimary))
}

#Preview("Error Banner") {
    VStack(spacing: Spacing.lg) {
        ErrorBannerView(
            error: .networkTimeout,
            onRetry: { print("Retry network") },
            onDismiss: { print("Dismiss banner") }
        )
        
        ErrorBannerView(
            error: .audioPermissionDenied,
            onDismiss: { print("Dismiss permission error") }
        )
    }
    .padding()
    .background(Color.semantic(.bgPrimary))
}