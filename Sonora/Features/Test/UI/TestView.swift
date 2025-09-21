import SwiftUI

struct TestView: View {
    #if DEBUG
    @AppStorage("debug.useMinimalSettings") private var debugUseMinimalSettings: Bool = false
    @AppStorage("debug.useMinimalMemos") private var debugUseMinimalMemos: Bool = false
    @AppStorage("debug.memos.usePathBinding") private var debugMemosUsePathBinding: Bool = true
    @AppStorage("debug.memos.plainListStyle") private var debugMemosPlainListStyle: Bool = false
    @AppStorage("debug.memos.inlineTitle") private var debugMemosInlineTitle: Bool = false
    @AppStorage("debug.memos.useScrollView") private var debugMemosUseScrollView: Bool = false
    // Full Memos (advanced) toggles
    @AppStorage("debug.memos.forceInlineTitle") private var debugMemosForceInlineTitle: Bool = false
    @AppStorage("debug.memos.hideTrailingToolbar") private var debugMemosHideTrailingToolbar: Bool = false
    @AppStorage("debug.memos.disableScrollContentBackground") private var debugMemosDisableScrollContentBackground: Bool = false
    @AppStorage("debug.memos.disableTopHeader") private var debugMemosDisableTopHeader: Bool = false
    @AppStorage("debug.memos.usePlainListStyleFull") private var debugMemosUsePlainListStyleFull: Bool = false
    #endif

    var body: some View {
        ScrollView {
        VStack(spacing: 16) {
            Text("Test tab content")
                .padding(.top)

            #if DEBUG
            GroupBox("Debug Navigation Toggles") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Use Minimal Settings Screen", isOn: $debugUseMinimalSettings)
                    Toggle("Use Minimal Memos Screen", isOn: $debugUseMinimalMemos)
                    Divider()
                    Toggle("Memos: Use Path-Bound Stack", isOn: $debugMemosUsePathBinding)
                    Toggle("Memos: Plain List Style", isOn: $debugMemosPlainListStyle)
                    Toggle("Memos: Inline Title", isOn: $debugMemosInlineTitle)
                    Toggle("Memos: Use ScrollView Root", isOn: $debugMemosUseScrollView)
                    Text("Switch these to isolate navigation title issues.")
                        .font(.footnote)
                        .foregroundColor(.semantic(.textSecondary))
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal)

            GroupBox("Full Memos Debug Toggles") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Full Memos: Force Inline Title", isOn: $debugMemosForceInlineTitle)
                    Toggle("Full Memos: Hide Trailing Toolbar", isOn: $debugMemosHideTrailingToolbar)
                    Toggle("Full Memos: Disable .scrollContentBackground(.hidden)", isOn: $debugMemosDisableScrollContentBackground)
                    Toggle("Full Memos: Disable Top Header Controls", isOn: $debugMemosDisableTopHeader)
                    Toggle("Full Memos: Plain List Style", isOn: $debugMemosUsePlainListStyleFull)
                    Text("Use these to pinpoint large-title suppression on iOS 26.")
                        .font(.footnote)
                        .foregroundColor(.semantic(.textSecondary))
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal)
            #endif
        }
        .padding(.bottom, 24)
        }
        .navigationTitle("Test")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    TestView()
}
