package com.pearsonmedia.seddly

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class SeddlyApplication : Application(), Configuration.Provider {

    @Inject
    lateinit var workerFactory: HiltWorkerFactory

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        val manager = getSystemService(NotificationManager::class.java)

        val deadlineChannel = NotificationChannel(
            CHANNEL_DEADLINES,
            "Deadline Reminders",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Notifications for approaching and overdue commitment deadlines"
        }

        val processingChannel = NotificationChannel(
            CHANNEL_PROCESSING,
            "Screenshot Processing",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Updates when screenshots are being analyzed"
        }

        manager.createNotificationChannels(listOf(deadlineChannel, processingChannel))
    }

    companion object {
        const val CHANNEL_DEADLINES = "seddly_deadlines"
        const val CHANNEL_PROCESSING = "seddly_processing"
    }
}
