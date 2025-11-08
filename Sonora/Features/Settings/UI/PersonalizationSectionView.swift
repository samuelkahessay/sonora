import SwiftUI

/// Settings section to manage personalization such as the display name entered during onboarding.
struct PersonalizationSectionView: View {
    @State private var name: String = OnboardingConfiguration.shared.getUserName()
    @FocusState private var focused: Bool
    @State private var savedBannerOpacity: Double = 0

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Personalization", systemImage: "person.text.rectangle")
                    .font(SonoraDesignSystem.Typography.headingSmall)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Display Name")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.semantic(.textPrimary))

                    HStack(spacing: Spacing.sm) {
                        TextField("Your first name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .focused($focused)
                            .submitLabel(.done)
                            .onSubmit(save)

                        Button("Save") { save() }
                            .buttonStyle(.borderedProminent)
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Text("Used in greetings and prompts. Stays on device.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }

                if savedBannerOpacity > 0 {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.semantic(.brandPrimary))
                        Text("Saved")
                    }
                    .font(.caption)
                    .opacity(savedBannerOpacity)
                    .animation(.easeInOut(duration: 0.25), value: savedBannerOpacity)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        HapticManager.shared.playSelection()
        OnboardingConfiguration.shared.saveUserName(trimmed)
        name = OnboardingConfiguration.shared.getUserName() // reflect canonicalized formatting
        focused = false
        // Show quick confirmation
        savedBannerOpacity = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { savedBannerOpacity = 0 }
        }
    }
}

#Preview {
    PersonalizationSectionView()
}
