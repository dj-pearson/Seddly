package com.pearsonmedia.seddly

import com.pearsonmedia.seddly.service.sync.SyncService
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Unit tests for SyncService constants and configuration.
 */
class SyncServiceTest {

    @Test
    fun `minimum sync interval is 30 seconds`() {
        assertEquals(30_000L, SyncService.MIN_SYNC_INTERVAL_MS)
    }

    @Test
    fun `batch size is 50`() {
        assertEquals(50, SyncService.BATCH_SIZE)
    }

    @Test
    fun `batch delay is 500ms`() {
        assertEquals(500L, SyncService.BATCH_DELAY_MS)
    }

    @Test
    fun `max retries is 3`() {
        assertEquals(3, SyncService.MAX_RETRIES)
    }

    @Test
    fun `initial backoff is 1 second`() {
        assertEquals(1000L, SyncService.INITIAL_BACKOFF_MS)
    }
}
