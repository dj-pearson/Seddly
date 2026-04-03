package com.pearsonmedia.seddly.service

import android.content.Context
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.pearsonmedia.seddly.data.local.dao.CommitmentDao
import com.pearsonmedia.seddly.data.local.dao.ProcessingQueueDao
import com.pearsonmedia.seddly.data.local.entity.CommitmentEntity
import com.pearsonmedia.seddly.data.local.entity.CommitmentSource
import com.pearsonmedia.seddly.data.local.entity.ProcessingStatus
import com.pearsonmedia.seddly.service.ai.AIExtractionService
import com.pearsonmedia.seddly.service.auth.SecureStorageService
import com.pearsonmedia.seddly.service.ocr.OCRService
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject

/**
 * Background worker that processes screenshots through the OCR -> AI pipeline.
 * Mirrors the iOS BackgroundTaskService + ScreenshotProcessingService.
 *
 * Pipeline:
 * 1. Fetch pending items from processing queue
 * 2. OCR text extraction via ML Kit
 * 3. Rule-based filtering (skip if clearly not a commitment)
 * 4. AI extraction via Supabase Edge Function
 * 5. Save extracted commitments to Room database
 */
@HiltWorker
class ScreenshotProcessingWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted workerParams: WorkerParameters,
    private val processingQueueDao: ProcessingQueueDao,
    private val commitmentDao: CommitmentDao,
    private val ocrService: OCRService,
    private val aiExtractionService: AIExtractionService,
    private val secureStorage: SecureStorageService
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        Log.i(TAG, "Starting screenshot processing")

        val pendingItems = processingQueueDao.getPending()
        if (pendingItems.isEmpty()) {
            Log.i(TAG, "No pending items to process")
            return Result.success()
        }

        val supabaseUrl = secureStorage.getString(SecureStorageService.KEY_SUPABASE_URL)
        val supabaseKey = secureStorage.getString(SecureStorageService.KEY_SUPABASE_KEY)

        var processed = 0
        var failed = 0

        // Process up to MAX_BATCH items per run
        for (item in pendingItems.take(MAX_BATCH_SIZE)) {
            try {
                // Mark as processing
                processingQueueDao.updateStatus(item.id, ProcessingStatus.PROCESSING.value)

                // Step 1: OCR
                val uri = android.net.Uri.parse(item.screenshotUri)
                val extractedText = ocrService.extractText(uri)

                if (extractedText.isNullOrBlank()) {
                    processingQueueDao.updateStatus(item.id, ProcessingStatus.SKIPPED.value)
                    continue
                }

                // Step 2: Rule-based scoring
                val ruleScore = calculateRuleScore(extractedText)
                processingQueueDao.update(
                    item.copy(
                        extractedText = extractedText,
                        ruleBasedScore = ruleScore
                    )
                )

                if (ruleScore < MIN_RULE_SCORE) {
                    processingQueueDao.updateStatus(item.id, ProcessingStatus.SKIPPED.value)
                    continue
                }

                // Step 3: AI extraction (if credentials available)
                if (supabaseUrl != null && supabaseKey != null) {
                    val results = aiExtractionService.extractCommitments(
                        extractedText, supabaseUrl, supabaseKey
                    )

                    for (result in results) {
                        if (result.commitmentType == "irrelevant") continue

                        val commitment = CommitmentEntity(
                            entityName = result.entityName,
                            summary = result.summary,
                            fullText = extractedText,
                            commitmentType = result.commitmentType,
                            category = result.category,
                            dollarAmount = result.dollarAmount,
                            confidenceScore = result.confidenceScore,
                            aiReasoning = result.aiReasoning,
                            source = CommitmentSource.AUTO.value,
                            screenshotUri = item.screenshotUri,
                            screenshotDate = item.createdAt,
                            needsAIProcessing = false
                        )
                        commitmentDao.insert(commitment)
                    }
                } else {
                    // No AI credentials — mark for manual review
                    processingQueueDao.updateStatus(item.id, ProcessingStatus.AWAITING_REVIEW.value)
                    continue
                }

                processingQueueDao.updateStatus(item.id, ProcessingStatus.COMPLETED.value)
                processed++

            } catch (e: Exception) {
                Log.e(TAG, "Failed to process item ${item.id}", e)
                failed++
                processingQueueDao.updateStatus(item.id, ProcessingStatus.PENDING.value)
            }
        }

        Log.i(TAG, "Processing complete: $processed succeeded, $failed failed")
        return if (failed > 0 && processed == 0) Result.retry() else Result.success()
    }

    /**
     * Rule-based heuristic scoring for commitment likelihood.
     * Mirrors iOS RuleFilterService scoring:
     * - Commitment signals: will, guarantee, promise, etc.
     * - Date patterns
     * - Dollar amounts
     * - Penalizes hedging language
     */
    private fun calculateRuleScore(text: String): Int {
        val lowerText = text.lowercase()
        var score = 0

        // Commitment signal words (+10 each, max 40)
        val commitmentSignals = listOf(
            "will", "guarantee", "promise", "commit", "agree",
            "ensure", "deadline", "by date", "no later than", "scheduled"
        )
        score += commitmentSignals.count { lowerText.contains(it) }.coerceAtMost(4) * 10

        // Date patterns (+15)
        val datePattern = Regex("""\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*\s+\d{1,2}""", RegexOption.IGNORE_CASE)
        if (datePattern.containsMatchIn(text)) score += 15

        // Dollar amounts (+15)
        val dollarPattern = Regex("""\$\d+\.?\d*|\d+\s*dollars""", RegexOption.IGNORE_CASE)
        if (dollarPattern.containsMatchIn(text)) score += 15

        // Hedging language (-10 each, max -20)
        val hedging = listOf("might", "probably", "maybe", "possibly", "could be", "not sure")
        score -= hedging.count { lowerText.contains(it) }.coerceAtMost(2) * 10

        return score.coerceIn(0, 100)
    }

    companion object {
        private const val TAG = "ScreenshotWorker"
        const val WORK_NAME = "screenshot_processing"
        const val MAX_BATCH_SIZE = 10
        const val MIN_RULE_SCORE = 20
    }
}
