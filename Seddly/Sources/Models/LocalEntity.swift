import Foundation
import SwiftData

@Model
final class LocalEntity {
    #Unique<LocalEntity>([\.id])

    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var commitments: [LocalCommitment]

    var totalCommitments: Int {
        commitments.count
    }

    var fulfilledCount: Int {
        commitments.filter { $0.status == .fulfilled }.count
    }

    var overdueCount: Int {
        commitments.filter { $0.status == .overdue || $0.isOverdue }.count
    }

    var fulfillmentRate: Double {
        guard totalCommitments > 0 else { return 0 }
        return Double(fulfilledCount) / Double(totalCommitments)
    }

    var accountabilityScore: Int {
        guard totalCommitments > 0 else { return 0 }
        let fulfilled = Double(fulfilledCount)
        let overdue = Double(overdueCount)
        let total = Double(totalCommitments)

        // Score from 0-100: rewards fulfilled, penalizes overdue
        let baseScore = (fulfilled / total) * 100
        let penalty = (overdue / total) * 30
        return max(0, min(100, Int(baseScore - penalty)))
    }

    var accountabilityGrade: String {
        switch accountabilityScore {
        case 90...100: "A"
        case 80..<90: "B"
        case 70..<80: "C"
        case 60..<70: "D"
        default: "F"
        }
    }

    var shareableScoreCard: String {
        "\(name) — Accountability Score: \(accountabilityScore)/100 (Grade: \(accountabilityGrade))\n"
        + "Fulfilled \(fulfilledCount) of \(totalCommitments) tracked commitment\(totalCommitments == 1 ? "" : "s").\n"
        + "\(overdueCount) overdue.\n"
        + "— Tracked by Seddly (seddly.com)"
    }

    var pendingCommitments: [LocalCommitment] {
        commitments
            .filter { $0.status == .pending }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
    }

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.updatedAt = .now
        self.commitments = []
    }
}
