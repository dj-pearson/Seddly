package com.pearsonmedia.seddly.service.ai

import android.util.Log
import com.pearsonmedia.seddly.data.local.dao.PrivacyAuditDao
import com.pearsonmedia.seddly.data.local.entity.AuditEventType
import com.pearsonmedia.seddly.data.local.entity.PrivacyAuditEntry
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import javax.inject.Inject
import javax.inject.Singleton

@Serializable
data class ExtractionResult(
    val entityName: String = "",
    val summary: String = "",
    val commitmentType: String = "informational",
    val category: String = "uncategorized",
    val deadline: String? = null,
    val dollarAmount: Double? = null,
    val confidenceScore: Int = 0,
    val aiReasoning: String? = null
)

@Serializable
data class ExtractionResponse(
    val commitments: List<ExtractionResult> = emptyList()
)

/**
 * Calls Claude AI via Supabase Edge Function to extract commitments from OCR text.
 * Mirrors the iOS AIExtractionService with:
 * - Request deduplication
 * - Result caching (5-minute TTL)
 * - Prompt injection protection (XML boundaries + text sanitization)
 * - Privacy audit logging
 * - Retry with exponential backoff
 */
@Singleton
class AIExtractionService @Inject constructor(
    private val httpClient: OkHttpClient,
    private val privacyAuditDao: PrivacyAuditDao
) {
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val cache = ConcurrentHashMap<String, CachedResult>()
    private val inFlightRequests = ConcurrentHashMap<String, Mutex>()

    private data class CachedResult(
        val result: List<ExtractionResult>,
        val timestamp: Long
    )

    /**
     * Extract commitments from OCR text via AI endpoint.
     * Returns empty list if extraction fails or text is irrelevant.
     */
    suspend fun extractCommitments(
        text: String,
        supabaseUrl: String,
        supabaseKey: String
    ): List<ExtractionResult> {
        if (text.isBlank() || text.length < MIN_TEXT_LENGTH) return emptyList()

        val truncated = if (text.length > MAX_TEXT_LENGTH) text.take(MAX_TEXT_LENGTH) else text
        val cacheKey = truncated.hashCode().toString()

        // Check cache
        cache[cacheKey]?.let { cached ->
            if (System.currentTimeMillis() - cached.timestamp < CACHE_TTL_MS) {
                return cached.result
            }
            cache.remove(cacheKey)
        }

        // Deduplicate in-flight requests
        val mutex = inFlightRequests.getOrPut(cacheKey) { Mutex() }
        return mutex.withLock {
            // Re-check cache after acquiring lock
            cache[cacheKey]?.let { cached ->
                if (System.currentTimeMillis() - cached.timestamp < CACHE_TTL_MS) {
                    return@withLock cached.result
                }
            }

            try {
                val result = callExtractionEndpoint(truncated, supabaseUrl, supabaseKey)

                // Cache result
                cache[cacheKey] = CachedResult(result, System.currentTimeMillis())

                // Log to privacy audit
                logPrivacyAudit(truncated, supabaseUrl)

                result
            } catch (e: Exception) {
                Log.e(TAG, "AI extraction failed", e)
                emptyList()
            } finally {
                inFlightRequests.remove(cacheKey)
            }
        }
    }

    private suspend fun callExtractionEndpoint(
        text: String,
        supabaseUrl: String,
        supabaseKey: String
    ): List<ExtractionResult> {
        // Sanitize input — strip XML-like tags to prevent prompt injection boundary escape
        val sanitized = sanitizeUserInput(text)

        // Detect suspicious patterns
        if (detectSuspiciousPatterns(sanitized)) {
            Log.w(TAG, "Suspicious patterns detected in input text")
        }

        val requestId = UUID.randomUUID().toString()
        val requestBody = """{"text": ${Json.encodeToString(kotlinx.serialization.serializer<String>(), sanitized)}}"""

        var lastException: Exception? = null

        // Retry with exponential backoff (max 3 attempts)
        for (attempt in 0 until MAX_RETRIES) {
            try {
                val request = Request.Builder()
                    .url("$supabaseUrl/functions/v1/extract-commitments")
                    .addHeader("Authorization", "Bearer $supabaseKey")
                    .addHeader("Content-Type", "application/json")
                    .addHeader("X-Request-ID", requestId)
                    .post(requestBody.toRequestBody("application/json".toMediaType()))
                    .build()

                val response = httpClient.newCall(request).execute()

                if (response.code == 429) {
                    // Rate limited — wait and retry
                    val retryAfter = response.header("Retry-After")?.toLongOrNull() ?: (attempt + 1) * 2L
                    kotlinx.coroutines.delay(retryAfter * 1000)
                    continue
                }

                if (!response.isSuccessful) {
                    throw Exception("AI extraction failed with status ${response.code}")
                }

                val body = response.body?.string() ?: throw Exception("Empty response body")
                val extractionResponse = json.decodeFromString<ExtractionResponse>(body)
                return extractionResponse.commitments

            } catch (e: Exception) {
                lastException = e
                if (attempt < MAX_RETRIES - 1) {
                    val delay = INITIAL_BACKOFF_MS * (1 shl attempt)
                    kotlinx.coroutines.delay(delay)
                }
            }
        }

        throw lastException ?: Exception("AI extraction failed after $MAX_RETRIES attempts")
    }

    private suspend fun logPrivacyAudit(text: String, destination: String) {
        try {
            privacyAuditDao.insert(
                PrivacyAuditEntry(
                    eventType = AuditEventType.AI_EXTRACTION.value,
                    destination = destination,
                    dataSummary = "OCR text sent for commitment extraction",
                    textLengthSent = text.length
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to log privacy audit", e)
        }
    }

    companion object {
        private const val TAG = "AIExtractionService"
        private const val MIN_TEXT_LENGTH = 10
        private const val MAX_TEXT_LENGTH = 10_000
        private const val CACHE_TTL_MS = 5 * 60 * 1000L // 5 minutes
        private const val MAX_RETRIES = 3
        private const val INITIAL_BACKOFF_MS = 1000L

        /**
         * Sanitize user input by stripping XML-like tags to prevent prompt injection.
         * Mirrors iOS sanitizeUserInput() in extract-commitments Edge Function.
         */
        fun sanitizeUserInput(text: String): String {
            return text.replace(Regex("<[^>]*>"), "")
        }

        /**
         * Detect common prompt injection patterns.
         * Returns true if suspicious patterns found.
         */
        fun detectSuspiciousPatterns(text: String): Boolean {
            val lowerText = text.lowercase()
            val suspiciousPatterns = listOf(
                "ignore previous instructions",
                "ignore all previous",
                "disregard above",
                "system prompt",
                "you are now",
                "new instructions",
                "override",
                "jailbreak"
            )
            return suspiciousPatterns.any { lowerText.contains(it) }
        }
    }
}
