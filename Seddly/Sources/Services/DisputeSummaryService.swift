import Foundation
import SwiftData

actor DisputeSummaryService {
    private let endpointURL: URL
    private let authToken: String?
    private let privacyAuditService = PrivacyAuditService()

    /// In-flight request deduplication: keyed by entity name, value is the pending Task.
    private var inFlightRequests: [String: Task<String, Error>] = [:]
    /// Timestamps for when each dedup entry was created, cleared after 60 seconds to allow retries.
    private var inFlightTimestamps: [String: Date] = [:]

    /// Maximum retry attempts for retriable HTTP errors (429, 5xx).
    private static let maxRetryAttempts = 3

    init(endpointURL: URL, authToken: String? = nil) {
        self.endpointURL = endpointURL
        self.authToken = authToken
    }

    struct SummaryResponse: Codable {
        let summary: String
    }

    func generateSummary(
        entityName: String,
        commitments: [LocalCommitment],
        context: ModelContext
    ) async throws -> String {
        // Deduplication: return existing in-flight request for same entity
        cleanupStaleDedup()

        if let existing = inFlightRequests[entityName] {
            return try await existing.value
        }

        let task = Task<String, Error> { [self] in
            try await performGenerateSummary(entityName: entityName, commitments: commitments, context: context)
        }
        inFlightRequests[entityName] = task
        inFlightTimestamps[entityName] = Date()

        do {
            let result = try await task.value
            inFlightRequests.removeValue(forKey: entityName)
            inFlightTimestamps.removeValue(forKey: entityName)
            return result
        } catch {
            inFlightRequests.removeValue(forKey: entityName)
            inFlightTimestamps.removeValue(forKey: entityName)
            throw error
        }
    }

    private func performGenerateSummary(
        entityName: String,
        commitments: [LocalCommitment],
        context: ModelContext
    ) async throws -> String {
        let payload: [String: Any] = [
            "entity_name": entityName,
            "commitments": commitments.map { commitment -> [String: Any?] in
                [
                    "summary": commitment.summary,
                    "deadline": commitment.deadline?.ISO8601Format(),
                    "dollar_amount": commitment.dollarAmount.map { NSDecimalNumber(decimal: $0).doubleValue },
                    "status": commitment.statusRaw,
                    "screenshot_date": (commitment.screenshotDate ?? commitment.createdAt).ISO8601Format(),
                    "source": commitment.sourceRaw,
                    "confidence": commitment.confidenceScore
                ].compactMapValues { $0 }
            }
        ]

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        var responseData: Data?

        for attempt in 0...Self.maxRetryAttempts {
            let (data, response) = try await CertificatePinningService.session.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? -1

            if (200...299).contains(statusCode) {
                responseData = data
                break
            }

            if statusCode == 401 {
                throw DisputeSummaryError.unauthorized
            }

            // Retry on 429 (rate limited) or 5xx (server error)
            let isRetriable = statusCode == 429 || (500...599).contains(statusCode)
            if isRetriable && attempt < Self.maxRetryAttempts {
                let retryAfter = httpResponse?.value(forHTTPHeaderField: "Retry-After")
                    .flatMap(Double.init)
                let delay = retryAfter ?? pow(2.0, Double(attempt + 1))
                AppLogger.ai.warning("Dispute summary got \(statusCode), retrying in \(delay)s (attempt \(attempt + 1)/\(Self.maxRetryAttempts))")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                continue
            }

            if statusCode == 429 {
                throw DisputeSummaryError.rateLimited
            }
            throw DisputeSummaryError.serverError
        }

        guard let finalData = responseData else {
            throw DisputeSummaryError.serverError
        }

        let summaryResponse = try JSONDecoder().decode(SummaryResponse.self, from: finalData)

        // Record in privacy audit
        let textLength = commitments.reduce(0) { $0 + $1.summary.count + $1.fullText.count }
        await privacyAuditService.recordDisputeSummary(
            commitmentCount: commitments.count,
            textLength: textLength,
            endpoint: endpointURL,
            context: context
        )

        return summaryResponse.summary
    }

    /// Fallback: generate summary locally without AI
    static func generateLocalSummary(entityName: String, commitments: [LocalCommitment]) -> String {
        let sorted = commitments.sorted { $0.createdAt < $1.createdAt }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long

        var summary = "Timeline of commitments from \(entityName):\n\n"

        for commitment in sorted {
            let dateStr = dateFormatter.string(from: commitment.createdAt)
            summary += "\(dateStr) — \(commitment.summary)"

            if let deadline = commitment.deadline {
                summary += " (Due: \(dateFormatter.string(from: deadline)))"
            }
            if let amount = commitment.dollarAmount {
                summary += " — $\(amount)"
            }

            let sourceLabel = switch commitment.source {
            case .auto: "screenshot"
            case .shareSheet: "share sheet"
            case .manual: "manual entry"
            }
            summary += "\nSource: \(sourceLabel)"
            summary += "\nStatus: \(commitment.status.label)\n\n"
        }

        let fulfilled = commitments.filter { $0.status == .fulfilled }.count
        let overdue = commitments.filter { $0.status == .overdue || $0.isOverdue }.count
        summary += "Summary: \(fulfilled) of \(commitments.count) commitments fulfilled. \(overdue) overdue."

        return summary
    }

    /// Removes deduplication entries older than 60 seconds to allow retries.
    private func cleanupStaleDedup() {
        let cutoff = Date().addingTimeInterval(-60)
        for (key, timestamp) in inFlightTimestamps where timestamp < cutoff {
            inFlightRequests[key]?.cancel()
            inFlightRequests.removeValue(forKey: key)
            inFlightTimestamps.removeValue(forKey: key)
        }
    }

    enum DisputeSummaryError: LocalizedError {
        case serverError
        case unauthorized
        case rateLimited

        var errorDescription: String? {
            switch self {
            case .serverError: "Failed to generate dispute summary. A local summary will be used instead."
            case .unauthorized: "Authentication expired. Please sign in again."
            case .rateLimited: "Too many requests. Please wait a moment and try again."
            }
        }
    }
}
