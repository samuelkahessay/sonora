import SwiftUI

/// Standardized icon sizes for consistent UI across the app
enum IconSize: CGFloat, CaseIterable {
    /// Small icons for compact UI elements (16pt)
    case small = 16
    /// Standard icons for most UI elements (24pt) - Accessibility minimum
    case standard = 24
    /// Medium icons for section headers and important elements (28pt)
    case medium = 28
    /// Large icons for primary actions and state displays (32pt)
    case large = 32
    /// Extra large icons for main UI elements and hero states (48pt)
    case extraLarge = 48

    /// Font equivalent for SF Symbols
    var font: Font {
        .system(size: rawValue, weight: .medium)
    }
}

/// Unified status indicator component for consistent status display throughout the app
struct StatusIndicator: View {
    let status: Status
    let size: IconSize
    let showText: Bool

    /// Status types with consistent icons and colors
    enum Status {
        case success(String? = nil)
        case warning(String? = nil)
        case error(String? = nil)
        case info(String? = nil)
        case loading(String? = nil)
        case completed(String? = nil)
        case failed(String? = nil)
        case inProgress(String? = nil)

        var icon: String {
            switch self {
            case .success, .completed:
                return "checkmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .error, .failed:
                return "xmark.circle.fill"
            case .info:
                return "info.circle.fill"
            case .loading, .inProgress:
                return "clock.fill"
            }
        }

        var color: Color {
            switch self {
            case .success, .completed:
                return .semantic(.success)
            case .warning:
                return .semantic(.warning)
            case .error, .failed:
                return .semantic(.error)
            case .info:
                return .semantic(.info)
            case .loading, .inProgress:
                return .semantic(.brandPrimary)
            }
        }

        var text: String? {
            switch self {
            case .success(let text), .warning(let text), .error(let text),
                 .info(let text), .loading(let text), .completed(let text),
                 .failed(let text), .inProgress(let text):
                return text
            }
        }

        var defaultText: String {
            switch self {
            case .success:
                return "Success"
            case .warning:
                return "Warning"
            case .error:
                return "Error"
            case .info:
                return "Info"
            case .loading:
                return "Loading"
            case .completed:
                return "Completed"
            case .failed:
                return "Failed"
            case .inProgress:
                return "In Progress"
            }
        }
    }

    init(
        status: Status,
        size: IconSize = .medium,
        showText: Bool = false
    ) {
        self.status = status
        self.size = size
        self.showText = showText
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            switch status {
            case .loading, .inProgress:
                LoadingIndicator(size: loadingSize)
                    .tint(status.color)
            default:
                Image(systemName: status.icon)
                    .font(size.font)
                    .foregroundColor(status.color)
            }

            if showText {
                Text(status.text ?? status.defaultText)
                    .font(textFont)
                    .foregroundColor(status.color)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(accessibilityTraits)
    }

    // MARK: - Private Helpers

    private var loadingSize: LoadingIndicator.Size {
        switch size {
        case .small:
            return .small
        case .standard, .medium:
            return .regular
        case .large, .extraLarge:
            return .large
        }
    }

    private var textFont: Font {
        switch size {
        case .small:
            return .caption
        case .standard, .medium:
            return .subheadline
        case .large:
            return .headline
        case .extraLarge:
            return .title3
        }
    }

    private var accessibilityLabel: String {
        let statusText = status.text ?? status.defaultText
        switch status {
        case .loading, .inProgress:
            return "\(statusText) in progress"
        case .success, .completed:
            return "\(statusText) successful"
        case .warning:
            return "\(statusText) warning"
        case .error, .failed:
            return "\(statusText) error"
        case .info:
            return "\(statusText) information"
        }
    }

    private var accessibilityTraits: AccessibilityTraits {
        switch status {
        case .loading, .inProgress:
            return .updatesFrequently
        default:
            return []
        }
    }
}

// MARK: - Convenience Initializers

extension StatusIndicator {
    /// Success indicator
    static func success(
        _ text: String? = nil,
        size: IconSize = .medium,
        showText: Bool = false
    ) -> StatusIndicator {
        StatusIndicator(
            status: .success(text),
            size: size,
            showText: showText
        )
    }

