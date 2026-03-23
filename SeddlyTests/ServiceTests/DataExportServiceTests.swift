import Testing
import Foundation
@testable import Seddly

@Suite("DataExportService Tests")
struct DataExportServiceTests {
    @Test("CSV export includes header and data")
    func csvExport() {
        let commitment = LocalCommitment(
            entityName: "Test Landlord",
            summary: "Fix the AC",
            fullText: "I'll fix the AC by Friday"
        )

        let csv = DataExportService.exportCSV([commitment])
        #expect(csv.contains("ID,Entity,Summary"))
        #expect(csv.contains("Test Landlord"))
        #expect(csv.contains("Fix the AC"))
    }

    @Test("JSON export produces valid structure")
    func jsonExport() {
        let commitment = LocalCommitment(
            entityName: "Client Co",
            summary: "Pay invoice",
            fullText: "We'll pay Net 30"
        )

        let json = DataExportService.exportJSON([commitment])
        #expect(json.contains("Client Co"))
        #expect(json.contains("Pay invoice"))
        #expect(json.starts(with: "["))
    }

    @Test("CSV escapes commas and quotes")
    func csvEscaping() {
        let commitment = LocalCommitment(
            entityName: "Smith, John",
            summary: "He said \"by Friday\"",
            fullText: "test"
        )

        let csv = DataExportService.exportCSV([commitment])
        #expect(csv.contains("\"Smith, John\""))
    }

    @Test("Empty array exports cleanly")
    func emptyExport() {
        let csv = DataExportService.exportCSV([])
        #expect(csv.contains("ID,Entity,Summary"))

        let json = DataExportService.exportJSON([])
        #expect(json == "[\n\n]")
    }
}
