import SwiftUI

/// Settings section for onboarding and app introduction
struct OnboardingSectionView: View {
    
    @StateObject private var onboardingConfiguration = OnboardingConfiguration.shared
    @State private var showingOnboarding = false
    @State private var showingNameChange = false
    
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Header
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.semantic(.info))
                    Text("Getting Started")
                        .font(SonoraDesignSystem.Typography.headingSmall)
                        .foregroundColor(.semantic(.textPrimary))
                    Spacer()
                }
                
                // View Onboarding option
                Button(action: {
                    showingOnboarding = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("View Onboarding")
                                .font(SonoraDesignSystem.Typography.bodyLarge)
                                .fontWeight(.medium)
                                .foregroundColor(.semantic(.textPrimary))
                            
                            Text("Review app setup and privacy information")
                                .font(.caption)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.vertical, Spacing.xs)
                
                // Onboarding status
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Onboarding Status")
                        .font(SonoraDesignSystem.Typography.bodyLarge)
                        .fontWeight(.medium)
                        .foregroundColor(.semantic(.textPrimary))
                    
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: onboardingConfiguration.hasCompletedOnboarding ? 
                              "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundColor(onboardingConfiguration.hasCompletedOnboarding ? 
                                           .semantic(.success) : .semantic(.textSecondary))
                        
                        Text(onboardingConfiguration.hasCompletedOnboarding ? 
                             "Completed" : "Not completed")
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                        
                        if let completionDate = onboardingConfiguration.onboardingCompletionDate {
                            Text("• \(formatDate(completionDate))")
                                .font(.caption)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                        
                        if onboardingConfiguration.hasCustomUserName {
                            Text("• Name: '\(onboardingConfiguration.getUserName())'")
                                .font(.caption)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                    }
                }
                
                // Change name option
                if onboardingConfiguration.hasCompletedOnboarding {
                    Divider()
                        .padding(.vertical, Spacing.xs)
                    
                    Button(action: {
                        showingNameChange = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Change Name")
                                    .font(SonoraDesignSystem.Typography.bodyLarge)
                                    .fontWeight(.medium)
                                    .foregroundColor(.semantic(.textPrimary))
                                
                                Text("Update your personalized name")
                                    .font(.caption)
                                    .foregroundColor(.semantic(.textSecondary))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
#if DEBUG
                // Debug section
                Divider()
                    .padding(.vertical, Spacing.xs)
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Debug Actions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.semantic(.warning))
                    
                    Button("Reset Onboarding State") {
                        onboardingConfiguration.debugResetForTesting()
                    }
                    .font(.caption)
                    .foregroundColor(.semantic(.warning))
                    .padding(.vertical, Spacing.xs)
                }
#endif
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
        }
        .sheet(isPresented: $showingNameChange) {
            NameChangeView()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            OnboardingSectionView()
        }
        .padding()
    }
    .background(Color.semantic(.bgPrimary))
}
