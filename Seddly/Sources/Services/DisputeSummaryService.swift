import Foundation
import SwiftData

actor DisputeSummaryService {
    private let endpointURL: URL
    private let authToken: String?
    private let privacyAuditService = PrivacyAuditService()

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

        let (data, response) = try await CertificatePinningService.session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            if statusCode == 401 {
                throw DisputeSummaryError.unauthorized
            }
            throw DisputeSummaryError.serverError
        }

        let summaryResponse = try JSONDecoder().decode(SummaryResponse.self, from: data)

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

    enum DisputeSummaryError: LocalizedError {
        case serverError
        case unauthorized

        var errorDescription: String? {
            switch self {
            case .serverError: "Failed to generate dispute summary. A local summary will be used instead."
            case .unauthorized: "Authentication expired. Please sign in again."
            }
        }
    }
}
