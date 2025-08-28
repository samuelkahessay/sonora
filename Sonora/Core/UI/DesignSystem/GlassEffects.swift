import SwiftUI

// MARK: - Glass Background Modifier
struct GlassBackground: ViewModifier {
    let palette: ColorPalette
    let material: Material
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    init(
        palette: ColorPalette,
        material: Material = .ultraThinMaterial,
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 10
    ) {
        self.palette = palette
        self.material = material
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(palette.glassGradient)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(palette.glassBorder, lineWidth: 0.5)
                    }
                    .shadow(color: palette.glassShadow, radius: shadowRadius, x: 0, y: 4)
            }
    }
}

// MARK: - Frosted Glass Card
struct FrostedGlassCard: ViewModifier {
    let palette: ColorPalette
    let elevation: GlassElevation
    
    enum GlassElevation {
        case low, medium, high
        
        var material: Material {
            switch self {
            case .low: return .ultraThinMaterial
            case .medium: return .thinMaterial
            case .high: return .regularMaterial
            }
        }
        
        var shadowRadius: CGFloat {
            switch self {
            case .low: return 8
            case .medium: return 12
            case .high: return 20
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .low: return 12
            case .medium: return 16
            case .high: return 20
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background {
                RoundedRectangle(cornerRadius: elevation.cornerRadius, style: .continuous)
                    .fill(elevation.material)
                    .overlay {
                        RoundedRectangle(cornerRadius: elevation.cornerRadius, style: .continuous)
                            .fill(palette.backgroundGlass)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: elevation.cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        palette.glassBorder,
                                        palette.glassBorder.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: palette.glassShadow,
                        radius: elevation.shadowRadius,
                        x: 0,
                        y: elevation.shadowRadius / 2
                    )
            }
    }
}

// MARK: - Interactive Glass Button
struct GlassButton: ViewModifier {
    let palette: ColorPalette
    let isPressed: Bool
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(palette.textOnGlass)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.primary.opacity(isPressed ? 0.3 : 0.15))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(palette.glassBorder, lineWidth: 0.5)
                    }
            }
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .shadow(
                color: palette.glassShadow,
                radius: isPressed ? 4 : 8,
                x: 0,
                y: isPressed ? 2 : 4
            )
    }
}

// MARK: - Shimmer Effect
struct ShimmerEffect: ViewModifier {
    let palette: ColorPalette
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [
                        Color.clear,
                        palette.glassHighlight.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .init(x: phase - 0.5, y: 0),
                    endPoint: .init(x: phase + 0.5, y: 1)
                )
                .animation(
                    .linear(duration: 2.5)
                    .repeatForever(autoreverses: false),
                    value: phase
                )
                .onAppear {
                    phase = 1.5
                }
                .allowsHitTesting(false)
                .mask(content)
            }
    }
}

// MARK: - Floating Element
struct FloatingElement: ViewModifier {
    let palette: ColorPalette
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .shadow(
                color: palette.glassShadow.opacity(0.5),
                radius: 20,
                x: 0,
                y: 10 + offset
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                ) {
                    offset = -5
                }
            }
    }
}

// MARK: - View Extensions
extension View {
    func glassBackground(
        palette: ColorPalette,
        material: Material = .ultraThinMaterial,
        cornerRadius: CGFloat = 16
    ) -> some View {
        modifier(GlassBackground(
            palette: palette,
            material: material,
            cornerRadius: cornerRadius
        ))
    }
    
    func frostedGlassCard(
        palette: ColorPalette,
        elevation: FrostedGlassCard.GlassElevation = .medium
    ) -> some View {
        modifier(FrostedGlassCard(palette: palette, elevation: elevation))
    }
    
    func glassButton(palette: ColorPalette, isPressed: Bool = false) -> some View {
        modifier(GlassButton(palette: palette, isPressed: isPressed))
    }
    
    func shimmerEffect(palette: ColorPalette) -> some View {
        modifier(ShimmerEffect(palette: palette))
    }
    
    func floatingElement(palette: ColorPalette) -> some View {
        modifier(FloatingElement(palette: palette))
    }
}

// MARK: - Glass Tab Bar
struct GlassTabBar: View {
    let palette: ColorPalette
    
    var body: some View {
        HStack {
            Spacer()
        }
        .frame(height: 83) // Standard tab bar height + safe area
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Rectangle()
                        .fill(palette.backgroundGlass)
                }
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(palette.glassBorder)
                        .frame(height: 0.5)
                }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass Navigation Bar
struct GlassNavigationBar: ViewModifier {
    let palette: ColorPalette
    
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

extension View {
    func glassNavigationBar(palette: ColorPalette) -> some View {
        modifier(GlassNavigationBar(palette: palette))
    }
}