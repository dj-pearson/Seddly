import Testing
import Foundation
@testable import Seddly

@Suite("LedgerViewModel History Limit Tests")
struct LedgerViewModelHistoryTests {
    private func makeCommitment(daysAgo: Int, name: String = "Entity") -> LocalCommitment {
        let commitment = LocalCommitment(
            entityName: name,
            summary: "\(daysAgo) days ago",
            fullText: "test"
        )
        commitment.createdAt = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        return commitment
    }

    @Test("applyHistoryLimit with .free tier filters out commitments older than 30 days")
    func freeTierLimit() {
        let vm = LedgerViewModel()
        let recent = makeCommitment(daysAgo: 5)
        let old = makeCommitment(daysAgo: 45)

        let result = vm.applyHistoryLimit([recent, old], tier: .free)
        #expect(result.count == 1)
        #expect(result[0].summary == "5 days ago")
    }

    @Test("applyHistoryLimit with .pro tier filters out commitments older than 1 year")
    func proTierLimit() {
        let vm = LedgerViewModel()
        let recent = makeCommitment(daysAgo: 60)
        let old = makeCommitment(daysAgo: 400)

        let result = vm.applyHistoryLimit([recent, old], tier: .pro)
        #expect(result.count == 1)
        #expect(result[0].summary == "60 days ago")
    }

    @Test("applyHistoryLimit with .proPlus tier returns all commitments")
    func proPlusTierNoLimit() {
        let vm = LedgerViewModel()
        let recent = makeCommitment(daysAgo: 5)
        let old = makeCommitment(daysAgo: 500)

        let result = vm.applyHistoryLimit([recent, old], tier: .proPlus)
        #expect(result.count == 2)
    }

    @Test("bulkUpdateStatus updates selected commitments")
    func bulkUpdateStatus() {
        let vm = LedgerViewModel()
        let c1 = LocalCommitment(entityName: "A", summary: "One", fullText: "t")
        let c2 = LocalCommitment(entityName: "B", summary: "Two", fullText: "t")
        let c3 = LocalCommitment(entityName: "C", summary: "Three", fullText: "t")

        vm.isSelecting = true
        vm.selectedCommitments = [c1.id, c3.id]

        vm.bulkUpdateStatus(.fulfilled, in: [c1, c2, c3])
        #expect(c1.status == .fulfilled)
        #expect(c2.status == .pending)
        #expect(c3.status == .fulfilled)
        #expect(vm.selectedCommitments.isEmpty)
    }

    @Test("bulkUpdateCategory updates selected commitments")
    func bulkUpdateCategory() {
        let vm = LedgerViewModel()
        let c1 = LocalCommitment(entityName: "A", summary: "One", fullText: "t")
        let c2 = LocalCommitment(entityName: "B", summary: "Two", fullText: "t")

        vm.isSelecting = true
        vm.selectedCommitments = [c1.id, c2.id]

        vm.bulkUpdateCategory(.housing, in: [c1, c2])
        #expect(c1.category == .housing)
        #expect(c2.category == .housing)
    }
}
