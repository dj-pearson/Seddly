package com.pearsonmedia.seddly.service.sync

import android.util.Log
import com.pearsonmedia.seddly.data.local.dao.CommitmentDao
import com.pearsonmedia.seddly.data.local.dao.PrivacyAuditDao
import com.pearsonmedia.seddly.data.local.entity.AuditEventType
import com.pearsonmedia.seddly.data.local.entity.CommitmentEntity
import com.pearsonmedia.seddly.data.local.entity.PrivacyAuditEntry
import com.pearsonmedia.seddly.data.local.entity.SyncStatus
import com.pearsonmedia.seddly.service.auth.AuthService
import com.pearsonmedia.seddly.service.auth.SecureStorageService
import kotlinx.coroutines.delay
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Serializable
data class SyncCommitmentPayload(
    val id: String,
    val entity_name: String,
    val summary: String,
    val full_text: String,
    val deadline: Long? = null,
    val dollar_amount: Double? = null,
    val status: String,
    val confidence_score: Int,
    val ai_reasoning: String? = null,
    val source: String,
    val commitment_type: String? = null,
    val category: String,
    val notes: String? = null,
    val custom_status_label: String? = null,
    val workflow_id: String? = null,
    val calendar_event_id: String? = null
)

/**
 * Cloud sync service for Pro+ users via Supabase Edge Functions.
 * Mirrors the iOS SyncService with:
 * - Batched uploads (50 at a time with 500ms delays)
 * - Client-side rate limiting (30s minimum between syncs)
 * - Token refresh on 401, Retry-After on 429, retry on 5xx
 * - X-Request-ID header on all requests
 * - Privacy audit logging
 */
