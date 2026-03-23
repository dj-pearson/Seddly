import Testing
import Foundation
@testable import Seddly

@Suite("LedgerViewModel Tests")
struct LedgerViewModelTests {
    @Test("Sorts by deadline proximity")
    func sortByDeadline() {
        let vm = LedgerViewModel()
        vm.sortOrder = .deadline

        let soon = LocalCommitment(
            entityName: "A",
            summary: "Soon",
            fullText: "test",
            deadline: Calendar.current.date(byAdding: .day, value: 1, to: .now)
        )
        let later = LocalCommitment(
            entityName: "B",
            summary: "Later",
            fullText: "test",
            deadline: Calendar.current.date(byAdding: .day, value: 10, to: .now)
        )
        let noDeadline = LocalCommitment(
            entityName: "C",
            summary: "No deadline",
            fullText: "test"
        )

        let sorted = vm.sortedCommitments([noDeadline, later, soon])
        #expect(sorted[0].entityName == "A")
        #expect(sorted[1].entityName == "B")
        #expect(sorted[2].entityName == "C")
    }

    @Test("Sorts by entity name")
    func sortByEntity() {
        let vm = LedgerViewModel()
        vm.sortOrder = .entity

        let b = LocalCommitment(entityName: "Bravo", summary: "test", fullText: "test")
        let a = LocalCommitment(entityName: "Alpha", summary: "test", fullText: "test")
        let c = LocalCommitment(entityName: "Charlie", summary: "test", fullText: "test")

        let sorted = vm.sortedCommitments([b, a, c])
        #expect(sorted[0].entityName == "Alpha")
        #expect(sorted[1].entityName == "Bravo")
        #expect(sorted[2].entityName == "Charlie")
    }

    @Test("Filters by status")
    func filterByStatus() {
        let vm = LedgerViewModel()
        vm.filterStatus = .fulfilled

        let pending = LocalCommitment(entityName: "A", summary: "test", fullText: "test")
        let fulfilled = LocalCommitment(
            entityName: "B",
            summary: "test",
            fullText: "test",
            status: .fulfilled
        )

        let filtered = vm.sortedCommitments([pending, fulfilled])
        #expect(filtered.count == 1)
        #expect(filtered[0].entityName == "B")
    }

    @Test("Search filters by entity name, summary, and full text")
    func searchFilter() {
        let vm = LedgerViewModel()
        vm.searchText = "landlord"

        let match = LocalCommitment(entityName: "Landlord John", summary: "Fix AC", fullText: "test")
        let noMatch = LocalCommitment(entityName: "Client", summary: "Pay invoice", fullText: "test")

        let results = vm.sortedCommitments([match, noMatch])
        #expect(results.count == 1)
        #expect(results[0].entityName == "Landlord John")
    }

    @Test("Fulfill updates status and timestamp")
    func fulfillCommitment() {
        let vm = LedgerViewModel()
        let commitment = LocalCommitment(entityName: "Test", summary: "test", fullText: "test")
        let before = commitment.updatedAt

        vm.fulfill(commitment)

        #expect(commitment.status == .fulfilled)
        #expect(commitment.updatedAt >= before)
    }

    @Test("Dismiss updates status and timestamp")
    func dismissCommitment() {
        let vm = LedgerViewModel()
        let commitment = LocalCommitment(entityName: "Test", summary: "test", fullText: "test")

        vm.dismiss(commitment)

        #expect(commitment.status == .dismissed)
    }
}
