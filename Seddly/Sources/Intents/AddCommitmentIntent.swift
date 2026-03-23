import AppIntents
import SwiftData

struct AddCommitmentIntent: AppIntent {
    static var title: LocalizedStringResource = "Add a Commitment"
    static var description: IntentDescription = "Add a new commitment to track in Seddly."
    static var openAppWhenRun = false

    @Parameter(title: "Who made the commitment?")
    var entityName: String

    @Parameter(title: "What did they promise?")
    var summary: String

    @Parameter(title: "Deadline", optionalityType: .optional)
    var deadline: Date?

    @Parameter(title: "Dollar amount", optionalityType: .optional)
    var dollarAmount: Double?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let commitment = LocalCommitment(
            entityName: entityName,
            summary: summary,
            fullText: summary,
            deadline: deadline,
            dollarAmount: dollarAmount.map { Decimal($0) },
            source: .manual
        )

        // Find or create entity
        let name = entityName
        let descriptor = FetchDescriptor<LocalEntity>(
            predicate: #Predicate { $0.name == name }
        )
        if let existing = try? context.fetch(descriptor).first {
            commitment.entity = existing
        } else {
            let entity = LocalEntity(name: name)
            context.insert(entity)
            commitment.entity = entity
        }

        context.insert(commitment)
        try context.save()

        var dialogText = "Added: \(entityName) — \(summary)"
        if let deadline {
            dialogText += ". Due \(deadline.formatted(date: .abbreviated, time: .omitted))"
        }

        return .result(dialog: IntentDialog(stringLiteral: dialogText))
    }
}

struct ViewOverdueIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Overdue Commitments"
    static var description: IntentDescription = "See how many commitments are overdue."
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<LocalCommitment>(
            predicate: #Predicate { $0.statusRaw == "pending" }
        )
        let pending = (try? context.fetch(descriptor)) ?? []
        let overdue = pending.filter { $0.isOverdue }

        if overdue.isEmpty {
            return .result(dialog: "No overdue commitments. You're all caught up!")
        }

        let names = overdue.prefix(3).map(\.entityName).joined(separator: ", ")
        return .result(dialog: "\(overdue.count) overdue commitment\(overdue.count == 1 ? "" : "s"). From: \(names).")
    }
}

struct SeddlyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddCommitmentIntent(),
            phrases: [
                "Add a commitment in \(.applicationName)",
                "Track a promise in \(.applicationName)",
                "Add commitment to \(.applicationName)"
            ],
            shortTitle: "Add Commitment",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: ViewOverdueIntent(),
            phrases: [
                "Check overdue commitments in \(.applicationName)",
                "How many overdue in \(.applicationName)",
                "Show overdue in \(.applicationName)"
            ],
            shortTitle: "Check Overdue",
            systemImageName: "exclamationmark.circle"
        )
    }
}
