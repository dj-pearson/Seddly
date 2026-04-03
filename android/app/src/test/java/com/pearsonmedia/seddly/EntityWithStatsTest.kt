package com.pearsonmedia.seddly

import com.pearsonmedia.seddly.data.local.entity.EntityWithStats
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Unit tests for EntityWithStats accountability scoring.
 * Mirrors iOS LocalEntity accountability score tests.
 */
class EntityWithStatsTest {

    private fun createEntity(
        total: Int = 10,
        fulfilled: Int = 0,
        overdue: Int = 0,
        pending: Int = 0,
        disputed: Int = 0,
        dismissed: Int = 0
    ) = EntityWithStats(
        id = "test-id",
        name = "Test Entity",
        totalCommitments = total,
        fulfilledCount = fulfilled,
        overdueCount = overdue,
        pendingCount = pending,
        disputedCount = disputed,
        dismissedCount = dismissed
    )

    @Test
    fun `accountabilityScore is 0 when no commitments`() {
        val entity = createEntity(total = 0)
        assertEquals(0, entity.accountabilityScore)
    }

    @Test
    fun `accountabilityScore is 100 when all fulfilled`() {
        val entity = createEntity(total = 10, fulfilled = 10)
        assertEquals(100, entity.accountabilityScore)
    }

    @Test
    fun `accountabilityScore penalizes overdue commitments`() {
        val entity = createEntity(total = 10, fulfilled = 5, overdue = 5)
        // base: 5/10 * 100 = 50
        // penalty: 5/10 * 30 = 15
        // score: 50 - 15 = 35
        assertEquals(35, entity.accountabilityScore)
    }

    @Test
    fun `accountabilityScore clamps to 0 minimum`() {
        val entity = createEntity(total = 10, fulfilled = 0, overdue = 10)
        // base: 0, penalty: 30
        // clamped to 0
        assertEquals(0, entity.accountabilityScore)
    }

    @Test
    fun `fulfillmentRate calculates correctly`() {
        val entity = createEntity(total = 8, fulfilled = 6)
        assertEquals(0.75, entity.fulfillmentRate, 0.001)
    }

    @Test
    fun `fulfillmentRate is 0 when no commitments`() {
        val entity = createEntity(total = 0)
        assertEquals(0.0, entity.fulfillmentRate, 0.001)
    }

    // --- Grade tests ---

    @Test
    fun `accountabilityGrade A for score 90+`() {
        val entity = createEntity(total = 10, fulfilled = 10)
        assertEquals("A", entity.accountabilityGrade)
    }

    @Test
    fun `accountabilityGrade B for score 80-89`() {
        val entity = createEntity(total = 10, fulfilled = 8, overdue = 0)
        // 80/100 = 80 -> B
        assertEquals("B", entity.accountabilityGrade)
    }

    @Test
    fun `accountabilityGrade F for score below 60`() {
        val entity = createEntity(total = 10, fulfilled = 2, overdue = 5)
        // base: 20, penalty: 15 -> 5 -> F
        assertEquals("F", entity.accountabilityGrade)
    }
}
