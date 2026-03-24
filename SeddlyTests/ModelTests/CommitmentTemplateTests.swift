import Testing
import Foundation
@testable import Seddly

@Suite("CommitmentTemplate Tests")
struct CommitmentTemplateTests {
    @Test("allTemplates has 9 entries")
    func templateCount() {
        #expect(CommitmentTemplate.allTemplates.count == 9)
    }

    @Test("Each template has non-empty name, icon, and defaultSummary")
    func templateFieldsNotEmpty() {
        for template in CommitmentTemplate.allTemplates {
            #expect(!template.name.isEmpty, "Template name should not be empty")
            #expect(!template.icon.isEmpty, "Template icon should not be empty")
            #expect(!template.defaultSummary.isEmpty, "Template defaultSummary should not be empty")
        }
    }

    @Test("Templates cover housing, freelance, purchases, medical, and insurance categories")
    func templateCategoryCoverage() {
        let categories = Set(CommitmentTemplate.allTemplates.map(\.category))
        #expect(categories.contains(.housing))
        #expect(categories.contains(.freelance))
        #expect(categories.contains(.purchases))
        #expect(categories.contains(.medical))
        #expect(categories.contains(.insurance))
    }

    @Test("Each template has a unique name")
    func uniqueNames() {
        let names = CommitmentTemplate.allTemplates.map(\.name)
        #expect(Set(names).count == names.count, "Template names should be unique")
    }
}
