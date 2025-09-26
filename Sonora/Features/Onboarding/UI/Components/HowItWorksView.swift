import SwiftUI

/// How It Works visual demo component for onboarding
struct HowItWorksView: View {
    
    // MARK: - Properties
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    // MARK: - Animation State
    @State private var currentStep: Int = 0
    @State private var isAnimating: Bool = false
    
    // MARK: - Constants
    private let steps = HowItWorksStep.allCases
    private let animationDuration: Double = 3.0
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Header section
                VStack(spacing: Spacing.lg) {
                    // Icon
                    Image(systemName: "lightbulb.circle")
                        .font(.system(size: 64, weight: .medium))
                        .symbolRenderingMode(.multicolor)
                        .foregroundStyle(.blue, .yellow)
                        .accessibilityHidden(true)
                    
                    // Title and description
                    VStack(spacing: Spacing.md) {
                        Text("How It Works")
                            .font(.system(.largeTitle, design: .serif))
                            .fontWeight(.bold)
                            .foregroundColor(.semantic(.textPrimary))
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        
                        Text("Transform your voice into actionable insights.")
                            .font(.system(.body, design: .serif))
                            .foregroundColor(.semantic(.textSecondary))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }
                .padding(.top, Spacing.xl)
                
                // Visual demonstration section
                VStack(spacing: Spacing.lg) {
                    // Step indicators
                    stepIndicators
                    
                    // Current step visualization
                    stepVisualization
                    
                    // Step description
                    stepDescription
                }
                .padding(.horizontal, Spacing.lg)
                
                // Privacy emphasis
                privacySection
                
                Spacer(minLength: Spacing.xl)
                
                // Action buttons
                VStack(spacing: Spacing.md) {
                    // Continue button (match first page)
                    Button(action: {
                        HapticManager.shared.playSelection()
                        onContinue()
                    }) {
                        Label("Continue", systemImage: "arrow.right.circle.fill")
                            .font(.system(.body, design: .serif))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .buttonBorderShape(.capsule)
                    .accessibilityLabel("Continue to next step")
                    .accessibilityHint("Double tap to proceed to the recording prompt")
                    
                    // Skip button
                    Button("Skip") {
                        HapticManager.shared.playSelection()
                        onSkip()
                    }
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.semantic(.textSecondary))
                    .padding(.vertical, Spacing.sm)
                    .accessibilityLabel("Skip demo")
                    .accessibilityHint("Double tap to skip the demo and go directly to recording")
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.semantic(.bgPrimary))
        .fontDesign(.serif)
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    // MARK: - Step Indicators
    
    @ViewBuilder
    private var stepIndicators: some View {
        HStack(spacing: Spacing.md) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, _ in
                Circle()
                    .fill(index == currentStep ? 
                          Color.semantic(.brandPrimary) : 
                          Color.semantic(.separator))
                    .frame(width: 12, height: 12)
                    .scaleEffect(index == currentStep ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Demo step \(currentStep + 1) of \(steps.count)")
    }
    
    // MARK: - Step Visualization
    
    @ViewBuilder
    private var stepVisualization: some View {
        let currentStepData = steps[currentStep]
        
        VStack(spacing: Spacing.lg) {
            // Step icon with animation
            Image(systemName: currentStepData.iconName)
                .font(.system(size: 48, weight: .medium))
                .symbolRenderingMode(.multicolor)
                .symbolEffect(.bounce, value: currentStep)
                .frame(height: 60)
                .accessibilityHidden(true)
            
            // Step visual representation
            stepVisualContent(for: currentStepData)
        }
        .padding(.vertical, Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.semantic(.fillSecondary))
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: currentStep)
    }
    
    @ViewBuilder
    private func stepVisualContent(for step: HowItWorksStep) -> some View {
        switch step {
        case .record:
            // Microphone with sound waves
            HStack(spacing: Spacing.sm) {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .foregroundColor(.semantic(.brandPrimary))
                
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.semantic(.brandPrimary))
                        .frame(width: 4, height: CGFloat.random(in: 20...40))
                        .scaleEffect(y: isAnimating ? CGFloat.random(in: 0.5...1.5) : 1.0)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.9)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            .accessibilityLabel("Recording voice memo")
            
        case .transcribe:
            // Text lines appearing (avoid invalid widths on device; compute relative width safely)
            GeometryReader { proxy in
                let full = max(proxy.size.width, 1)
                VStack(spacing: Spacing.xs) {
                    ForEach(0..<3, id: \.self) { index in
                        let width = index == 2 ? full * 0.7 : full
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.semantic(.textSecondary))
                            .frame(width: width, height: 4, alignment: .leading)
                            .opacity(isAnimating ? 1.0 : 0.3)
                            .scaleEffect(x: isAnimating ? 1.0 : 0.1, anchor: .leading)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.9)
                                    .delay(Double(index) * 0.25),
                                value: isAnimating
                            )
                    }
                }
            }
            .frame(height: 28)
            .padding(.horizontal, Spacing.md)
            .accessibilityLabel("Converting speech to text")
            
        case .analyze:
            // Sparkles and insights
            HStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(Color.semantic(.success))
                        .frame(width: 8, height: 8)
                    Text("Theme")
                        .font(.caption2)
                        .foregroundColor(.semantic(.textSecondary))
                }
                
                VStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(Color.semantic(.info))
                        .frame(width: 8, height: 8)
                    Text("Summary")
                        .font(.caption2)
                        .foregroundColor(.semantic(.textSecondary))
                }
                
                VStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(Color.semantic(.warning))
                        .frame(width: 8, height: 8)
                    Text("Actions")
                        .font(.caption2)
                        .foregroundColor(.semantic(.textSecondary))
                }
            }
            .scaleEffect(isAnimating ? 1.1 : 0.9)
            .animation(.spring(response: 0.8, dampingFraction: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            .accessibilityLabel("Analyzing and extracting insights")
        }
    }
    
    // MARK: - Step Description
    
    @ViewBuilder
    private var stepDescription: some View {
        let currentStepData = steps[currentStep]
        
        VStack(spacing: Spacing.sm) {
            Text(currentStepData.title)
                .font(.system(.headline, design: .serif))
                .fontWeight(.semibold)
                .foregroundColor(.semantic(.textPrimary))
                .multilineTextAlignment(.center)
            
            Text(currentStepData.description)
                .font(.system(.body, design: .serif))
                .foregroundColor(.semantic(.textSecondary))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: currentStep)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(currentStepData.title). \(currentStepData.description)")
    }
    
    // MARK: - Privacy Section
    
    @ViewBuilder
    private var privacySection: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "lock.shield")
                .font(.title3)
                .foregroundColor(.semantic(.success))
                .accessibilityHidden(true)
            
            Text("All processing respects your privacy")
                .font(.subheadline)
                .fontDesign(.default)
                .fontWeight(.medium)
                .foregroundColor(.semantic(.success))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.semantic(.success).opacity(0.1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Privacy guarantee: All processing respects your privacy")
    }
    
    // MARK: - Animation Methods
    
    private func startAnimation() {
        isAnimating = true
        
        Timer.scheduledTimer(withTimeInterval: animationDuration, repeats: true) { timer in
            Task { @MainActor in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                    currentStep = (currentStep + 1) % steps.count
                }
            }
        }
    }
    
    private func stopAnimation() {
        isAnimating = false
    }
}

