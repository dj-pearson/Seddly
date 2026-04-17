import SwiftUI
import SwiftData
import WatchConnectivity

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
    @AppStorage("deepLinkCommitmentID") private var deepLinkCommitmentID: String?
    @State private var showDeepLinkNotFound = false
    @State private var showMigrationError = false
    @State private var showDowngradeAlert = false
    private let migrationErrorMessage: String?
    /// True when running on a fallback in-memory container due to migration failure.
    private let isRunningInMemory: Bool

    init() {
        var migrationError: String?
        do {
            modelContainer = try SharedModelContainer.create()
        } catch {
            migrationError = error.localizedDescription
            // Fall back to a fresh in-memory container so the app doesn't crash
            do {
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
                modelContainer = try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                fatalError("Failed to create even in-memory ModelContainer: \(error)")
            }
        }
        self.migrationErrorMessage = migrationError
        self.isRunningInMemory = migrationError != nil

        // US-147: Route Supabase credential lookup through AppConfiguration so a
        // missing / placeholder value is caught once (crash in DEBUG, degrade in
        // RELEASE) instead of letting every call site silently fall back.
        authService = AuthService(
            supabaseURL: AppConfiguration.supabaseURLOrPlaceholder,
            supabaseKey: AppConfiguration.supabaseAnonKeyOrEmpty
        )

        if migrationError == nil {
            WatchSyncService.shared.activate(with: modelContainer)
        }

        Task {
            await BackgroundTaskService.shared.registerBackgroundTasks()
            await BackgroundTaskService.shared.scheduleNextRefresh()
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                ContentView()
                    .environment(subscriptionService)
                    .environment(calendarService)
                    .environment(\.authService, authService)

                if isRunningInMemory {
                    migrationWarningBanner
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .alert("Commitment Not Found", isPresented: $showDeepLinkNotFound) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This commitment is not on this device.")
            }
            .alert("Data Migration Issue", isPresented: $showMigrationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your data could not be migrated. The app is running with temporary storage — any changes will be lost when you close the app.\n\nPlease reinstall the app or contact support at seddly.com/help to restore your data.")
            }
            .onAppear {
                if migrationErrorMessage != nil {
                    showMigrationError = true
                }
            }
                .onChange(of: subscriptionService.tierDowngradeDetected) { _, detected in
                    if detected {
                        handleTierDowngrade()
                        showDowngradeAlert = true
                    }
                }
                .alert("Subscription Changed", isPresented: $showDowngradeAlert) {
                    Button("OK", role: .cancel) {
                        subscriptionService.dismissDowngradeAlert()
                    }
                } message: {
                    Text(subscriptionService.downgradeMessage)
                }
        }
        .modelContainer(modelContainer)
    }

    private var migrationWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text("Temporary storage — data will not persist. Reinstall to fix.")
                .font(.caption)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.red.gradient)
    }

    private func handleTierDowngrade() {
        let newTier = subscriptionService.currentTier
        let oldTier = subscriptionService.previousTier

        // Sign out of Supabase when downgrading from Pro+
        if oldTier == .proPlus && newTier < .proPlus {
            Task {
                await authService.signOut()
            }
            let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
            defaults.set(false, forKey: "isSignedIn")
        }
    }

    private func handleDeepLink(_ url: URL) {
        let commitmentID: String?

        if url.scheme == "seddly" {
            // Handle seddly://commitment/{id} widget deep links
            guard url.host == "commitment",
                  let id = url.pathComponents.dropFirst().first else { return }
            commitmentID = id
        } else {
            // Handle seddly.com/c/{id} universal links
            guard url.host == "seddly.com" || url.host == "www.seddly.com",
                  url.pathComponents.count >= 3,
                  url.pathComponents[1] == "c" else { return }
            commitmentID = url.pathComponents[2]
        }

        guard let commitmentID else { return }
        deepLinkCommitmentID = commitmentID

        // US-146: Resolve the deep link with a bounded predicate fetch instead of
        // loading every commitment into memory. Try an exact UUID match first,
        // then fall back to a prefix scan with fetchLimit = 1 for legacy short IDs.
        let context = modelContainer.mainContext
        let normalized = commitmentID.lowercased()

        if let exactUUID = UUID(uuidString: commitmentID) {
            var descriptor = FetchDescriptor<LocalCommitment>(
                predicate: #Predicate { $0.id == exactUUID }
            )
            descriptor.fetchLimit = 1
            if let match = try? context.fetch(descriptor).first, match != nil {
                return // NavigationStack in LedgerView handles routing via deepLinkCommitmentID
            }
            showDeepLinkNotFound = true
            return
        }

        // Prefix fallback: fetch a small sorted page, then scan.
        var descriptor = FetchDescriptor<LocalCommitment>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        guard let candidates = try? context.fetch(descriptor) else {
            showDeepLinkNotFound = true
            return
        }
        let match = candidates.first { commitment in
            commitment.id.uuidString.lowercased().hasPrefix(normalized)
        }
        if match == nil {
            showDeepLinkNotFound = true
        }
    }
}
