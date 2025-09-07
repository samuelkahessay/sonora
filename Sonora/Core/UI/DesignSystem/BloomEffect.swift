//
//  BloomEffect.swift
//  Sonora
//
//  One-shot bloom pulse overlay aligned with Sonora brand theming
//

import SwiftUI

enum BloomStyle: Equatable {
    case expand
    case collapse
}

struct BloomEvent: Equatable {
    let id: UUID
    let style: BloomStyle
}

struct BloomEffect: ViewModifier {
    @Binding var trigger: Bool
    var style: BloomStyle = .expand
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
            let scale: CGFloat = {
                switch style {
                case .expand:
                    return 1 + progress * 2.2
                case .collapse:
                    return 1 + (1 - progress) * 2.2
                }
            }()
            return AnyView(
                Circle()
                    .stroke(Color.insightGold.opacity(0.35), lineWidth: 10)
                    .frame(width: size, height: size)
                    .scaleEffect(scale)
                    .opacity(1 - progress)
                    .blendMode(.plusLighter)
                    .animation(SonoraDesignSystem.Animation.bloomTransition, value: progress)
            )
        } else {
            return AnyView(
                Circle()
                    .stroke(Color.insightGold.opacity(0.25), lineWidth: 10)
                    .frame(width: size, height: size)
                    .opacity(0.7)
            )
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
        modifier(BloomEffect(trigger: trigger, style: .expand))
    }
    
    func bloomPulse(trigger: Binding<Bool>, style: BloomStyle) -> some View {
        modifier(BloomEffect(trigger: trigger, style: style))
    }

    // Counter-based pulse (reliable on every increment)
    func bloomPulse(count: Binding<Int>, style: BloomStyle = .expand) -> some View {
        modifier(BloomEffectCounter(triggerCount: count, style: style))
    }

    // Event-based pulse that switches style with a single overlay (avoids stacking conflicts)
    func bloomPulse(event: Binding<BloomEvent>) -> some View {
        modifier(BloomEffectEvent(triggerEvent: event))
    }
}

// Counter-based variant to avoid boolean coalescing
private struct BloomEffectCounter: ViewModifier {
    @Binding var triggerCount: Int
    var style: BloomStyle = .expand
    @State private var lastSeen: Int = 0
    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                bloomLayer(size: size)
                    .opacity(progress > 0 ? 1 : 0)
                    .allowsHitTesting(false)
            }
        )
        .onChange(of: triggerCount) { _, newValue in
            guard newValue != lastSeen else { return }
            lastSeen = newValue
            run()
        }
    }

    @ViewBuilder
    private func bloomLayer(size: CGFloat) -> some View {
        if !SonoraAnimations.prefersReducedMotion {
            let scale: CGFloat = {
                switch style {
                case .expand:   return 1 + progress * 2.2
                case .collapse: return 1 + (1 - progress) * 2.2
                }
            }()
            AnyView(
                Circle()
                    .stroke(Color.insightGold.opacity(0.35), lineWidth: 10)
                    .frame(width: size, height: size)
                    .scaleEffect(scale)
                    .opacity(1 - progress)
                    .blendMode(.plusLighter)
                    .animation(SonoraDesignSystem.Animation.bloomTransition, value: progress)
            )
        } else {
            AnyView(
                Circle()
                    .stroke(Color.insightGold.opacity(0.25), lineWidth: 10)
                    .frame(width: size, height: size)
                    .opacity(0.7)
            )
        }
    }

    @MainActor
    private func run() {
        progress = 0
        withAnimation(SonoraDesignSystem.Animation.bloomTransition) {
            progress = 1
        }
        // No external reset; internal state fades naturally
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            progress = 0
        }
    }
}

// Single-overlay, event-driven pulse to prevent modifier stacking issues
private struct BloomEffectEvent: ViewModifier {
    @Binding var triggerEvent: BloomEvent
    @State private var lastSeenId: UUID = UUID()
    @State private var progress: CGFloat = 0
    @State private var currentStyle: BloomStyle = .expand

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                bloomLayer(size: size)
                    .opacity(progress > 0 ? 1 : 0)
                    .allowsHitTesting(false)
            }
        )
        .onChange(of: triggerEvent) { _, newValue in
            // Only react to new IDs
            guard newValue.id != lastSeenId else { return }
            lastSeenId = newValue.id
            currentStyle = newValue.style
            run()
        }
    }

    @ViewBuilder
    private func bloomLayer(size: CGFloat) -> some View {
        if !SonoraAnimations.prefersReducedMotion {
            let scale: CGFloat = {
                switch currentStyle {
                case .expand:   return 1 + progress * 2.2
                case .collapse: return 1 + (1 - progress) * 2.2
                }
            }()
            AnyView(
                Circle()
                    .stroke(Color.insightGold.opacity(0.35), lineWidth: 10)
                    .frame(width: size, height: size)
                    .scaleEffect(scale)
                    .opacity(1 - progress)
                    .blendMode(.plusLighter)
                    .animation(SonoraDesignSystem.Animation.bloomTransition, value: progress)
            )
        } else {
            AnyView(
                Circle()
                    .stroke(Color.insightGold.opacity(0.25), lineWidth: 10)
                    .frame(width: size, height: size)
                    .opacity(0.7)
            )
        }
    }

    @MainActor
    private func run() {
        progress = 0
        withAnimation(SonoraDesignSystem.Animation.bloomTransition) {
            progress = 1
        }
        // Natural fade; reset internal progress after transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            progress = 0
        }
    }
}
