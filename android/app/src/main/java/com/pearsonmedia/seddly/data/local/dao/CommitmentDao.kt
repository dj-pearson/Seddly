package com.pearsonmedia.seddly.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.pearsonmedia.seddly.data.local.entity.CommitmentEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface CommitmentDao {

    @Query("SELECT * FROM commitments WHERE deleted_at IS NULL ORDER BY created_at DESC")
    fun observeAll(): Flow<List<CommitmentEntity>>

    @Query("SELECT * FROM commitments WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT :limit OFFSET :offset")
    fun observePaginated(limit: Int, offset: Int): Flow<List<CommitmentEntity>>

    @Query("SELECT * FROM commitments WHERE deleted_at IS NULL AND status = :status ORDER BY deadline ASC")
    fun observeByStatus(status: String): Flow<List<CommitmentEntity>>

    @Query("SELECT * FROM commitments WHERE id = :id")
    suspend fun getById(id: String): CommitmentEntity?

    @Query("SELECT * FROM commitments WHERE id = :id")
    fun observeById(id: String): Flow<CommitmentEntity?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(commitment: CommitmentEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(commitments: List<CommitmentEntity>)

    @Update
    suspend fun update(commitment: CommitmentEntity)

    @Query("UPDATE commitments SET status = :status, updated_at = :updatedAt WHERE id = :id")
    suspend fun updateStatus(id: String, status: String, updatedAt: Long = System.currentTimeMillis())

    @Query("UPDATE commitments SET status = :status, updated_at = :updatedAt WHERE id IN (:ids)")
    suspend fun bulkUpdateStatus(ids: List<String>, status: String, updatedAt: Long = System.currentTimeMillis())

    @Query("UPDATE commitments SET deleted_at = :deletedAt WHERE id = :id")
    suspend fun softDelete(id: String, deletedAt: Long = System.currentTimeMillis())

    @Query("DELETE FROM commitments WHERE id = :id")
    suspend fun hardDelete(id: String)

    @Query("SELECT * FROM commitments WHERE needs_ai_processing = 1 AND deleted_at IS NULL")
    suspend fun getPendingAIProcessing(): List<CommitmentEntity>

    @Query("SELECT * FROM commitments WHERE sync_status = 'pending_sync' AND deleted_at IS NULL")
    suspend fun getPendingSync(): List<CommitmentEntity>

    @Query("SELECT COUNT(*) FROM commitments WHERE status = 'overdue' AND deleted_at IS NULL")
    fun observeOverdueCount(): Flow<Int>

    @Query("SELECT COUNT(*) FROM commitments WHERE deleted_at IS NULL")
    fun observeTotalCount(): Flow<Int>

    @Query("""
        UPDATE commitments SET status = 'overdue', updated_at = :now
        WHERE status = 'pending' AND deadline IS NOT NULL AND deadline < :now AND deleted_at IS NULL
    """)
    suspend fun markOverdueCommitments(now: Long = System.currentTimeMillis()): Int

    @Query("""
        SELECT * FROM commitments
        WHERE deleted_at IS NULL
        AND (entity_name LIKE '%' || :query || '%' OR summary LIKE '%' || :query || '%' OR full_text LIKE '%' || :query || '%')
        ORDER BY created_at DESC
    """)
    fun search(query: String): Flow<List<CommitmentEntity>>

    @Query("SELECT DISTINCT entity_name FROM commitments WHERE deleted_at IS NULL ORDER BY entity_name ASC")
    fun observeEntityNames(): Flow<List<String>>
}
