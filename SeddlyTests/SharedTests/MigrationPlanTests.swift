import Testing
import SwiftData
@testable import Seddly

@Suite("SeddlyMigrationPlan Tests")
struct MigrationPlanTests {

    @Test("Migration plan defines correct schema versions in order")
    func schemaVersionsOrder() {
        let schemas = SeddlyMigrationPlan.schemas
        #expect(schemas.count == 2)
        #expect(schemas[0] == SeddlySchemaV1.self)
        #expect(schemas[1] == SeddlySchemaV2.self)
    }

    @Test("Migration plan has one stage per version transition")
    func stageCount() {
        let stages = SeddlyMigrationPlan.stages
        let schemas = SeddlyMigrationPlan.schemas
        #expect(stages.count == schemas.count - 1)
    }

    @Test("V1 schema contains all five models")
    func v1ModelsComplete() {
        let models = SeddlySchemaV1.models
        #expect(models.count == 5)
        let modelNames = Set(models.map { String(describing: $0) })
        #expect(modelNames.contains("LocalCommitment"))
        #expect(modelNames.contains("LocalEntity"))
        #expect(modelNames.contains("ProcessingQueue"))
        #expect(modelNames.contains("PrivacyAuditEntry"))
        #expect(modelNames.contains("CustomWorkflow"))
    }

    @Test("V2 schema contains all five models")
    func v2ModelsComplete() {
        let models = SeddlySchemaV2.models
        #expect(models.count == 5)
        let modelNames = Set(models.map { String(describing: $0) })
        #expect(modelNames.contains("LocalCommitment"))
        #expect(modelNames.contains("LocalEntity"))
        #expect(modelNames.contains("ProcessingQueue"))
        #expect(modelNames.contains("PrivacyAuditEntry"))
        #expect(modelNames.contains("CustomWorkflow"))
    }

    @Test("Schema version identifiers are sequential")
    func versionIdentifiers() {
        let v1 = SeddlySchemaV1.versionIdentifier
        let v2 = SeddlySchemaV2.versionIdentifier
        #expect(v1 < v2)
    }

    @Test("ModelContainer can be created with migration plan using in-memory config")
    func containerCreationWithMigrationPlan() throws {
        let schema = Schema(versionedSchema: SeddlySchemaV2.self)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: SeddlyMigrationPlan.self,
            configurations: [config]
        )
        #expect(container.schema.entities.count == 5)
    }
}
