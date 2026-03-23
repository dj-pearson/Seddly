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
