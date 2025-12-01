import SwiftData
import Foundation

// Legacy model snapshots for V1/V2 live in LegacySchemaV1Models.swift and LegacySchemaV2Models.swift.
// MARK: - Schema V1 (Before AutoDistillJob)
enum SonoraSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            MemoModelV1.self,
            TranscriptionModelV1.self,
            AnalysisResultModelV1.self,
            AutoTitleJobModelV1.self
        ]
    }
}

// MARK: - Schema V2 (With AutoDistillJob)
enum SonoraSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            MemoModelV2.self,
            TranscriptionModelV2.self,
            AnalysisResultModelV2.self,
            AutoTitleJobModelV2.self,
            AutoDistillJobModelV2.self  // NEW
        ]
    }
}

// MARK: - Schema V3 (Current - Remove nextRetryAt)
enum SonoraSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            MemoModel.self,
            TranscriptionModel.self,
            AnalysisResultModel.self,
            AutoTitleJobModel.self,
            AutoDistillJobModel.self
        ]
    }
}

// MARK: - Migration Plan
enum SonoraVersionedSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SonoraSchemaV1.self, SonoraSchemaV2.self, SonoraSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [
            // V1 -> V2: Lightweight migration (additive only)
            // SwiftData automatically handles adding new model + relationship
            // All existing MemoModel instances get nil autoDistillJob
            migrateV1toV2,

            // V2 -> V3: Lightweight migration (remove nextRetryAt from both job models)
            // SwiftData automatically handles column removal
            migrateV2toV3
        ]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SonoraSchemaV1.self,
        toVersion: SonoraSchemaV2.self
    )

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: SonoraSchemaV2.self,
        toVersion: SonoraSchemaV3.self
    )
}

// Current schema alias
typealias SonoraCurrentSchema = SonoraSchemaV3
