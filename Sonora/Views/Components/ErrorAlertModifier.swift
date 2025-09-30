import SwiftUI

// MARK: - Error Alert Modifier

/// View modifier for displaying SonoraError as native iOS alerts
struct ErrorAlertModifier: ViewModifier {
    @Binding var error: SonoraError?
    let onRetry: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .alert(
                error?.category.displayName ?? "Error",
                isPresented: .constant(error != nil),
                presenting: error,
                actions: { presentedError in
                    // Primary action button
                    if presentedError.isRetryable, let onRetry = onRetry {
                        Button("Try Again") {
                            onRetry()
                            error = nil
                        }
                    }

                    // Settings button for permission errors
                    if needsSettingsButton(for: presentedError) {
                        Button("Settings") {
                            openSettings()
                            error = nil
                        }
                    }

                    // Dismiss button
                    Button(presentedError.isRetryable ? "Cancel" : "OK", role: .cancel) {
                        error = nil
                    }
                },
                message: { presentedError in
                    VStack(alignment: .leading, spacing: 8) {
                        if let description = presentedError.errorDescription {
                            Text(description)
                        }

                        if let suggestion = presentedError.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                        }
                    }
                }
            )
    }

    private func needsSettingsButton(for error: SonoraError) -> Bool {
        switch error {
        case .audioPermissionDenied, .storagePermissionDenied:
            return true
        default:
            return false
        }
    }

    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
            }
        }
    }
}

// MARK: - Error Banner Modifier

/// View modifier for displaying errors as dismissible banners
struct ErrorBannerModifier: ViewModifier {
    @Binding var error: SonoraError?
    let onRetry: (() -> Void)?

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if let error = error {
                NotificationBanner.error(
                    error,
                    onRetry: onRetry,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.error = nil
                        }
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            content
        }
        .animation(.easeInOut(duration: 0.3), value: error != nil)
    }
}

// MARK: - Loading State Modifier

/// View modifier for displaying loading states with optional error handling
struct LoadingStateModifier: ViewModifier {
    let isLoading: Bool
    let loadingMessage: String
    @Binding var error: SonoraError?
    let onRetry: (() -> Void)?

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)

            if isLoading {
                LoadingStateView(message: loadingMessage)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}

// MARK: - Loading State View

/// Simple loading state view
struct LoadingStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: Spacing.lg) {
            LoadingIndicator(size: .large)
                .tint(.semantic(.brandPrimary))

            Text(message)
                .font(.body)
                .foregroundColor(.semantic(.textSecondary))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.semantic(.bgPrimary).opacity(0.9))
    }
}

// MARK: - View Extensions

extension View {
    /// Shows SonoraError as an alert dialog
    func errorAlert(
        _ error: Binding<SonoraError?>,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorAlertModifier(error: error, onRetry: onRetry))
    }

    /// Shows SonoraError as a dismissible banner
    func errorBanner(
        _ error: Binding<SonoraError?>,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorBannerModifier(error: error, onRetry: onRetry))
    }

    /// Shows loading state with optional error handling
    func loadingState(
        isLoading: Bool,
        message: String = "Loading...",
        error: Binding<SonoraError?> = .constant(nil),
        onRetry: (() -> Void)? = nil
    ) -> some View {
        modifier(LoadingStateModifier(
            isLoading: isLoading,
            loadingMessage: message,
            error: error,
            onRetry: onRetry
        ))
    }
}

// MARK: - ViewModel Integration Helpers

/// Protocol for ViewModels that handle errors
@MainActor
protocol ErrorHandling: ObservableObject {
    var error: SonoraError? { get set }
    var isLoading: Bool { get }

    func handleError(_ error: Error)
    func clearError()
    func retryLastOperation()
}

/// Default implementation for error handling
@MainActor
extension ErrorHandling {
    func handleError(_ error: Error) {
        self.error = ErrorMapping.mapError(error)
    }

    func clearError() {
        self.error = nil
    }

    func retryLastOperation() {
        // Default implementation - override in specific ViewModels
        clearError()
    }
}

// MARK: - Previews

#Preview("Error Alert") {
    struct PreviewView: View {
        @State private var error: SonoraError?

        var body: some View {
            VStack(spacing: Spacing.lg) {
                Button("Show Permission Error") {
                    error = .audioPermissionDenied
                }

                Button("Show Network Error") {
                    error = .networkTimeout
                }

                Button("Show Storage Error") {
                    error = .storageSpaceInsufficient
                }
            }
            .errorAlert($error) {
                print("Retry action")
            }
        }
    }

    return PreviewView()
}

#Preview("Error Banner") {
    struct PreviewView: View {
        @State private var error: SonoraError? = SonoraError.networkUnavailable

        var body: some View {
            List {
                ForEach(1...10, id: \.self) { index in
                    Text("Item \(index)")
                }
            }
            .errorBanner($error) {
                print("Retry network connection")
            }
        }
    }

    return PreviewView()
}

#Preview("Loading State") {
    struct PreviewView: View {
        @State private var isLoading = true
        @State private var error: SonoraError?

        var body: some View {
            List {
                ForEach(1...10, id: \.self) { index in
                    Text("Item \(index)")
                }
            }
            .loadingState(
                isLoading: isLoading,
                message: "Loading memos...",
                error: $error
            ) {
                error = nil
                isLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isLoading = false
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isLoading = false
                    error = .networkTimeout
                }
            }
        }
    }

    return PreviewView()
}
