package com.pearsonmedia.seddly.di

import android.content.Context
import androidx.room.Room
import com.pearsonmedia.seddly.data.local.SeddlyDatabase
import com.pearsonmedia.seddly.data.local.dao.CommitmentDao
import com.pearsonmedia.seddly.data.local.dao.EntityDao
import com.pearsonmedia.seddly.data.local.dao.PrivacyAuditDao
import com.pearsonmedia.seddly.data.local.dao.ProcessingQueueDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): SeddlyDatabase {
        return Room.databaseBuilder(
            context,
            SeddlyDatabase::class.java,
            SeddlyDatabase.DATABASE_NAME
        )
            .fallbackToDestructiveMigration(false)
            .build()
    }

    @Provides
    fun provideCommitmentDao(db: SeddlyDatabase): CommitmentDao = db.commitmentDao()

    @Provides
    fun provideEntityDao(db: SeddlyDatabase): EntityDao = db.entityDao()

    @Provides
    fun provideProcessingQueueDao(db: SeddlyDatabase): ProcessingQueueDao = db.processingQueueDao()

    @Provides
    fun providePrivacyAuditDao(db: SeddlyDatabase): PrivacyAuditDao = db.privacyAuditDao()

    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient {
        return OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()
    }
}
