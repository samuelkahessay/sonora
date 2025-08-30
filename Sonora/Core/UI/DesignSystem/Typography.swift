import SwiftUI

struct Typography {
    // Primary text styles
    let largeTitle: Font
    let title: Font
    let title2: Font
    let title3: Font
    let headline: Font
    let subheadline: Font
    let body: Font
    let callout: Font
    let footnote: Font
    let caption: Font
    let caption2: Font
    
    // Specialized styles
    let monospace: Font
    let monospaceLarge: Font
    let glassHeader: Font
    let glassBody: Font
    
    // Text modifiers for glass surfaces
    let hasTextShadow: Bool
    let textShadowRadius: CGFloat
    let letterSpacing: CGFloat
}

extension Typography {
    // Default typography (legacy support)
    static let `default` = Typography(
        largeTitle: .system(.largeTitle, design: .default).weight(.bold),
        title: .system(.title, design: .default).weight(.bold),
        title2: .system(.title2, design: .default).weight(.semibold),
        title3: .system(.title3, design: .default).weight(.semibold),
        headline: .system(.headline, design: .default).weight(.semibold),
        subheadline: .system(.subheadline, design: .default),
        body: .system(.body, design: .default),
        callout: .system(.callout, design: .default),
        footnote: .system(.footnote, design: .default),
        caption: .system(.caption, design: .default),
        caption2: .system(.caption2, design: .default),
        monospace: .system(.body, design: .monospaced),
        monospaceLarge: .system(.title2, design: .monospaced).weight(.medium),
        glassHeader: .system(.title2, design: .default).weight(.semibold),
        glassBody: .system(.body, design: .default),
        hasTextShadow: false,
        textShadowRadius: 0,
        letterSpacing: 0
    )
    
    // Liquid Glass typography - optimized for translucent surfaces
    static let glass = Typography(
        largeTitle: .system(.largeTitle, design: .rounded).weight(.heavy),
        title: .system(.title, design: .rounded).weight(.bold),
        title2: .system(.title2, design: .rounded).weight(.bold),
        title3: .system(.title3, design: .rounded).weight(.semibold),
        headline: .system(.headline, design: .rounded).weight(.semibold),
        subheadline: .system(.subheadline, design: .rounded).weight(.medium),
        body: .system(.body, design: .rounded),
        callout: .system(.callout, design: .rounded),
        footnote: .system(.footnote, design: .rounded),
        caption: .system(.caption, design: .rounded).weight(.medium),
        caption2: .system(.caption2, design: .rounded).weight(.medium),
        monospace: .system(.body, design: .monospaced).weight(.medium),
        monospaceLarge: .system(.title, design: .monospaced).weight(.semibold),
        glassHeader: .system(.title2, design: .rounded).weight(.bold),
        glassBody: .system(.body, design: .rounded).weight(.medium),
        hasTextShadow: true,
        textShadowRadius: 1.5,
        letterSpacing: 0.3
    )
}

// MARK: - Text Style Modifiers
// Removed glass-specific text style modifier as part of reverting to native styling

// MARK: - Conditional helper (retained for general use)
extension View {
    /// Conditional view modifier helper
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Dynamic Type Mapping
extension Typography {
    /// Convenience mapping from `Font.TextStyle` to the corresponding theme font.
    func font(for style: Font.TextStyle) -> Font {
        switch style {
        case .largeTitle: return largeTitle
        case .title: return title
        case .title2: return title2
        case .title3: return title3
        case .headline: return headline
        case .subheadline: return subheadline
        case .body: return body
        case .callout: return callout
        case .footnote: return footnote
        case .caption: return caption
        case .caption2: return caption2
        @unknown default:
            return body
        }
    }
}
