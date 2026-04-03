package com.pearsonmedia.seddly.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.UUID

/**
 * Room entity logging all data transmissions for privacy transparency.
 */
@Entity(tableName = "privacy_audit_log")
data class PrivacyAuditEntry(
    @PrimaryKey
    val id: String = UUID.randomUUID().toString(),

    val timestamp: Long = System.currentTimeMillis(),

    @ColumnInfo(name = "event_type")
    val eventType: String,

    val destination: String,

    @ColumnInfo(name = "data_summary")
    val dataSummary: String,

    @ColumnInfo(name = "text_length_sent")
    val textLengthSent: Int,

    @ColumnInfo(name = "commitment_id")
    val commitmentId: String? = null
)

enum class AuditEventType(val value: String) {
    AI_EXTRACTION("ai_extraction"),
    DISPUTE_SUMMARY("dispute_summary"),
    CLOUD_SYNC("cloud_sync")
}
