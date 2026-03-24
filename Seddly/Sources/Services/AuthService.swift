import AuthenticationServices
import Foundation
import Security

/// Handles Apple Sign-In for Pro+ tier accounts.
/// Stores tokens securely in Keychain.
actor AuthService {
    private let supabaseURL: URL
    private let supabaseKey: String

    private(set) var currentUserID: String?
    private(set) var accessToken: String?

    private static let keychainServiceName = "com.pearsonmedia.Seddly.auth"
    private static let keychainTokenKey = "accessToken"
    private static let keychainUserIDKey = "userID"

    init(supabaseURL: URL, supabaseKey: String) {
        self.supabaseURL = supabaseURL
        self.supabaseKey = supabaseKey

        // Restore tokens from Keychain on init
        self.accessToken = Self.readKeychain(key: Self.keychainTokenKey)
        self.currentUserID = Self.readKeychain(key: Self.keychainUserIDKey)
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }

        let endpoint = supabaseURL.appendingPathComponent("auth/v1/token")
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw AuthError.signInFailed
        }
        components.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]

        guard let url = components.url else {
            throw AuthError.signInFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
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

        // Persist to Keychain
        Self.writeKeychain(key: Self.keychainTokenKey, value: authResponse.access_token)
        Self.writeKeychain(key: Self.keychainUserIDKey, value: authResponse.user.id)
    }

    func signOut() {
        currentUserID = nil
        accessToken = nil
        Self.deleteKeychain(key: Self.keychainTokenKey)
        Self.deleteKeychain(key: Self.keychainUserIDKey)
    }

    var isAuthenticated: Bool {
        accessToken != nil
    }

    // MARK: - Keychain Helpers

    private static func writeKeychain(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceName,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary) // Remove existing
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private static func readKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceName,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
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
