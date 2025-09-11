import SwiftUI

struct InspireMeSheet: View {
    let didSelect: (PromptCategory) -> Void

    private let categories: [PromptCategory] = PromptCategory.allCases

    var body: some View {
        NavigationStack {
            List(categories, id: \.self) { category in
                Button(action: { didSelect(category) }) {
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: category))
                            .foregroundStyle(.secondary)
                        Text(title(for: category))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Inspire Me")
        }
    }

    private func title(for category: PromptCategory) -> String {
        switch category {
        case .growth: return "Growth"
        case .work: return "Work"
        case .relationships: return "Relationships"
        case .creative: return "Creative"
        case .goals: return "Goals"
        case .mindfulness: return "Mindfulness"
        }
    }

    private func icon(for category: PromptCategory) -> String {
        switch category {
        case .growth: return "leaf"
        case .work: return "briefcase"
        case .relationships: return "heart"
        case .creative: return "paintbrush"
        case .goals: return "target"
        case .mindfulness: return "brain.head.profile"
        }
    }
}

