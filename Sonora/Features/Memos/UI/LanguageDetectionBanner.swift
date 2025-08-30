import SwiftUI

struct LanguageDetectionBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .foregroundColor(.orange)
                .imageScale(.medium)
                .accessibilityHidden(true)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityLabel(message)
                .accessibilityAddTraits(.isStaticText)
            
            Spacer(minLength: 8)
            
            Button("Dismiss") {
                onDismiss()
            }
            .font(.caption)
            .foregroundColor(.blue)
            .accessibilityLabel("Dismiss language notice")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

