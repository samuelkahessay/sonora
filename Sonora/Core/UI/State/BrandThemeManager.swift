//
//  BrandThemeManager.swift
//  Sonora
//
//  Central theme management system coordinating brand identity across the app
//  Manages color themes, animation states, and brand consistency enforcement
//

import SwiftUI
import Combine

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
    private let persistenceKey = "SonoraBrandTheme"
    
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
    
    /// Get the current recording button configuration
    /// - Returns: Recording button theme configuration
    func getRecordingButtonTheme() -> RecordingButtonTheme {
        RecordingButtonTheme(
            activeColor: currentTheme.recordingActive,
            inactiveColor: currentTheme.recordingInactive,
            pulseColor: currentTheme.recordingActive.opacity(0.6),
            shadowColor: currentTheme.recordingActive.opacity(0.25),
            animationStyle: recordingState == .active ? .energetic : .gentle,
            isAnimated: !reducedMotion && animationIntensity > 0.5
        )
    }
    
    /// Get the current insight highlight configuration
    /// - Returns: Insight theme configuration
    func getInsightTheme() -> InsightTheme {
        InsightTheme(
            highlightColor: currentTheme.insightHighlight,
            backgroundColor: currentTheme.surface.opacity(0.8),
            textColor: currentTheme.onSurface,
            accentColor: currentTheme.secondary,
            isAnimated: !reducedMotion
        )
    }
    
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

/// Configuration for recording button theming
struct RecordingButtonTheme {
    let activeColor: Color
    let inactiveColor: Color
    let pulseColor: Color
    let shadowColor: Color
    let animationStyle: AnimationStyle
    let isAnimated: Bool
    
    enum AnimationStyle {
        case gentle, energetic, dramatic
    }
}

/// Configuration for insight display theming
struct InsightTheme {
    let highlightColor: Color
    let backgroundColor: Color
    let textColor: Color
    let accentColor: Color
    let isAnimated: Bool
}

/// Extended brand theme with dark mode adaptation
extension SonoraBrandTheme {
    
    /// Dark-adapted Sonora theme maintaining brand identity
    static let darkAdapted = SonoraBrandTheme(
        primary: Color.insightGold,
        secondary: Color.growthGreen,
        accent: Color.sparkOrange,
        background: Color.sonoraDep,
        surface: Color.sonoraDep.opacity(0.8),
        onPrimary: Color.clarityWhite,
        onSurface: Color.clarityWhite,
        recordingActive: Color.insightGold,
        recordingInactive: Color.reflectionGray,
        insightHighlight: Color.growthGreen,
        textPrimary: Color.clarityWhite,
        textSecondary: Color.reflectionGray,
        isDark: true
    )
}

// MARK: - Brand Themeable Protocol

/// Protocol for views that respond to brand theme changes
protocol BrandThemeable: AnyObject {
    
    /// Apply current brand styling to the view
    func applyBrandStyling()
    
    /// Update view for new recording state
    /// - Parameter state: Current recording state
    func updateForRecordingState(_ state: RecordingState)
    
    /// Update view for focus mode changes
    /// - Parameter enabled: Whether focus mode is enabled
    func updateForFocusMode(_ enabled: Bool)
    
    /// Get appropriate animation for theme changes
    /// - Parameter type: Type of transition
    /// - Returns: Animation configured for this view
    func getAnimation(for type: TransitionType) -> Animation
}

// MARK: - Default Implementation

extension BrandThemeable {
    
    func applyBrandStyling() {
        // Default implementation - override in conforming views
    }
    
    func updateForRecordingState(_ state: RecordingState) {
        // Default implementation - override in conforming views
    }
    
    func updateForFocusMode(_ enabled: Bool) {
        // Default implementation - override in conforming views
    }
    
    @MainActor
    func getAnimation(for type: TransitionType) -> Animation {
        BrandThemeManager.shared.getAppropriateAnimation(for: type)
    }
}

// MARK: - View Modifier for Theme Management

struct BrandThemeModifier: ViewModifier {
    @StateObject private var themeManager = BrandThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .environmentObject(themeManager)
            .colorScheme(themeManager.colorScheme)
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

#if DEBUG
struct BrandThemeManager_Preview: View {
    @StateObject private var themeManager = BrandThemeManager.shared
    
    var body: some View {
        VStack(spacing: SonoraDesignSystem.Spacing.lg) {
            Text("Brand Theme Manager")
                .headingStyle(.large)
            
            VStack(spacing: SonoraDesignSystem.Spacing.md) {
                themeInfoSection
                controlsSection
                recordingStateSection
            }
            .breathingRoom()
        }
        .brandThemed()
        .previewDisplayName("Brand Theme Manager")
    }
    
    private var themeInfoSection: some View {
        VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.sm) {
            Text("Current Theme")
                .headingStyle(.small)
            
            HStack {
                colorSwatch("Primary", themeManager.currentTheme.primary)
                colorSwatch("Secondary", themeManager.currentTheme.secondary)
                colorSwatch("Accent", themeManager.currentTheme.accent)
                colorSwatch("Background", themeManager.currentTheme.background)
            }
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: SonoraDesignSystem.Spacing.sm) {
            Text("Controls")
                .headingStyle(.small)
            
            HStack {
                Button("Light Theme") {
                    themeManager.setColorScheme(.light)
                }
                .buttonStyle(.bordered)
                
                Button("Dark Theme") {
                    themeManager.setColorScheme(.dark)
                }
                .buttonStyle(.bordered)
                
                Button("Toggle Focus") {
                    themeManager.toggleFocusMode()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var recordingStateSection: some View {
        VStack(spacing: SonoraDesignSystem.Spacing.sm) {
            Text("Recording State: \(themeManager.recordingState.description)")
                .bodyStyle(.regular)
            
            HStack {
                Button("Idle") {
                    themeManager.updateRecordingState(.idle)
                }
                .buttonStyle(.bordered)
                
                Button("Recording") {
                    themeManager.updateRecordingState(.active)
                }
                .buttonStyle(.bordered)
                
                Button("Processing") {
                    themeManager.updateRecordingState(.processing)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func colorSwatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(width: 40, height: 40)
            
            Text(name)
                .bodyStyle(.caption)
        }
    }
}

struct BrandThemeManager_Previews: PreviewProvider {
    static var previews: some View {
        BrandThemeManager_Preview()
    }
}
#endif
