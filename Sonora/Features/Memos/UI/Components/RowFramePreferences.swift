import SwiftUI

/// Preference key that accumulates per-row frames in a named coordinate space.
struct RowFramesPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    /// Reports this row's frame under the given id into RowFramesPreferenceKey using the named coordinate space.
    func reportRowFrame(id: UUID, inNamedCoordinateSpace name: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: RowFramesPreferenceKey.self, value: [id: proxy.frame(in: .named(name))])
            }
        )
    }
}
