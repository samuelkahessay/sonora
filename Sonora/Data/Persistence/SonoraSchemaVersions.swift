import SwiftData
import Foundation

// MARK: - Schema V1 (Before AutoDistillJob)
enum SonoraSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            MemoModel.self,
            TranscriptionModel.self,
            AnalysisResultModel.self,
            AutoTitleJobModel.self
        ]
    }
}

// MARK: - Schema V2 (Current - With AutoDistillJob)
enum SonoraSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            MemoModel.self,
            TranscriptionModel.self,
            AnalysisResultModel.self,
            AutoTitleJobModel.self,
            AutoDistillJobModel.self  // NEW
        ]
    }
}

// MARK: - Migration Plan
enum SonoraVersionedSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SonoraSchemaV1.self, SonoraSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            // V1 -> V2: Lightweight migration (additive only)
            // SwiftData automatically handles adding new model + relationship
            // All existing MemoModel instances get nil autoDistillJob
            migrateV1toV2
        ]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SonoraSchemaV1.self,
        toVersion: SonoraSchemaV2.self
    )
}

// Current schema alias
typealias SonoraCurrentSchema = SonoraSchemaV2
