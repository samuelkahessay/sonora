import SwiftUI

/// Conditionally apply SwiftUI's refreshable modifier.
struct ConditionalRefreshModifier: ViewModifier {
    let enabled: Bool
    let action: () async -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.refreshable { await action() }
        } else {
            content
        }
    }
}

extension View {
    func conditionalRefreshable(_ enabled: Bool, action: @escaping () async -> Void) -> some View {
        modifier(ConditionalRefreshModifier(enabled: enabled, action: action))
    }
}

