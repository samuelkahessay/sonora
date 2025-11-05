//
//  ComponentBadge.swift
//  Sonora
//
//  Created by Claude on 2025-11-04.
//  SSE streaming component badge for progressive loading UI
//

import SwiftUI

/// Small animated badge showing the current processing component during SSE streaming
struct ComponentBadge: View {
    let componentName: String

    var body: some View {
        Text(displayName(for: componentName))
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.2))
            .foregroundColor(.accentColor)
            .cornerRadius(12)
            .accessibilityLabel("Processing \(displayName(for: componentName))")
    }

    /// Maps internal component names to user-friendly display names
    private func displayName(for component: String) -> String {
        switch component {
        case "base":
            return "Summary"
        case "thinkingPatterns":
            return "Thinking Patterns"
        case "philosophicalEchoes":
            return "Wisdom"
        case "valuesInsights":
            return "Values"
        default:
            // Fallback: capitalize first letter of component name
            return component.prefix(1).uppercased() + component.dropFirst()
        }
    }
}

// MARK: - Preview
#Preview("Component Badge") {
    VStack(spacing: 16) {
        ComponentBadge(componentName: "base")
        ComponentBadge(componentName: "thinkingPatterns")
        ComponentBadge(componentName: "philosophicalEchoes")
        ComponentBadge(componentName: "valuesInsights")
    }
    .padding()
}
