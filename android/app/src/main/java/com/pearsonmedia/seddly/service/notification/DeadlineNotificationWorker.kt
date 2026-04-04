package com.pearsonmedia.seddly.service.notification

import android.content.Context
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.pearsonmedia.seddly.data.local.dao.CommitmentDao
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject

/**
 * Worker that sends deadline notifications.
 * Triggered by DeadlineAlarmReceiver when scheduled alarms fire.
 */
@HiltWorker
class DeadlineNotificationWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted workerParams: WorkerParameters,
    private val commitmentDao: CommitmentDao,
    private val notificationService: NotificationService
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        val commitmentId = inputData.getString("commitment_id") ?: return Result.failure()
        val typeName = inputData.getString("notification_type") ?: return Result.failure()

        val commitment = commitmentDao.getById(commitmentId)
        if (commitment == null) {
            Log.w(TAG, "Commitment $commitmentId not found, skipping notification")
            return Result.success()
        }

        // Don't notify for already fulfilled/dismissed commitments
        if (commitment.status != "pending") {
            Log.d(TAG, "Commitment $commitmentId is ${commitment.status}, skipping")
            return Result.success()
        }

        return try {
            when (NotificationScheduler.NotificationType.valueOf(typeName)) {
                NotificationScheduler.NotificationType.REMINDER -> {
                    notificationService.sendDeadlineReminder(commitment)
                    Log.i(TAG, "Sent deadline reminder for $commitmentId")
                }
                NotificationScheduler.NotificationType.OVERDUE -> {
                    notificationService.sendOverdueNotification(commitment)
                    Log.i(TAG, "Sent overdue notification for $commitmentId")
                }
            }
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send notification for $commitmentId", e)
            Result.retry()
        }
    }

    companion object {
        private const val TAG = "DeadlineNotifWorker"
    }
}
