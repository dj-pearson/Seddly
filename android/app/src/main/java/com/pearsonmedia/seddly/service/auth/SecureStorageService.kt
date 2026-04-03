package com.pearsonmedia.seddly.service.auth

import android.content.Context
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Secure key-value storage using AndroidX EncryptedSharedPreferences.
 * Mirrors the iOS Keychain storage with WhenUnlockedThisDeviceOnly accessibility.
 *
 * Security features:
 * - AES-256 GCM encryption for values
 * - AES-256 SIV encryption for keys (deterministic, prevents enumeration)
 * - Backed by Android Keystore (hardware-backed on supported devices)
 * - Data is not included in backups (see data_extraction_rules.xml)
 */
@Singleton
class SecureStorageService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .setUserAuthenticationRequired(false)
        .build()

    private val prefs = EncryptedSharedPreferences.create(
        context,
        PREFS_NAME,
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun getString(key: String): String? {
        return try {
            prefs.getString(key, null)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read secure value for key: $key", e)
            null
        }
    }

    fun putString(key: String, value: String) {
        try {
            prefs.edit().putString(key, value).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write secure value for key: $key", e)
        }
    }

    fun remove(key: String) {
        try {
            prefs.edit().remove(key).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to remove secure value for key: $key", e)
        }
    }

    fun clearAll() {
        try {
            prefs.edit().clear().apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clear secure storage", e)
        }
    }

    fun contains(key: String): Boolean = prefs.contains(key)

    companion object {
        private const val TAG = "SecureStorageService"
        private const val PREFS_NAME = "seddly_secure_prefs"

        // Storage keys
        const val KEY_ACCESS_TOKEN = "access_token"
        const val KEY_REFRESH_TOKEN = "refresh_token"
        const val KEY_TOKEN_EXPIRY = "token_expiry"
        const val KEY_USER_ID = "user_id"
        const val KEY_SUPABASE_URL = "supabase_url"
        const val KEY_SUPABASE_KEY = "supabase_key"
    }
}
