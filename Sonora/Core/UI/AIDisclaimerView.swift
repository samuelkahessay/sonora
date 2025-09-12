import SwiftUI

/// Reusable AI content disclaimer component for accessibility and transparency
struct AIDisclaimerView: View {
    
    // MARK: - Configuration
    let contentType: AIContentType
    let style: DisclaimerStyle
    
    // MARK: - Content Types
    enum AIContentType: String, CaseIterable {
        case transcription = "transcription"
        case analysis = "analysis"
        case summary = "summary"
        case generic = "generic"
        
        var displayName: String {
            switch self {
            case .transcription:
                return "AI-generated transcription"
            case .analysis:
                return "AI-generated analysis"
            case .summary:
                return "AI-generated summary"
            case .generic:
                return "AI-generated content"
            }
        }
        
        var accessibilityDescription: String {
            switch self {
            case .transcription:
                return "AI disclaimer: Transcription may contain errors"
            case .analysis:
                return "AI disclaimer: Analysis may contain inaccuracies"
            case .summary:
                return "AI disclaimer: Summary may be incomplete"
            case .generic:
                return "AI disclaimer: Content may be inaccurate"
            }
        }
    }
    
    // MARK: - Disclaimer Styles
    enum DisclaimerStyle {
        case compact
        case detailed
        case inline
        
        var iconName: String {
            switch self {
            case .compact, .inline:
                return "sparkles"
            case .detailed:
                return "info.circle.fill"
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .compact:
                return .semantic(.info).opacity(0.1)
            case .detailed:
                return .semantic(.fillSecondary)
            case .inline:
                return .semantic(.brandPrimary).opacity(0.1)
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .compact:
                return .semantic(.info)
            case .detailed:
                return .semantic(.textSecondary)
            case .inline:
                return .semantic(.brandPrimary)
            }
        }
    }
    
    // MARK: - Initialization
    init(
        contentType: AIContentType = .generic,
        style: DisclaimerStyle = .compact
    ) {
        self.contentType = contentType
        self.style = style
    }
    
    // MARK: - Body
    var body: some View {
        switch style {
        case .compact:
            compactDisclaimer
        case .detailed:
            detailedDisclaimer
        case .inline:
            inlineDisclaimer
        }
    }
    
    // MARK: - Compact Disclaimer
    @ViewBuilder
    private var compactDisclaimer: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: style.iconName)
                .font(.caption)
                .foregroundColor(style.foregroundColor)
            
            Text(contentType.displayName)
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(style.backgroundColor)
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(contentType.accessibilityDescription)
        .accessibilityAddTraits(.isStaticText)
    }
    
    // MARK: - Detailed Disclaimer
    @ViewBuilder
    private var detailedDisclaimer: some View {
        // Compact, on-brand copy with a Learn more link to the AI disclosure sheet
        DetailedDisclosureRow(contentType: contentType, tint: style.foregroundColor, bg: style.backgroundColor)
    }
    
    // MARK: - Inline Disclaimer
    @ViewBuilder
    private var inlineDisclaimer: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: style.iconName)
                .font(.caption2)
                .foregroundColor(style.foregroundColor)
            
            Text("AI")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(style.foregroundColor)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 2)
        .background(style.backgroundColor)
        .cornerRadius(4)
        .accessibilityLabel("AI generated content")
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Detailed Disclosure Row (with Learn more)

private struct DetailedDisclosureRow: View {
    let contentType: AIDisclaimerView.AIContentType
    let tint: Color
    let bg: Color
    @State private var showFullDisclosure = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundColor(tint)

                VStack(alignment: .leading, spacing: 4) {
                    // Requested concise copy
                    Text("AI-generated. Review for accuracy.")
                        .font(.subheadline)
                        .foregroundColor(.semantic(.textPrimary))

                    Button("Learn more") { showFullDisclosure = true }
                        .font(.caption)
                        .foregroundColor(.semantic(.brandPrimary))
                        .buttonStyle(.plain)
                        .accessibilityLabel("Learn more about AI features")
                }

                Spacer(minLength: 0)
            }
        }
        .padding(Spacing.sm)
        .background(bg)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.semantic(.textTertiary).opacity(0.25), lineWidth: 1)
        )
        .sheet(isPresented: $showFullDisclosure) {
            ScrollView { AIDisclosureSectionView().padding() }
                .presentationDetents([.medium, .large])
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI disclaimer. Review for accuracy. Learn more about AI features.")
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Convenience Initializers

extension AIDisclaimerView {
    
    /// Disclaimer for transcription content
    static func transcription(style: DisclaimerStyle = .compact) -> AIDisclaimerView {
        AIDisclaimerView(contentType: .transcription, style: style)
    }
    
    /// Disclaimer for analysis content
    static func analysis(style: DisclaimerStyle = .detailed) -> AIDisclaimerView {
        AIDisclaimerView(contentType: .analysis, style: style)
    }
    
    /// Disclaimer for summary content
    static func summary(style: DisclaimerStyle = .compact) -> AIDisclaimerView {
        AIDisclaimerView(contentType: .summary, style: style)
    }
    
    /// Inline disclaimer badge
    static func inline() -> AIDisclaimerView {
        AIDisclaimerView(contentType: .generic, style: .inline)
    }
}

// MARK: - View Extensions

extension View {
    /// Add AI disclaimer below content
    func withAIDisclaimer(
        _ contentType: AIDisclaimerView.AIContentType = .generic,
        style: AIDisclaimerView.DisclaimerStyle = .compact
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            self
            AIDisclaimerView(contentType: contentType, style: style)
        }
    }
}

// MARK: - Previews

#Preview("Compact Disclaimers") {
    VStack(spacing: Spacing.md) {
        AIDisclaimerView.transcription()
        AIDisclaimerView.analysis(style: .compact)
        AIDisclaimerView.summary()
        AIDisclaimerView(contentType: .generic)
    }
    .padding()
    .background(Color.semantic(.bgPrimary))
}

#Preview("Detailed Disclaimers") {
    VStack(spacing: Spacing.md) {
        AIDisclaimerView.transcription(style: .detailed)
        AIDisclaimerView.analysis()
        AIDisclaimerView.summary(style: .detailed)
    }
    .padding()
    .background(Color.semantic(.bgPrimary))
}

#Preview("Inline Disclaimers") {
    VStack(spacing: Spacing.md) {
        HStack {
            Text("Transcription Results")
                .font(.headline)
            Spacer()
            AIDisclaimerView.inline()
        }
        
        HStack {
            Text("Analysis Summary")
                .font(.headline)
            Spacer()
            AIDisclaimerView.inline()
        }
    }
    .padding()
    .background(Color.semantic(.bgPrimary))
}

#Preview("With Content Example") {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        Text("This is a sample transcription of your voice memo. It contains the main points and key information from your recording.")
            .padding()
            .background(Color.semantic(.fillSecondary))
            .cornerRadius(12)
            .withAIDisclaimer(.transcription, style: .detailed)
        
        Text("Summary: The memo discusses project updates and next steps for the team.")
            .padding()
            .background(Color.semantic(.fillSecondary))
            .cornerRadius(12)
            .withAIDisclaimer(.summary)
    }
    .padding()
    .background(Color.semantic(.bgPrimary))
}
