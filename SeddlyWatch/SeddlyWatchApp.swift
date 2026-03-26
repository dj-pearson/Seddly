import SwiftUI
import SwiftData
import WatchConnectivity

@main
struct SeddlyWatchApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try SharedModelContainer.create()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        WatchSyncService.shared.activate(with: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            WatchLedgerView()
        }
        .modelContainer(modelContainer)
    }
}
