package com.pearsonmedia.seddly.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID

/**
 * Room entity representing a tracked commitment extracted from screenshots or entered manually.
 * Mirrors the iOS LocalCommitment SwiftData model.
 */
@Entity(
    tableName = "commitments",
    indices = [
        Index(value = ["status", "deadline"]),
        Index(value = ["entity_name"]),
        Index(value = ["sync_status"]),
        Index(value = ["created_at"]),
        Index(value = ["needs_ai_processing"])
    ]
)
data class CommitmentEntity(
    @PrimaryKey
    val id: String = UUID.randomUUID().toString(),

    @ColumnInfo(name = "entity_name")
    val entityName: String,

    val summary: String,

    @ColumnInfo(name = "full_text")
    val fullText: String = "",

    val deadline: Long? = null,

    @ColumnInfo(name = "dollar_amount")
    val dollarAmount: Double? = null,

    val status: String = CommitmentStatus.PENDING.value,

    @ColumnInfo(name = "confidence_score")
    val confidenceScore: Int = 0,

    @ColumnInfo(name = "ai_reasoning")
    val aiReasoning: String? = null,

    val source: String = CommitmentSource.MANUAL.value,

    @ColumnInfo(name = "commitment_type")
    val commitmentType: String? = null,

    val category: String = CommitmentCategory.UNCATEGORIZED.value,

    @ColumnInfo(name = "screenshot_uri")
    val screenshotUri: String? = null,

    @ColumnInfo(name = "screenshot_date")
    val screenshotDate: Long? = null,

    val notes: String? = null,

    @ColumnInfo(name = "needs_ai_processing")
    val needsAIProcessing: Boolean = false,

    @ColumnInfo(name = "sync_status")
    val syncStatus: String = SyncStatus.LOCAL.value,

    @ColumnInfo(name = "custom_status_label")
    val customStatusLabel: String? = null,

    @ColumnInfo(name = "workflow_id")
    val workflowId: String? = null,

    @ColumnInfo(name = "calendar_event_id")
    val calendarEventId: String? = null,

    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),

    @ColumnInfo(name = "updated_at")
    val updatedAt: Long = System.currentTimeMillis(),

    @ColumnInfo(name = "deleted_at")
    val deletedAt: Long? = null
) {
    val isOverdue: Boolean
        get() {
            val dl = deadline ?: return false
            return status == CommitmentStatus.PENDING.value && dl < System.currentTimeMillis()
        }

    val urgencyLevel: UrgencyLevel
        get() {
            val dl = deadline ?: return UrgencyLevel.NONE
            val now = System.currentTimeMillis()
            val daysUntil = (dl - now) / (1000 * 60 * 60 * 24)
            return when {
                dl < now -> UrgencyLevel.OVERDUE
                daysUntil <= 6 -> UrgencyLevel.APPROACHING
                else -> UrgencyLevel.SAFE
            }
        }
}

enum class CommitmentStatus(val value: String) {
    PENDING("pending"),
    FULFILLED("fulfilled"),
    OVERDUE("overdue"),
    DISPUTED("disputed"),
    DISMISSED("dismissed");

    companion object {
        fun fromValue(value: String): CommitmentStatus =
            entries.firstOrNull { it.value == value } ?: PENDING
    }
}

enum class CommitmentType(val value: String) {
    FIRM_PROMISE("firm_promise"),
    SOFT_COMMITMENT("soft_commitment"),
    INFORMATIONAL("informational"),
    IRRELEVANT("irrelevant");

    companion object {
        fun fromValue(value: String): CommitmentType? =
            entries.firstOrNull { it.value == value }
    }
}

enum class CommitmentSource(val value: String) {
    AUTO("auto"),
    MANUAL("manual"),
    SHARE_SHEET("share_sheet");

    companion object {
        fun fromValue(value: String): CommitmentSource =
            entries.firstOrNull { it.value == value } ?: MANUAL
    }
}

enum class CommitmentCategory(val value: String, val displayName: String) {
    HOUSING("housing", "Housing"),
    FREELANCE("freelance", "Freelance"),
    PURCHASES("purchases", "Purchases"),
    PERSONAL("personal", "Personal"),
    MEDICAL("medical", "Medical"),
    INSURANCE("insurance", "Insurance"),
    UNCATEGORIZED("uncategorized", "Uncategorized");

    companion object {
        fun fromValue(value: String): CommitmentCategory =
            entries.firstOrNull { it.value == value } ?: UNCATEGORIZED
    }
}

enum class SyncStatus(val value: String) {
    LOCAL("local"),
    SYNCED("synced"),
    PENDING_SYNC("pending_sync");

    companion object {
        fun fromValue(value: String): SyncStatus =
            entries.firstOrNull { it.value == value } ?: LOCAL
    }
}

enum class UrgencyLevel {
    OVERDUE, APPROACHING, SAFE, NONE
}
