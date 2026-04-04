package com.pearsonmedia.seddly

import com.pearsonmedia.seddly.service.SubscriptionTier
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for SubscriptionTier feature gating.
 */
class BillingServiceTest {

    @Test
    fun `FREE tier has AI extraction disabled`() {
        assertFalse(SubscriptionTier.FREE.isAIExtractionEnabled)
    }

    @Test
    fun `PRO tier has AI extraction enabled`() {
        assertTrue(SubscriptionTier.PRO.isAIExtractionEnabled)
    }

    @Test
    fun `PRO_PLUS tier has AI extraction enabled`() {
        assertTrue(SubscriptionTier.PRO_PLUS.isAIExtractionEnabled)
    }

    @Test
    fun `FREE tier has sync disabled`() {
        assertFalse(SubscriptionTier.FREE.isSyncEnabled)
    }

    @Test
    fun `PRO tier has sync disabled`() {
        assertFalse(SubscriptionTier.PRO.isSyncEnabled)
    }

    @Test
    fun `PRO_PLUS tier has sync enabled`() {
        assertTrue(SubscriptionTier.PRO_PLUS.isSyncEnabled)
    }

    @Test
    fun `FREE tier limited to 5 active commitments`() {
        assertEquals(5, SubscriptionTier.FREE.maxActiveCommitments)
    }

    @Test
    fun `PRO tier has unlimited commitments`() {
        assertEquals(Int.MAX_VALUE, SubscriptionTier.PRO.maxActiveCommitments)
    }

    @Test
    fun `PRO_PLUS tier has unlimited commitments`() {
        assertEquals(Int.MAX_VALUE, SubscriptionTier.PRO_PLUS.maxActiveCommitments)
    }
}
