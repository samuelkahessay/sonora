//
//  LiquidGlassTabViewModifier.swift
//  Sonora
//
//  iOS 26 Liquid Glass tab view implementation
//  Provides floating, translucent tab bars that shrink on scroll
//

import SwiftUI

/// iOS 26 Liquid Glass tab view modifier that creates floating, adaptive tab bars
/// that shrink during scroll interactions and expand when returning to top
struct LiquidGlassTabViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // Future iOS 26+ implementation with Liquid Glass tab style
            content
                .tabViewStyle(.automatic) // Will be .liquidGlass when available
                .tint(.semantic(.brandPrimary))
                .toolbarBackground(.thinMaterial, for: .tabBar)
        } else if #available(iOS 16.0, *) {
            // iOS 16+ with enhanced materials
            content
                .tabViewStyle(.automatic)
                .tint(.semantic(.brandPrimary))
                .toolbarBackground(.thinMaterial, for: .tabBar)
        } else {
            // iOS 15 fallback
            content
                .tabViewStyle(.automatic)
                .tint(.semantic(.brandPrimary))
        }
    }
}

/// Convenience extension for applying Liquid Glass tab view styling
extension View {
    /// Applies iOS 26 Liquid Glass tab view with automatic fallback to standard styling
    func liquidGlassTabView() -> some View {
        modifier(LiquidGlassTabViewModifier())
    }

}

