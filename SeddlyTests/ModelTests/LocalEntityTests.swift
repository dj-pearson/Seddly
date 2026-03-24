import Testing
import Foundation
@testable import Seddly

@Suite("LocalEntity Accountability Score Tests")
struct LocalEntityTests {
    @Test("accountabilityScore returns 0 for entity with no commitments")
    func scoreNoCommitments() {
        let entity = LocalEntity(name: "Nobody")
        #expect(entity.accountabilityScore == 0)
    }

    @Test("accountabilityScore returns 100 for entity with all fulfilled")
    func scoreAllFulfilled() {
        let entity = LocalEntity(name: "Perfect Corp")
        let c1 = LocalCommitment(entityName: "Perfect Corp", summary: "Task 1", fullText: "test", status: .fulfilled)
        let c2 = LocalCommitment(entityName: "Perfect Corp", summary: "Task 2", fullText: "test", status: .fulfilled)
        let c3 = LocalCommitment(entityName: "Perfect Corp", summary: "Task 3", fullText: "test", status: .fulfilled)
        entity.commitments = [c1, c2, c3]

        #expect(entity.accountabilityScore == 100)
    }

    @Test("accountabilityScore penalizes overdue commitments")
    func scoreOverduePenalty() {
        let entity = LocalEntity(name: "Late Corp")
        let fulfilled = LocalCommitment(entityName: "Late Corp", summary: "Done", fullText: "test", status: .fulfilled)
        let overdue = LocalCommitment(entityName: "Late Corp", summary: "Late", fullText: "test", status: .overdue)
        entity.commitments = [fulfilled, overdue]

        // Base: 1/2 fulfilled = 50, penalty: 1/2 overdue * 30 = 15, score = 35
        #expect(entity.accountabilityScore == 35)
        #expect(entity.accountabilityScore < 100)
    }

    @Test("accountabilityGrade returns A for 90+, B for 80+, etc.")
    func gradeMapping() {
        // All fulfilled = 100 → A
        let entityA = LocalEntity(name: "A")
        entityA.commitments = (0..<10).map {
            LocalCommitment(entityName: "A", summary: "Task \($0)", fullText: "t", status: .fulfilled)
        }
        #expect(entityA.accountabilityGrade == "A")

        // 0 fulfilled, 0 overdue but has commitments: all pending = 0 score → F
        let entityF = LocalEntity(name: "F")
        entityF.commitments = [
            LocalCommitment(entityName: "F", summary: "Task", fullText: "t", status: .pending)
        ]
        #expect(entityF.accountabilityGrade == "F")
    }

    @Test("shareableScoreCard contains entity name and score")
    func scoreCard() {
        let entity = LocalEntity(name: "Acme Corp")
        let c1 = LocalCommitment(entityName: "Acme Corp", summary: "Done", fullText: "t", status: .fulfilled)
        entity.commitments = [c1]

        let card = entity.shareableScoreCard
        #expect(card.contains("Acme Corp"))
        #expect(card.contains("100/100"))
        #expect(card.contains("Grade: A"))
        #expect(card.contains("Fulfilled 1 of 1"))
        #expect(card.contains("Seddly"))
    }
}
