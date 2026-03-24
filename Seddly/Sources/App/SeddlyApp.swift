import SwiftUI
import SwiftData

@main
struct SeddlyApp: App {
    let modelContainer: ModelContainer
    @State private var subscriptionService = SubscriptionService()
    @State private var calendarService = CalendarService()
    @State private var deepLinkCommitmentID: String?
    @State private var showDeepLinkNotFound = false

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
                .environment(calendarService)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .alert("Commitment Not Found", isPresented: $showDeepLinkNotFound) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("This commitment is not on this device.")
                }
        }
        .modelContainer(modelContainer)
    }

    private func handleDeepLink(_ url: URL) {
        // Handle seddly.com/c/{id} universal links
        guard url.host == "seddly.com" || url.host == "www.seddly.com",
              url.pathComponents.count >= 3,
              url.pathComponents[1] == "c" else { return }

        let commitmentShortID = url.pathComponents[2]
        deepLinkCommitmentID = commitmentShortID

        // Search for matching commitment by ID prefix
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<LocalCommitment>()
        guard let commitments = try? context.fetch(descriptor) else {
            showDeepLinkNotFound = true
            return
        }

        let match = commitments.first { commitment in
            commitment.id.uuidString.lowercased().hasPrefix(commitmentShortID.lowercased())
        }

        if match == nil {
            showDeepLinkNotFound = true
        }
        // Navigation to the matched commitment is handled by the NavigationStack in LedgerView
    }
}
