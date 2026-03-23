import AuthenticationServices
import Foundation

/// Handles Apple Sign-In for Pro+ tier accounts.
actor AuthService {
    private let supabaseURL: URL
    private let supabaseKey: String

    private(set) var currentUserID: String?
    private(set) var accessToken: String?

    init(supabaseURL: URL, supabaseKey: String) {
        self.supabaseURL = supabaseURL
        self.supabaseKey = supabaseKey
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }

        let endpoint = supabaseURL.appendingPathComponent("auth/v1/token")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        let body: [String: Any] = [
            "provider": "apple",
            "id_token": tokenString,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.signInFailed
        }

        struct AuthResponse: Codable {
            let access_token: String
            let user: AuthUser
        }

        struct AuthUser: Codable {
            let id: String
        }

        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        currentUserID = authResponse.user.id
        accessToken = authResponse.access_token
    }

    func signOut() {
        currentUserID = nil
        accessToken = nil
    }

    var isAuthenticated: Bool {
        accessToken != nil
    }

    enum AuthError: LocalizedError {
        case invalidCredential
        case signInFailed

        var errorDescription: String? {
            switch self {
            case .invalidCredential: "Invalid Apple Sign-In credential."
            case .signInFailed: "Sign-in failed. Please try again."
            }
        }
    }
}
