import Foundation

/// Pro+ API client for programmatic access to commitment data.
/// Enables integrations with Notion, Airtable, Zapier, and custom workflows.
actor APIAccessService {
    private let baseURL: URL
    private let authToken: String

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
    }

    func listCommitments(
        status: String? = nil,
        entity: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> ListResponse {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
        ]
        if let status { queryItems.append(URLQueryItem(name: "status", value: status)) }
        if let entity { queryItems.append(URLQueryItem(name: "entity", value: entity)) }
        components.queryItems = queryItems

        let request = authenticatedRequest(url: components.url!, method: "GET")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ListResponse.self, from: data)
    }

    func getCommitment(id: String) async throws -> APICommitment {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: id)]

        let request = authenticatedRequest(url: components.url!, method: "GET")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(APICommitment.self, from: data)
    }

    func createCommitment(_ commitment: APICommitment) async throws -> APICommitment {
        var request = authenticatedRequest(url: baseURL, method: "POST")
        request.httpBody = try JSONEncoder().encode(commitment)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(APICommitment.self, from: data)
    }

    func updateCommitment(id: String, updates: [String: Any]) async throws -> APICommitment {
        var body = updates
        body["id"] = id
        var request = authenticatedRequest(url: baseURL, method: "PATCH")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(APICommitment.self, from: data)
    }

    func deleteCommitment(id: String) async throws {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: id)]

        let request = authenticatedRequest(url: components.url!, method: "DELETE")
        _ = try await URLSession.shared.data(for: request)
    }

    private func authenticatedRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        return request
    }
}
