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
extension View {
    // Event-based pulse that switches style with a single overlay (avoids stacking conflicts)
    func bloomPulse(event: Binding<BloomEvent>) -> some View {
        modifier(BloomEffectEvent(triggerEvent: event))
    }
}

// Single-overlay, event-driven pulse to prevent modifier stacking issues
private struct BloomEffectEvent: ViewModifier {
    @Binding var triggerEvent: BloomEvent
    @State private var lastSeenId = UUID()
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

            // Use logo gradient colors for the bloom effect
            let bloomGradient = AngularGradient(
                colors: [
                    Color.sonoraCoral,     // Bright coral
                    Color.sonoraWarmPink,  // Warm pink
                    Color.sonoraMagenta,   // Rich magenta
                    Color.sonoraPlum,      // Deep plum
                    Color.sonoraCoral      // Back to coral for seamless loop
                ],
                center: .center
            )

            AnyView(
                ZStack {
                    // Outer glow for visibility in dark mode
                    Circle()
                        .stroke(bloomGradient, lineWidth: 14)
                        .frame(width: size, height: size)
                        .scaleEffect(scale)
                        .opacity((1 - progress) * 0.4)
                        .blur(radius: 8)
                        .blendMode(.screen)

                    // Sharp gradient ring
                    Circle()
                        .stroke(bloomGradient, lineWidth: 10)
                        .frame(width: size, height: size)
                        .scaleEffect(scale)
                        .opacity((1 - progress) * 0.8)  // Increased opacity
                        .blendMode(.plusLighter)
                }
                .animation(SonoraDesignSystem.Animation.bloomTransition, value: progress)
            )
        } else {
            AnyView(
                Circle()
                    .stroke(Color.sonoraCoral.opacity(0.3), lineWidth: 10)
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
