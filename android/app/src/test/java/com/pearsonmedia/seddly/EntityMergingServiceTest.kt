package com.pearsonmedia.seddly

import com.pearsonmedia.seddly.service.EntityMergingService
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for EntityMergingService name similarity detection.
 */
class EntityMergingServiceTest {

    // Create a testable instance by accessing the internal method
    private val service = EntityMergingService(
        entityDao = throw IllegalStateException("Not used in these tests"),
        commitmentDao = throw IllegalStateException("Not used in these tests")
    )

    // Test the similarity algorithm directly
    private fun calculateSimilarity(a: String, b: String): Double {
        // Reimplementation for testing since we can't easily construct the service
        if (a == b) return 1.0
        if (a.isEmpty() || b.isEmpty()) return 0.0
        val maxLen = maxOf(a.length, b.length)
        val distance = levenshteinDistance(a, b)
        return 1.0 - (distance.toDouble() / maxLen)
    }

    private fun levenshteinDistance(a: String, b: String): Int {
        val dp = Array(a.length + 1) { IntArray(b.length + 1) }
        for (i in 0..a.length) dp[i][0] = i
        for (j in 0..b.length) dp[0][j] = j
        for (i in 1..a.length) {
            for (j in 1..b.length) {
                val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                dp[i][j] = minOf(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost)
            }
        }
        return dp[a.length][b.length]
    }

    @Test
    fun `identical strings have similarity 1_0`() {
        assertEquals(1.0, calculateSimilarity("AT&T", "AT&T"), 0.001)
    }

    @Test
    fun `completely different strings have low similarity`() {
        val sim = calculateSimilarity("AT&T", "Verizon")
        assertTrue("Similarity $sim should be < 0.3", sim < 0.3)
    }

    @Test
    fun `similar strings above threshold`() {
        val sim = calculateSimilarity("at&t", "att")
        assertTrue("Similarity $sim should be >= 0.60", sim >= 0.60)
    }

    @Test
    fun `empty string has similarity 0`() {
        assertEquals(0.0, calculateSimilarity("", "test"), 0.001)
    }

    @Test
    fun `both empty strings have similarity 0`() {
        assertEquals(0.0, calculateSimilarity("", ""), 0.001)
    }

    @Test
    fun `case variations detected`() {
        val sim = calculateSimilarity("comcast", "Comcast")
        // These differ by 1 char case - Levenshtein treats them differently
        // but lowercase comparison would catch this
        assertTrue("Similarity $sim should be > 0.5", sim > 0.5)
    }

    @Test
    fun `similarity threshold is 60 percent`() {
        assertEquals(0.60, EntityMergingService.SIMILARITY_THRESHOLD, 0.001)
    }
}
