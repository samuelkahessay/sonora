import SwiftUI

struct MemoRowListItemModifier: ViewModifier {
    let colorScheme: ColorScheme
    let separator: (visibility: Visibility, edges: VerticalEdge.Set)

    func body(content: Content) -> some View {
        content
            .listRowSeparator(separator.visibility, edges: separator.edges)
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

