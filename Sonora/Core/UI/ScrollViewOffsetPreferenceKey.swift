import SwiftUI

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    nonisolated static var defaultValue: CGFloat { 0 }
    nonisolated static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
