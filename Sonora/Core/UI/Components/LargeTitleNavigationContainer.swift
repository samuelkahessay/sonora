import SwiftUI

/// Wrapper that standardises large navigation titles with Sonora's brand theme.
struct LargeTitleNavigationContainer<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
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
