package com.pearsonmedia.seddly

import com.pearsonmedia.seddly.data.local.entity.CommitmentCategory
import com.pearsonmedia.seddly.data.local.entity.CommitmentEntity
import com.pearsonmedia.seddly.data.local.entity.CommitmentStatus
import com.pearsonmedia.seddly.data.local.entity.CommitmentSource
import com.pearsonmedia.seddly.data.local.entity.SyncStatus
import com.pearsonmedia.seddly.data.local.entity.UrgencyLevel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for CommitmentEntity data model.
 * Verifies computed properties, enum mappings, and edge cases.
 */
class CommitmentEntityTest {

    private fun createCommitment(
        status: String = CommitmentStatus.PENDING.value,
        deadline: Long? = null
    ) = CommitmentEntity(
        entityName = "Test Entity",
        summary = "Test commitment",
        status = status,
        deadline = deadline
    )

    // --- isOverdue tests ---

    @Test
    fun `isOverdue returns true when pending and past deadline`() {
        val pastDeadline = System.currentTimeMillis() - 24 * 60 * 60 * 1000 // yesterday
        val commitment = createCommitment(
            status = CommitmentStatus.PENDING.value,
            deadline = pastDeadline
        )
        assertTrue(commitment.isOverdue)
    }

    @Test
    fun `isOverdue returns false when fulfilled even with past deadline`() {
        val pastDeadline = System.currentTimeMillis() - 24 * 60 * 60 * 1000
        val commitment = createCommitment(
            status = CommitmentStatus.FULFILLED.value,
            deadline = pastDeadline
        )
        assertFalse(commitment.isOverdue)
    }

    @Test
    fun `isOverdue returns false when no deadline set`() {
        val commitment = createCommitment(deadline = null)
        assertFalse(commitment.isOverdue)
    }

    @Test
    fun `isOverdue returns false when deadline is in future`() {
        val futureDeadline = System.currentTimeMillis() + 7 * 24 * 60 * 60 * 1000 // next week
        val commitment = createCommitment(deadline = futureDeadline)
        assertFalse(commitment.isOverdue)
    }

    // --- urgencyLevel tests ---

    @Test
    fun `urgencyLevel is OVERDUE when deadline has passed`() {
        val pastDeadline = System.currentTimeMillis() - 1000
        val commitment = createCommitment(deadline = pastDeadline)
        assertEquals(UrgencyLevel.OVERDUE, commitment.urgencyLevel)
    }

    @Test
    fun `urgencyLevel is APPROACHING when deadline within 6 days`() {
        val deadline = System.currentTimeMillis() + 3 * 24 * 60 * 60 * 1000L // 3 days
        val commitment = createCommitment(deadline = deadline)
        assertEquals(UrgencyLevel.APPROACHING, commitment.urgencyLevel)
    }

    @Test
    fun `urgencyLevel is SAFE when deadline beyond 6 days`() {
        val deadline = System.currentTimeMillis() + 14 * 24 * 60 * 60 * 1000L // 2 weeks
        val commitment = createCommitment(deadline = deadline)
        assertEquals(UrgencyLevel.SAFE, commitment.urgencyLevel)
    }

    @Test
    fun `urgencyLevel is NONE when no deadline`() {
        val commitment = createCommitment(deadline = null)
        assertEquals(UrgencyLevel.NONE, commitment.urgencyLevel)
    }

    // --- Enum mapping tests ---

    @Test
    fun `CommitmentStatus fromValue handles all values`() {
        assertEquals(CommitmentStatus.PENDING, CommitmentStatus.fromValue("pending"))
        assertEquals(CommitmentStatus.FULFILLED, CommitmentStatus.fromValue("fulfilled"))
        assertEquals(CommitmentStatus.OVERDUE, CommitmentStatus.fromValue("overdue"))
        assertEquals(CommitmentStatus.DISPUTED, CommitmentStatus.fromValue("disputed"))
        assertEquals(CommitmentStatus.DISMISSED, CommitmentStatus.fromValue("dismissed"))
    }

    @Test
    fun `CommitmentStatus fromValue defaults to PENDING for unknown`() {
        assertEquals(CommitmentStatus.PENDING, CommitmentStatus.fromValue("unknown"))
    }

    @Test
    fun `CommitmentCategory fromValue handles all categories`() {
        assertEquals(CommitmentCategory.HOUSING, CommitmentCategory.fromValue("housing"))
        assertEquals(CommitmentCategory.FREELANCE, CommitmentCategory.fromValue("freelance"))
        assertEquals(CommitmentCategory.MEDICAL, CommitmentCategory.fromValue("medical"))
        assertEquals(CommitmentCategory.UNCATEGORIZED, CommitmentCategory.fromValue("unknown"))
    }

    @Test
    fun `CommitmentSource fromValue handles all sources`() {
        assertEquals(CommitmentSource.AUTO, CommitmentSource.fromValue("auto"))
        assertEquals(CommitmentSource.MANUAL, CommitmentSource.fromValue("manual"))
        assertEquals(CommitmentSource.SHARE_SHEET, CommitmentSource.fromValue("share_sheet"))
        assertEquals(CommitmentSource.MANUAL, CommitmentSource.fromValue("unknown"))
    }

    @Test
    fun `SyncStatus fromValue handles all statuses`() {
        assertEquals(SyncStatus.LOCAL, SyncStatus.fromValue("local"))
        assertEquals(SyncStatus.SYNCED, SyncStatus.fromValue("synced"))
        assertEquals(SyncStatus.PENDING_SYNC, SyncStatus.fromValue("pending_sync"))
        assertEquals(SyncStatus.LOCAL, SyncStatus.fromValue("unknown"))
    }
}
