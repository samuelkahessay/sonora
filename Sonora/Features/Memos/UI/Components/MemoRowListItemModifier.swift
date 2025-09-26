import SwiftUI

struct MemoRowListItemModifier: ViewModifier {
    let colorScheme: ColorScheme
    let separator: (visibility: Visibility, edges: VerticalEdge.Set)

    func body(content: Content) -> some View {
        content
            // Option A: Hide all separators at the row level to prevent
            // any default/bottom lines and overextending separators.
            .listRowSeparator(.hidden, edges: .all)
            .listRowInsets(MemoListConstants.rowInsets)
            .memoRowBackground(colorScheme)
    }
}

extension View {
    func memoRowListItem(colorScheme: ColorScheme,
                         separator: (visibility: Visibility, edges: VerticalEdge.Set)) -> some View {
        modifier(MemoRowListItemModifier(colorScheme: colorScheme, separator: separator))
    }
}