// MARK: - How It Works Steps

enum HowItWorksStep: CaseIterable {
    case record
    case transcribe
    case analyze
    
    var title: String {
        switch self {
        case .record:
            return "1. Tap Record & Speak"
        case .transcribe:
            return "2. Automatic Transcription"
        case .analyze:
            return "3. Get Distilled Insights"
        }
    }
    
    var description: String {
        switch self {
        case .record:
            return "Simply tap the record button and speak naturally about anything on your mind."
        case .transcribe:
            return "Your voice is automatically converted to text with high accuracy."
        case .analyze:
            return "AI extracts key themes, summaries, and actionable items from your thoughts."
        }
    }
    
    var iconName: String {
        switch self {
        case .record:
            return "mic.badge.plus"
        case .transcribe:
            return "text.badge.checkmark"
        case .analyze:
            return "sparkles"
        }
    }
}

// MARK: - Previews

#Preview("How It Works - Step 1") {
    HowItWorksView(
        onContinue: {
            print("Continue tapped")
        },
        onSkip: {
            print("Skip tapped")
        }
    )
}

#Preview("How It Works - Interactive") {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        
        var body: some View {
            if isPresented {
                HowItWorksView(
                    onContinue: {
                        print("Continue tapped")
                        isPresented = false
                    },
                    onSkip: {
                        print("Skip tapped")
                        isPresented = false
                    }
                )
            } else {
                Text("Demo completed")
                    .font(.title)
                    .foregroundColor(.semantic(.textPrimary))
            }
        }
    }
    
    return PreviewWrapper()
}
