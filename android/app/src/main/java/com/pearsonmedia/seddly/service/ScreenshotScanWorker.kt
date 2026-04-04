package com.pearsonmedia.seddly.service

import android.content.Context
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import java.util.concurrent.TimeUnit

/**
 * Periodic worker that scans for new screenshots and queues them for processing.
 * Runs every 15 minutes when device is idle.
 */
@HiltWorker
class ScreenshotScanWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted workerParams: WorkerParameters,
    private val screenshotScanner: ScreenshotScannerService
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        return try {
            val queued = screenshotScanner.scanForNewScreenshots()
            Log.i(TAG, "Screenshot scan complete: $queued new screenshots queued")
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Screenshot scan failed", e)
            Result.retry()
        }
    }

    companion object {
        private const val TAG = "ScreenshotScanWorker"
        const val WORK_NAME = "screenshot_scan"

        /**
         * Enqueue periodic screenshot scanning (every 15 minutes).
         */
        fun enqueuePeriodicScan(context: Context) {
            val workRequest = PeriodicWorkRequestBuilder<ScreenshotScanWorker>(
                15, TimeUnit.MINUTES
            ).build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                workRequest
            )
        }
    }
}
