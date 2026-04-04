package com.pearsonmedia.seddly.service

import android.util.Log
import com.pearsonmedia.seddly.data.local.dao.CommitmentDao
import com.pearsonmedia.seddly.data.local.dao.EntityDao
import com.pearsonmedia.seddly.data.local.entity.EntityProfile
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Entity merging service that detects and merges duplicate entities.
 * Mirrors the iOS EntityMergingService with:
 * - Name similarity detection (60% threshold via Levenshtein distance)
 * - Merge operation: updates all commitments from secondary to primary entity
 * - Soft-deletes the secondary entity after merge
 */
@Singleton
class EntityMergingService @Inject constructor(
    private val entityDao: EntityDao,
    private val commitmentDao: CommitmentDao
) {
    /**
     * Find potential duplicate entities based on name similarity.
     * Returns pairs of (entity1, entity2) that are potential duplicates.
     */
    suspend fun findDuplicates(): List<Pair<EntityProfile, EntityProfile>> {
        val entities = entityDao.observeAll().first()
        val duplicates = mutableListOf<Pair<EntityProfile, EntityProfile>>()
        val seen = mutableSetOf<String>()

        for (i in entities.indices) {
            for (j in i + 1 until entities.size) {
                val similarity = calculateSimilarity(
                    entities[i].name.lowercase(),
                    entities[j].name.lowercase()
                )
                if (similarity >= SIMILARITY_THRESHOLD) {
                    val key = "${entities[i].id}-${entities[j].id}"
                    if (key !in seen) {
                        duplicates.add(entities[i] to entities[j])
                        seen.add(key)
                    }
                }
            }
        }

        Log.i(TAG, "Found ${duplicates.size} potential duplicate pairs")
        return duplicates
    }

    /**
     * Merge secondary entity into primary entity.
     * All commitments from secondary are reassigned to primary.
     * Secondary entity is soft-deleted.
     */
    suspend fun merge(primaryId: String, secondaryId: String): Boolean {
        return try {
            val primary = entityDao.getById(primaryId) ?: return false
            val secondary = entityDao.getById(secondaryId) ?: return false

            // Get all commitments belonging to secondary entity
            val commitments = commitmentDao.observeAll().first()
                .filter { it.entityName.equals(secondary.name, ignoreCase = true) }

            // Update each commitment to use primary entity name
            for (commitment in commitments) {
                commitmentDao.update(
                    commitment.copy(
                        entityName = primary.name,
                        updatedAt = System.currentTimeMillis()
                    )
                )
            }

            // Soft-delete the secondary entity
            entityDao.softDelete(secondaryId)

            Log.i(TAG, "Merged '${secondary.name}' into '${primary.name}' (${commitments.size} commitments)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Merge failed: $primaryId <- $secondaryId", e)
            false
        }
    }

    /**
     * Calculate string similarity using Levenshtein distance.
     * Returns a value between 0.0 (completely different) and 1.0 (identical).
     */
    internal fun calculateSimilarity(a: String, b: String): Double {
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
                dp[i][j] = minOf(
                    dp[i - 1][j] + 1,       // deletion
                    dp[i][j - 1] + 1,       // insertion
                    dp[i - 1][j - 1] + cost  // substitution
                )
            }
        }

        return dp[a.length][b.length]
    }

    companion object {
        private const val TAG = "EntityMergingService"
        const val SIMILARITY_THRESHOLD = 0.60
    }
}
