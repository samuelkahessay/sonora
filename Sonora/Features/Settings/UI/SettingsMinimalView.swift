import SwiftUI

struct SettingsMinimalView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                Text("Settings minimal screen")
                    .font(.title2)
                Text("Use this DEBUG view to confirm navigation title rendering without complex modifiers.")
                    .foregroundColor(.semantic(.textSecondary))
            }
            .padding()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack { SettingsMinimalView() }
}

