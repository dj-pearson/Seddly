package com.pearsonmedia.seddly.service

import android.content.Context
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.pearsonmedia.seddly.data.local.dao.CommitmentDao
import com.pearsonmedia.seddly.service.notification.NotificationService
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject

/**
 * Background worker that marks overdue commitments and sends notifications.
 * Mirrors the iOS StatusUpdateService.
 */
@HiltWorker
class StatusUpdateWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted workerParams: WorkerParameters,
    private val commitmentDao: CommitmentDao,
    private val notificationService: NotificationService
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        return try {
            val updated = commitmentDao.markOverdueCommitments()
            Log.i(TAG, "Marked $updated commitments as overdue")

            // Send notifications for newly overdue commitments
            if (updated > 0) {
                val overdueCommitments = commitmentDao.getPendingAIProcessing()
                // Note: This would be refined to only notify for newly overdue items
            }

            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Status update failed", e)
            Result.retry()
        }
    }

    companion object {
        private const val TAG = "StatusUpdateWorker"
        const val WORK_NAME = "status_update"
    }
}
