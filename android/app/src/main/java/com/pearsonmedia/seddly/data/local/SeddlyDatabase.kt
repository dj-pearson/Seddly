package com.pearsonmedia.seddly.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import com.pearsonmedia.seddly.data.local.dao.CommitmentDao
import com.pearsonmedia.seddly.data.local.dao.EntityDao
import com.pearsonmedia.seddly.data.local.dao.PrivacyAuditDao
import com.pearsonmedia.seddly.data.local.dao.ProcessingQueueDao
import com.pearsonmedia.seddly.data.local.entity.CommitmentEntity
import com.pearsonmedia.seddly.data.local.entity.EntityProfile
import com.pearsonmedia.seddly.data.local.entity.PrivacyAuditEntry
import com.pearsonmedia.seddly.data.local.entity.ProcessingQueueEntry

@Database(
    entities = [
        CommitmentEntity::class,
        EntityProfile::class,
        ProcessingQueueEntry::class,
        PrivacyAuditEntry::class
    ],
    version = 1,
    exportSchema = true
)
abstract class SeddlyDatabase : RoomDatabase() {
    abstract fun commitmentDao(): CommitmentDao
    abstract fun entityDao(): EntityDao
    abstract fun processingQueueDao(): ProcessingQueueDao
    abstract fun privacyAuditDao(): PrivacyAuditDao

    companion object {
        const val DATABASE_NAME = "seddly_db"
    }
}
