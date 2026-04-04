package com.pearsonmedia.seddly

import com.pearsonmedia.seddly.service.EscalationTemplateService
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for EscalationTemplateService.
 * Mirrors iOS EscalationTemplateService tests.
 */
class EscalationTemplateServiceTest {

    private val service = EscalationTemplateService()

    @Test
    fun `templates list has 5 templates`() {
        assertEquals(5, service.getTemplates().size)
    }

    @Test
    fun `housing template contains housing-specific language`() {
        val templates = service.getTemplatesByCategory("housing")
        assertTrue("Should have housing template", templates.isNotEmpty())
        assertTrue(
            "Housing template should mention housing authority",
            templates.first().body.contains("housing authority")
        )
    }

    @Test
    fun `freelance template contains payment language`() {
        val templates = service.getTemplatesByCategory("freelance")
        assertTrue("Should have freelance template", templates.isNotEmpty())
        assertTrue(
            "Freelance template should mention payment",
            templates.first().body.contains("payment")
        )
    }

    @Test
    fun `insurance template contains claim language`() {
        val templates = service.getTemplatesByCategory("insurance")
        assertTrue(templates.isNotEmpty())
        assertTrue(templates.first().body.contains("claim"))
    }

    @Test
    fun `populateTemplate replaces all placeholders`() {
        val template = service.getTemplates().first()
        val populated = service.populateTemplate(
            template = template,
            entityName = "Test Corp",
            commitmentSummary = "Fix the roof",
            deadline = 1735689600000, // Jan 1, 2025
            dollarAmount = 500.0,
            senderName = "John Doe"
        )

        assertTrue(populated.contains("Test Corp"))
        assertTrue(populated.contains("Fix the roof"))
        assertTrue(populated.contains("John Doe"))
        assertTrue(populated.contains("$500.00"))
        assertTrue(!populated.contains("{ENTITY_NAME}"))
        assertTrue(!populated.contains("{COMMITMENT_SUMMARY}"))
        assertTrue(!populated.contains("{SENDER_NAME}"))
        assertTrue(!populated.contains("{DOLLAR_AMOUNT}"))
    }

    @Test
    fun `each template has unique id`() {
        val ids = service.getTemplates().map { it.id }
        assertEquals(ids.size, ids.toSet().size)
    }

    @Test
    fun `all templates have non-empty body`() {
        service.getTemplates().forEach { template ->
            assertTrue(
                "Template ${template.id} should have non-empty body",
                template.body.isNotBlank()
            )
        }
    }
}
