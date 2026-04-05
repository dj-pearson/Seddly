package com.pearsonmedia.seddly

import com.pearsonmedia.seddly.service.ClipboardMonitorService
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Unit tests for ClipboardMonitorService constants and configuration.
 */
class ClipboardMonitorServiceTest {

    @Test
    fun `minimum text length is 30 characters`() {
        assertEquals(30, ClipboardMonitorService.MIN_TEXT_LENGTH)
    }

    @Test
    fun `minimum confidence score is 20`() {
        assertEquals(20, ClipboardMonitorService.MIN_CONFIDENCE_SCORE)
    }
}
