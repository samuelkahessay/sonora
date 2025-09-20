import SwiftUI

struct TestView: View {
    var body: some View {
        LargeTitleNavigationContainer(title: "Test") {
            Text("Test tab content")
                .padding()
        }
    }
}

#Preview {
    TestView()
}
