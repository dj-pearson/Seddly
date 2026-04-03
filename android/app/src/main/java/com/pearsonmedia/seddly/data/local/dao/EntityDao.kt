package com.pearsonmedia.seddly.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.pearsonmedia.seddly.data.local.entity.EntityProfile
import com.pearsonmedia.seddly.data.local.entity.EntityWithStats
import kotlinx.coroutines.flow.Flow

@Dao
interface EntityDao {

    @Query("SELECT * FROM entities WHERE deleted_at IS NULL ORDER BY name ASC")
    fun observeAll(): Flow<List<EntityProfile>>

    @Query("SELECT * FROM entities WHERE id = :id")
    suspend fun getById(id: String): EntityProfile?

    @Query("SELECT * FROM entities WHERE LOWER(name) = LOWER(:name) AND deleted_at IS NULL LIMIT 1")
    suspend fun findByName(name: String): EntityProfile?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: EntityProfile)

    @Query("UPDATE entities SET deleted_at = :deletedAt WHERE id = :id")
    suspend fun softDelete(id: String, deletedAt: Long = System.currentTimeMillis())

    @Query("""
        SELECT e.id, e.name,
            COUNT(c.id) as totalCommitments,
            SUM(CASE WHEN c.status = 'fulfilled' THEN 1 ELSE 0 END) as fulfilledCount,
            SUM(CASE WHEN c.status = 'overdue' THEN 1 ELSE 0 END) as overdueCount,
            SUM(CASE WHEN c.status = 'pending' THEN 1 ELSE 0 END) as pendingCount,
            SUM(CASE WHEN c.status = 'disputed' THEN 1 ELSE 0 END) as disputedCount,
            SUM(CASE WHEN c.status = 'dismissed' THEN 1 ELSE 0 END) as dismissedCount
        FROM entities e
        LEFT JOIN commitments c ON LOWER(e.name) = LOWER(c.entity_name) AND c.deleted_at IS NULL
        WHERE e.id = :entityId AND e.deleted_at IS NULL
        GROUP BY e.id
    """)
    suspend fun getEntityWithStats(entityId: String): EntityWithStats?

    @Query("""
        SELECT e.id, e.name,
            COUNT(c.id) as totalCommitments,
            SUM(CASE WHEN c.status = 'fulfilled' THEN 1 ELSE 0 END) as fulfilledCount,
            SUM(CASE WHEN c.status = 'overdue' THEN 1 ELSE 0 END) as overdueCount,
            SUM(CASE WHEN c.status = 'pending' THEN 1 ELSE 0 END) as pendingCount,
            SUM(CASE WHEN c.status = 'disputed' THEN 1 ELSE 0 END) as disputedCount,
            SUM(CASE WHEN c.status = 'dismissed' THEN 1 ELSE 0 END) as dismissedCount
        FROM entities e
        LEFT JOIN commitments c ON LOWER(e.name) = LOWER(c.entity_name) AND c.deleted_at IS NULL
        WHERE e.deleted_at IS NULL
        GROUP BY e.id
        ORDER BY totalCommitments DESC
    """)
    fun observeAllWithStats(): Flow<List<EntityWithStats>>
}
