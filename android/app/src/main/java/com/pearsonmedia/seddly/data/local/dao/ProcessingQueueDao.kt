package com.pearsonmedia.seddly.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.pearsonmedia.seddly.data.local.entity.ProcessingQueueEntry
import kotlinx.coroutines.flow.Flow

@Dao
interface ProcessingQueueDao {

    @Query("SELECT * FROM processing_queue WHERE processing_status = 'pending' ORDER BY created_at ASC")
    suspend fun getPending(): List<ProcessingQueueEntry>

    @Query("SELECT * FROM processing_queue WHERE processing_status IN ('pending', 'processing') ORDER BY created_at ASC")
    fun observeActive(): Flow<List<ProcessingQueueEntry>>

    @Query("SELECT COUNT(*) FROM processing_queue WHERE processing_status IN ('pending', 'processing')")
    fun observeActiveCount(): Flow<Int>

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insert(entry: ProcessingQueueEntry)

    @Update
    suspend fun update(entry: ProcessingQueueEntry)

    @Query("UPDATE processing_queue SET processing_status = :status WHERE id = :id")
    suspend fun updateStatus(id: String, status: String)

    @Query("SELECT EXISTS(SELECT 1 FROM processing_queue WHERE screenshot_uri = :uri)")
    suspend fun existsByUri(uri: String): Boolean

    @Query("DELETE FROM processing_queue WHERE processing_status = 'completed'")
    suspend fun clearCompleted()
}
