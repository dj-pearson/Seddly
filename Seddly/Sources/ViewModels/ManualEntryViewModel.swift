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
    var category: CommitmentCategory = .uncategorized

    static let entityNameMaxLength = 100
    static let summaryMaxLength = 500

    var entityNameError: String? {
        let trimmed = entityName.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "Entity name is required" }
        if trimmed.count > Self.entityNameMaxLength { return "Entity name must be \(Self.entityNameMaxLength) characters or fewer" }
        return nil
    }

    var summaryError: String? {
        let trimmed = summary.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "Summary is required" }
        if trimmed.count > Self.summaryMaxLength { return "Summary must be \(Self.summaryMaxLength) characters or fewer" }
        return nil
    }

    var dollarAmountError: String? {
        guard !dollarAmount.isEmpty else { return nil }
        let cleaned = dollarAmount.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        // Reject empty after cleanup (e.g. "$" or "$$")
        guard !cleaned.isEmpty else { return "Enter a valid dollar amount" }
        // Reject multiple decimal points (e.g. "1.2.3")
        if cleaned.filter({ $0 == "." }).count > 1 { return "Invalid format — too many decimal points" }
        // Reject non-numeric characters after cleanup
        let validChars = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))
        if cleaned.unicodeScalars.contains(where: { !validChars.contains($0) }) {
            return "Amount contains invalid characters"
        }
        guard let value = Decimal(string: cleaned) else { return "Enter a valid dollar amount" }
        if value < 0 { return "Amount must be a positive number" }
        return nil
    }

    var isValid: Bool {
        entityNameError == nil && summaryError == nil && dollarAmountError == nil
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
        commitment.category = category

        // Find or create entity using case-insensitive match to prevent duplicates
        let name = commitment.entityName
        let descriptor = FetchDescriptor<LocalEntity>(predicate: #Predicate {
            $0.name.localizedStandardContains(name) || $0.name == name
        })
        let existingEntities = (try? context.fetch(descriptor)) ?? []
        // Prefer exact match, then case-insensitive match
        if let exact = existingEntities.first(where: { $0.name == name }) {
            commitment.entity = exact
        } else if let similar = existingEntities.first {
            commitment.entity = similar
        } else {
            let entity = LocalEntity(name: name)
            context.insert(entity)
            commitment.entity = entity
        }

        context.insert(commitment)
        ClassifierFeedbackService.recordManualAddition()

        // Schedule notifications for commitments with deadlines
        if commitment.deadline != nil {
            let notificationService = NotificationService()
            Task {
                await notificationService.scheduleDeadlineApproaching(for: commitment)
                await notificationService.scheduleDeadlinePassed(for: commitment)
            }
        }

        WatchSyncService.shared.sendCommitmentUpdate(
            id: commitment.id, action: "created",
            entityName: commitment.entityName, summary: commitment.summary,
            statusRaw: commitment.statusRaw
        )

        return commitment
    }

    func reset() {
        entityName = ""
        summary = ""
        deadline = nil
        hasDeadline = false
        dollarAmount = ""
        notes = ""
        category = .uncategorized
    }
}
