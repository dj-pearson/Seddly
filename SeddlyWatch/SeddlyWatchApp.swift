import SwiftUI
import SwiftData
import WatchConnectivity

@main
struct SeddlyWatchApp: App {
    let modelContainer: ModelContainer
    private let containerFailed: Bool

    init() {
        do {
            modelContainer = try SharedModelContainer.create()
            containerFailed = false
        } catch {
            // Fall back to in-memory container instead of crashing
            let schema = Schema([
                LocalCommitment.self,
                LocalEntity.self,
                ProcessingQueue.self,
                PrivacyAuditEntry.self,
                CustomWorkflow.self
            ])
            let fallbackConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            // If even in-memory fails, use an empty container as last resort
            if let fallback = try? ModelContainer(for: schema, configurations: [fallbackConfig]) {
                modelContainer = fallback
            } else {
                modelContainer = try! ModelContainer(for: schema)
            }
            containerFailed = true
        }

        if !containerFailed {
            WatchSyncService.shared.activate(with: modelContainer)
        }
    }

    var body: some Scene {
        WindowGroup {
            if containerFailed {
                ContentUnavailableView(
                    "Data Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Unable to load your data. Please re-pair with your iPhone or reinstall the app.")
                )
            } else {
                WatchLedgerView()
            }
        }
        .modelContainer(modelContainer)
    }
}
