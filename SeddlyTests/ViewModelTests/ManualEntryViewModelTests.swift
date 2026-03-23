import Testing
import Foundation
@testable import Seddly

@Suite("ManualEntryViewModel Tests")
struct ManualEntryViewModelTests {
    @Test("Validation requires entity name and summary")
    func validation() {
        let vm = ManualEntryViewModel()

        vm.entityName = ""
        vm.summary = ""
        #expect(vm.isValid == false)

        vm.entityName = "Landlord"
        vm.summary = ""
        #expect(vm.isValid == false)

        vm.entityName = ""
        vm.summary = "Fix the AC"
        #expect(vm.isValid == false)

        vm.entityName = "Landlord"
        vm.summary = "Fix the AC"
        #expect(vm.isValid == true)
    }

    @Test("Whitespace-only input is invalid")
    func whitespaceValidation() {
        let vm = ManualEntryViewModel()
        vm.entityName = "   "
        vm.summary = "   "
        #expect(vm.isValid == false)
    }

    @Test("Reset clears all fields")
    func reset() {
        let vm = ManualEntryViewModel()
        vm.entityName = "Test"
        vm.summary = "Something"
        vm.hasDeadline = true
        vm.deadline = .now
        vm.dollarAmount = "$500"
        vm.notes = "Some notes"

        vm.reset()

        #expect(vm.entityName == "")
        #expect(vm.summary == "")
        #expect(vm.hasDeadline == false)
        #expect(vm.deadline == nil)
        #expect(vm.dollarAmount == "")
        #expect(vm.notes == "")
    }
}
