import SwiftUI

struct MemoEmptyStateView: View {
    @State private var sonicBloomPulse: Bool = false
    @State private var messageOpacity: Double = 0
    @State private var currentTimeOfDay = TimeOfDay.current
    
    var body: some View {
        VStack(spacing: SonoraDesignSystem.Spacing.lg) {
            // SonicBloom hint animation
            sonicBloomHint
            
            // Contextual brand voice messaging
            brandVoiceSection
            
            // Subtle recording hint
            recordingHintSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            configureAnimations()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
    
    // MARK: - View Components
    
    /// SonicBloom hint with gentle pulsing animation
    @ViewBuilder
    private var sonicBloomHint: some View {
        ZStack {
            // Outer bloom effect
            Circle()
                .stroke(Color.insightGold.opacity(0.2), lineWidth: 2)
                .frame(width: 88, height: 88)
                .scaleEffect(sonicBloomPulse ? 1.2 : 1.0)
                .opacity(sonicBloomPulse ? 0.0 : 0.6)
            
            // Inner bloom effect
            Circle()
                .stroke(Color.insightGold.opacity(0.4), lineWidth: 1)
                .frame(width: 64, height: 64)
                .scaleEffect(sonicBloomPulse ? 1.1 : 1.0)
                .opacity(sonicBloomPulse ? 0.2 : 0.8)
            
            // Core waveform icon
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.insightGold)
                .symbolEffect(.pulse.byLayer)
        }
        .padding(.bottom, SonoraDesignSystem.Spacing.md)
    }
    
    /// Brand voice messaging section
    @ViewBuilder
    private var brandVoiceSection: some View {
        VStack(spacing: SonoraDesignSystem.Spacing.sm) {
            // Primary message - contextual to time of day
            Text(contextualMessage)
                .font(SonoraDesignSystem.Typography.headingMedium)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(messageOpacity)
            
            // Secondary encouragement
            Text(encouragementMessage)
                .font(SonoraDesignSystem.Typography.bodyRegular)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .opacity(messageOpacity * 0.8)
        }
        .padding(.horizontal, SonoraDesignSystem.Spacing.breathingRoom)
    }
    
    /// Subtle recording hint section
    @ViewBuilder
    private var recordingHintSection: some View {
        HStack(spacing: SonoraDesignSystem.Spacing.iconToTextSpacing) {
            Image(systemName: "mic.circle")
                .font(.caption)
                .foregroundColor(.reflectionGray)
            
            Text("Tap the bloom button to begin")
                .font(SonoraDesignSystem.Typography.caption)
                .foregroundColor(.reflectionGray)
        }
        .opacity(messageOpacity * 0.6)
        .padding(.top, SonoraDesignSystem.Spacing.md)
    }
    
    // MARK: - Helper Properties
    
    /// Contextual message based on time of day
    private var contextualMessage: String {
        switch currentTimeOfDay {
        case .morning:
            return "What thoughts are stirring this morning?"
        case .afternoon:
            return "Capture what's emerging in your mind"
        case .evening:
            return "Time to distill today's experiences"
        case .lateNight:
            return "Your late-night clarity awaits"
        }
    }
    
    /// Encouragement message
    private var encouragementMessage: String {
        "Your voice holds insights waiting to be discovered. Each recording becomes a step toward greater self-understanding."
    }
    
    /// Comprehensive accessibility description
    private var accessibilityDescription: String {
        "\(contextualMessage) \(encouragementMessage) Tap the bloom button to begin recording."
    }
    
    // MARK: - Animation Configuration
    
    private func configureAnimations() {
        // SonicBloom pulse animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            sonicBloomPulse = true
        }
        
        // Message fade-in with delay for organic feel
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            messageOpacity = 1.0
        }
    }
}

// MARK: - Time of Day Helper

enum TimeOfDay {
    case morning, afternoon, evening, lateNight
    
    static var current: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<22:
            return .evening
        default:
            return .lateNight
        }
    }
}

#Preview {
    MemoEmptyStateView()
}
