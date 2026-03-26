import SwiftData
import os

enum SharedModelContainer {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.pearsonmedia.Seddly", category: "SharedModelContainer")

    static func create() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SeddlySchemaV2.self)
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppConstants.appGroupIdentifier)
        )
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: SeddlyMigrationPlan.self,
                configurations: [config]
            )
            logger.info("ModelContainer created successfully with migration plan")
            return container
        } catch {
            logger.error("Migration failed: \(error.localizedDescription)")
            throw MigrationError.migrationFailed(underlying: error)
        }
    }

    enum MigrationError: LocalizedError {
        case migrationFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .migrationFailed(let underlying):
                "Data migration failed: \(underlying.localizedDescription)"
            }
        }

        var recoverySuggestion: String? {
            "Try reinstalling the app. If the problem persists, contact support."
        }
    }
}
