import SwiftUI

/// Name entry component for personalized onboarding
struct NameEntryView: View {

    // MARK: - Properties
    let onContinue: (String) -> Void

    // MARK: - State
    @State private var nameInput: String = ""
    @State private var isValid: Bool = true
    @FocusState private var isTextFieldFocused: Bool
    @State private var shouldAutoFocus = true

    // MARK: - Constants
    private let maxNameLength = 20

    // MARK: - Body
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Form {
                Section {
                    TextField("Your first name", text: $nameInput)
                        .textContentType(.givenName)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .font(.system(.title3, design: .serif))
                        .focused($isTextFieldFocused)
                        .onChange(of: nameInput) { _, newValue in validateInput(newValue) }
                        .submitLabel(.continue)
                        .onSubmit(handleContinue)
                } header: {
                    VStack(spacing: Spacing.lg) {
                        Image(systemName: "waveform.badge.mic")
                            .font(.system(size: 64, weight: .medium))
                            .foregroundStyle(.blue.gradient)
                            .symbolRenderingMode(.multicolor)
                            .accessibilityHidden(true)

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
                    .frame(maxWidth: .infinity)
                } footer: {
                    Text("Don't worry, this stays private on your device")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.semantic(.bgPrimary))

            // Actions
            VStack(spacing: Spacing.md) {
                Button(action: handleContinue) {
                    HStack(spacing: Spacing.sm) {
                        Text("Continue")
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .font(.system(.body, design: .serif))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonBorderShape(.capsule)
                .accessibilityLabel("Continue with name")
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.semantic(.bgPrimary))
        .fontDesign(.serif)
        .onAppear {
            guard shouldAutoFocus else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { isTextFieldFocused = true }
        }
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
        isTextFieldFocused = false
        shouldAutoFocus = false
        let processedName = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        onContinue(processedName)
    }
}

// MARK: - Previews

#Preview("Name Entry - Empty") {
    NameEntryView        { name in
            print("Continue with name: '\(name)'")
        }
}

#Preview("Name Entry - With Text") {
    struct PreviewWrapper: View {
        @State private var name = "Sam"

        var body: some View {
            NameEntryView                { name in
                    print("Continue with name: '\(name)'")
                }
        }
    }

    return PreviewWrapper()
}
