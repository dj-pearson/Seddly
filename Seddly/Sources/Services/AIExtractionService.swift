import Foundation
import os

actor AIExtractionService {
    private let endpointURL: URL
    private let authToken: String?

    /// In-flight request deduplication: keyed by text hash, value is the pending Task.
    private var inFlightRequests: [Int: Task<ExtractionResponse, Error>] = [:]
    /// Timestamps for when each dedup entry was created, cleared after 60 seconds to allow retries.
    private var inFlightTimestamps: [Int: Date] = [:]

    /// Result cache: keyed by text hash, stores (response, timestamp) for 5-minute TTL.
    private static let cacheTTL: TimeInterval = 300 // 5 minutes
    private var resultCache: [Int: (response: ExtractionResponse, timestamp: Date)] = [:]

    struct ExtractionResponse: Codable {
        let commitments: [ExtractedCommitment]
        let rejected: [RejectedCommitment]
    }

    struct ExtractedCommitment: Codable {
        let text: String
        let madeBy: String
        let madeTo: String
        let type: String
        let category: String?
        let deadline: String?
        let dollarAmount: Double?
        let confidence: Int
        let reasoning: String

        enum CodingKeys: String, CodingKey {
            case text
            case madeBy = "made_by"
            case madeTo = "made_to"
            case type
            case category
            case deadline
            case dollarAmount = "dollar_amount"
            case confidence
            case reasoning
        }
    }

    struct RejectedCommitment: Codable {
        let text: String
        let type: String
        let confidence: Int
        let reasoning: String
    }

    static let maxTextLength = 10_000

    init(endpointURL: URL, authToken: String? = nil) {
        self.endpointURL = endpointURL
        self.authToken = authToken
    }

    func extractCommitments(from text: String) async throws -> ExtractionResponse {
        // Validate UTF-8 encoding
        guard text.utf8.elementsEqual(text.utf8),
              String(data: Data(text.utf8), encoding: .utf8) != nil else {
            throw AIExtractionError.invalidEncoding
        }

        // Validate text length
        guard text.count <= Self.maxTextLength else {
            throw AIExtractionError.inputTooLong(length: text.count, max: Self.maxTextLength)
        }

        // Check result cache first (5-minute TTL)
        let textHash = text.hashValue
        if let cached = resultCache[textHash],
           Date().timeIntervalSince(cached.timestamp) < Self.cacheTTL {
            return cached.response
        }

        // Deduplication: return existing in-flight request for same text
        cleanupStaleDedup()

        if let existing = inFlightRequests[textHash] {
            return try await existing.value
        }

        let task = Task<ExtractionResponse, Error> {
            try await performExtraction(text: text)
        }
        inFlightRequests[textHash] = task
        inFlightTimestamps[textHash] = Date()

        do {
            let result = try await task.value
            inFlightRequests.removeValue(forKey: textHash)
            inFlightTimestamps.removeValue(forKey: textHash)
            resultCache[textHash] = (response: result, timestamp: Date())
            return result
        } catch {
            inFlightRequests.removeValue(forKey: textHash)
            inFlightTimestamps.removeValue(forKey: textHash)
            throw error
        }
    }

    private func performExtraction(text: String) async throws -> ExtractionResponse {
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let payload = ["text": text]
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await CertificatePinningService.session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            AppLogger.ai.error("AI extraction failed with status \(statusCode)")
            if statusCode == 401 {
                throw AIExtractionError.unauthorized
            }
            throw AIExtractionError.serverError
        }

        do {
            return try JSONDecoder().decode(ExtractionResponse.self, from: data)
        } catch {
            AppLogger.ai.error("Failed to decode AI extraction response: \(error.localizedDescription)")
            throw error
        }
    }

    /// Removes deduplication entries older than 60 seconds to allow retries.
    private func cleanupStaleDedup() {
        let cutoff = Date().addingTimeInterval(-60)
        for (hash, timestamp) in inFlightTimestamps where timestamp < cutoff {
            inFlightRequests[hash]?.cancel()
            inFlightRequests.removeValue(forKey: hash)
            inFlightTimestamps.removeValue(forKey: hash)
        }
    }

    enum AIExtractionError: LocalizedError {
        case serverError
        case unauthorized
        case inputTooLong(length: Int, max: Int)
        case invalidEncoding

        var errorDescription: String? {
            switch self {
            case .serverError: "Failed to connect to the analysis service. Your screenshot has been queued for later processing."
            case .unauthorized: "Authentication expired. Please sign in again."
            case .inputTooLong(let length, let max): "Text too long for analysis (\(length) characters, maximum \(max)). Try a smaller screenshot."
            case .invalidEncoding: "Text contains invalid characters and cannot be analyzed."
            }
        }
    }
}
