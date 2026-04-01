import Foundation
import SwiftData
import os

/// Handles Pro+ cloud sync between local SwiftData and Supabase.
actor SyncService {
    private let supabaseURL: URL
    private let supabaseKey: String
    private let authService: AuthService

    private static let pushBatchSize = 50
    private static let pushBatchDelayMs: UInt64 = 500_000_000 // 500ms in nanoseconds
    private static let pullPageSize = 100
    private static let minSyncIntervalSeconds: TimeInterval = 30

    /// Maximum retry attempts for retriable HTTP errors (429, 5xx).
    private static let maxRetryAttempts = 3

    /// Tracks the last sync time to enforce client-side rate limiting.
    private var lastSyncTime: Date?

    /// Reports sync progress as (completed, total).
    struct SyncProgress {
        var pushed: Int = 0
        var pulled: Int = 0
        var totalToPush: Int = 0
    }

    init(supabaseURL: URL, supabaseKey: String, authService: AuthService) {
        self.supabaseURL = supabaseURL
        self.supabaseKey = supabaseKey
        self.authService = authService
    }

    /// Returns a valid Bearer token from AuthService, throwing if not authenticated.
    private func bearerToken() async throws -> String {
        guard let token = await authService.validAccessToken() else {
            throw SyncError.notAuthenticated
        }
        return token
    }

    /// Determines if an HTTP status code is retriable (429 or 5xx).
    private func isRetriableStatus(_ statusCode: Int) -> Bool {
        statusCode == 429 || (500...599).contains(statusCode)
    }

    /// Calculates retry delay, respecting Retry-After header if present.
    private func retryDelay(attempt: Int, response: HTTPURLResponse?) -> UInt64 {
        if let retryAfter = response?.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(retryAfter) {
            return UInt64(seconds * 1_000_000_000)
        }
        // Exponential backoff: 2s, 4s, 8s
        return UInt64(pow(2.0, Double(attempt + 1))) * 1_000_000_000
    }

    func syncCommitments(context: ModelContext) async throws {
        // Client-side rate limiting: prevent more than 1 sync per 30 seconds
        if let lastSync = lastSyncTime,
           Date().timeIntervalSince(lastSync) < Self.minSyncIntervalSeconds {
            AppLogger.sync.info("Sync throttled — last sync was \(Int(Date().timeIntervalSince(lastSync)))s ago")
            return
        }

        lastSyncTime = Date()

        // Fetch local commitments that need syncing
        let descriptor = FetchDescriptor<LocalCommitment>(
            predicate: #Predicate { $0.syncStatusRaw == "pendingSync" }
        )
        let pendingSync = try context.fetch(descriptor)

        guard !pendingSync.isEmpty else { return }

        // Upload to Supabase in batches of 50
        let endpoint = supabaseURL.appendingPathComponent("rest/v1/commitments")
        var progress = SyncProgress(totalToPush: pendingSync.count)
        let token = try await bearerToken()

        for batch in pendingSync.chunked(into: Self.pushBatchSize) {
            for commitment in batch {
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
                request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

                let payload: [String: Any?] = [
                    "id": commitment.id.uuidString,
                    "entity_name": commitment.entityName,
                    "summary": commitment.summary,
                    "full_text": commitment.fullText,
                    "deadline": commitment.deadline?.ISO8601Format(),
                    "dollar_amount": commitment.dollarAmount.map { NSDecimalNumber(decimal: $0).doubleValue },
                    "status": commitment.statusRaw,
                    "confidence": commitment.confidenceScore,
                    "ai_reasoning": commitment.aiReasoning,
                    "source": commitment.sourceRaw,
                    "category": commitment.categoryRaw ?? "uncategorized",
                    "screenshot_date": commitment.screenshotDate?.ISO8601Format(),
                    "notes": commitment.notes,
                    "calendar_event_id": commitment.calendarEventID,
                    "custom_status_label": commitment.customStatusLabel,
                    "workflow_id": commitment.workflowID?.uuidString,
                ]

                request.httpBody = try JSONSerialization.data(
                    withJSONObject: payload.compactMapValues { $0 }
                )

                var lastStatusCode = -1
                var succeeded = false

                for attempt in 0...Self.maxRetryAttempts {
                    let (_, response) = try await CertificatePinningService.session.data(for: request)
                    let httpResponse = response as? HTTPURLResponse
                    let statusCode = httpResponse?.statusCode ?? -1
                    lastStatusCode = statusCode

                    if (200...299).contains(statusCode) {
                        commitment.syncStatus = .synced
                        commitment.updatedAt = .now
                        progress.pushed += 1
                        succeeded = true
                        break
                    } else if statusCode == 401 {
                        // Token expired during sync — refresh and retry once
                        if let newToken = await authService.handleUnauthorizedResponse() {
                            request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                            continue
                        } else {
                            AppLogger.sync.error("Sync auth failed — user signed out")
                            throw SyncError.notAuthenticated
                        }
                    } else if isRetriableStatus(statusCode) && attempt < Self.maxRetryAttempts {
                        let delay = retryDelay(attempt: attempt, response: httpResponse)
                        AppLogger.sync.warning("Sync push got \(statusCode), retrying in \(delay / 1_000_000_000)s (attempt \(attempt + 1)/\(Self.maxRetryAttempts))")
                        try? await Task.sleep(nanoseconds: delay)
                        continue
                    } else {
                        break
                    }
                }

                if !succeeded {
                    AppLogger.sync.error("Sync push failed for commitment \(commitment.id) with status \(lastStatusCode)")
                }
            }

            // Save after each batch to preserve partial progress
            try context.save()

            // Delay between batches to avoid network storms
            if batch.count == Self.pushBatchSize {
                try? await Task.sleep(nanoseconds: Self.pushBatchDelayMs)
            }
        }

        AppLogger.sync.info("Sync push complete: \(progress.pushed)/\(progress.totalToPush) items synced")
    }

    func pullCommitments(context: ModelContext) async throws {
        struct RemoteCommitment: Codable {
            let id: String
            let entity_name: String
            let summary: String
            let full_text: String
            let deadline: String?
            let dollar_amount: Double?
            let status: String
            let confidence: Int
            let ai_reasoning: String?
            let source: String
            let category: String?
            let screenshot_date: String?
            let notes: String?
            let calendar_event_id: String?
            let custom_status_label: String?
            let workflow_id: String?
        }

        let isoFormatter = ISO8601DateFormatter()
        var offset = 0
        var hasMore = true
        var progress = SyncProgress()

        // Pre-fetch all local commitment IDs to avoid N+1 queries
        let allLocalDescriptor = FetchDescriptor<LocalCommitment>()
        let localIDs = Set((try context.fetch(allLocalDescriptor)).map(\.id))

        var currentToken = try await bearerToken()

        while hasMore {
            var components = URLComponents(url: supabaseURL.appendingPathComponent("rest/v1/commitments"), resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "limit", value: "\(Self.pullPageSize)"),
                URLQueryItem(name: "offset", value: "\(offset)"),
                URLQueryItem(name: "order", value: "created_at.asc"),
            ]

            var request = URLRequest(url: components.url!)
            request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

            var fetchedData = Data()
            var lastStatusCode = -1

            // Retry loop for pull requests
            var fetchSucceeded = false
            for attempt in 0...Self.maxRetryAttempts {
                let (responseData, response) = try await CertificatePinningService.session.data(for: request)
                let httpResponse = response as? HTTPURLResponse
                let statusCode = httpResponse?.statusCode ?? -1
                lastStatusCode = statusCode

                if (200...299).contains(statusCode) {
                    fetchedData = responseData
                    fetchSucceeded = true
                    break
                } else if statusCode == 401 {
                    if let newToken = await authService.handleUnauthorizedResponse() {
                        currentToken = newToken
                        request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                        continue
                    } else {
                        throw SyncError.notAuthenticated
                    }
                } else if isRetriableStatus(statusCode) && attempt < Self.maxRetryAttempts {
                    let delay = retryDelay(attempt: attempt, response: httpResponse)
                    AppLogger.sync.warning("Sync pull got \(statusCode), retrying in \(delay / 1_000_000_000)s (attempt \(attempt + 1)/\(Self.maxRetryAttempts))")
                    try? await Task.sleep(nanoseconds: delay)
                    continue
                } else {
                    break
                }
            }

            guard fetchSucceeded else {
                AppLogger.sync.error("Sync pull failed with status \(lastStatusCode)")
                throw SyncError.pullFailed(statusCode: lastStatusCode)
            }

            let remoteCommitments = try JSONDecoder().decode([RemoteCommitment].self, from: fetchedData)

            for remote in remoteCommitments {
                guard let uuid = UUID(uuidString: remote.id) else { continue }

                if localIDs.contains(uuid) {
                    continue // Already exists locally
                }

                let commitment = LocalCommitment(
                    entityName: remote.entity_name,
                    summary: remote.summary,
                    fullText: remote.full_text,
                    deadline: remote.deadline.flatMap { isoFormatter.date(from: $0) },
                    dollarAmount: remote.dollar_amount.map { Decimal($0) },
                    status: CommitmentStatus(rawValue: remote.status) ?? .pending,
                    confidenceScore: remote.confidence,
                    aiReasoning: remote.ai_reasoning,
                    source: CommitmentSource(rawValue: remote.source) ?? .auto,
                    screenshotDate: remote.screenshot_date.flatMap { isoFormatter.date(from: $0) },
                    notes: remote.notes
                )
                if let cat = remote.category, let category = CommitmentCategory(rawValue: cat) {
                    commitment.category = category
                }
                commitment.calendarEventID = remote.calendar_event_id
                commitment.customStatusLabel = remote.custom_status_label
                if let wfID = remote.workflow_id {
                    commitment.workflowID = UUID(uuidString: wfID)
                }
                commitment.syncStatus = .synced
                context.insert(commitment)
                progress.pulled += 1
            }

            hasMore = remoteCommitments.count == Self.pullPageSize
            offset += remoteCommitments.count
        }

        try context.save()
        AppLogger.sync.info("Sync pull complete: \(progress.pulled) new items pulled")
    }

    /// Soft deletes a commitment by setting deleted_at instead of hard deleting.
    /// The record stays locally and remotely for 30 days per Privacy Policy.
    func softDelete(commitment: LocalCommitment, context: ModelContext) async throws {
        let now = Date()

        // Update remote record with deleted_at timestamp
        let endpoint = supabaseURL
            .appendingPathComponent("rest/v1/commitments")
            .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(commitment.id.uuidString)")])

        let token = try await bearerToken()

        var request = URLRequest(url: endpoint)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        let payload: [String: Any] = ["deleted_at": ISO8601DateFormatter().string(from: now)]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await CertificatePinningService.session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let statusCode = httpResponse.statusCode
            AppLogger.sync.error("Soft delete failed with status \(statusCode)")
            if statusCode == 401 {
                throw SyncError.notAuthenticated
            }
        }

        // Remove from local store (remote retains for 30 days)
        context.delete(commitment)
        try context.save()
    }

    enum SyncError: LocalizedError {
        case notAuthenticated
        case pullFailed(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: "Please sign in to sync your data."
            case .pullFailed(let code): "Failed to download data (status \(code)). Please try again later."
            }
        }
    }
}

// MARK: - Array chunking helper

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
