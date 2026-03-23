import Testing
import Foundation
@testable import Seddly

@Suite("LocalCommitment Tests")
struct LocalCommitmentTests {
    @Test("Default values are correct")
    func defaultValues() {
        let commitment = LocalCommitment(
            entityName: "Test Landlord",
            summary: "Fix the AC",
            fullText: "I'll fix the AC by next Friday"
        )

        #expect(commitment.status == .pending)
        #expect(commitment.source == .manual)
        #expect(commitment.confidenceScore == 0)
        #expect(commitment.needsAIProcessing == false)
        #expect(commitment.syncStatus == .local)
        #expect(commitment.deadline == nil)
        #expect(commitment.dollarAmount == nil)
    }

    @Test("Urgency level reflects deadline proximity")
    func urgencyLevel() {
        let overdue = LocalCommitment(
            entityName: "Test",
            summary: "Overdue task",
            fullText: "test",
            deadline: Calendar.current.date(byAdding: .day, value: -2, to: .now)
        )
        #expect(overdue.urgencyLevel == .overdue)

        let approaching = LocalCommitment(
            entityName: "Test",
            summary: "Approaching task",
            fullText: "test",
            deadline: Calendar.current.date(byAdding: .day, value: 3, to: .now)
        )
        #expect(approaching.urgencyLevel == .approaching)

        let safe = LocalCommitment(
            entityName: "Test",
            summary: "Safe task",
            fullText: "test",
            deadline: Calendar.current.date(byAdding: .day, value: 14, to: .now)
        )
        #expect(safe.urgencyLevel == .safe)
    }

    @Test("isOverdue only for pending commitments past deadline")
    func isOverdue() {
        let pastDeadline = LocalCommitment(
            entityName: "Test",
            summary: "Past due",
            fullText: "test",
            deadline: Calendar.current.date(byAdding: .day, value: -1, to: .now)
        )
        #expect(pastDeadline.isOverdue == true)

        let fulfilled = LocalCommitment(
            entityName: "Test",
            summary: "Done",
            fullText: "test",
            deadline: Calendar.current.date(byAdding: .day, value: -1, to: .now),
            status: .fulfilled
        )
        #expect(fulfilled.isOverdue == false)
    }
}
