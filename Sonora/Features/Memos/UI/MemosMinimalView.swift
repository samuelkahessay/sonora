import SwiftUI

struct MemosMinimalView: View {
    @AppStorage("debug.memos.plainListStyle") private var debugMemosPlainListStyle: Bool = false
    @AppStorage("debug.memos.inlineTitle") private var debugMemosInlineTitle: Bool = false
    @AppStorage("debug.memos.useScrollView") private var debugMemosUseScrollView: Bool = false

    var body: some View {
        content
            .onAppear {
                print("[DEBUG] MemosMinimalView appear: useScrollView=\(debugMemosUseScrollView), plainListStyle=\(debugMemosPlainListStyle), inlineTitle=\(debugMemosInlineTitle)")
            }
    }

    @ViewBuilder
    private var content: some View {
        if debugMemosUseScrollView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("Row 1").padding(.horizontal)
                    Text("Row 2").padding(.horizontal)
                }
                .padding(.vertical)
            }
        } else {
            if debugMemosPlainListStyle {
                List {
                    SwiftUI.Section("Recent") {
                        Text("Row 1")
                        Text("Row 2")
                    }
                }
                .listStyle(.plain)
            } else {
                List {
                    SwiftUI.Section("Recent") {
                        Text("Row 1")
                        Text("Row 2")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

#Preview {
    NavigationStack { MemosMinimalView() }
}
