import Foundation
import SwiftData

// MARK: - Schema V1 (Initial Release)

enum SeddlySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            LocalCommitment.self,
            LocalEntity.self,
            ProcessingQueue.self,
            PrivacyAuditEntry.self,
            CustomWorkflow.self
        ]
    }
}

// MARK: - Schema V2 (Template for next migration)

enum SeddlySchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        // Currently identical to V1. When a schema change is needed:
        // 1. Copy the V1 model classes here with the changes applied
        // 2. Add a migration stage in SeddlyMigrationPlan
        [
            LocalCommitment.self,
            LocalEntity.self,
            ProcessingQueue.self,
            PrivacyAuditEntry.self,
            CustomWorkflow.self
        ]
    }
}

// MARK: - Migration Plan

enum SeddlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SeddlySchemaV1.self, SeddlySchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    // V1 → V2: Lightweight migration (no data transformation needed yet)
    // When schema changes require data transformation, convert to .custom() with willMigrate/didMigrate closures
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SeddlySchemaV1.self,
        toVersion: SeddlySchemaV2.self
    )
}
