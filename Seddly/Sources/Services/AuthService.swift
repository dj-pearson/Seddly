import AuthenticationServices
import Foundation
import os
import Security

/// Handles Apple Sign-In for Pro+ tier accounts.
/// Stores tokens securely in Keychain with automatic refresh.
actor AuthService {
    private let supabaseURL: URL
    private let supabaseKey: String

    private(set) var currentUserID: String?
    private(set) var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiresAt: Date?
    private var isRefreshing = false

    private static let keychainServiceName = "com.pearsonmedia.Seddly.auth"
    private static let keychainTokenKey = "accessToken"
    private static let keychainRefreshTokenKey = "refreshToken"
    private static let keychainUserIDKey = "userID"
    private static let keychainExpiresAtKey = "tokenExpiresAt"

    /// Buffer before actual expiry to refresh proactively (60 seconds).
    private static let expirationBuffer: TimeInterval = 60

    private static let keychainMigrationKey = "keychainMigratedToWhenUnlocked"

    init(supabaseURL: URL, supabaseKey: String) {
        self.supabaseURL = supabaseURL
        self.supabaseKey = supabaseKey

        // Restore tokens from Keychain on init
        self.accessToken = Self.readKeychain(key: Self.keychainTokenKey)
        self.refreshToken = Self.readKeychain(key: Self.keychainRefreshTokenKey)
        self.currentUserID = Self.readKeychain(key: Self.keychainUserIDKey)
        if let expiresString = Self.readKeychain(key: Self.keychainExpiresAtKey),
           let interval = TimeInterval(expiresString) {
            self.tokenExpiresAt = Date(timeIntervalSince1970: interval)
        }

        // Migrate existing Keychain items to stricter accessibility (one-time)
        if !UserDefaults.standard.bool(forKey: Self.keychainMigrationKey) {
            Self.migrateKeychainAccessibility()
            UserDefaults.standard.set(true, forKey: Self.keychainMigrationKey)
        }
    }

    /// Re-writes all Keychain items with kSecAttrAccessibleWhenUnlockedThisDeviceOnly.
    private static func migrateKeychainAccessibility() {
        let keys = [keychainTokenKey, keychainRefreshTokenKey, keychainUserIDKey, keychainExpiresAtKey]
        for key in keys {
            if let value = readKeychain(key: key) {
                writeKeychain(key: key, value: value)
            }
        }
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
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            AppLogger.auth.error("Apple Sign-In auth request failed with status \(statusCode)")
            throw AuthError.signInFailed
        }

        let authResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        storeTokens(authResponse)
    }

    /// Returns a valid access token, refreshing automatically if expired.
    /// Returns nil if not authenticated or refresh fails.
    func validAccessToken() async -> String? {
        guard accessToken != nil else { return nil }

        if isTokenExpired {
            do {
                try await refreshAccessToken()
            } catch {
                AppLogger.auth.error("Token refresh failed: \(error.localizedDescription)")
                signOut()
                return nil
            }
        }

        return accessToken
    }

    /// Handles a 401 response by refreshing the token and retrying once.
    /// Returns the new access token if refresh succeeds, nil otherwise.
    func handleUnauthorizedResponse() async -> String? {
        do {
            try await refreshAccessToken()
            return accessToken
        } catch {
            AppLogger.auth.error("Token refresh after 401 failed: \(error.localizedDescription)")
            signOut()
            return nil
        }
    }

    func signOut() {
        currentUserID = nil
        accessToken = nil
        refreshToken = nil
        tokenExpiresAt = nil
        isRefreshing = false
        Self.deleteKeychain(key: Self.keychainTokenKey)
        Self.deleteKeychain(key: Self.keychainRefreshTokenKey)
        Self.deleteKeychain(key: Self.keychainUserIDKey)
        Self.deleteKeychain(key: Self.keychainExpiresAtKey)
    }

    var isAuthenticated: Bool {
        accessToken != nil
    }

    /// Whether the current access token needs refreshing.
    var needsRefresh: Bool {
        isTokenExpired
    }

    // MARK: - Token Refresh

    private var isTokenExpired: Bool {
        guard let expiresAt = tokenExpiresAt else { return true }
        return Date.now >= expiresAt.addingTimeInterval(-Self.expirationBuffer)
    }

    private func refreshAccessToken() async throws {
        guard let currentRefreshToken = refreshToken else {
            throw AuthError.refreshFailed
        }

        // Prevent concurrent refresh attempts
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let endpoint = supabaseURL.appendingPathComponent("auth/v1/token")
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw AuthError.refreshFailed
        }
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]

        guard let url = components.url else {
            throw AuthError.refreshFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        let body: [String: String] = ["refresh_token": currentRefreshToken]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            AppLogger.auth.error("Token refresh request failed with status \(statusCode)")
            throw AuthError.refreshFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        storeTokens(tokenResponse)
        AppLogger.auth.info("Access token refreshed successfully")
    }

    private func storeTokens(_ response: TokenResponse) {
        accessToken = response.access_token
        refreshToken = response.refresh_token
        currentUserID = response.user.id

        let expiresAt = Date.now.addingTimeInterval(TimeInterval(response.expires_in))
        tokenExpiresAt = expiresAt

        Self.writeKeychain(key: Self.keychainTokenKey, value: response.access_token)
        Self.writeKeychain(key: Self.keychainRefreshTokenKey, value: response.refresh_token)
        Self.writeKeychain(key: Self.keychainUserIDKey, value: response.user.id)
        Self.writeKeychain(key: Self.keychainExpiresAtKey, value: String(expiresAt.timeIntervalSince1970))
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
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
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

    // MARK: - Types

    private struct TokenResponse: Codable {
        let access_token: String
        let refresh_token: String
        let expires_in: Int
        let user: TokenUser
    }

    private struct TokenUser: Codable {
        let id: String
    }

    enum AuthError: LocalizedError {
        case invalidCredential
        case signInFailed
        case refreshFailed

        var errorDescription: String? {
            switch self {
            case .invalidCredential: "Invalid Apple Sign-In credential."
            case .signInFailed: "Sign-in failed. Please try again."
            case .refreshFailed: "Session expired. Please sign in again."
            }
        }
    }
}
