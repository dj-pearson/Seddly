import SwiftData
import Photos
import UIKit

/// Orchestrates the full screenshot processing pipeline:
/// PhotoKit → OCR → Classifier → Rule Filter → AI Extraction → SwiftData
actor ScreenshotProcessingService {
    private let screenshotService = ScreenshotService()
    private let ocrService = OCRService()
    private let classifierService = ClassifierService()
    private let notificationService = NotificationService()
    private let privacyAuditService = PrivacyAuditService()

    struct ProcessingResult {
        var screenshotsFound: Int = 0
        var screenshotsProcessed: Int = 0
        var commitmentsDetected: Int = 0
    }

    func processNewScreenshots(
        since date: Date?,
        context: ModelContext,
        aiEndpoint: URL?,
        authToken: String? = nil,
        subscriptionTier: SubscriptionService.SubscriptionTier,
        autoAnalyze: Bool = false,
        offlineMode: Bool = false
    ) async -> ProcessingResult {
        var result = ProcessingResult()

        let assets = screenshotService.fetchNewScreenshots(since: date)
        result.screenshotsFound = assets.count

        for asset in assets {
            let assetID = asset.localIdentifier

            // Skip already-queued screenshots
            let descriptor = FetchDescriptor<ProcessingQueue>(
                predicate: #Predicate { $0.screenshotAssetID == assetID }
            )
            if (try? context.fetchCount(descriptor)) ?? 0 > 0 { continue }

            guard let image = await loadImage(from: asset) else { continue }

            // Layer 1: OCR
            guard let ocrText = try? await ocrService.recognizeText(in: image) else { continue }

            // Layer 2: Classification
            let category = await classifierService.classify(image, ocrText: ocrText)
            guard category.shouldProcess else {
                let skipped = ProcessingQueue(screenshotAssetID: assetID)
                skipped.extractedText = ocrText
                skipped.classifierResult = category.rawValue
                skipped.processingStatus = .skipped
                context.insert(skipped)
                continue
            }

            // Layer 3: Rule-based filter (use feedback-adjusted threshold)
            let adjustedThreshold = ClassifierFeedbackService.currentThreshold()
            let ruleScore = RuleFilterService.score(text: ocrText)

            let queueItem = ProcessingQueue(screenshotAssetID: assetID)
            queueItem.extractedText = ocrText
            queueItem.classifierResult = category.rawValue
            queueItem.ruleBasedScore = ruleScore
            context.insert(queueItem)

            result.screenshotsProcessed += 1

            // Layer 4: AI extraction (Pro+ only, requires network + threshold + not offline)
            // Skip AI extraction if text exceeds length limit
            if subscriptionTier >= .pro,
               !offlineMode,
               ruleScore >= adjustedThreshold,
               ocrText.count <= AIExtractionService.maxTextLength,
               let endpoint = aiEndpoint {
                if autoAnalyze {
                    // Auto-analyze: send directly to AI without user review
                    let commitments = await extractWithAI(
                        text: ocrText,
                        endpoint: endpoint,
                        authToken: authToken,
                        assetID: assetID,
                        screenshotDate: asset.creationDate,
                        context: context,
                        autoAnalyze: true
                    )
                    result.commitmentsDetected += commitments
                    queueItem.processingStatus = .completed
                } else {
                    // Needs user review before AI send (PRD §5.4)
                    queueItem.processingStatus = .awaitingReview
                }
            } else if ruleScore >= adjustedThreshold {
                // On-device only: create commitment from rule-based analysis
                let commitment = LocalCommitment(
                    entityName: "Unknown",
                    summary: String(ocrText.prefix(200)),
                    fullText: ocrText,
                    screenshotAssetID: assetID,
                    screenshotDate: asset.creationDate,
                    needsAIProcessing: !autoAnalyze
                )
                context.insert(commitment)

                // Schedule notifications for any commitment with a deadline
                if commitment.deadline != nil {
                    await notificationService.scheduleDeadlineApproaching(for: commitment)
                    await notificationService.scheduleDeadlinePassed(for: commitment)
                }

                result.commitmentsDetected += 1
                queueItem.processingStatus = .completed
            } else {
                queueItem.processingStatus = .completed
            }
        }

        try? context.save()

        UserDefaults(suiteName: AppConstants.appGroupIdentifier)?
            .set(Date.now, forKey: "lastProcessedDate")

        return result
    }

    private func extractWithAI(
        text: String,
        endpoint: URL,
        authToken: String? = nil,
        assetID: String,
        screenshotDate: Date?,
        context: ModelContext,
        autoAnalyze: Bool = false
    ) async -> Int {
        let aiService = AIExtractionService(endpointURL: endpoint, authToken: authToken)

        guard let response = try? await aiService.extractCommitments(from: text) else {
            return 0
        }

        // Record data transmission in privacy audit log
        await privacyAuditService.recordAIExtraction(
            textLength: text.count,
            endpoint: endpoint,
            context: context
        )

        var count = 0

        // Pre-fetch entities to avoid N+1 queries
        let uniqueEntityNames = Set(response.commitments.filter { $0.confidence >= 4 }.map(\.madeBy))
        var entityCache: [String: LocalEntity] = [:]
        for name in uniqueEntityNames {
            let entityDescriptor = FetchDescriptor<LocalEntity>(
                predicate: #Predicate { $0.name == name }
            )
            if let existing = try? context.fetch(entityDescriptor).first {
                entityCache[name] = existing
            }
        }

        for extracted in response.commitments {
            guard extracted.confidence >= 4 else { continue }

            let deadline: Date? = if let dateStr = extracted.deadline {
                ISO8601DateFormatter().date(from: dateStr) ??
                    dateFromString(dateStr)
            } else {
                nil
            }

            // High confidence (7+): auto-add. Medium (4-6): review queue unless auto-analyze is on.
            let needsReview = extracted.confidence < 7 && !autoAnalyze

            let commitment = LocalCommitment(
                entityName: extracted.madeBy,
                summary: extracted.text,
                fullText: text,
                deadline: deadline,
                dollarAmount: extracted.dollarAmount.map { Decimal($0) },
                status: .pending,
                confidenceScore: extracted.confidence,
                aiReasoning: extracted.reasoning,
                source: .auto,
                commitmentType: CommitmentType(rawValue: extracted.type),
                screenshotAssetID: assetID,
                screenshotDate: screenshotDate,
                needsAIProcessing: needsReview
            )

            // Apply AI-detected category
            if let categoryStr = extracted.category,
               let detectedCategory = CommitmentCategory(rawValue: categoryStr) {
                commitment.category = detectedCategory
            }

            // Find or create entity (using pre-fetched cache)
            let entityName = extracted.madeBy
            if let existingEntity = entityCache[entityName] {
                commitment.entity = existingEntity
            } else {
                let newEntity = LocalEntity(name: entityName)
                context.insert(newEntity)
                entityCache[entityName] = newEntity
                commitment.entity = newEntity
            }

            context.insert(commitment)

            // Schedule notifications for all commitments with deadlines
            if commitment.deadline != nil {
                await notificationService.scheduleDeadlineApproaching(for: commitment)
                await notificationService.scheduleDeadlinePassed(for: commitment)
            }

            count += 1
        }

        return count
    }

    /// Process a single queue item after user approves the text for AI analysis.
    func processReviewedItem(
        _ queueItem: ProcessingQueue,
        approvedText: String,
        aiEndpoint: URL,
        authToken: String? = nil,
        context: ModelContext
    ) async -> Int {
        let commitments = await extractWithAI(
            text: approvedText,
            endpoint: aiEndpoint,
            authToken: authToken,
            assetID: queueItem.screenshotAssetID,
            screenshotDate: queueItem.createdAt,
            context: context,
            autoAnalyze: false
        )
        queueItem.processingStatus = .completed
        try? context.save()
        return commitments
    }

    private func loadImage(from asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 1024, height: 1024),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    private func dateFromString(_ string: String) -> Date? {
        let formatter = DateFormatter()
        for format in ["yyyy-MM-dd", "MM/dd/yyyy", "M/d/yyyy", "MM-dd-yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
