package com.pearsonmedia.seddly

import com.pearsonmedia.seddly.service.auth.AuthService
import com.pearsonmedia.seddly.service.auth.SecureStorageService
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for AuthService session management.
 * Tests token validation, session timeout, and sign-in/sign-out flows.
 */
class AuthServiceTest {

    private lateinit var secureStorage: SecureStorageService
    private lateinit var authService: AuthService

    @Before
    fun setup() {
        secureStorage = mockk(relaxed = true)
        every { secureStorage.contains(SecureStorageService.KEY_ACCESS_TOKEN) } returns false
        authService = AuthService(secureStorage)
    }

    @Test
    fun `initial state is not signed in`() {
        assertFalse(authService.isSignedIn.value)
    }

    @Test
    fun `signIn updates signed in state`() {
        authService.signIn(
            accessToken = "test-token",
            refreshToken = "test-refresh",
            expiresAt = System.currentTimeMillis() + 3600000,
            userId = "user-123"
        )
        assertTrue(authService.isSignedIn.value)
    }

    @Test
    fun `signIn stores tokens in secure storage`() {
        authService.signIn(
            accessToken = "test-token",
            refreshToken = "test-refresh",
            expiresAt = System.currentTimeMillis() + 3600000,
            userId = "user-123"
        )
        verify { secureStorage.putString(SecureStorageService.KEY_ACCESS_TOKEN, "test-token") }
        verify { secureStorage.putString(SecureStorageService.KEY_REFRESH_TOKEN, "test-refresh") }
        verify { secureStorage.putString(SecureStorageService.KEY_USER_ID, "user-123") }
    }

    @Test
    fun `signOut clears tokens and updates state`() {
        authService.signIn("token", "refresh", System.currentTimeMillis() + 3600000, "user-123")
        authService.signOut()
        assertFalse(authService.isSignedIn.value)
        verify { secureStorage.remove(SecureStorageService.KEY_ACCESS_TOKEN) }
        verify { secureStorage.remove(SecureStorageService.KEY_REFRESH_TOKEN) }
    }

    @Test
    fun `validAccessToken returns null when not signed in`() {
        every { secureStorage.getString(SecureStorageService.KEY_ACCESS_TOKEN) } returns null
        assertNull(authService.validAccessToken())
    }

    @Test
    fun `validAccessToken returns token when signed in and active`() {
        every { secureStorage.getString(SecureStorageService.KEY_ACCESS_TOKEN) } returns "test-token"
        every { secureStorage.getString(SecureStorageService.KEY_TOKEN_EXPIRY) } returns
            (System.currentTimeMillis() + 3600000).toString()

        // Sign in first to reset activity timestamp
        authService.signIn("test-token", "refresh", System.currentTimeMillis() + 3600000, "user-123")

        val token = authService.validAccessToken()
        assertNotNull(token)
    }

    @Test
    fun `session timeout constant is 15 minutes`() {
        assertEquals(15 * 60 * 1000L, AuthService.SESSION_TIMEOUT_MS)
    }

    @Test
    fun `token refresh buffer is 60 seconds`() {
        assertEquals(60 * 1000L, AuthService.TOKEN_REFRESH_BUFFER_MS)
    }

    private fun assertEquals(expected: Long, actual: Long) {
        org.junit.Assert.assertEquals(expected, actual)
    }
}
