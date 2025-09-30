//
//  BrandThemeManager.swift
//  Sonora
//
//  Central theme management system coordinating brand identity across the app
//  Manages color themes, animation states, and brand consistency enforcement
//

import Combine
import SwiftUI

// MARK: - Brand Theme Manager

/// Central coordinator for Sonora's brand identity and theme management
/// Ensures consistent application of colors, animations, and brand elements
@MainActor
final class BrandThemeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = BrandThemeManager()

    // MARK: - Published Properties

    /// Current brand theme configuration
    @Published var currentTheme: SonoraBrandTheme = .default

    /// Current recording state affecting visual presentation
    @Published var recordingState: RecordingState = .idle

    /// Whether animations should be reduced for accessibility
    @Published var reducedMotion: Bool = UIAccessibility.isReduceMotionEnabled

    /// Current app-wide color scheme preference
    @Published var colorScheme: ColorScheme = .light

    /// Whether the app is in focus mode (simplified interface)
    @Published var isFocusMode: Bool = false

    /// Animation intensity level (0.0 to 1.0)
    @Published var animationIntensity: Double = 1.0

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupAccessibilityObservers()
        loadPersistedTheme()
        observeRecordingStateChanges()
    }

    // MARK: - Public Interface

    /// Update the recording state and trigger appropriate visual changes
    /// - Parameter state: New recording state
    func updateRecordingState(_ state: RecordingState) {
        guard recordingState != state else { return }

        withAnimation(getAppropriateAnimation(for: .recordingTransition)) {
            recordingState = state
        }

        // Notify all themeable views
        notifyThemeableViews()

        // Apply haptic feedback for state changes
        if !reducedMotion {
            applyHapticFeedback(for: state)
        }
    }

    /// Switch to a different color scheme
    /// - Parameter scheme: Target color scheme
    func setColorScheme(_ scheme: ColorScheme) {
        withAnimation(getAppropriateAnimation(for: .themeChange)) {
            colorScheme = scheme
            updateThemeForColorScheme(scheme)
        }

        persistTheme()
    }

    /// Toggle focus mode for simplified interface
    func toggleFocusMode() {
        withAnimation(getAppropriateAnimation(for: .interfaceChange)) {
            isFocusMode.toggle()
        }

        notifyThemeableViews()
    }

    /// Get the appropriate animation for a given transition type
    /// - Parameter type: Type of transition
    /// - Returns: SwiftUI Animation configured for the transition
    func getAppropriateAnimation(for type: TransitionType) -> Animation {
        let baseAnimation = type.baseAnimation

        if reducedMotion {
            return .easeInOut(duration: 0.2)
        }

        // Scale animation intensity
        return baseAnimation.speed(animationIntensity)
    }

    // removed unused theme helper builders

    // MARK: - Private Implementation

    /// Setup accessibility observers for motion preferences
    private func setupAccessibilityObservers() {
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.reducedMotion = UIAccessibility.isReduceMotionEnabled
                    self?.updateAnimationIntensity()
                }
            }
            .store(in: &cancellables)
    }

    /// Load persisted theme settings
    private func loadPersistedTheme() {
        // Implementation would load from UserDefaults or other persistence
        // For now, use default theme
        currentTheme = .default
    }

    /// Persist current theme settings
    private func persistTheme() {
        // Implementation would save to UserDefaults
        // For now, just log the change
        print("🎨 BrandThemeManager: Theme persisted")
    }

    /// Observe recording state changes from other parts of the app
    private func observeRecordingStateChanges() {
        NotificationCenter.default.publisher(for: .recordingStateChanged)
            .compactMap { $0.userInfo?["state"] as? RecordingState }
            .sink { [weak self] state in
                self?.updateRecordingState(state)
            }
            .store(in: &cancellables)
    }

    /// Update theme properties for new color scheme
    private func updateThemeForColorScheme(_ scheme: ColorScheme) {
        // Sonora brand prefers light appearance but adapts to user preference
        if scheme == .dark {
            currentTheme = .darkAdapted
        } else {
            currentTheme = .default
        }
    }

    /// Update animation intensity based on accessibility settings
    private func updateAnimationIntensity() {
        if reducedMotion {
            animationIntensity = 0.3
        } else {
            animationIntensity = 1.0
        }
    }

    /// Notify all views that conform to BrandThemeable protocol
    private func notifyThemeableViews() {
        NotificationCenter.default.post(
            name: .brandThemeChanged,
            object: self,
            userInfo: [
                "theme": currentTheme,
                "recordingState": recordingState,
                "focusMode": isFocusMode
            ]
        )
    }

    /// Apply appropriate haptic feedback for recording state changes
    private func applyHapticFeedback(for state: RecordingState) {
        switch state {
        case .active:
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        case .idle:
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        case .processing:
            let selection = UISelectionFeedbackGenerator()
            selection.selectionChanged()
        case .error:
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
        }
    }
}

// MARK: - Supporting Types

/// Recording states that affect visual presentation
enum RecordingState: Equatable, Sendable {
    case idle
    case active
    case processing
    case error

    var description: String {
        switch self {
        case .idle: return "Ready to record"
        case .active: return "Recording active"
        case .processing: return "Processing audio"
        case .error: return "Recording error"
        }
    }
}

/// Types of UI transitions for appropriate animation selection
enum TransitionType {
    case recordingTransition
    case themeChange
    case interfaceChange
    case contentReveal
    case microInteraction

    var baseAnimation: Animation {
        switch self {
        case .recordingTransition:
            return SonoraDesignSystem.Animation.bloomTransition
        case .themeChange:
            return SonoraDesignSystem.Animation.reveal
        case .interfaceChange:
            return SonoraDesignSystem.Animation.gentleSpring
        case .contentReveal:
            return SonoraDesignSystem.Animation.reveal
        case .microInteraction:
            return SonoraDesignSystem.Animation.quickFeedback
        }
    }
}

// removed unused theme data structs

/// Extended brand theme with dark mode adaptation
extension SonoraBrandTheme {

    /// Dark-adapted Sonora theme maintaining brand identity
    static let darkAdapted = SonoraBrandTheme(
        primary: Color.insightGold,
        secondary: Color.growthGreen,
        accent: Color.sparkOrange,
        background: Color.sonoraDep
    )
}

// MARK: - Brand Themeable Protocol

// removed unused BrandThemeable protocol and defaults

// MARK: - View Modifier for Theme Management

struct BrandThemeModifier: ViewModifier {
    @StateObject private var themeManager = BrandThemeManager.shared

    func body(content: Content) -> some View {
        content
            .environmentObject(themeManager)
            // Do not override system color scheme; rely solely on device setting
            .animation(themeManager.getAppropriateAnimation(for: .themeChange), value: themeManager.colorScheme)
    }
}

extension View {

    /// Apply brand theme management to the view
    func brandThemed() -> some View {
        self.modifier(BrandThemeModifier())
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let brandThemeChanged = Notification.Name("brandThemeChanged")
    static let recordingStateChanged = Notification.Name("recordingStateChanged")
}

// MARK: - Preview Support
