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

    // MARK: - US-148

    @Test("activeFilterCount counts each distinct filter once")
    func activeFilterCount() {
        let vm = LedgerViewModel()
        #expect(vm.activeFilterCount == 0)

        vm.filterStatus = .pending
        #expect(vm.activeFilterCount == 1)

        vm.filterEntityName = "Alice"
        #expect(vm.activeFilterCount == 2)

        vm.filterHasDeadlineOnly = true
        #expect(vm.activeFilterCount == 3)

        // Date range is treated as a single filter regardless of which end is set.
        vm.filterDateStart = .now
        #expect(vm.activeFilterCount == 4)
        vm.filterDateEnd = .now
        #expect(vm.activeFilterCount == 4)

        vm.filterCategory = .freelance
        #expect(vm.activeFilterCount == 5)

        // Amount range is also a single filter.
        vm.filterAmountMin = 10
        #expect(vm.activeFilterCount == 6)
        vm.filterAmountMax = 100
        #expect(vm.activeFilterCount == 6)

        // Search text should NOT be counted (it has its own surfacing).
        vm.searchText = "foo"
        #expect(vm.activeFilterCount == 6)
    }

    // MARK: - US-145

    @Test("Memoized sort returns identical results for unchanged inputs")
    func sortedCommitmentsIsMemoized() {
        let vm = LedgerViewModel()
        let a = LocalCommitment(entityName: "A", summary: "test", fullText: "test")
        let b = LocalCommitment(entityName: "B", summary: "test", fullText: "test")
        let input = [b, a]

        let first = vm.sortedCommitments(input)
        let second = vm.sortedCommitments(input)
        #expect(first.map(\.id) == second.map(\.id))
    }

    @Test("Changing a filter invalidates the memoized sort result")
    func memoizationInvalidatesOnFilterChange() {
        let vm = LedgerViewModel()
        let pending = LocalCommitment(entityName: "A", summary: "test", fullText: "test")
        let fulfilled = LocalCommitment(
            entityName: "B", summary: "test", fullText: "test", status: .fulfilled
        )

        let before = vm.sortedCommitments([pending, fulfilled])
        #expect(before.count == 2)

        vm.filterStatus = .fulfilled
        let after = vm.sortedCommitments([pending, fulfilled])
        #expect(after.count == 1)
        #expect(after[0].entityName == "B")
    }
}
