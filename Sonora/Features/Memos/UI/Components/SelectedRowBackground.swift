import SwiftUI

/// Rounded card background for InsetGrouped rows that supports a selected tint.
struct SelectedRowBackground: View {
    let selected: Bool
    let colorScheme: ColorScheme

    var body: some View {
        let base = Color(UIColor.systemBackground)
        let fill = selected ? Color.semantic(.brandPrimary).opacity(0.1) : base
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(fill)
    }
}

