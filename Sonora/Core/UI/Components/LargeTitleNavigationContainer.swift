import SwiftUI

/// Wrapper that standardises large navigation titles with Sonora's brand theme.
/// Updated for iOS 26 Liquid Glass compatibility with automatic fallback to iOS 18.
struct LargeTitleNavigationContainer<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .liquidGlassNavigation(titleDisplayMode: .large)
                .brandThemed()
        }
    }
}

#Preview {
    LargeTitleNavigationContainer(title: "Preview") {
        Text("Example content")
            .padding()
    }
}
