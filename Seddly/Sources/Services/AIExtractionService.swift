import Foundation

actor AIExtractionService {
    private let endpointURL: URL

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

    init(endpointURL: URL) {
        self.endpointURL = endpointURL
    }

    func extractCommitments(from text: String) async throws -> ExtractionResponse {
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["text": text]
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIExtractionError.serverError
        }

        return try JSONDecoder().decode(ExtractionResponse.self, from: data)
    }

    enum AIExtractionError: LocalizedError {
        case serverError

        var errorDescription: String? {
            switch self {
            case .serverError: "Failed to connect to the analysis service. Your screenshot has been queued for later processing."
            }
        }
    }
}
