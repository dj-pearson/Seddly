import Foundation
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

struct MarkFulfilledIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Commitment as Fulfilled"
    static var description: IntentDescription = "Mark a commitment as fulfilled by searching for its summary text."
    static var openAppWhenRun = false

    @Parameter(title: "Commitment summary text")
    var summaryText: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<LocalCommitment>()
        let all = (try? context.fetch(descriptor)) ?? []
        let query = summaryText.lowercased()

        guard let match = all.first(where: {
            $0.summary.lowercased().contains(query) || $0.entityName.lowercased().contains(query)
        }) else {
            return .result(dialog: "No commitment found matching '\(summaryText)'.")
        }

        match.status = .fulfilled
        match.updatedAt = .now
        try context.save()

        return .result(dialog: "Marked as fulfilled: \(match.entityName) — \(match.summary)")
    }
}

struct CheckEntityIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Entity Accountability"
    static var description: IntentDescription = "Check an entity's accountability score and overdue count."
    static var openAppWhenRun = false

    @Parameter(title: "Entity name")
    var entityName: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let name = entityName
        let descriptor = FetchDescriptor<LocalEntity>(
            predicate: #Predicate { $0.name == name }
        )

        guard let entity = try? context.fetch(descriptor).first else {
            return .result(dialog: "No entity named '\(entityName)' found.")
        }

        let score = entity.accountabilityScore
        let overdue = entity.overdueCount
        let grade = entity.accountabilityGrade

        return .result(dialog: "\(entity.name): \(grade) (\(score)%). \(overdue) overdue commitment\(overdue == 1 ? "" : "s").")
    }
}

struct UpdateDeadlineIntent: AppIntent {
    static var title: LocalizedStringResource = "Update Commitment Deadline"
    static var description: IntentDescription = "Update the deadline for a commitment."
    static var openAppWhenRun = false

    @Parameter(title: "Commitment summary text")
    var summaryText: String

    @Parameter(title: "New deadline")
    var newDeadline: Date

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SharedModelContainer.create()
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<LocalCommitment>()
        let all = (try? context.fetch(descriptor)) ?? []
        let query = summaryText.lowercased()

        guard let match = all.first(where: {
            $0.summary.lowercased().contains(query) || $0.entityName.lowercased().contains(query)
        }) else {
            return .result(dialog: "No commitment found matching '\(summaryText)'.")
        }

        match.deadline = newDeadline
        match.updatedAt = .now
        try context.save()

        return .result(dialog: "Updated deadline for \(match.entityName) — \(match.summary) to \(newDeadline.formatted(date: .abbreviated, time: .omitted)).")
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

        AppShortcut(
            intent: MarkFulfilledIntent(),
            phrases: [
                "Mark commitment as fulfilled in \(.applicationName)",
                "Complete a commitment in \(.applicationName)",
                "Fulfill commitment in \(.applicationName)"
            ],
            shortTitle: "Mark Fulfilled",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: CheckEntityIntent(),
            phrases: [
                "Check entity score in \(.applicationName)",
                "How reliable is someone in \(.applicationName)",
                "Check accountability in \(.applicationName)"
            ],
            shortTitle: "Check Entity",
            systemImageName: "person.circle"
        )

        AppShortcut(
            intent: UpdateDeadlineIntent(),
            phrases: [
                "Update commitment deadline in \(.applicationName)",
                "Change deadline in \(.applicationName)",
                "Reschedule commitment in \(.applicationName)"
            ],
            shortTitle: "Update Deadline",
            systemImageName: "calendar.badge.clock"
        )
    }
}
