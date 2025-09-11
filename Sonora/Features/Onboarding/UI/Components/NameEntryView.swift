import SwiftUI

/// Name entry component for personalized onboarding
struct NameEntryView: View {
    
    // MARK: - Properties
    let onContinue: (String) -> Void
    let onSkip: () -> Void
    
    // MARK: - State
    @State private var nameInput: String = ""
    @State private var isValid: Bool = true
    @FocusState private var isTextFieldFocused: Bool
    
    // MARK: - Constants
    private let maxNameLength = 20
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Header section
                VStack(spacing: Spacing.lg) {
                    // Icon
                    Image(systemName: "waveform.badge.mic")
                        .font(.system(size: 64, weight: .medium))
                        .foregroundColor(.semantic(.brandPrimary))
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)
                    
                    // Title and description
                    VStack(spacing: Spacing.md) {
                        Text("Welcome to Sonora")
                            .font(.system(.largeTitle, design: .serif))
                            .fontWeight(.bold)
                            .foregroundColor(.semantic(.textPrimary))
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        
                        Text("What should I call you?")
                            .font(.system(.title2, design: .serif))
                            .foregroundColor(.semantic(.textSecondary))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, Spacing.xl)
                
                // Name input section
                VStack(spacing: Spacing.md) {
                    // Text input field
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        TextField("Your first name", text: $nameInput)
                            .textFieldStyle(.plain)
                            .font(.system(.title3, design: .serif))
                            .foregroundColor(.semantic(.textPrimary))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.semantic(.fillSecondary))
                                    .stroke(
                                        isTextFieldFocused ? 
                                            Color.semantic(.brandPrimary) : 
                                            Color.clear, 
                                        lineWidth: 2
                                    )
                            )
                            .focused($isTextFieldFocused)
                            .onChange(of: nameInput) { _, newValue in
                                validateInput(newValue)
                            }
                            .onSubmit {
                                handleContinue()
                            }
                            .submitLabel(.continue)
                        
                        // Character limit indicator
                        if nameInput.count > maxNameLength - 5 {
                            HStack {
                                Spacer()
                                Text("\(nameInput.count)/\(maxNameLength)")
                                    .font(.caption2)
                                    .foregroundColor(
                                        nameInput.count > maxNameLength ? 
                                            .semantic(.warning) : 
                                            .semantic(.textSecondary)
                                    )
                            }
                            .padding(.horizontal, Spacing.sm)
                        }
                    }
                    
                    // Helper text
                    Text("Don't worry, this stays private on your device")
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(.semantic(.textSecondary))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.lg)
                }
                .padding(.horizontal, Spacing.lg)
                
                Spacer(minLength: Spacing.xxl)
                
                // Action buttons
                VStack(spacing: Spacing.md) {
                    // Continue button
                    Button(action: handleContinue) {
                        Text("Continue")
                            .font(.system(.body, design: .serif))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.large)
                    .buttonBorderShape(.roundedRectangle)
                    .accessibilityLabel("Continue with name")
                    .accessibilityHint("Double tap to continue with the entered name, or 'friend' if empty")
                    
                    // Skip button
                    Button("Skip") {
                        HapticManager.shared.playSelection()
                        onSkip()
                    }
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.semantic(.textSecondary))
                    .padding(.vertical, Spacing.sm)
                    .accessibilityLabel("Skip name entry")
                    .accessibilityHint("Double tap to skip name entry and continue as 'friend'")
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.semantic(.bgPrimary))
        .fontDesign(.serif)
        .onAppear {
            // Auto-focus text field after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            // Dismiss keyboard when tapping outside without interfering with buttons
            isTextFieldFocused = false
        })
    }
    
    // MARK: - Helper Methods
    
    private func validateInput(_ input: String) {
        // Validate input length
        isValid = input.count <= maxNameLength
        
        // Truncate if too long (prevent typing beyond limit)
        if input.count > maxNameLength {
            nameInput = String(input.prefix(maxNameLength))
        }
    }
    
    private func handleContinue() {
        HapticManager.shared.playSelection()
        let processedName = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        onContinue(processedName)
    }
}

// MARK: - Previews

#Preview("Name Entry - Empty") {
    NameEntryView(
        onContinue: { name in
            print("Continue with name: '\(name)'")
        },
        onSkip: {
            print("Skip name entry")
        }
    )
}

#Preview("Name Entry - With Text") {
    struct PreviewWrapper: View {
        @State private var name = "Sam"
        
        var body: some View {
            NameEntryView(
                onContinue: { name in
                    print("Continue with name: '\(name)'")
                },
                onSkip: {
                    print("Skip name entry")
                }
            )
        }
    }
    
    return PreviewWrapper()
}
