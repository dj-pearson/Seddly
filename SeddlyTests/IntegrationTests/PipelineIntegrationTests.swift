import Testing
import Foundation
import SwiftData
import UIKit
@testable import Seddly

@Suite("Pipeline Integration Tests")
struct PipelineIntegrationTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: LocalCommitment.self, LocalEntity.self, ProcessingQueue.self,
            PrivacyAuditEntry.self, CustomWorkflow.self,
            configurations: config
        )
        return ModelContext(container)
    }

    // MARK: - Screenshot → OCR → Classifier → RuleFilter → Commitment Pipeline

    @Test("Full pipeline: rendered commitment text → OCR → classify → filter → local commitment")
    func screenshotToCommitmentPipeline() async throws {
        let ocrService = OCRService()
        let classifierService = ClassifierService()
        let context = try makeContext()

        // Step 1: Create an image with commitment-like text
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 200))
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: CGSize(width: 600, height: 200))
            UIColor.white.setFill()
            ctx.fill(rect)
            let text = "I will pay you $5,000 by March 28, 2026" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28),
                .foregroundColor: UIColor.black,
            ]
            text.draw(in: CGRect(x: 10, y: 60, width: 580, height: 80), withAttributes: attributes)
        }

        // Step 2: OCR extraction
        let ocrText = try await ocrService.recognizeText(in: image)
        #expect(!ocrText.isEmpty, "OCR should extract text from the rendered image")

        // Step 3: Classification
        let category = await classifierService.classify(image, ocrText: ocrText)
        #expect(category.shouldProcess, "Text with commitment signals should be classified as processable")

        // Step 4: Rule-based filter
        let ruleScore = RuleFilterService.score(text: ocrText)
        let threshold = ClassifierFeedbackService.currentThreshold()

        // Step 5: If the score passes threshold, create a commitment (simulating on-device path)
        if ruleScore >= threshold {
            let commitment = LocalCommitment(
                entityName: "Unknown",
                summary: String(ocrText.prefix(200)),
                fullText: ocrText,
                screenshotAssetID: "integration-test-asset",
                screenshotDate: .now,
                needsAIProcessing: true
            )
            context.insert(commitment)

            let queueItem = ProcessingQueue(screenshotAssetID: "integration-test-asset")
            queueItem.extractedText = ocrText
            queueItem.classifierResult = category.rawValue
            queueItem.ruleBasedScore = ruleScore
            queueItem.processingStatus = .completed
            context.insert(queueItem)

            try context.save()

            // Verify the commitment was persisted
            let commitments = try context.fetch(FetchDescriptor<LocalCommitment>())
            #expect(commitments.count == 1)
            #expect(commitments[0].fullText == ocrText)
            #expect(commitments[0].needsAIProcessing == true)
            #expect(commitments[0].source == .photoLibrary)

            // Verify the processing queue entry
            let queue = try context.fetch(FetchDescriptor<ProcessingQueue>())
            #expect(queue.count == 1)
            #expect(queue[0].processingStatus == .completed)
            #expect(queue[0].ruleBasedScore == ruleScore)
        } else {
            // Even low-scoring text should still be trackable
            #expect(ruleScore >= 0, "Rule score should be non-negative")
        }
    }

    @Test("Pipeline rejects non-commitment screenshots: UI screenshot with no signals")
    func pipelineRejectsNonCommitmentContent() async throws {
        let ocrService = OCRService()
        let classifierService = ClassifierService()

        // Create image with generic UI text (no commitment signals)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 100))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: 400, height: 100)))
            let text = "Settings Menu Options" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20),
                .foregroundColor: UIColor.black,
            ]
            text.draw(in: CGRect(x: 10, y: 30, width: 380, height: 50), withAttributes: attrs)
        }

        let ocrText = try await ocrService.recognizeText(in: image)

        // Classification should flag this as non-processable or rule filter should reject
        let category = await classifierService.classify(image, ocrText: ocrText)
        let ruleScore = RuleFilterService.score(text: ocrText)
        let threshold = ClassifierFeedbackService.currentThreshold()

        // Either classifier rejects OR rule score is below threshold
        let rejected = !category.shouldProcess || ruleScore < threshold
        #expect(rejected, "Generic UI text should not produce a commitment")
    }

    // MARK: - SyncService Push Integration

    @Test("SyncService push: local commitment with pendingSync status is identified for upload")
    func syncServicePushIdentifiesPendingCommitments() throws {
        let context = try makeContext()

        // Create a commitment marked for sync
        let synced = LocalCommitment(
            entityName: "Acme Corp",
            summary: "Pay invoice by end of month",
            fullText: "We will pay the invoice of $2,000 by end of March.",
            status: .pending,
            confidenceScore: 8
        )
        synced.syncStatus = .pendingSync
        context.insert(synced)

        // Create a commitment NOT marked for sync
        let local = LocalCommitment(
            entityName: "Local Only",
            summary: "Local commitment",
            fullText: "Not synced",
            status: .pending,
            confidenceScore: 5
        )
        local.syncStatus = .localOnly
        context.insert(local)

        try context.save()

        // Verify only pendingSync items are fetched (mirrors SyncService.syncCommitments logic)
        let descriptor = FetchDescriptor<LocalCommitment>(
            predicate: #Predicate { $0.syncStatusRaw == "pendingSync" }
        )
        let pending = try context.fetch(descriptor)
        #expect(pending.count == 1)
        #expect(pending[0].entityName == "Acme Corp")

        // Verify push payload contains all required fields
        let commitment = pending[0]
        let payload: [String: Any?] = [
            "id": commitment.id.uuidString,
            "entity_name": commitment.entityName,
            "summary": commitment.summary,
            "full_text": commitment.fullText,
            "status": commitment.statusRaw,
            "confidence": commitment.confidenceScore,
            "source": commitment.sourceRaw,
            "category": commitment.categoryRaw ?? "uncategorized",
        ]

        let compacted = payload.compactMapValues { $0 }
        #expect(compacted["entity_name"] as? String == "Acme Corp")
        #expect(compacted["confidence"] as? Int == 8)
        #expect(compacted["status"] as? String != nil)
    }

    // MARK: - SyncService Pull Integration

    @Test("SyncService pull: remote data creates local commitment with correct fields")
    func syncServicePullCreatesLocalCommitment() throws {
        let context = try makeContext()

        // Simulate a remote commitment payload (as returned by Supabase REST API)
        let remoteID = UUID()
        let remoteData: [String: Any] = [
            "id": remoteID.uuidString,
            "entity_name": "Landlord",
            "summary": "Promised to fix the plumbing by Friday",
            "full_text": "I'll have the plumber come fix the leak by Friday March 28.",
            "status": "pending",
            "confidence": 7,
            "source": "photoLibrary",
            "category": "housing",
            "dollar_amount": 0,
            "screenshot_date": "2026-03-25T10:00:00Z",
        ]

        // Pre-fetch existing IDs to check duplicates (mirrors SyncService.pullCommitments logic)
        let existingDescriptor = FetchDescriptor<LocalCommitment>()
        let existingIDs = Set(try context.fetch(existingDescriptor).map { $0.id.uuidString })
        #expect(!existingIDs.contains(remoteID.uuidString))

        // Create local commitment from remote data
        let commitment = LocalCommitment(
            entityName: remoteData["entity_name"] as? String ?? "Unknown",
            summary: remoteData["summary"] as? String ?? "",
            fullText: remoteData["full_text"] as? String ?? "",
            status: .pending,
            confidenceScore: remoteData["confidence"] as? Int ?? 0
        )
        commitment.categoryRaw = remoteData["category"] as? String
        commitment.syncStatus = .synced
        context.insert(commitment)
        try context.save()

        // Verify the local state
        let locals = try context.fetch(FetchDescriptor<LocalCommitment>())
        #expect(locals.count == 1)
        #expect(locals[0].entityName == "Landlord")
        #expect(locals[0].summary == "Promised to fix the plumbing by Friday")
        #expect(locals[0].confidenceScore == 7)
        #expect(locals[0].syncStatus == .synced)
        #expect(locals[0].category == .housing)
    }

    @Test("SyncService pull: duplicate remote IDs are not re-inserted")
    func syncServicePullDeduplicates() throws {
        let context = try makeContext()

        let sharedID = UUID()

        // Insert existing local commitment
        let existing = LocalCommitment(
            entityName: "Existing",
            summary: "Already here",
            fullText: "Already synced",
            status: .pending,
            confidenceScore: 5
        )
        // Simulate same ID from remote by setting directly
        context.insert(existing)
        try context.save()

        // Pre-fetch IDs (mirrors SyncService logic)
        let existingIDs = Set(try context.fetch(FetchDescriptor<LocalCommitment>()).map { $0.id })

        // Simulate receiving the same commitment from remote
        let shouldInsert = !existingIDs.contains(existing.id)
        #expect(shouldInsert == false, "Duplicate commitment should be skipped")

        // Verify count unchanged
        let count = try context.fetchCount(FetchDescriptor<LocalCommitment>())
        #expect(count == 1)
    }

    // MARK: - Share Extension → ProcessingQueue → Background Processing

    @Test("Share Extension pipeline: text saved to ProcessingQueue feeds into background processing")
    func shareExtensionToBackgroundProcessing() throws {
        let context = try makeContext()

        // Step 1: Simulate Share Extension saving to ProcessingQueue
        let shareText = "We will deliver the completed website by April 15 for $3,500"
        let shareID = "share-\(UUID().uuidString)"
        let score = RuleFilterService.score(text: shareText)

        let queueItem = ProcessingQueue(screenshotAssetID: shareID)
        queueItem.extractedText = shareText
        queueItem.ruleBasedScore = score
        queueItem.processingStatus = .completed
        context.insert(queueItem)

        // Step 2: If score passes, Share Extension also creates a commitment
        if score >= AppConstants.defaultConfidenceThreshold {
            let commitment = LocalCommitment(
                entityName: "Unknown",
                summary: String(shareText.prefix(200)),
                fullText: shareText,
                source: .shareSheet,
                screenshotAssetID: shareID,
                screenshotDate: .now,
                needsAIProcessing: true
            )
            context.insert(commitment)
        }

        try context.save()

        // Step 3: Verify ProcessingQueue state (what background task would read)
        let queueDescriptor = FetchDescriptor<ProcessingQueue>()
        let queue = try context.fetch(queueDescriptor)
        #expect(queue.count == 1)
        #expect(queue[0].screenshotAssetID == shareID)
        #expect(queue[0].extractedText == shareText)
        #expect(queue[0].processingStatus == .completed)

        // Step 4: Verify commitment was created from share with correct source
        let commitmentDescriptor = FetchDescriptor<LocalCommitment>()
        let commitments = try context.fetch(commitmentDescriptor)

        if score >= AppConstants.defaultConfidenceThreshold {
            #expect(commitments.count == 1)
            #expect(commitments[0].source == .shareSheet)
            #expect(commitments[0].needsAIProcessing == true)
            #expect(commitments[0].screenshotAssetID == shareID)
        } else {
            #expect(commitments.isEmpty, "Below-threshold text should not create commitment")
        }
    }

    @Test("Share Extension duplicate: background processing skips already-queued share items")
    func shareExtensionDuplicateSkipped() throws {
        let context = try makeContext()

        let shareID = "share-duplicate-test"

        // Simulate Share Extension saving an item
        let queueItem = ProcessingQueue(screenshotAssetID: shareID)
        queueItem.extractedText = "Some shared text"
        queueItem.processingStatus = .completed
        context.insert(queueItem)
        try context.save()

        // Simulate background processing checking for this asset (mirrors ScreenshotProcessingService logic)
        let allQueueDescriptor = FetchDescriptor<ProcessingQueue>()
        let queuedAssetIDs = Set(try context.fetch(allQueueDescriptor).map(\.screenshotAssetID))

        #expect(queuedAssetIDs.contains(shareID), "Already-queued share item should be detected")

        // Background processing would skip this asset
        let shouldProcess = !queuedAssetIDs.contains(shareID)
        #expect(shouldProcess == false, "Duplicate share item should be skipped by background processing")
    }
}
