import SwiftUI

/// First recording prompt component with personalized greeting
struct FirstRecordingPromptView: View {
    
    // MARK: - Properties
    let userName: String
    let onStartRecording: () -> Void
    let onSkip: () -> Void
    
    // MARK: - State
    @State private var isAnimating: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Header section
                VStack(spacing: Spacing.lg) {
                    // Animated microphone icon
                    animatedMicrophoneIcon
                    
                    // Personalized title and greeting
                    VStack(spacing: Spacing.md) {
                        Text("Ready to Start")
                            .font(.system(.largeTitle, design: .serif))
                            .fontWeight(.bold)
                            .foregroundColor(.semantic(.textPrimary))
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        
                        personalizedGreeting
                    }
                }
                .padding(.top, Spacing.xl)
                
                // Encouragement section
                encouragementSection
                
                // Recording tips
                recordingTips
                
                Spacer(minLength: Spacing.xl)
                
                // Action buttons
                VStack(spacing: Spacing.md) {
                    // Start Recording button (primary)
                    Button(action: {
                        HapticManager.shared.playProcessingComplete()
                        onStartRecording()
                    }) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "mic.badge.plus")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                            
                            Text("Start Recording")
                                .font(.system(.body, design: .serif))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.semantic(.brandPrimary))
                    .controlSize(.large)
                    .buttonBorderShape(.roundedRectangle)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Start your first recording")
                    .accessibilityHint("Double tap to start recording your first voice memo")
                    
                    // Skip button
                    Button("Complete Setup") {
                        HapticManager.shared.playSelection()
                        onSkip()
                    }
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.semantic(.textSecondary))
                    .padding(.vertical, Spacing.sm)
                    .accessibilityLabel("Complete setup without recording")
                    .accessibilityHint("Double tap to complete onboarding without making a recording")
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.semantic(.bgPrimary))
        .fontDesign(.serif)
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
    }
    
    // MARK: - Animated Microphone Icon
    
    @ViewBuilder
    private var animatedMicrophoneIcon: some View {
        ZStack {
            // Outer pulse circle
            Circle()
                .stroke(Color.semantic(.brandPrimary).opacity(0.3), lineWidth: 2)
                .frame(width: 100, height: 100)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .opacity(isAnimating ? 0.0 : 0.3)
                .animation(
                    .easeOut(duration: 2.0)
                    .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            // Inner circle background
            Circle()
                .fill(Color.semantic(.brandPrimary).opacity(0.1))
                .frame(width: 80, height: 80)
            
            // Microphone icon
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.semantic(.brandPrimary))
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.pulse, isActive: isAnimating)
        }
        .accessibilityHidden(true)
    }
    
    // MARK: - Personalized Greeting
    
    @ViewBuilder
    private var personalizedGreeting: some View {
        VStack(spacing: Spacing.sm) {
            Text("How was your day, \(userName)?")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.semantic(.textPrimary))
                .multilineTextAlignment(.center)
            
            Text("Let's create your first voice memo together.")
                .font(.body)
                .foregroundColor(.semantic(.textSecondary))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Personalized greeting: How was your day, \(userName)? Let's create your first voice memo together.")
    }
    
    // MARK: - Encouragement Section
    
    @ViewBuilder
    private var encouragementSection: some View {
        VStack(spacing: Spacing.md) {
            Text("✨ Just speak naturally")
                .font(.system(.headline, design: .serif))
                .fontWeight(.medium)
                .foregroundColor(.semantic(.textPrimary))
                .multilineTextAlignment(.center)
            
            Text("There's no wrong way to start. Share a thought, describe your day, or voice an idea. Sonora will help you discover insights you might have missed.")
                .font(.system(.body, design: .serif))
                .foregroundColor(.semantic(.textSecondary))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Encouragement: Just speak naturally. There's no wrong way to start.")
    }
    
    // MARK: - Recording Tips
    
    @ViewBuilder
    private var recordingTips: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "lightbulb")
                    .font(.title3)
                    .foregroundColor(.semantic(.info))
                    .accessibilityHidden(true)
                
                Text("Quick Tips")
                    .font(.subheadline)
                    .fontDesign(.default)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
            }
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                tipRow(text: "Speak for a minimum of 30 seconds")
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.semantic(.info).opacity(0.1))
        )
        .padding(.horizontal, Spacing.md)
        .accessibilityElement(children: .contain)
    }
    
    @ViewBuilder
    private func tipRow(text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text("•")
                .font(.body)
                .foregroundColor(.semantic(.info))
                .accessibilityHidden(true)
            
            Text(text)
                .font(.subheadline)
                .fontDesign(.default)
                .foregroundColor(.semantic(.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tip: \(text)")
    }
    
    // MARK: - Animation Methods
    
    private func startAnimations() {
        isAnimating = true
        
        // Start pulse animation for the recording button
        withAnimation {
            pulseScale = 1.05
        }
    }
    
    private func stopAnimations() {
        isAnimating = false
        pulseScale = 1.0
    }
}

// MARK: - Previews

#Preview("First Recording - Sam") {
    FirstRecordingPromptView(
        userName: "Sam",
        onStartRecording: {
            print("Start recording tapped")
        },
        onSkip: {
            print("Complete setup tapped")
        }
    )
}

#Preview("First Recording - Friend") {
    FirstRecordingPromptView(
        userName: "friend",
        onStartRecording: {
            print("Start recording tapped")
        },
        onSkip: {
            print("Complete setup tapped")
        }
    )
}

#Preview("First Recording - Long Name") {
    FirstRecordingPromptView(
        userName: "Alexandra",
        onStartRecording: {
            print("Start recording tapped")
        },
        onSkip: {
            print("Complete setup tapped")
        }
    )
}
