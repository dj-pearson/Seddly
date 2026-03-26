import Foundation

/// Pro+ API client for programmatic access to commitment data.
/// Enables integrations with Notion, Airtable, Zapier, and custom workflows.
actor APIAccessService {
    private let baseURL: URL
    private let authToken: String
    private let urlSession: URLSession

    struct APICommitment: Codable {
        let id: String?
        let entityName: String
        let summary: String
        let fullText: String?
        let deadline: String?
        let dollarAmount: Double?
        let status: String?
        let confidence: Int?
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case id
            case entityName = "entity_name"
            case summary
            case fullText = "full_text"
            case deadline
            case dollarAmount = "dollar_amount"
            case status
            case confidence
            case notes
        }
    }

    struct ListResponse: Codable {
        let data: [APICommitment]
        let pagination: Pagination

        struct Pagination: Codable {
            let limit: Int
            let offset: Int
            let total: Int?
        }
    }

    init(baseURL: URL, authToken: String) {
        self.baseURL = baseURL.appendingPathComponent("api-commitments")
        self.authToken = authToken
        self.urlSession = CertificatePinningService.session
    }

    enum APIError: LocalizedError {
        case invalidURL

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Failed to construct API request URL."
            }
        }
    }

    func listCommitments(
        status: String? = nil,
        entity: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> ListResponse {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        var queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
        ]
        if let status { queryItems.append(URLQueryItem(name: "status", value: status)) }
        if let entity { queryItems.append(URLQueryItem(name: "entity", value: entity)) }
        components.queryItems = queryItems

        guard let url = components.url else { throw APIError.invalidURL }
        let request = authenticatedRequest(url: url, method: "GET")
        let (data, _) = try await urlSession.data(for: request)
        return try JSONDecoder().decode(ListResponse.self, from: data)
    }

    func getCommitment(id: String) async throws -> APICommitment {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "id", value: id)]

        guard let url = components.url else { throw APIError.invalidURL }
        let request = authenticatedRequest(url: url, method: "GET")
        let (data, _) = try await urlSession.data(for: request)
        return try JSONDecoder().decode(APICommitment.self, from: data)
    }

    func createCommitment(_ commitment: APICommitment) async throws -> APICommitment {
        var request = authenticatedRequest(url: baseURL, method: "POST")
        request.httpBody = try JSONEncoder().encode(commitment)
        let (data, _) = try await urlSession.data(for: request)
        return try JSONDecoder().decode(APICommitment.self, from: data)
    }

    func updateCommitment(id: String, updates: [String: Any]) async throws -> APICommitment {
        var body = updates
        body["id"] = id
        var request = authenticatedRequest(url: baseURL, method: "PATCH")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await urlSession.data(for: request)
        return try JSONDecoder().decode(APICommitment.self, from: data)
    }

    func deleteCommitment(id: String) async throws {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "id", value: id)]

        guard let url = components.url else { throw APIError.invalidURL }
        let request = authenticatedRequest(url: url, method: "DELETE")
        _ = try await urlSession.data(for: request)
    }

    private func authenticatedRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        return request
    }
}
