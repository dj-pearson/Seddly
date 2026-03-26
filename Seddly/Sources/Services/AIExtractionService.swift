import Foundation
import os

actor AIExtractionService {
    private let endpointURL: URL
    private let authToken: String?

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
