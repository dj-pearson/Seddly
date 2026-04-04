package com.pearsonmedia.seddly.service.security

import android.util.Log
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import com.pearsonmedia.seddly.service.auth.SecureStorageService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Biometric authentication service for app lock.
 * Uses AndroidX Biometric library with:
 * - Fingerprint and face unlock support
 * - Fallback to device PIN/pattern/password
 * - Settings persisted in EncryptedSharedPreferences
 * - Lock state tracked via StateFlow for Compose UI
 */
@Singleton
class BiometricService @Inject constructor(
    private val secureStorage: SecureStorageService
) {
    private val _isLocked = MutableStateFlow(false)
    val isLocked: StateFlow<Boolean> = _isLocked.asStateFlow()

    private val _isEnabled = MutableStateFlow(false)
    val isEnabled: StateFlow<Boolean> = _isEnabled.asStateFlow()

    init {
        _isEnabled.value = secureStorage.getString(KEY_BIOMETRIC_ENABLED) == "true"
        // If biometric is enabled, start locked
        _isLocked.value = _isEnabled.value
    }

    /**
     * Check if the device supports biometric authentication.
     */
    fun canAuthenticate(activity: FragmentActivity): Boolean {
        val biometricManager = BiometricManager.from(activity)
        return when (biometricManager.canAuthenticate(AUTHENTICATORS)) {
            BiometricManager.BIOMETRIC_SUCCESS -> true
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> {
                Log.w(TAG, "No biometrics enrolled")
                false
            }
            else -> false
        }
    }

    /**
     * Toggle biometric lock on/off.
     */
    fun setEnabled(enabled: Boolean) {
        _isEnabled.value = enabled
        secureStorage.putString(KEY_BIOMETRIC_ENABLED, enabled.toString())
        if (!enabled) {
            _isLocked.value = false
        }
    }

    /**
     * Show the biometric prompt to unlock the app.
     */
    fun authenticate(
        activity: FragmentActivity,
        onSuccess: () -> Unit,
        onError: (String) -> Unit
    ) {
        if (!_isEnabled.value || !_isLocked.value) {
            onSuccess()
            return
        }

        val executor = ContextCompat.getMainExecutor(activity)

        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                _isLocked.value = false
                Log.i(TAG, "Biometric authentication succeeded")
                onSuccess()
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                Log.e(TAG, "Biometric error ($errorCode): $errString")
                onError(errString.toString())
            }

            override fun onAuthenticationFailed() {
                Log.w(TAG, "Biometric authentication failed (bad biometric)")
            }
        }

        val prompt = BiometricPrompt(activity, executor, callback)

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Unlock Seddly")
            .setSubtitle("Verify your identity to access your commitments")
            .setAllowedAuthenticators(AUTHENTICATORS)
            .build()

        prompt.authenticate(promptInfo)
    }

    /**
     * Called when app goes to background — re-lock if enabled.
     */
    fun onAppBackgrounded() {
        if (_isEnabled.value) {
            _isLocked.value = true
        }
    }

    companion object {
        private const val TAG = "BiometricService"
        private const val KEY_BIOMETRIC_ENABLED = "biometric_enabled"
        private const val AUTHENTICATORS =
            BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
    }
}
