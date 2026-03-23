import Foundation
import SwiftData

/// Handles Pro+ cloud sync between local SwiftData and Supabase.
actor SyncService {
    private let supabaseURL: URL
    private let supabaseKey: String

    init(supabaseURL: URL, supabaseKey: String) {
        self.supabaseURL = supabaseURL
        self.supabaseKey = supabaseKey
    }

    func syncCommitments(context: ModelContext) async throws {
        // Fetch local commitments that need syncing
        let descriptor = FetchDescriptor<LocalCommitment>(
            predicate: #Predicate { $0.syncStatusRaw == "pendingSync" }
        )
        let pendingSync = try context.fetch(descriptor)

        guard !pendingSync.isEmpty else { return }

        // Upload to Supabase
        let endpoint = supabaseURL.appendingPathComponent("rest/v1/commitments")

        for commitment in pendingSync {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
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
            ]

            request.httpBody = try JSONSerialization.data(
                withJSONObject: payload.compactMapValues { $0 }
            )

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                commitment.syncStatus = .synced
                commitment.updatedAt = .now
            }
        }

        try context.save()
    }

    func pullCommitments(context: ModelContext) async throws {
        let endpoint = supabaseURL.appendingPathComponent("rest/v1/commitments")
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        let (data, _) = try await URLSession.shared.data(for: request)

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
        }

        let remoteCommitments = try JSONDecoder().decode([RemoteCommitment].self, from: data)
        let isoFormatter = ISO8601DateFormatter()

        for remote in remoteCommitments {
            guard let uuid = UUID(uuidString: remote.id) else { continue }

            let idToFind = uuid
            let descriptor = FetchDescriptor<LocalCommitment>(
                predicate: #Predicate { $0.id == idToFind }
            )

            if (try? context.fetch(descriptor).first) != nil {
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
            commitment.syncStatus = .synced
            context.insert(commitment)
        }

        try context.save()
    }
}
