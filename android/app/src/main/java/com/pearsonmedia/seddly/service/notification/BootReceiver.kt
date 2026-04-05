package com.pearsonmedia.seddly.service.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

/**
 * Re-schedules all deadline notifications after device reboot.
 * AlarmManager alarms are cleared on reboot, so this restores them.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        Log.i(TAG, "Device booted — rescheduling deadline notifications")

        // Enqueue a one-time worker to re-read all commitments and reschedule
        val workRequest = OneTimeWorkRequestBuilder<RescheduleNotificationsWorker>()
            .build()

        WorkManager.getInstance(context).enqueue(workRequest)
    }

    companion object {
        private const val TAG = "BootReceiver"
    }
}
