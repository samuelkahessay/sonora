import Foundation

/// Components a user can include in an export bundle.
enum ExportComponent: Hashable, CaseIterable {
    case memos
    case transcripts
    case analysis
}

/// Scope of content to include. v1 ships with full backups only, but the type allows future filtering.
enum ExportScope: Equatable {
    case all
}

/// High-level description of an export request flowing from presentation to the domain layer.
struct ExportRequest: Equatable {
    var components: Set<ExportComponent>
    var scope: ExportScope

    init(components: Set<ExportComponent>, scope: ExportScope = .all) {
        self.components = components
        self.scope = scope
    }

    static let fullBackup = ExportRequest(components: Set(ExportComponent.allCases), scope: .all)
}
