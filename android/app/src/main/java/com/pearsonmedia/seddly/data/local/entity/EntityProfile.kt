package com.pearsonmedia.seddly.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID

/**
 * Room entity representing a person or organization that made commitments.
 * Mirrors the iOS LocalEntity SwiftData model.
 */
@Entity(
    tableName = "entities",
    indices = [
        Index(value = ["name"], unique = true)
    ]
)
data class EntityProfile(
    @PrimaryKey
    val id: String = UUID.randomUUID().toString(),

    val name: String,

    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),

    @ColumnInfo(name = "updated_at")
    val updatedAt: Long = System.currentTimeMillis(),

    @ColumnInfo(name = "deleted_at")
    val deletedAt: Long? = null
)

/**
 * Aggregated entity stats computed from commitments.
 */
data class EntityWithStats(
    val id: String,
    val name: String,
    val totalCommitments: Int,
    val fulfilledCount: Int,
    val overdueCount: Int,
    val pendingCount: Int,
    val disputedCount: Int,
    val dismissedCount: Int
) {
    val fulfillmentRate: Double
        get() = if (totalCommitments > 0) fulfilledCount.toDouble() / totalCommitments else 0.0

    val accountabilityScore: Int
        get() {
            if (totalCommitments == 0) return 0
            val base = (fulfilledCount.toDouble() / totalCommitments) * 100
            val penalty = (overdueCount.toDouble() / totalCommitments) * 30
            return (base - penalty).toInt().coerceIn(0, 100)
        }

    val accountabilityGrade: String
        get() = when {
            accountabilityScore >= 90 -> "A"
            accountabilityScore >= 80 -> "B"
            accountabilityScore >= 70 -> "C"
            accountabilityScore >= 60 -> "D"
            else -> "F"
        }
}
