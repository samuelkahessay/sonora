//
//  LiquidGlassNavigationModifier.swift
//  Sonora
//
//  iOS 26 Liquid Glass navigation implementation
//  Provides dynamic transparency and content-aware adaptation
//

import SwiftUI

/// Future-proof title display mode enum for iOS 26 Liquid Glass navigation
enum LiquidGlassTitleDisplayMode {
    case automatic
    case inline
    case inlineLarge  // Future iOS 26 feature
    case large
}

/// iOS 26 Liquid Glass navigation modifier that creates floating, translucent navigation bars
/// that dynamically adapt to content underneath with smooth material transitions
struct LiquidGlassNavigationModifier: ViewModifier {
    let titleDisplayMode: LiquidGlassTitleDisplayMode
    let enableContentAdaptation: Bool

    init(
        titleDisplayMode: LiquidGlassTitleDisplayMode = .automatic,
        enableContentAdaptation: Bool = true
    ) {
        self.titleDisplayMode = titleDisplayMode
        self.enableContentAdaptation = enableContentAdaptation
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // Future iOS 26+ implementation with Liquid Glass
            content
                .navigationBarTitleDisplayMode(titleDisplayMode.fallbackMode)
                .toolbarBackground(.thinMaterial, for: .navigationBar)
                .background(liquidGlassBackground)
        } else if #available(iOS 16.0, *) {
            // iOS 16+ with enhanced materials
            content
                .navigationBarTitleDisplayMode(titleDisplayMode.fallbackMode)
                .toolbarBackground(.thinMaterial, for: .navigationBar)
        } else {
            // iOS 15 fallback
            content
                .navigationBarTitleDisplayMode(titleDisplayMode.fallbackMode)
        }
    }

    /// Dynamic background that adapts to content for Liquid Glass effect
    @ViewBuilder
    private var liquidGlassBackground: some View {
        if enableContentAdaptation {
            GeometryReader { proxy in
                if #available(iOS 26.0, *) {
                    LiquidGlassBackground()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Fallback background for pre-iOS 26
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .ignoresSafeArea(.all)
        }
    }
}

/// iOS 26 Liquid Glass background implementation
@available(iOS 26.0, *)
private struct LiquidGlassBackground: View {
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Dynamic material that reacts to content
            Rectangle()
                .fill(.ultraThinMaterial) // Use available material until .liquidGlass is implemented
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .primary.opacity(scrollOffset > 50 ? 0.05 : 0.02)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .animation(.easeInOut(duration: 0.3), value: scrollOffset)
        }
        .background(.ultraThinMaterial)
        .onPreferenceChange(LiquidGlassScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
        }
    }
}

/// Fallback conversion for current iOS versions
extension LiquidGlassTitleDisplayMode {
    fileprivate var fallbackMode: NavigationBarItem.TitleDisplayMode {
        switch self {
        case .automatic:
            return .automatic
        case .inline:
            return .inline
        case .inlineLarge:
            return .large  // Best approximation for future inlineLarge
        case .large:
            return .large
        }
    }
}

/// ScrollView offset tracking for dynamic effects (Liquid Glass specific)
struct LiquidGlassScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Convenience extension for applying Liquid Glass navigation
extension View {
    /// Applies iOS 26 Liquid Glass navigation with automatic fallback to iOS 18 patterns
    func liquidGlassNavigation(
        titleDisplayMode: LiquidGlassTitleDisplayMode = .automatic,
        enableContentAdaptation: Bool = true
    ) -> some View {
        modifier(LiquidGlassNavigationModifier(
            titleDisplayMode: titleDisplayMode,
            enableContentAdaptation: enableContentAdaptation
        ))
    }

}

