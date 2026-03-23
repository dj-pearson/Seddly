import SwiftData

enum SharedModelContainer {
    static func create() throws -> ModelContainer {
        let schema = Schema([
            LocalCommitment.self,
            LocalEntity.self,
            ProcessingQueue.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppConstants.appGroupIdentifier)
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