@Singleton
class SyncService @Inject constructor(
    private val commitmentDao: CommitmentDao,
    private val privacyAuditDao: PrivacyAuditDao,
    private val authService: AuthService,
    private val secureStorage: SecureStorageService,
    private val httpClient: OkHttpClient
) {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private var lastSyncTimestamp: Long = 0

    /**
     * Full sync: pull remote changes, then push local pending changes.
     * Enforces 30-second rate limit between syncs.
     */
    suspend fun syncIfEligible(): SyncResult {
        // Rate limiting: 30s minimum between syncs
        val elapsed = System.currentTimeMillis() - lastSyncTimestamp
        if (elapsed < MIN_SYNC_INTERVAL_MS) {
            Log.d(TAG, "Sync throttled: ${(MIN_SYNC_INTERVAL_MS - elapsed) / 1000}s remaining")
            return SyncResult.Throttled
        }

        val token = authService.validAccessToken()
            ?: return SyncResult.Error("Not authenticated")

        val supabaseUrl = secureStorage.getString(SecureStorageService.KEY_SUPABASE_URL)
            ?: return SyncResult.Error("No Supabase URL configured")

        lastSyncTimestamp = System.currentTimeMillis()

        return try {
            val pullCount = pullCommitments(token, supabaseUrl)
            val pushCount = pushCommitments(token, supabaseUrl)

            // Log to privacy audit
            privacyAuditDao.insert(
                PrivacyAuditEntry(
                    eventType = AuditEventType.CLOUD_SYNC.value,
                    destination = supabaseUrl,
                    dataSummary = "Synced: pulled $pullCount, pushed $pushCount commitments",
                    textLengthSent = pushCount * 200 // estimate
                )
            )

            Log.i(TAG, "Sync complete: pulled $pullCount, pushed $pushCount")
            SyncResult.Success(pulled = pullCount, pushed = pushCount)
        } catch (e: Exception) {
            Log.e(TAG, "Sync failed", e)
            SyncResult.Error(e.message ?: "Unknown sync error")
        }
    }

    /**
     * Pull remote commitments and merge into local database.
     */
    private suspend fun pullCommitments(token: String, supabaseUrl: String): Int {
        val requestId = UUID.randomUUID().toString()
        val request = Request.Builder()
            .url("$supabaseUrl/functions/v1/api-commitments")
            .addHeader("Authorization", "Bearer $token")
            .addHeader("X-Request-ID", requestId)
            .get()
            .build()

        val response = executeWithRetry(request)
        if (!response.isSuccessful) {
            if (response.code == 401) {
                // Token expired — caller should re-authenticate
                throw SyncException("Unauthorized", response.code)
            }
            throw SyncException("Pull failed: ${response.code}", response.code)
        }

        val body = response.body?.string() ?: return 0
        // Parse and merge would happen here
        // For now, return 0 as placeholder for remote data merge
        return 0
    }

    /**
     * Push locally modified commitments to the server in batches.
     */
    private suspend fun pushCommitments(token: String, supabaseUrl: String): Int {
        val pendingCommitments = commitmentDao.getPendingSync()
        if (pendingCommitments.isEmpty()) return 0

        var pushed = 0
        val batches = pendingCommitments.chunked(BATCH_SIZE)

        for (batch in batches) {
            val payloads = batch.map { it.toSyncPayload() }
            val requestId = UUID.randomUUID().toString()
            val jsonBody = json.encodeToString(payloads)

            val request = Request.Builder()
                .url("$supabaseUrl/functions/v1/api-commitments")
                .addHeader("Authorization", "Bearer $token")
                .addHeader("Content-Type", "application/json")
                .addHeader("X-Request-ID", requestId)
                .post(jsonBody.toRequestBody("application/json".toMediaType()))
                .build()

            val response = executeWithRetry(request)

            if (response.isSuccessful) {
                // Mark as synced
                for (commitment in batch) {
                    commitmentDao.update(
                        commitment.copy(
                            syncStatus = SyncStatus.SYNCED.value,
                            updatedAt = System.currentTimeMillis()
                        )
                    )
                }
                pushed += batch.size
            } else if (response.code == 401) {
                throw SyncException("Unauthorized during push", 401)
            } else {
                Log.e(TAG, "Push batch failed: ${response.code}")
            }

            // Delay between batches to avoid rate limiting
            if (batches.size > 1) {
                delay(BATCH_DELAY_MS)
            }
        }

        return pushed
    }

    /**
     * Execute request with retry logic for 429 and 5xx errors.
     */
    private suspend fun executeWithRetry(
        request: Request,
        maxRetries: Int = MAX_RETRIES
    ): okhttp3.Response {
        var lastResponse: okhttp3.Response? = null

        for (attempt in 0 until maxRetries) {
            val response = httpClient.newCall(request).execute()
            lastResponse = response

            when {
                response.isSuccessful -> return response

                response.code == 429 -> {
                    val retryAfter = response.header("Retry-After")?.toLongOrNull() ?: (attempt + 1) * 2L
                    Log.w(TAG, "Rate limited, retrying after ${retryAfter}s")
                    delay(retryAfter * 1000)
                }

                response.code in 500..599 -> {
                    val backoff = INITIAL_BACKOFF_MS * (1 shl attempt)
                    Log.w(TAG, "Server error ${response.code}, retrying in ${backoff}ms")
                    delay(backoff)
                }

                else -> return response // Client error, don't retry
            }
        }

        return lastResponse ?: throw SyncException("No response after $maxRetries retries", 0)
    }

    private fun CommitmentEntity.toSyncPayload() = SyncCommitmentPayload(
        id = id,
        entity_name = entityName,
        summary = summary,
        full_text = fullText,
        deadline = deadline,
        dollar_amount = dollarAmount,
        status = status,
        confidence_score = confidenceScore,
        ai_reasoning = aiReasoning,
        source = source,
        commitment_type = commitmentType,
        category = category,
        notes = notes,
        custom_status_label = customStatusLabel,
        workflow_id = workflowId,
        calendar_event_id = calendarEventId
    )

    sealed class SyncResult {
        data class Success(val pulled: Int, val pushed: Int) : SyncResult()
        data object Throttled : SyncResult()
        data class Error(val message: String) : SyncResult()
    }

    class SyncException(message: String, val statusCode: Int) : Exception(message)

    companion object {
        private const val TAG = "SyncService"
        const val MIN_SYNC_INTERVAL_MS = 30_000L // 30 seconds
        const val BATCH_SIZE = 50
        const val BATCH_DELAY_MS = 500L
        const val MAX_RETRIES = 3
        const val INITIAL_BACKOFF_MS = 1000L
    }
}
