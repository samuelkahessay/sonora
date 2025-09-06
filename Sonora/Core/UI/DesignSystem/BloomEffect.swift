//
//  BloomEffect.swift
//  Sonora
//
//  One-shot bloom pulse overlay aligned with Sonora brand theming
//

import SwiftUI

struct BloomEffect: ViewModifier {
    @Binding var trigger: Bool
    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                bloomLayer(size: size)
                    .opacity(trigger ? 1 : 0)
                    .allowsHitTesting(false)
            }
        )
        .onChange(of: trigger) { _, newValue in
            guard newValue else { return }
            run()
        }
    }

    @ViewBuilder
    private func bloomLayer(size: CGFloat) -> some View {
        if !SonoraAnimations.prefersReducedMotion {
            Circle()
                .stroke(Color.insightGold.opacity(0.35), lineWidth: 10)
                .frame(width: size, height: size)
                .scaleEffect(1 + progress * 2.2)
                .opacity(1 - progress)
                .blendMode(.plusLighter)
                .animation(SonoraDesignSystem.Animation.bloomTransition, value: progress)
        } else {
            Circle()
                .stroke(Color.insightGold.opacity(0.25), lineWidth: 10)
                .frame(width: size, height: size)
                .opacity(0.7)
        }
    }

    @MainActor
    private func run() {
        progress = 0
        withAnimation(SonoraDesignSystem.Animation.bloomTransition) {
            progress = 1
        }
        // Reset trigger after the animation window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            trigger = false
        }
    }
}

extension View {
    func bloomPulse(trigger: Binding<Bool>) -> some View {
        modifier(BloomEffect(trigger: trigger))
    }
}

