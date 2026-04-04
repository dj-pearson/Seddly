package com.pearsonmedia.seddly.service.auth

import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Lifecycle observer that checks session timeout on app foreground.
 * Mirrors the iOS SessionTimeoutService actor that monitors background duration.
 *
 * When the app returns to foreground:
 * - Checks if session has exceeded inactivity timeout (15 min)
 * - If timed out, triggers automatic sign-out via AuthService
 * - Records background entry time for duration tracking
 */
@Singleton
class SessionTimeoutObserver @Inject constructor(
    private val authService: AuthService
) : DefaultLifecycleObserver {

    private var backgroundEntryTime: Long = 0

    override fun onStop(owner: LifecycleOwner) {
        backgroundEntryTime = System.currentTimeMillis()
        Log.d(TAG, "App backgrounded at $backgroundEntryTime")
    }

    override fun onStart(owner: LifecycleOwner) {
        if (backgroundEntryTime > 0 && authService.isSignedIn.value) {
            val backgroundDuration = System.currentTimeMillis() - backgroundEntryTime
            if (backgroundDuration > AuthService.SESSION_TIMEOUT_MS) {
                Log.w(TAG, "Session timed out after ${backgroundDuration / 1000}s in background")
                authService.signOut()
            }
        }
        backgroundEntryTime = 0
    }

    companion object {
        private const val TAG = "SessionTimeoutObserver"
    }
}
