import Testing
import Foundation
@testable import Seddly

@Suite("EscalationTemplateService Tests")
struct EscalationTemplateServiceTests {
    private func makeEntity(name: String, commitments: [LocalCommitment]) -> LocalEntity {
        let entity = LocalEntity(name: name)
        entity.commitments = commitments
        return entity
    }

    @Test("generateLetter for housing includes landlord-specific language")
    func housingLetter() {
        let commitment = LocalCommitment(
            entityName: "Landlord",
            summary: "Fix leaking faucet",
            fullText: "I'll fix the faucet next week",
            deadline: Calendar.current.date(byAdding: .day, value: -10, to: .now),
            status: .overdue
        )
        let entity = makeEntity(name: "Landlord", commitments: [commitment])

        let letter = EscalationTemplateService.generateLetter(for: entity, category: .housing, senderName: "Jane Doe")
        #expect(letter.contains("Landlord"))
        #expect(letter.contains("tenant"))
        #expect(letter.contains("habitability"))
        #expect(letter.contains("Fix leaking faucet"))
        #expect(letter.contains("Jane Doe"))
    }

    @Test("generateLetter for freelance includes payment-specific language")
    func freelanceLetter() {
        let commitment = LocalCommitment(
            entityName: "Client Inc",
            summary: "Pay invoice NET-30",
            fullText: "Payment will be processed NET-30",
            deadline: Calendar.current.date(byAdding: .day, value: -5, to: .now),
            dollarAmount: 5000,
            status: .overdue
        )
        let entity = makeEntity(name: "Client Inc", commitments: [commitment])

        let letter = EscalationTemplateService.generateLetter(for: entity, category: .freelance, senderName: "Dev")
        #expect(letter.contains("Client Inc"))
        #expect(letter.contains("payment") || letter.contains("Payment"))
        #expect(letter.contains("collection"))
        #expect(letter.contains("Pay invoice NET-30"))
    }

    @Test("generateLetter populates commitment timeline with real data")
    func timelinePopulation() {
        let c1 = LocalCommitment(
            entityName: "Shop",
            summary: "Refund order #100",
            fullText: "We will refund",
            status: .pending
        )
        let c2 = LocalCommitment(
            entityName: "Shop",
            summary: "Replace item #200",
            fullText: "We will replace",
            status: .overdue
        )
        let entity = makeEntity(name: "Shop", commitments: [c1, c2])

        let letter = EscalationTemplateService.generateLetter(for: entity, category: .purchases)
        #expect(letter.contains("1. Refund order #100"))
        #expect(letter.contains("2. Replace item #200"))
        #expect(letter.contains("Recorded:"))
    }

    @Test("availableTemplates returns all non-personal categories")
    func availableTemplatesCount() {
        let templates = EscalationTemplateService.availableTemplates()
        // Categories: housing, freelance, purchases, medical, insurance (5 total — excludes personal and uncategorized)
        #expect(templates.count == 5)
        let categories = Set(templates.map(\.category))
        #expect(categories.contains(.housing))
        #expect(categories.contains(.freelance))
        #expect(categories.contains(.purchases))
        #expect(categories.contains(.medical))
        #expect(categories.contains(.insurance))
    }
}
