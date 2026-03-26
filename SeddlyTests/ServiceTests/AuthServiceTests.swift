import Testing
import Foundation
@testable import Seddly

@Suite("AuthService Tests")
struct AuthServiceTests {
    private func makeService() -> AuthService {
        // Use a fake URL/key so no real network calls happen
        AuthService(
            supabaseURL: URL(string: "https://test.supabase.co")!,
            supabaseKey: "test-api-key"
        )
    }

    @Test("signOut clears all authentication state")
    func signOutClearsState() async {
        let service = makeService()

        await service.signOut()

        let isAuth = await service.isAuthenticated
        let token = await service.accessToken
        let userID = await service.currentUserID

        #expect(isAuth == false)
        #expect(token == nil)
        #expect(userID == nil)
    }

    @Test("isAuthenticated returns false when no token is stored")
    func isAuthenticatedWithoutToken() async {
        let service = makeService()

        // Clean state — sign out to ensure no leftover keychain data
        await service.signOut()

        let isAuth = await service.isAuthenticated
        #expect(isAuth == false)
    }

    @Test("validAccessToken returns nil when not authenticated")
    func validAccessTokenWhenNotAuthenticated() async {
        let service = makeService()
        await service.signOut()

        let token = await service.validAccessToken()
        #expect(token == nil)
    }

    @Test("handleUnauthorizedResponse returns nil when no refresh token exists")
    func handleUnauthorizedWithoutRefreshToken() async {
        let service = makeService()
        await service.signOut()

        let newToken = await service.handleUnauthorizedResponse()
        #expect(newToken == nil)
    }

    @Test("needsRefresh is true when not authenticated")
    func needsRefreshWhenNotAuthenticated() async {
        let service = makeService()
        await service.signOut()

        let needs = await service.needsRefresh
        #expect(needs == true)
    }

    @Test("AuthError descriptions are user-friendly")
    func authErrorDescriptions() {
        #expect(AuthService.AuthError.invalidCredential.errorDescription != nil)
        #expect(AuthService.AuthError.signInFailed.errorDescription != nil)
        #expect(AuthService.AuthError.refreshFailed.errorDescription != nil)

        #expect(AuthService.AuthError.invalidCredential.errorDescription!.contains("credential"))
        #expect(AuthService.AuthError.signInFailed.errorDescription!.contains("Sign-in"))
        #expect(AuthService.AuthError.refreshFailed.errorDescription!.contains("expired"))
    }

    @Test("Multiple signOut calls are idempotent")
    func signOutIdempotent() async {
        let service = makeService()

        await service.signOut()
        await service.signOut()
        await service.signOut()

        let isAuth = await service.isAuthenticated
        #expect(isAuth == false)
    }
}
