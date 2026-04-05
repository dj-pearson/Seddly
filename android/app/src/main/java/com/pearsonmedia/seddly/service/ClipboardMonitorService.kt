package com.pearsonmedia.seddly.service

import android.content.ClipboardManager
import android.content.Context
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Clipboard monitoring service that detects commitment-like text.
 * Mirrors the iOS ClipboardMonitorService with:
 * - Checks clipboard on app foreground
 * - Minimum 30 character threshold
 * - Rule-based scoring to filter non-commitment text
 * - Dismiss state tracking (doesn't re-prompt for same text)
 */
@Singleton
class ClipboardMonitorService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val clipboardManager = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    private var lastDismissedText: String? = null

    private val _detectedText = MutableStateFlow<ClipboardDetection?>(null)
    val detectedText: StateFlow<ClipboardDetection?> = _detectedText.asStateFlow()

    /**
     * Check clipboard for commitment-like text.
     * Call this on app foreground (Activity.onResume).
     */
    fun checkClipboard() {
        try {
            if (!clipboardManager.hasPrimaryClip()) {
                _detectedText.value = null
                return
            }

            val clip = clipboardManager.primaryClip ?: return
            if (clip.itemCount == 0) return

            val text = clip.getItemAt(0).text?.toString()
            if (text.isNullOrBlank()) {
                _detectedText.value = null
                return
            }

            // Minimum length threshold
            if (text.length < MIN_TEXT_LENGTH) {
                _detectedText.value = null
                return
            }

            // Don't re-prompt for dismissed text
            if (text == lastDismissedText) {
                return
            }

            // Rule-based scoring
            val score = calculateCommitmentScore(text)
            if (score >= MIN_CONFIDENCE_SCORE) {
                _detectedText.value = ClipboardDetection(
                    text = text,
                    confidenceScore = score
                )
                Log.i(TAG, "Detected commitment-like clipboard text (score=$score)")
            } else {
                _detectedText.value = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Clipboard check failed", e)
            _detectedText.value = null
        }
    }

    /**
     * Dismiss the current detection — prevents re-prompting for same text.
     */
    fun dismiss() {
        lastDismissedText = _detectedText.value?.text
        _detectedText.value = null
    }

    /**
     * Clear the detection after user accepts it.
     */
    fun clearDetection() {
        _detectedText.value = null
    }

    /**
     * Rule-based scoring for commitment likelihood.
     */
    private fun calculateCommitmentScore(text: String): Int {
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

    data class ClipboardDetection(
        val text: String,
        val confidenceScore: Int
    )

    companion object {
        private const val TAG = "ClipboardMonitor"
        const val MIN_TEXT_LENGTH = 30
        const val MIN_CONFIDENCE_SCORE = 20
    }
}
