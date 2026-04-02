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

    /// Maximum retry attempts for retriable HTTP errors (429, 5xx).
    private static let maxRetryAttempts = 3

    init(endpointURL: URL, authToken: String? = nil) {
        self.endpointURL = endpointURL
        self.authToken = authToken
    }

    /// Strips HTML/script tags from text before sending to AI endpoint.
    private static func sanitizeForAPI(_ text: String) -> String {
        // Remove <script>...</script> blocks entirely (case-insensitive, multiline)
        var sanitized = text
        while let scriptRange = sanitized.range(of: "<script[^>]*>.*?</script>",
                                                 options: [.regularExpression, .caseInsensitive]) {
            sanitized.removeSubrange(scriptRange)
        }
        // Remove remaining HTML tags
        while let tagRange = sanitized.range(of: "<[^>]+>", options: .regularExpression) {
            sanitized.removeSubrange(tagRange)
        }
        return sanitized
    }

    func extractCommitments(from text: String) async throws -> ExtractionResponse {
        // Validate UTF-8 encoding
        guard text.utf8.elementsEqual(text.utf8),
              String(data: Data(text.utf8), encoding: .utf8) != nil else {
            throw AIExtractionError.invalidEncoding
        }

        // Sanitize input before processing
        let sanitizedText = Self.sanitizeForAPI(text)

        // Validate text length
        guard sanitizedText.count <= Self.maxTextLength else {
            throw AIExtractionError.inputTooLong(length: sanitizedText.count, max: Self.maxTextLength)
        }

        // Check result cache first (5-minute TTL)
        let textHash = sanitizedText.hashValue
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
            try await performExtraction(text: sanitizedText)
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
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let payload = ["text": text]
        request.httpBody = try JSONEncoder().encode(payload)

        for attempt in 0...Self.maxRetryAttempts {
            let (data, response) = try await CertificatePinningService.session.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? -1

            if (200...299).contains(statusCode) {
                do {
                    return try JSONDecoder().decode(ExtractionResponse.self, from: data)
                } catch {
                    AppLogger.ai.error("Failed to decode AI extraction response: \(error.localizedDescription)")
                    throw error
                }
            }

            if statusCode == 401 {
                throw AIExtractionError.unauthorized
            }

            // Retry on 429 (rate limited) or 5xx (server error)
            let isRetriable = statusCode == 429 || (500...599).contains(statusCode)
            if isRetriable && attempt < Self.maxRetryAttempts {
                let retryAfter = httpResponse?.value(forHTTPHeaderField: "Retry-After")
                    .flatMap(Double.init)
                let delay = retryAfter ?? pow(2.0, Double(attempt + 1))
                AppLogger.ai.warning("AI extraction got \(statusCode), retrying in \(delay)s (attempt \(attempt + 1)/\(Self.maxRetryAttempts))")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                continue
            }

            AppLogger.ai.error("AI extraction failed with status \(statusCode)")
            if statusCode == 429 {
                throw AIExtractionError.rateLimited
            }
            throw AIExtractionError.serverError
        }

        throw AIExtractionError.serverError
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
        case rateLimited
        case inputTooLong(length: Int, max: Int)
        case invalidEncoding

        var errorDescription: String? {
            switch self {
            case .serverError: "Failed to connect to the analysis service. Your screenshot has been queued for later processing."
            case .unauthorized: "Authentication expired. Please sign in again."
            case .rateLimited: "Too many requests. Please wait a moment and try again."
            case .inputTooLong(let length, let max): "Text too long for analysis (\(length) characters, maximum \(max)). Try a smaller screenshot."
            case .invalidEncoding: "Text contains invalid characters and cannot be analyzed."
            }
        }
    }
}
