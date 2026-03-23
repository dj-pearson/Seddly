import SwiftUI
import SwiftData

@Observable
final class ManualEntryViewModel {
    var entityName = ""
    var summary = ""
    var deadline: Date?
    var hasDeadline = false
    var dollarAmount = ""
    var notes = ""

    var isValid: Bool {
        !entityName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !summary.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func createCommitment(in context: ModelContext) -> LocalCommitment {
        let amount: Decimal? = if dollarAmount.isEmpty {
            nil
        } else {
            Decimal(string: dollarAmount.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: ""))
        }

        let commitment = LocalCommitment(
            entityName: entityName.trimmingCharacters(in: .whitespaces),
            summary: summary.trimmingCharacters(in: .whitespaces),
            fullText: summary.trimmingCharacters(in: .whitespaces),
            deadline: hasDeadline ? deadline : nil,
            dollarAmount: amount,
            source: .manual,
            notes: notes.isEmpty ? nil : notes
        )

        // Find or create entity
        let name = commitment.entityName
        let descriptor = FetchDescriptor<LocalEntity>(predicate: #Predicate { $0.name == name })
        if let existing = try? context.fetch(descriptor).first {
            commitment.entity = existing
        } else {
            let entity = LocalEntity(name: name)
            context.insert(entity)
            commitment.entity = entity
        }

        context.insert(commitment)
        return commitment
    }

    func reset() {
        entityName = ""
        summary = ""
        deadline = nil
        hasDeadline = false
        dollarAmount = ""
        notes = ""
    }
}
