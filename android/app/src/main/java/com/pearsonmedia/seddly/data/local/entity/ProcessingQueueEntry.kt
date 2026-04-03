package com.pearsonmedia.seddly.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID

/**
 * Room entity tracking screenshots in the processing pipeline.
 */
@Entity(
    tableName = "processing_queue",
    indices = [
        Index(value = ["processing_status"]),
        Index(value = ["screenshot_uri"], unique = true)
    ]
)
data class ProcessingQueueEntry(
    @PrimaryKey
    val id: String = UUID.randomUUID().toString(),

    @ColumnInfo(name = "screenshot_uri")
    val screenshotUri: String,

    @ColumnInfo(name = "extracted_text")
    val extractedText: String? = null,

    @ColumnInfo(name = "classifier_result")
    val classifierResult: String? = null,

    @ColumnInfo(name = "rule_based_score")
    val ruleBasedScore: Int? = null,

    @ColumnInfo(name = "processing_status")
    val processingStatus: String = ProcessingStatus.PENDING.value,

    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis()
)

enum class ProcessingStatus(val value: String) {
    PENDING("pending"),
    PROCESSING("processing"),
    AWAITING_REVIEW("awaiting_review"),
    COMPLETED("completed"),
    SKIPPED("skipped");

    companion object {
        fun fromValue(value: String): ProcessingStatus =
            entries.firstOrNull { it.value == value } ?: PENDING
    }
}
