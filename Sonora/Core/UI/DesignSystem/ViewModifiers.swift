import SwiftUI

// MARK: - Legacy Support (kept for backward compatibility)
struct ThemedBackground: ViewModifier {
    let palette: ColorPalette
    func body(content: Content) -> some View {
        content
            .background(palette.background)
    }
}

struct ElevatedBackground: ViewModifier {
    let palette: ColorPalette
    let useGlass: Bool
    
    init(palette: ColorPalette, useGlass: Bool = true) {
        self.palette = palette
        self.useGlass = useGlass
    }
    
    func body(content: Content) -> some View {
        if useGlass {
            content
                .glassBackground(palette: palette, material: .thinMaterial, cornerRadius: 12)
        } else {
            content
                .background(palette.backgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - Liquid Glass Components

// Glass List Row (non-intercepting; preserves NavigationLink taps)
struct GlassListRow: ViewModifier {
    let palette: ColorPalette
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(palette.glassBorder.opacity(0.3), lineWidth: 0.5)
                    }
            }
            // Ensure the entire row is tappable by NavigationLink without custom gestures
            .contentShape(Rectangle())
    }
}

// Glass Text Field
struct GlassTextField: ViewModifier {
    let palette: ColorPalette
    @FocusState private var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(palette.backgroundGlass)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isFocused ? palette.primary : palette.glassBorder,
                                lineWidth: isFocused ? 1.5 : 0.5
                            )
                    }
            }
            .focused($isFocused)
            .animation(.spring(response: 0.3), value: isFocused)
    }
}

// Glass Alert/Modal Background
struct GlassAlert: ViewModifier {
    let palette: ColorPalette
    
    func body(content: Content) -> some View {
        content
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(palette.backgroundGlass)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(palette.glassBorder, lineWidth: 1)
                    }
                    .shadow(
                        color: palette.glassShadow.opacity(0.3),
                        radius: 30,
                        x: 0,
                        y: 20
                    )
            }
    }
}

// Glass Section Container
struct GlassSection: ViewModifier {
    let palette: ColorPalette
    let title: String?
    
    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(palette.textSecondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)
            }
            
            content
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.thinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(palette.backgroundGlassSecondary)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(palette.glassBorder.opacity(0.5), lineWidth: 0.5)
                        }
                }
        }
    }
}

// MARK: - View Extensions
extension View {
    func themedBackground(_ palette: ColorPalette) -> some View {
        modifier(ThemedBackground(palette: palette))
    }
    
    func elevatedBackground(_ palette: ColorPalette, useGlass: Bool = true) -> some View {
        modifier(ElevatedBackground(palette: palette, useGlass: useGlass))
    }
    
    func glassListRow(palette: ColorPalette) -> some View {
        modifier(GlassListRow(palette: palette))
    }
    
    func glassTextField(palette: ColorPalette) -> some View {
        modifier(GlassTextField(palette: palette))
    }
    
    func glassAlert(palette: ColorPalette) -> some View {
        modifier(GlassAlert(palette: palette))
    }
    
    func glassSection(palette: ColorPalette, title: String? = nil) -> some View {
        modifier(GlassSection(palette: palette, title: title))
    }
}
