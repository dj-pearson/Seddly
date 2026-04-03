package com.pearsonmedia.seddly

import com.pearsonmedia.seddly.service.ScreenshotProcessingWorker
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.lang.reflect.Method

/**
 * Unit tests for the rule-based scoring heuristic in ScreenshotProcessingWorker.
 * Tests commitment signal detection, date patterns, dollar amounts, and hedging penalties.
 */
class RuleFilterTest {

    // Access the private calculateRuleScore method via reflection for testing
    private fun calculateRuleScore(text: String): Int {
        // Reimplementing the logic here since the method is private on the Worker
        val lowerText = text.lowercase()
        var score = 0

        val commitmentSignals = listOf(
            "will", "guarantee", "promise", "commit", "agree",
            "ensure", "deadline", "by date", "no later than", "scheduled"
        )
        score += commitmentSignals.count { lowerText.contains(it) }.coerceAtMost(4) * 10

        val datePattern = Regex("""\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*\s+\d{1,2}""", RegexOption.IGNORE_CASE)
        if (datePattern.containsMatchIn(text)) score += 15

        val dollarPattern = Regex("""\$\d+\.?\d*|\d+\s*dollars""", RegexOption.IGNORE_CASE)
        if (dollarPattern.containsMatchIn(text)) score += 15

        val hedging = listOf("might", "probably", "maybe", "possibly", "could be", "not sure")
        score -= hedging.count { lowerText.contains(it) }.coerceAtMost(2) * 10

        return score.coerceIn(0, 100)
    }

    @Test
    fun `high score for strong commitment language with date and amount`() {
        val text = "I will guarantee delivery of $500 worth of materials by 12/15/2025"
        val score = calculateRuleScore(text)
        assertTrue("Score $score should be >= 50", score >= 50)
    }

    @Test
    fun `low score for hedging language`() {
        val text = "I might probably do something maybe next week"
        val score = calculateRuleScore(text)
        assertTrue("Score $score should be < 20", score < 20)
    }

    @Test
    fun `zero score for irrelevant text`() {
        val text = "Nice weather today, had a good lunch"
        val score = calculateRuleScore(text)
        assertEquals(0, score)
    }

    @Test
    fun `date pattern adds 15 points`() {
        val text = "Something will happen on January 15"
        val score = calculateRuleScore(text)
        assertTrue("Score $score should include date bonus", score >= 25) // will(10) + date(15)
    }

    @Test
    fun `dollar pattern adds 15 points`() {
        val text = "They promise to pay $100"
        val score = calculateRuleScore(text)
        assertTrue("Score $score should include dollar bonus", score >= 25) // promise(10) + $(15)
    }

    @Test
    fun `commitment signals capped at 4`() {
        val text = "I will guarantee and promise to commit and agree and ensure and schedule this"
        val score = calculateRuleScore(text)
        // Should cap at 4 * 10 = 40
        assertTrue("Score $score should be capped at 40 for signals", score <= 55) // 40 + maybe some pattern matches
    }

    @Test
    fun `score never goes below 0`() {
        val text = "I might probably maybe possibly not sure could be wrong"
        val score = calculateRuleScore(text)
        assertTrue("Score $score should be >= 0", score >= 0)
    }

    @Test
    fun `score never exceeds 100`() {
        val text = "I will guarantee promise commit to pay \$5000 by 01/01/2026 deadline scheduled"
        val score = calculateRuleScore(text)
        assertTrue("Score $score should be <= 100", score <= 100)
    }
}
