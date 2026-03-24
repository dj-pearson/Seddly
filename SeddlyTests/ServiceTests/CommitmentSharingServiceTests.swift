import Testing
import Foundation
@testable import Seddly

@Suite("CommitmentSharingService Tests")
struct CommitmentSharingServiceTests {
    @Test("generateReminderMessage includes entity name, summary, and deadline")
    func reminderMessageFormat() {
        let commitment = LocalCommitment(
            entityName: "Acme Corp",
            summary: "Pay invoice #1234",
            fullText: "We will pay invoice #1234 by end of month",
            deadline: Calendar.current.date(byAdding: .day, value: 7, to: .now)
        )

        let message = CommitmentSharingService.generateReminderMessage(for: commitment)
        #expect(message.contains("Acme Corp"))
        #expect(message.contains("Pay invoice #1234"))
        #expect(message.contains("Due by:"))
        #expect(message.contains("Seddly"))
    }

    @Test("generateReminderMessage shows days overdue for past deadlines")
    func reminderMessageOverdue() {
        let commitment = LocalCommitment(
            entityName: "Late Larry",
            summary: "Fix the roof",
            fullText: "I'll fix the roof",
            deadline: Calendar.current.date(byAdding: .day, value: -5, to: .now)
        )

        let message = CommitmentSharingService.generateReminderMessage(for: commitment)
        #expect(message.contains("Late Larry"))
        #expect(message.contains("ago"))
        #expect(message.contains("day"))
    }

    @Test("generateReminderMessage includes dollar amount when present")
    func reminderMessageWithAmount() {
        let commitment = LocalCommitment(
            entityName: "Vendor",
            summary: "Refund order",
            fullText: "We will refund your order",
            dollarAmount: 99.99
        )

        let message = CommitmentSharingService.generateReminderMessage(for: commitment)
        #expect(message.contains("$99.99"))
    }

    @Test("generateEvidenceSummary includes all commitment fields")
    func evidenceSummaryFields() {
        let commitment = LocalCommitment(
            entityName: "Big Co",
            summary: "Replace defective unit",
            fullText: "We will replace the defective unit",
            deadline: Calendar.current.date(byAdding: .day, value: 14, to: .now),
            dollarAmount: 250.00,
            source: .auto,
            screenshotAssetID: "test-asset",
            notes: "Called customer service twice"
        )
        commitment.screenshotDate = .now

        let summary = CommitmentSharingService.generateEvidenceSummary(for: commitment)
        #expect(summary.contains("COMMITMENT RECORD"))
        #expect(summary.contains("Big Co"))
        #expect(summary.contains("Replace defective unit"))
        #expect(summary.contains("Deadline:"))
        #expect(summary.contains("$250"))
        #expect(summary.contains("Pending"))
        #expect(summary.contains("Auto-detected from screenshot"))
        #expect(summary.contains("Called customer service twice"))
        #expect(summary.contains("Seddly"))
    }
}
