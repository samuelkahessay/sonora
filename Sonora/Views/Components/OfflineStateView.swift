import SwiftUI

/// Specialized view for network offline states
struct OfflineStateView: View {
    let onRetry: () -> Void
    let onDismiss: (() -> Void)?
    
    init(onRetry: @escaping () -> Void, onDismiss: (() -> Void)? = nil) {
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Offline icon with animation
            ZStack {
                Circle()
                    .fill(Color.semantic(.error).opacity(0.1))
                    .frame(width: 88, height: 88)
                
                Image(systemName: "wifi.slash")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.semantic(.error))
            }
            
            // Content
            VStack(spacing: Spacing.md) {
                Text("No Internet Connection")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
                
                Text("Connect to the internet to use transcription and analysis features. Your recordings are saved locally.")
                    .font(.body)
                    .foregroundColor(.semantic(.textSecondary))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            .padding(.horizontal, Spacing.lg)
            
            // Action buttons
            VStack(spacing: Spacing.sm) {
                Button(action: onRetry) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "arrow.clockwise")
                            .font(.body.weight(.medium))
                        Text("Check Connection")
                            .font(.body.weight(.medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.semantic(.brandPrimary))
                
                if let onDismiss = onDismiss {
                    Button("Continue Offline", action: onDismiss)
                        .buttonStyle(.bordered)
                        .foregroundColor(.semantic(.textSecondary))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }
}

// MARK: - Compact Offline Banner

/// Compact offline banner for persistent display
struct OfflineBannerView: View {
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "wifi.slash")
                .font(.title3.weight(.medium))
                .foregroundColor(.semantic(.error))
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("No Internet Connection")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.semantic(.textPrimary))
                
                Text("Transcription and analysis unavailable")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
            }
            
            Spacer()
            
            HStack(spacing: Spacing.xs) {
                Button("Retry", action: onRetry)
                    .font(.caption.weight(.medium))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                
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
                .fill(Color.semantic(.error).opacity(0.1))
                .stroke(Color.semantic(.error).opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Network Status Indicator

/// Small network status indicator for tab bar or toolbar
struct NetworkStatusIndicator: View {
    @State private var isAnimating = false
    let isOffline: Bool
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: isOffline ? "wifi.slash" : "wifi")
                .font(.caption.weight(.medium))
                .foregroundColor(isOffline ? .semantic(.error) : .semantic(.success))
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    isOffline ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .none,
                    value: isAnimating
                )
            
            if isOffline {
                Text("Offline")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.semantic(.error))
            }
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(isOffline ? Color.semantic(.error).opacity(0.1) : Color.semantic(.success).opacity(0.1))
        )
        .onAppear {
            if isOffline {
                isAnimating = true
            }
        }
        .onChange(of: isOffline) { _, newValue in
            isAnimating = newValue
        }
    }
}

// MARK: - Convenience Modifiers

extension View {
    /// Shows offline banner when network is unavailable
    func offlineBanner(
        isOffline: Bool,
        onRetry: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            if isOffline {
                OfflineBannerView(onRetry: onRetry, onDismiss: onDismiss)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            self
        }
        .animation(.easeInOut(duration: 0.3), value: isOffline)
    }
    
    /// Shows network status indicator
    func networkStatus(isOffline: Bool) -> some View {
        overlay(alignment: .topTrailing) {
            if isOffline {
                NetworkStatusIndicator(isOffline: true)
                    .padding(Spacing.sm)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isOffline)
    }
}

// MARK: - Previews

#Preview("Offline State") {
    OfflineStateView(onRetry: {
        print("Check connection tapped")
    }, onDismiss: {
        print("Continue offline tapped")
    })
    .background(Color.semantic(.bgPrimary))
}

#Preview("Offline Banner") {
    VStack(spacing: Spacing.lg) {
        OfflineBannerView(
            onRetry: { print("Retry connection") },
            onDismiss: { print("Dismiss banner") }
        )
    }
    .padding()
    .background(Color.semantic(.bgPrimary))
}

#Preview("Network Status") {
    VStack(spacing: Spacing.lg) {
        NetworkStatusIndicator(isOffline: false)
        NetworkStatusIndicator(isOffline: true)
    }
    .padding()
    .background(Color.semantic(.bgPrimary))
}

#Preview("With Modifiers") {
    List {
        ForEach(1...10, id: \.self) { index in
            Text("Item \(index)")
        }
    }
    .offlineBanner(
        isOffline: true,
        onRetry: { print("Retry") },
        onDismiss: { print("Dismiss") }
    )
    .networkStatus(isOffline: true)
}
