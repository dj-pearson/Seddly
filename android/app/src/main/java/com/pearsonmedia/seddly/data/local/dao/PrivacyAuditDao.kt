package com.pearsonmedia.seddly.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import com.pearsonmedia.seddly.data.local.entity.PrivacyAuditEntry
import kotlinx.coroutines.flow.Flow

@Dao
interface PrivacyAuditDao {

    @Query("SELECT * FROM privacy_audit_log ORDER BY timestamp DESC")
    fun observeAll(): Flow<List<PrivacyAuditEntry>>

    @Query("SELECT * FROM privacy_audit_log ORDER BY timestamp DESC LIMIT :limit")
    fun observeRecent(limit: Int): Flow<List<PrivacyAuditEntry>>

    @Insert
    suspend fun insert(entry: PrivacyAuditEntry)

    @Query("SELECT COUNT(*) FROM privacy_audit_log")
    fun observeCount(): Flow<Int>

    @Query("DELETE FROM privacy_audit_log")
    suspend fun deleteAll()
}
