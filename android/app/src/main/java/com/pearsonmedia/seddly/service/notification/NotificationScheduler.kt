package com.pearsonmedia.seddly.service.notification

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.pearsonmedia.seddly.data.local.entity.CommitmentEntity
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Schedules deadline notifications via AlarmManager.
 * Mirrors the iOS NotificationService scheduling with:
 * - 24 hours before deadline: "Deadline Tomorrow" notification
 * - At deadline: "Commitment Overdue" notification
 * - Cancels alarms when commitment is fulfilled/dismissed/deleted
 * - Re-schedules on boot via BootReceiver
 */
@Singleton
class NotificationScheduler @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    /**
     * Schedule deadline notifications for a commitment.
     * Creates two alarms: 24h before (reminder) and at deadline (overdue).
     */
    fun scheduleDeadlineNotifications(commitment: CommitmentEntity) {
        val deadline = commitment.deadline ?: return
        val now = System.currentTimeMillis()

        // Schedule 24-hour reminder if deadline is > 24h from now
        val reminderTime = deadline - REMINDER_OFFSET_MS
        if (reminderTime > now) {
            scheduleAlarm(
                requestCode = reminderRequestCode(commitment.id),
                triggerAtMillis = reminderTime,
                commitmentId = commitment.id,
                type = NotificationType.REMINDER
            )
            Log.d(TAG, "Scheduled reminder for ${commitment.id} at $reminderTime")
        }

        // Schedule overdue notification at deadline
        if (deadline > now) {
            scheduleAlarm(
                requestCode = overdueRequestCode(commitment.id),
                triggerAtMillis = deadline,
                commitmentId = commitment.id,
                type = NotificationType.OVERDUE
            )
            Log.d(TAG, "Scheduled overdue for ${commitment.id} at $deadline")
        }
    }

    /**
     * Cancel all scheduled notifications for a commitment.
     */
    fun cancelNotifications(commitmentId: String) {
        cancelAlarm(reminderRequestCode(commitmentId))
        cancelAlarm(overdueRequestCode(commitmentId))
        Log.d(TAG, "Cancelled notifications for $commitmentId")
    }

    /**
     * Reschedule deadline when it changes.
     */
    fun rescheduleDeadline(commitment: CommitmentEntity) {
        cancelNotifications(commitment.id)
        scheduleDeadlineNotifications(commitment)
    }

    private fun scheduleAlarm(
        requestCode: Int,
        triggerAtMillis: Long,
        commitmentId: String,
        type: NotificationType
    ) {
        val intent = Intent(context, DeadlineAlarmReceiver::class.java).apply {
            putExtra(EXTRA_COMMITMENT_ID, commitmentId)
            putExtra(EXTRA_NOTIFICATION_TYPE, type.name)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent
                )
            } else {
                // Fall back to inexact alarm
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent
                )
            }
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent
            )
        }
    }

    private fun cancelAlarm(requestCode: Int) {
        val intent = Intent(context, DeadlineAlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }

    private fun reminderRequestCode(id: String): Int = id.hashCode()
    private fun overdueRequestCode(id: String): Int = id.hashCode() + OVERDUE_OFFSET

    enum class NotificationType {
        REMINDER, OVERDUE
    }

    companion object {
        private const val TAG = "NotificationScheduler"
        const val EXTRA_COMMITMENT_ID = "commitment_id"
        const val EXTRA_NOTIFICATION_TYPE = "notification_type"
        const val REMINDER_OFFSET_MS = 24 * 60 * 60 * 1000L // 24 hours
        const val OVERDUE_OFFSET = 100_000
    }
}

/**
 * BroadcastReceiver that fires when a deadline alarm triggers.
 * Looks up the commitment and sends the appropriate notification.
 */
class DeadlineAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val commitmentId = intent.getStringExtra(NotificationScheduler.EXTRA_COMMITMENT_ID) ?: return
        val typeName = intent.getStringExtra(NotificationScheduler.EXTRA_NOTIFICATION_TYPE) ?: return
        val type = NotificationScheduler.NotificationType.valueOf(typeName)

        Log.i("DeadlineAlarmReceiver", "Alarm fired for $commitmentId, type=$type")

        // The actual notification sending is handled by NotificationService
        // which will be triggered via WorkManager or direct service lookup.
        // This receiver queues the work.
        val workRequest = androidx.work.OneTimeWorkRequestBuilder<DeadlineNotificationWorker>()
            .setInputData(
                androidx.work.Data.Builder()
                    .putString("commitment_id", commitmentId)
                    .putString("notification_type", typeName)
                    .build()
            )
            .build()

        androidx.work.WorkManager.getInstance(context).enqueue(workRequest)
    }
}
