package com.pearsonmedia.seddly.service

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.provider.CalendarContract
import android.util.Log
import com.pearsonmedia.seddly.data.local.entity.CommitmentEntity
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.TimeZone
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Calendar integration service using Android CalendarProvider.
 * Mirrors the iOS CalendarService (EventKit) with:
 * - Creates calendar event with 24-hour reminder for commitments with deadlines
 * - Updates event when deadline changes
 * - Deletes event when commitment is fulfilled/dismissed/deleted
 * - Requires WRITE_CALENDAR and READ_CALENDAR runtime permissions
 */
@Singleton
class CalendarService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    /**
     * Create a calendar event for a commitment's deadline.
     * Returns the calendar event ID or null if creation fails.
     */
    fun createEvent(commitment: CommitmentEntity): String? {
        val deadline = commitment.deadline ?: return null

        return try {
            val calendarId = getPrimaryCalendarId() ?: return null

            val values = ContentValues().apply {
                put(CalendarContract.Events.CALENDAR_ID, calendarId)
                put(CalendarContract.Events.TITLE, "Seddly: ${commitment.entityName}")
                put(CalendarContract.Events.DESCRIPTION, commitment.summary)
                put(CalendarContract.Events.DTSTART, deadline)
                put(CalendarContract.Events.DTEND, deadline + EVENT_DURATION_MS)
                put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
                put(CalendarContract.Events.HAS_ALARM, 1)
            }

            val uri = context.contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
            val eventId = uri?.lastPathSegment

            // Add 24-hour reminder
            if (eventId != null) {
                addReminder(eventId.toLong(), REMINDER_MINUTES_BEFORE)
            }

            Log.i(TAG, "Created calendar event $eventId for ${commitment.id}")
            eventId
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create calendar event", e)
            null
        }
    }

    /**
     * Update an existing calendar event when the deadline changes.
     */
    fun updateEvent(calendarEventId: String, commitment: CommitmentEntity): Boolean {
        val deadline = commitment.deadline ?: return false

        return try {
            val values = ContentValues().apply {
                put(CalendarContract.Events.TITLE, "Seddly: ${commitment.entityName}")
                put(CalendarContract.Events.DESCRIPTION, commitment.summary)
                put(CalendarContract.Events.DTSTART, deadline)
                put(CalendarContract.Events.DTEND, deadline + EVENT_DURATION_MS)
            }

            val eventUri = ContentUris.withAppendedId(
                CalendarContract.Events.CONTENT_URI,
                calendarEventId.toLong()
            )

            val rows = context.contentResolver.update(eventUri, values, null, null)
            Log.i(TAG, "Updated calendar event $calendarEventId ($rows rows)")
            rows > 0
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update calendar event $calendarEventId", e)
            false
        }
    }

    /**
     * Delete a calendar event when commitment is fulfilled/dismissed/deleted.
     */
    fun deleteEvent(calendarEventId: String): Boolean {
        return try {
            val eventUri = ContentUris.withAppendedId(
                CalendarContract.Events.CONTENT_URI,
                calendarEventId.toLong()
            )

            val rows = context.contentResolver.delete(eventUri, null, null)
            Log.i(TAG, "Deleted calendar event $calendarEventId ($rows rows)")
            rows > 0
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete calendar event $calendarEventId", e)
            false
        }
    }

    private fun addReminder(eventId: Long, minutesBefore: Int) {
        try {
            val values = ContentValues().apply {
                put(CalendarContract.Reminders.EVENT_ID, eventId)
                put(CalendarContract.Reminders.MINUTES, minutesBefore)
                put(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_ALERT)
            }
            context.contentResolver.insert(CalendarContract.Reminders.CONTENT_URI, values)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add reminder for event $eventId", e)
        }
    }

    private fun getPrimaryCalendarId(): Long? {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.IS_PRIMARY
        )

        context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            "${CalendarContract.Calendars.VISIBLE} = 1",
            null,
            "${CalendarContract.Calendars.IS_PRIMARY} DESC"
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getLong(cursor.getColumnIndexOrThrow(CalendarContract.Calendars._ID))
            }
        }

        return null
    }

    companion object {
        private const val TAG = "CalendarService"
        const val EVENT_DURATION_MS = 60 * 60 * 1000L // 1 hour
        const val REMINDER_MINUTES_BEFORE = 24 * 60   // 24 hours
    }
}
