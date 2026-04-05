package com.pearsonmedia.seddly.service

import android.content.ContentUris
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import com.pearsonmedia.seddly.data.local.dao.ProcessingQueueDao
import com.pearsonmedia.seddly.data.local.entity.ProcessingQueueEntry
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Screenshot library scanner using Android MediaStore.
 * Mirrors the iOS ScreenshotService (PHPhotoLibrary) with:
 * - Queries Screenshots folder for new images
 * - Filters to only images added since last scan
 * - Adds new screenshots to ProcessingQueue
 * - Respects READ_MEDIA_IMAGES permission on Android 13+
 */
@Singleton
class ScreenshotScannerService @Inject constructor(
    @ApplicationContext private val context: Context,
    private val processingQueueDao: ProcessingQueueDao
) {
    private var lastScanTimestamp: Long = 0

    /**
     * Scan the device's screenshot folder for new images.
     * Returns the number of new screenshots queued for processing.
     */
    suspend fun scanForNewScreenshots(): Int {
        val screenshots = queryScreenshots()
        var queued = 0

        for (screenshot in screenshots) {
            val uri = screenshot.uri.toString()

            // Skip if already in processing queue
            if (processingQueueDao.existsByUri(uri)) continue

            processingQueueDao.insert(
                ProcessingQueueEntry(
                    screenshotUri = uri,
                    createdAt = screenshot.dateAdded
                )
            )
            queued++
        }

        if (queued > 0) {
            Log.i(TAG, "Queued $queued new screenshots for processing")
        }

        lastScanTimestamp = System.currentTimeMillis()
        return queued
    }

    /**
     * Query MediaStore for screenshot images.
     * Looks in the Screenshots directory and filters by date.
     */
    private fun queryScreenshots(): List<ScreenshotInfo> {
        val screenshots = mutableListOf<ScreenshotInfo>()

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }

        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATE_ADDED,
            MediaStore.Images.Media.RELATIVE_PATH,
            MediaStore.Images.Media.SIZE
        )

        // Filter for screenshots directory only, and only new ones
        val selection = buildString {
            append("(")
            append("${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?")
            append(" OR ${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?")
            append(")")
            if (lastScanTimestamp > 0) {
                append(" AND ${MediaStore.Images.Media.DATE_ADDED} > ?")
            }
        }

        val selectionArgs = buildList {
            add("%Screenshots%")
            add("%Screenshot%")
            if (lastScanTimestamp > 0) {
                add((lastScanTimestamp / 1000).toString()) // MediaStore uses seconds
            }
        }.toTypedArray()

        val sortOrder = "${MediaStore.Images.Media.DATE_ADDED} DESC"

        context.contentResolver.query(
            collection, projection, selection, selectionArgs, sortOrder
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
            val dateColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.SIZE)

            while (cursor.moveToNext() && screenshots.size < MAX_SCREENSHOTS_PER_SCAN) {
                val id = cursor.getLong(idColumn)
                val name = cursor.getString(nameColumn)
                val dateAdded = cursor.getLong(dateColumn) * 1000 // Convert to millis
                val size = cursor.getLong(sizeColumn)

                // Skip very small images (likely thumbnails)
                if (size < MIN_IMAGE_SIZE_BYTES) continue

                val uri = ContentUris.withAppendedId(collection, id)
                screenshots.add(ScreenshotInfo(uri, name, dateAdded))
            }
        }

        Log.d(TAG, "Found ${screenshots.size} screenshots")
        return screenshots
    }

    private data class ScreenshotInfo(
        val uri: Uri,
        val name: String,
        val dateAdded: Long
    )

    companion object {
        private const val TAG = "ScreenshotScanner"
        const val MAX_SCREENSHOTS_PER_SCAN = 50
        const val MIN_IMAGE_SIZE_BYTES = 10_000L // 10KB minimum
    }
}
