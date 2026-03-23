import SwiftData

enum PersistenceService {
    static func previewContainer() throws -> ModelContainer {
        let schema = Schema([
            LocalCommitment.self,
            LocalEntity.self,
            ProcessingQueue.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
