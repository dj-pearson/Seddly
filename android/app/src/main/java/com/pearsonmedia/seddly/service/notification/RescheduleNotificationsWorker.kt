package com.pearsonmedia.seddly.service.notification

import android.content.Context
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.pearsonmedia.seddly.data.local.dao.CommitmentDao
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.flow.first

/**
 * Worker that re-schedules all deadline notifications.
 * Used after device reboot (AlarmManager alarms are lost on reboot).
 */
@HiltWorker
class RescheduleNotificationsWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted workerParams: WorkerParameters,
    private val commitmentDao: CommitmentDao,
    private val notificationScheduler: NotificationScheduler
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        return try {
            val commitments = commitmentDao.observeByStatus("pending").first()
            var scheduled = 0

            for (commitment in commitments) {
                if (commitment.deadline != null && commitment.deadline > System.currentTimeMillis()) {
                    notificationScheduler.scheduleDeadlineNotifications(commitment)
                    scheduled++
                }
            }

            Log.i(TAG, "Rescheduled notifications for $scheduled commitments")
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reschedule notifications", e)
            Result.retry()
        }
    }

    companion object {
        private const val TAG = "RescheduleWorker"
    }
}
