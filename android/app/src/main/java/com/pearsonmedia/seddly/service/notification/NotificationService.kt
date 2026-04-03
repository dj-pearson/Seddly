package com.pearsonmedia.seddly.service.notification

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.pearsonmedia.seddly.R
import com.pearsonmedia.seddly.SeddlyApplication
import com.pearsonmedia.seddly.data.local.entity.CommitmentEntity
import com.pearsonmedia.seddly.ui.MainActivity
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Local notification service for deadline reminders.
 * Mirrors the iOS NotificationService with:
 * - Deadline approaching (24 hours before)
 * - Commitment overdue (1 day after deadline)
 */
@Singleton
class NotificationService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val notificationManager = NotificationManagerCompat.from(context)

    fun sendDeadlineReminder(commitment: CommitmentEntity) {
        if (!hasPermission()) return

        val intent = Intent(context, MainActivity::class.java).apply {
            data = android.net.Uri.parse("seddly://commitment/${commitment.id}")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context, commitment.id.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, SeddlyApplication.CHANNEL_DEADLINES)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Deadline Tomorrow")
            .setContentText("${commitment.entityName}: ${commitment.summary}")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(commitment.id.hashCode(), notification)
    }

    fun sendOverdueNotification(commitment: CommitmentEntity) {
        if (!hasPermission()) return

        val intent = Intent(context, MainActivity::class.java).apply {
            data = android.net.Uri.parse("seddly://commitment/${commitment.id}")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context, commitment.id.hashCode() + 1000, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, SeddlyApplication.CHANNEL_DEADLINES)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Commitment Overdue")
            .setContentText("${commitment.entityName}: ${commitment.summary}")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setColor(0xFFEF5350.toInt())
            .build()

        notificationManager.notify(commitment.id.hashCode() + 1000, notification)
    }

    private fun hasPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }
}