    /// Warning indicator
    static func warning(
        _ text: String? = nil,
        size: IconSize = .medium,
        showText: Bool = false
    ) -> StatusIndicator {
        StatusIndicator(
            status: .warning(text),
            size: size,
            showText: showText
        )
    }

    /// Error indicator
    static func error(
        _ text: String? = nil,
        size: IconSize = .medium,
        showText: Bool = false
    ) -> StatusIndicator {
        StatusIndicator(
            status: .error(text),
            size: size,
            showText: showText
        )
    }

    /// Info indicator
    static func info(
        _ text: String? = nil,
        size: IconSize = .medium,
        showText: Bool = false
    ) -> StatusIndicator {
        StatusIndicator(
            status: .info(text),
            size: size,
            showText: showText
        )
    }

    /// Loading indicator
    static func loading(
        _ text: String? = nil,
        size: IconSize = .medium,
        showText: Bool = false
    ) -> StatusIndicator {
        StatusIndicator(
            status: .loading(text),
            size: size,
            showText: showText
        )
    }

    /// Completed indicator (alias for success)
    static func completed(
        _ text: String? = nil,
        size: IconSize = .medium,
        showText: Bool = false
    ) -> StatusIndicator {
        StatusIndicator(
            status: .completed(text),
            size: size,
            showText: showText
        )
    }

    /// Failed indicator (alias for error)
    static func failed(
        _ text: String? = nil,
        size: IconSize = .medium,
        showText: Bool = false
    ) -> StatusIndicator {
        StatusIndicator(
            status: .failed(text),
            size: size,
            showText: showText
        )
    }

    /// In progress indicator (alias for loading)
    static func inProgress(
        _ text: String? = nil,
        size: IconSize = .medium,
        showText: Bool = false
    ) -> StatusIndicator {
        StatusIndicator(
            status: .inProgress(text),
            size: size,
            showText: showText
        )
    }
}

// MARK: - Transcription State Support

extension StatusIndicator {
    /// Create status indicator from TranscriptionState
    static func transcription(
        state: TranscriptionState,
        size: IconSize = .medium,
        showText: Bool = false
    ) -> StatusIndicator {
        switch state {
        case .notStarted:
            return .info("Not started", size: size, showText: showText)
        case .inProgress:
            return .inProgress("Transcribing", size: size, showText: showText)
        case .completed:
            return .completed("Transcription completed", size: size, showText: showText)
        case .failed:
            return .failed("Transcription failed", size: size, showText: showText)
        }
    }
}

// MARK: - Previews

#Preview("Status Indicators") {
    VStack(spacing: Spacing.lg) {
        VStack(spacing: Spacing.sm) {
            Text("Icon Only")
                .font(.headline)

            HStack(spacing: Spacing.md) {
                StatusIndicator.success()
                StatusIndicator.warning()
                StatusIndicator.error()
                StatusIndicator.info()
                StatusIndicator.loading()
            }
        }

        VStack(spacing: Spacing.sm) {
            Text("With Text")
                .font(.headline)

            VStack(spacing: Spacing.sm) {
                StatusIndicator.success("Operation completed successfully", showText: true)
                StatusIndicator.warning("Please check your settings", showText: true)
                StatusIndicator.error("Failed to complete operation", showText: true)
                StatusIndicator.info("Additional information available", showText: true)
                StatusIndicator.loading("Processing your request", showText: true)
            }
        }

        VStack(spacing: Spacing.sm) {
            Text("Different Sizes")
                .font(.headline)

            HStack(spacing: Spacing.md) {
                StatusIndicator.success(size: .small)
                StatusIndicator.success(size: .standard)
                StatusIndicator.success(size: .medium)
                StatusIndicator.success(size: .large)
                StatusIndicator.success(size: .extraLarge)
            }
        }
    }
    .padding()
    .background(Color.semantic(.bgPrimary))
}

#Preview("Transcription Status") {
    VStack(spacing: Spacing.md) {
        StatusIndicator.transcription(state: .notStarted, showText: true)
        StatusIndicator.transcription(state: .inProgress, showText: true)
        StatusIndicator.transcription(state: .completed("Your memo has been transcribed"), showText: true)
        StatusIndicator.transcription(state: .failed("Transcription failed"), showText: true)
    }
    .padding()
    .background(Color.semantic(.bgPrimary))
}
