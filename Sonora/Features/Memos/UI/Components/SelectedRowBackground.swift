import SwiftUI

/// Rounded card background for InsetGrouped rows that supports a selected tint.
struct SelectedRowBackground: View {
    let selected: Bool
    let colorScheme: ColorScheme

    var body: some View {
        // Use a clear background when not selected to let the
        // list's container background show through and avoid
        // an unintended white gutter around our card.
        let fill: Color = selected ? Color.semantic(.fillSecondary) : .clear
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(fill)
    }
}
