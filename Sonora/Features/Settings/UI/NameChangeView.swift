import SwiftUI

/// Focused view for updating the user's display name without running full onboarding
struct NameChangeView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction
    @StateObject private var onboardingConfiguration = OnboardingConfiguration.shared

    @State private var nameInput: String = ""
    @State private var isValid: Bool = true
    @FocusState private var isTextFieldFocused: Bool

    private let maxNameLength = 20

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Title
                    VStack(spacing: Spacing.sm) {
                        Text("Change Name")
                            .font(.system(.title2, design: .serif))
                            .foregroundColor(.semantic(.textPrimary))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Update how Sonora addresses you. This stays on your device.")
                            .font(.system(.caption, design: .serif))
                            .foregroundColor(.semantic(.textSecondary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Text input field (mirrors onboarding styling but simplified)
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        TextField("Your first name", text: $nameInput)
                            .textFieldStyle(.plain)
                            .font(.system(.title3, design: .serif))
                            .foregroundColor(.semantic(.textPrimary))
                            .multilineTextAlignment(.leading)
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
                            .onSubmit { saveAndDismiss() }
                            .submitLabel(.done)

                        if nameInput.count > maxNameLength - 5 {
                            HStack {
                                Spacer()
                                Text("\(nameInput.count)/\(maxNameLength)")
                                    .font(.system(.caption2, design: .serif))
                                    .foregroundColor(
                                        nameInput.count > maxNameLength ?
                                            .semantic(.warning) :
                                            .semantic(.textSecondary)
                                    )
                            }
                            .padding(.horizontal, Spacing.sm)
                        }
                    }

                    // Primary Save button (single action; keyboard Done also saves)
                    Button(action: saveAndDismiss) {
                        Text("Save")
                            .font(.system(.body, design: .serif))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.large)
                    .buttonBorderShape(.roundedRectangle)
                    .disabled(!isValid)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
            }
            .background(Color.semantic(.bgPrimary))
            .fontDesign(.serif)
            .navigationTitle("Change Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                nameInput = onboardingConfiguration.getUserName()
                // Auto-focus text field after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
        }
    }

    private func validateInput(_ input: String) {
        isValid = input.trimmingCharacters(in: .whitespacesAndNewlines).count <= maxNameLength
        if input.count > maxNameLength {
            nameInput = String(input.prefix(maxNameLength))
        }
    }

    private func saveAndDismiss() {
        let processed = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        HapticManager.shared.playSelection()
        onboardingConfiguration.saveUserName(processed)
        dismiss()
    }
}
