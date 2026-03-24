import Testing
import Foundation
import SwiftData
@testable import Seddly

@Suite("PrivacyAuditService Tests")
struct PrivacyAuditServiceTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PrivacyAuditEntry.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test("recordAIExtraction creates entry with correct eventType and textLength")
    func recordAIExtraction() async throws {
        let context = try makeContext()
        let service = PrivacyAuditService()
        let url = URL(string: "https://api.example.com/extract")!

        await service.recordAIExtraction(
            textLength: 1500,
            endpoint: url,
            commitmentID: UUID(),
            context: context
        )

        let descriptor = FetchDescriptor<PrivacyAuditEntry>()
        let entries = try context.fetch(descriptor)
        #expect(entries.count == 1)
        #expect(entries[0].eventType == .aiExtraction)
        #expect(entries[0].textLengthSent == 1500)
        #expect(entries[0].destination == "api.example.com")
    }

    @Test("recordDisputeSummary creates entry with commitment count in summary")
    func recordDisputeSummary() async throws {
        let context = try makeContext()
        let service = PrivacyAuditService()
        let url = URL(string: "https://api.example.com/dispute")!

        await service.recordDisputeSummary(
            commitmentCount: 3,
            textLength: 800,
            endpoint: url,
            context: context
        )

        let descriptor = FetchDescriptor<PrivacyAuditEntry>()
        let entries = try context.fetch(descriptor)
        #expect(entries.count == 1)
        #expect(entries[0].eventType == .disputeSummary)
        #expect(entries[0].dataSummary.contains("3 commitment"))
        #expect(entries[0].textLengthSent == 800)
    }

    @Test("generateReport returns correct counts and totals")
    func generateReport() async throws {
        let context = try makeContext()
        let service = PrivacyAuditService()
        let url = URL(string: "https://api.example.com")!

        await service.recordAIExtraction(textLength: 100, endpoint: url, context: context)
        await service.recordAIExtraction(textLength: 200, endpoint: url, context: context)
        await service.recordDisputeSummary(commitmentCount: 1, textLength: 50, endpoint: url, context: context)

        let report = try await service.generateReport(context: context)
        #expect(report.totalEvents == 3)
        #expect(report.totalCharactersSent == 350)
        #expect(report.countsByType[.aiExtraction] == 2)
        #expect(report.countsByType[.disputeSummary] == 1)
    }

    @Test("exportReport produces formatted text with all sections")
    func exportReport() async throws {
        let context = try makeContext()
        let service = PrivacyAuditService()
        let url = URL(string: "https://api.example.com")!

        await service.recordAIExtraction(textLength: 500, endpoint: url, context: context)

        let output = try await service.exportReport(context: context)
        #expect(output.contains("SEDDLY PRIVACY AUDIT REPORT"))
        #expect(output.contains("SUMMARY"))
        #expect(output.contains("Total data transmissions: 1"))
        #expect(output.contains("Total characters sent off-device: 500"))
        #expect(output.contains("BREAKDOWN BY TYPE"))
        #expect(output.contains("DETAILED LOG"))
    }
}
