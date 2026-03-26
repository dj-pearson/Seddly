import SwiftUI
import SwiftData

// MARK: - AuthService Environment Key

private struct AuthServiceKey: EnvironmentKey {
    static let defaultValue: AuthService = AuthService(
        supabaseURL: URL(string: "https://placeholder.supabase.co")!,
        supabaseKey: ""
    )
}

extension EnvironmentValues {
    var authService: AuthService {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
}

@main
struct SeddlyApp: App {
    let modelContainer: ModelContainer
    @State private var subscriptionService = SubscriptionService()
    @State private var calendarService = CalendarService()
    private let authService: AuthService
    @State private var deepLinkCommitmentID: String?
    @State private var showDeepLinkNotFound = false

    init() {
        do {
            modelContainer = try SharedModelContainer.create()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Read Supabase credentials from Info.plist
        let supabaseURLString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
        let supabaseKey = Bundle.main.infoDictionary?["SUPABASE_KEY"] as? String ?? ""
        let supabaseURL = URL(string: supabaseURLString) ?? URL(string: "https://placeholder.supabase.co")!
        authService = AuthService(supabaseURL: supabaseURL, supabaseKey: supabaseKey)

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
                .environment(\.authService, authService)
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
