import SwiftUI

struct TestView: View {
    var body: some View {
        NavigationView {
            Text("Test tab content")
                .padding()
                .navigationTitle("Test")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    TestView()
}
