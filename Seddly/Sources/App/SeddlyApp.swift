import SwiftUI
import SwiftData

@main
struct SeddlyApp: App {
    let modelContainer: ModelContainer
    @State private var subscriptionService = SubscriptionService()

    init() {
        do {
            modelContainer = try SharedModelContainer.create()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        Task {
            await BackgroundTaskService.shared.registerBackgroundTasks()
            await BackgroundTaskService.shared.scheduleNextRefresh()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(subscriptionService)
        }
        .modelContainer(modelContainer)
    }
}
