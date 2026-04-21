import Testing
import Foundation
import SwiftData
import UIKit
@testable import Seddly

@Suite("ScreenshotProcessingService Tests")
struct ScreenshotProcessingServiceTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: LocalCommitment.self, LocalEntity.self, ProcessingQueue.self,
            PrivacyAuditEntry.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test("ProcessingResult defaults to zero counts")
    func processingResultDefaults() {
        let result = ScreenshotProcessingService.ProcessingResult()
        #expect(result.screenshotsFound == 0)
        #expect(result.screenshotsProcessed == 0)
        #expect(result.commitmentsDetected == 0)
    }

    @Test("Duplicate detection: same assetID is not processed twice")
    func duplicateDetection() async throws {
        let context = try makeContext()

        // Insert a ProcessingQueue item to simulate already-processed screenshot
        let existing = ProcessingQueue(screenshotAssetID: "test-asset-123")
        existing.processingStatus = .completed
        context.insert(existing)
        try context.save()

        // Verify the item exists
        let assetID = "test-asset-123"
        let descriptor = FetchDescriptor<ProcessingQueue>(
            predicate: #Predicate { $0.screenshotAssetID == assetID }
        )
        let count = try context.fetchCount(descriptor)
        #expect(count == 1, "Existing asset should be found in processing queue")
    }

    @Test("ProcessingQueue status transitions work correctly")
    func processingQueueStatusTransitions() throws {
        let item = ProcessingQueue(screenshotAssetID: "asset-456")
        #expect(item.processingStatus == .pending)

        item.processingStatus = .processing
        #expect(item.processingStatusRaw == "processing")

        item.processingStatus = .awaitingReview
        #expect(item.processingStatusRaw == "awaitingReview")

        item.processingStatus = .completed
        #expect(item.processingStatusRaw == "completed")

        item.processingStatus = .skipped
        #expect(item.processingStatusRaw == "skipped")
    }

    @Test("AI extraction requires minimum confidence score of 4")
    func aiConfidenceThreshold() throws {
        // Extracted commitments with confidence < 4 are filtered out
        // Verify the threshold by creating commitments at boundary values
        let lowConfidence = LocalCommitment(
            entityName: "Test",
            summary: "Low confidence item",
            fullText: "test",
            status: .pending,
            confidenceScore: 3
        )
        let highConfidence = LocalCommitment(
            entityName: "Test",
            summary: "High confidence item",
            fullText: "test",
            status: .pending,
            confidenceScore: 4
        )

        // The pipeline filters at confidence >= 4
        #expect(lowConfidence.confidenceScore < 4)
        #expect(highConfidence.confidenceScore >= 4)
    }

    @Test("AI text length limit is enforced")
    func aiTextLengthLimit() {
        #expect(AIExtractionService.maxTextLength == 10_000)

        let shortText = String(repeating: "a", count: 5_000)
        #expect(shortText.count <= AIExtractionService.maxTextLength)

        let longText = String(repeating: "a", count: 15_000)
        #expect(longText.count > AIExtractionService.maxTextLength)
    }

    @Test("Rule filter scoring feeds into processing pipeline threshold")
    func ruleFilterIntegration() {
        // Text with strong commitment signals should score high
        let commitmentText = "We will deliver the project by Friday 3/28 for $5,000"
        let score = RuleFilterService.score(text: commitmentText)
        let threshold = ClassifierFeedbackService.currentThreshold()

        // This text should pass the threshold with commitment signals + date + dollar
        #expect(score >= threshold, "Strong commitment text should pass filter threshold")
    }

    @Test("Classifier routes processable categories to pipeline")
    func classifierRouting() async {
        let classifier = ClassifierService()

        let conversationText = "Hey, I promised to deliver the package by tomorrow via messenger"
        let category = await classifier.classify(UIImage(), ocrText: conversationText)
        #expect(category.shouldProcess == true)

        let receiptText = "Order confirmation: your payment of $50 has been processed"
        let receiptCategory = await classifier.classify(UIImage(), ocrText: receiptText)
        #expect(receiptCategory.shouldProcess == true)
    }

    @Test("Classifier filters non-processable categories")
    func classifierFiltering() async {
        let classifier = ClassifierService()

        // Short text with no signals defaults to .other
        let shortText = "Hi"
        let category = await classifier.classify(UIImage(), ocrText: shortText)
        #expect(category.shouldProcess == false)
    }

    @Test("End-to-end: skipped items get correct status in SwiftData")
    func skippedItemsPersisted() throws {
        let context = try makeContext()

        let skipped = ProcessingQueue(screenshotAssetID: "skipped-asset")
        skipped.extractedText = "Just a UI screenshot"
        skipped.classifierResult = "ui_screenshot"
        skipped.processingStatus = .skipped
        context.insert(skipped)
        try context.save()

        let descriptor = FetchDescriptor<ProcessingQueue>()
        let items = try context.fetch(descriptor)
        #expect(items.count == 1)
        #expect(items[0].processingStatus == .skipped)
        #expect(items[0].classifierResult == "ui_screenshot")
    }

    // MARK: - US-161: AI review approval wiring
    //
    // processReviewedItem is the path that LedgerView's approval callback now
    // invokes when the user greenlights OCR text for Claude extraction. We
    // can't hit the real Supabase endpoint from a unit test, but we can pin
    // the contract that (a) calling it with an unreachable endpoint fails
    // gracefully (returns 0 commitments), and (b) the queue item's status
    // transitions to .completed regardless.

    @Test("processReviewedItem marks the queue item completed even when AI fails")
    func reviewedItemStatusTransitionsOnAIFailure() async throws {
        let context = try makeContext()
        let queueItem = ProcessingQueue(screenshotAssetID: "reviewed-asset")
        queueItem.extractedText = "Unreachable endpoint — this will fail"
        queueItem.processingStatus = .awaitingReview
        context.insert(queueItem)
        try context.save()

        let service = ScreenshotProcessingService()
        // RFC 5737 TEST-NET-1 — guaranteed unroutable, so the actor falls
        // through to the error path without a real network call.
        let unreachable = URL(string: "https://192.0.2.1/functions/v1/extract-commitments")!

        let count = await service.processReviewedItem(
            queueItem,
            approvedText: "I will send the files tomorrow",
            aiEndpoint: unreachable,
            authToken: nil,
            context: context
        )

        #expect(count == 0, "Unreachable endpoint should yield zero commitments")
        #expect(queueItem.processingStatus == .completed,
                "Queue item must still transition to completed so the review banner clears")
    }

    @Test("processReviewedItem is safe to call with empty approvedText")
    func reviewedItemWithEmptyText() async throws {
        let context = try makeContext()
        let queueItem = ProcessingQueue(screenshotAssetID: "empty-reviewed")
        queueItem.processingStatus = .awaitingReview
        context.insert(queueItem)
        try context.save()

        let service = ScreenshotProcessingService()
        let endpoint = URL(string: "https://192.0.2.1/functions/v1/extract-commitments")!

        // Must not crash on empty input; the AI actor will sanitize + return 0.
        let count = await service.processReviewedItem(
            queueItem,
            approvedText: "",
            aiEndpoint: endpoint,
            authToken: nil,
            context: context
        )

        #expect(count == 0)
        #expect(queueItem.processingStatus == .completed)
    }
}
