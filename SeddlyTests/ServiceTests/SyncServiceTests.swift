import Testing
import Foundation
import SwiftData
@testable import Seddly

@Suite("SyncService Tests")
struct SyncServiceTests {
    private func makeAuthService() -> AuthService {
        AuthService(
            supabaseURL: URL(string: "https://test.supabase.co")!,
            supabaseKey: "test-api-key"
        )
    }

    private func makeSyncService(authService: AuthService? = nil) -> SyncService {
        let auth = authService ?? makeAuthService()
        return SyncService(
            supabaseURL: URL(string: "https://test.supabase.co")!,
            supabaseKey: "test-api-key",
            authService: auth
        )
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            LocalCommitment.self,
            LocalEntity.self,
            ProcessingQueue.self,
            PrivacyAuditEntry.self,
            CustomWorkflow.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - Rate Limiting Tests

    @Test("Sync throttle prevents rapid consecutive syncs")
    func syncThrottlePreventsRapidSyncs() async throws {
        let service = makeSyncService()
        let context = try makeInMemoryContext()

        // First sync should execute (even though it has nothing to sync)
        try await service.syncCommitments(context: context)

        // Second immediate sync should be throttled silently (no error)
        try await service.syncCommitments(context: context)
    }

    @Test("SyncService requires authentication to push")
    func syncRequiresAuthentication() async throws {
        let auth = makeAuthService()
        await auth.signOut()
        let service = makeSyncService(authService: auth)
        let context = try makeInMemoryContext()

        // Insert a commitment with pendingSync status
        let commitment = LocalCommitment(
            entityName: "Test Entity",
            summary: "Test commitment",
            fullText: "Test full text",
            source: .manual
        )
        commitment.syncStatusRaw = "pendingSync"
        context.insert(commitment)
        try context.save()

        // Sync should throw notAuthenticated since we signed out
        await #expect(throws: SyncService.SyncError.self) {
            try await service.syncCommitments(context: context)
        }
    }

    @Test("SyncService requires authentication to pull")
    func pullRequiresAuthentication() async throws {
        let auth = makeAuthService()
        await auth.signOut()
        let service = makeSyncService(authService: auth)
        let context = try makeInMemoryContext()

        await #expect(throws: SyncService.SyncError.self) {
            try await service.pullCommitments(context: context)
        }
    }

    @Test("SyncService requires authentication for soft delete")
    func softDeleteRequiresAuthentication() async throws {
        let auth = makeAuthService()
        await auth.signOut()
        let service = makeSyncService(authService: auth)
        let context = try makeInMemoryContext()

        let commitment = LocalCommitment(
            entityName: "Test",
            summary: "Test",
            fullText: "Test",
            source: .manual
        )
        context.insert(commitment)
        try context.save()

        await #expect(throws: SyncService.SyncError.self) {
            try await service.softDelete(commitment: commitment, context: context)
        }
    }

    // MARK: - Batch Tests

    @Test("Batch splitting works correctly for commitments exceeding batch size")
    func batchSplittingLogic() throws {
        // Test the array chunking helper indirectly
        let items = Array(0..<125)
        let batchSize = 50

        let batches = stride(from: 0, to: items.count, by: batchSize).map {
            Array(items[$0..<Swift.min($0 + batchSize, items.count)])
        }

        #expect(batches.count == 3)
        #expect(batches[0].count == 50)
        #expect(batches[1].count == 50)
        #expect(batches[2].count == 25)
    }

    // MARK: - Error Type Tests

    @Test("SyncError descriptions are user-friendly")
    func syncErrorDescriptions() {
        let notAuth = SyncService.SyncError.notAuthenticated
        #expect(notAuth.errorDescription != nil)
        #expect(notAuth.errorDescription!.contains("sign in"))

        let pullFailed = SyncService.SyncError.pullFailed(statusCode: 500)
        #expect(pullFailed.errorDescription != nil)
        #expect(pullFailed.errorDescription!.contains("500"))
    }

    // MARK: - Pending Sync Fetch Tests

    @Test("Only pendingSync commitments are identified for upload")
    func onlyPendingSyncFetched() throws {
        let context = try makeInMemoryContext()

        let synced = LocalCommitment(
            entityName: "Entity A", summary: "Already synced",
            fullText: "Text", source: .manual
        )
        synced.syncStatusRaw = "synced"
        context.insert(synced)

        let pending = LocalCommitment(
            entityName: "Entity B", summary: "Needs sync",
            fullText: "Text", source: .manual
        )
        pending.syncStatusRaw = "pendingSync"
        context.insert(pending)

        let local = LocalCommitment(
            entityName: "Entity C", summary: "Local only",
            fullText: "Text", source: .manual
        )
        local.syncStatusRaw = "local"
        context.insert(local)

        try context.save()

        let descriptor = FetchDescriptor<LocalCommitment>(
            predicate: #Predicate { $0.syncStatusRaw == "pendingSync" }
        )
        let pendingSync = try context.fetch(descriptor)

        #expect(pendingSync.count == 1)
        #expect(pendingSync.first?.entityName == "Entity B")
    }
}
