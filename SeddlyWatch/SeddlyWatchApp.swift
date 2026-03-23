import SwiftUI
import SwiftData

@main
struct SeddlyWatchApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try SharedModelContainer.create()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchLedgerView()
        }
        .modelContainer(modelContainer)
    }
}
