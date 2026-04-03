package com.pearsonmedia.seddly.data.repository

import com.pearsonmedia.seddly.data.local.dao.CommitmentDao
import com.pearsonmedia.seddly.data.local.dao.EntityDao
import com.pearsonmedia.seddly.data.local.entity.CommitmentEntity
import com.pearsonmedia.seddly.data.local.entity.EntityProfile
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class CommitmentRepository @Inject constructor(
    private val commitmentDao: CommitmentDao,
    private val entityDao: EntityDao
) {
    fun observeAll(): Flow<List<CommitmentEntity>> = commitmentDao.observeAll()

    fun observePaginated(limit: Int, offset: Int): Flow<List<CommitmentEntity>> =
        commitmentDao.observePaginated(limit, offset)

    fun observeByStatus(status: String): Flow<List<CommitmentEntity>> =
        commitmentDao.observeByStatus(status)

    fun observeById(id: String): Flow<CommitmentEntity?> = commitmentDao.observeById(id)

    fun observeOverdueCount(): Flow<Int> = commitmentDao.observeOverdueCount()

    fun observeTotalCount(): Flow<Int> = commitmentDao.observeTotalCount()

    fun search(query: String): Flow<List<CommitmentEntity>> = commitmentDao.search(query)

    fun observeEntityNames(): Flow<List<String>> = commitmentDao.observeEntityNames()

    suspend fun getById(id: String): CommitmentEntity? = commitmentDao.getById(id)

    suspend fun insert(commitment: CommitmentEntity) {
        commitmentDao.insert(commitment)
        // Ensure entity profile exists (case-insensitive dedup)
        val existing = entityDao.findByName(commitment.entityName)
        if (existing == null) {
            entityDao.insert(EntityProfile(name = commitment.entityName))
        }
    }

    suspend fun update(commitment: CommitmentEntity) {
        commitmentDao.update(commitment.copy(updatedAt = System.currentTimeMillis()))
    }

    suspend fun updateStatus(id: String, status: String) {
        commitmentDao.updateStatus(id, status)
    }

    suspend fun bulkUpdateStatus(ids: List<String>, status: String) {
        commitmentDao.bulkUpdateStatus(ids, status)
    }

    suspend fun softDelete(id: String) {
        commitmentDao.softDelete(id)
    }

    suspend fun markOverdueCommitments(): Int {
        return commitmentDao.markOverdueCommitments()
    }

    suspend fun getPendingAIProcessing(): List<CommitmentEntity> {
        return commitmentDao.getPendingAIProcessing()
    }
}
