package com.pearsonmedia.seddly.service

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Pre-written escalation letter templates for dispute generation.
 * Mirrors the iOS EscalationTemplateService with:
 * - Category-specific templates (housing, freelance, insurance, etc.)
 * - Template population with commitment data
 * - Sender name and date substitution
 */
@Singleton
class EscalationTemplateService @Inject constructor() {

    data class EscalationTemplate(
        val id: String,
        val name: String,
        val category: String,
        val subject: String,
        val body: String
    )

    fun getTemplates(): List<EscalationTemplate> = templates

    fun getTemplatesByCategory(category: String): List<EscalationTemplate> =
        templates.filter { it.category == category }

    fun populateTemplate(
        template: EscalationTemplate,
        entityName: String,
        commitmentSummary: String,
        deadline: Long?,
        dollarAmount: Double?,
        senderName: String
    ): String {
        val dateFormat = SimpleDateFormat("MMMM d, yyyy", Locale.getDefault())
        val today = dateFormat.format(Date())
        val deadlineStr = deadline?.let { dateFormat.format(Date(it)) } ?: "[deadline not specified]"
        val amountStr = dollarAmount?.let { "$${String.format("%.2f", it)}" } ?: "[amount not specified]"

        return template.body
            .replace("{ENTITY_NAME}", entityName)
            .replace("{COMMITMENT_SUMMARY}", commitmentSummary)
            .replace("{DEADLINE}", deadlineStr)
            .replace("{DOLLAR_AMOUNT}", amountStr)
            .replace("{SENDER_NAME}", senderName)
            .replace("{DATE}", today)
    }

    companion object {
        val templates = listOf(
            EscalationTemplate(
                id = "housing_demand",
                name = "Housing Demand Letter",
                category = "housing",
                subject = "Formal Demand: Unfulfilled Commitment",
                body = """Dear {ENTITY_NAME},

I am writing to formally demand fulfillment of the commitment made regarding: {COMMITMENT_SUMMARY}.

This commitment was due by {DEADLINE}. As of {DATE}, this obligation remains unfulfilled.

I am requesting immediate action to resolve this matter. If this commitment involved a financial obligation of {DOLLAR_AMOUNT}, I expect full payment or resolution within 14 business days of this letter.

Failure to respond may result in further action, including but not limited to filing a complaint with the appropriate housing authority.

Sincerely,
{SENDER_NAME}"""
            ),
            EscalationTemplate(
                id = "freelance_invoice",
                name = "Freelance Payment Demand",
                category = "freelance",
                subject = "Past Due Payment Notice",
                body = """Dear {ENTITY_NAME},

This letter serves as a formal notice regarding the outstanding payment for: {COMMITMENT_SUMMARY}.

Payment of {DOLLAR_AMOUNT} was due by {DEADLINE} and remains unpaid as of {DATE}.

Please remit payment within 10 business days. If payment is not received, I reserve the right to pursue collection through appropriate legal channels.

Sincerely,
{SENDER_NAME}"""
            ),
            EscalationTemplate(
                id = "insurance_claim",
                name = "Insurance Claim Follow-Up",
                category = "insurance",
                subject = "Claim Follow-Up: Outstanding Commitment",
                body = """Dear {ENTITY_NAME},

I am following up on the commitment made regarding my claim: {COMMITMENT_SUMMARY}.

The promised resolution date of {DEADLINE} has passed. The expected amount of {DOLLAR_AMOUNT} has not been disbursed as of {DATE}.

Please provide an update on the status of this claim within 5 business days. I have documented all communications regarding this matter.

Sincerely,
{SENDER_NAME}"""
            ),
            EscalationTemplate(
                id = "service_complaint",
                name = "Service Complaint Letter",
                category = "purchases",
                subject = "Formal Complaint: Unmet Service Commitment",
                body = """Dear {ENTITY_NAME},

I am writing to express my dissatisfaction with the unfulfilled commitment: {COMMITMENT_SUMMARY}.

This was promised by {DEADLINE} and has not been delivered as of {DATE}.

I request immediate resolution or a full refund of {DOLLAR_AMOUNT}. Please respond within 7 business days.

Sincerely,
{SENDER_NAME}"""
            ),
            EscalationTemplate(
                id = "general_demand",
                name = "General Demand Letter",
                category = "personal",
                subject = "Formal Demand for Commitment Fulfillment",
                body = """Dear {ENTITY_NAME},

This letter serves as a formal demand for the fulfillment of the following commitment: {COMMITMENT_SUMMARY}.

The agreed deadline was {DEADLINE}. As of {DATE}, this commitment remains unmet.

I expect this matter to be resolved promptly. Please respond within 14 days.

Sincerely,
{SENDER_NAME}"""
            )
        )
    }
}
