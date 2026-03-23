import Testing
import Foundation
@testable import Seddly

@Suite("EntityMergingService Tests")
struct EntityMergingServiceTests {
    @Test("Finds similar entity names")
    func findsSimilarNames() {
        let entities = [
            LocalEntity(name: "John"),
            LocalEntity(name: "John from Acme"),
            LocalEntity(name: "Completely Different"),
        ]

        let suggestions = EntityMergingService.findMergeCandidates(entities: entities)
        #expect(suggestions.count == 1)
        #expect(suggestions[0].primary.name == "John")
        #expect(suggestions[0].duplicates.count == 1)
        #expect(suggestions[0].duplicates[0].name == "John from Acme")
    }

    @Test("No duplicates when names are unique")
    func noDuplicates() {
        let entities = [
            LocalEntity(name: "Alice"),
            LocalEntity(name: "Bob"),
            LocalEntity(name: "Charlie"),
        ]

        let suggestions = EntityMergingService.findMergeCandidates(entities: entities)
        #expect(suggestions.isEmpty)
    }

    @Test("Detects containment-based similarity")
    func containmentSimilarity() {
        let entities = [
            LocalEntity(name: "Acme Property Management"),
            LocalEntity(name: "Acme Property"),
        ]

        let suggestions = EntityMergingService.findMergeCandidates(entities: entities)
        #expect(suggestions.count == 1)
    }
}
