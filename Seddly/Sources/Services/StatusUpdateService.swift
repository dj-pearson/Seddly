import Foundation
import SwiftData
import UserNotifications

struct StatusUpdateService {
    /// Scans all pending commitments and marks them as overdue if their deadline has passed.
    /// Returns the count of overdue commitments (for badge updates).
    @discardableResult
    static func updateOverdueStatuses(in context: ModelContext) -> Int {
        let pendingRaw = CommitmentStatus.pending.rawValue
        let descriptor = FetchDescriptor<LocalCommitment>(
            predicate: #Predicate { $0.statusRaw == pendingRaw && $0.deadline != nil }
        )
        guard let pendingCommitments = try? context.fetch(descriptor) else { return 0 }

        var overdueCount = 0
        let now = Date.now
        for commitment in pendingCommitments {
            if let deadline = commitment.deadline, deadline < now {
                commitment.status = .overdue
                commitment.updatedAt = now
                overdueCount += 1
            }
        }

        // Count all overdue (including previously marked)
        let overdueRaw = CommitmentStatus.overdue.rawValue
        let allOverdueDescriptor = FetchDescriptor<LocalCommitment>(
            predicate: #Predicate { $0.statusRaw == overdueRaw }
        )
        let totalOverdue = (try? context.fetchCount(allOverdueDescriptor)) ?? overdueCount

        if overdueCount > 0 {
            try? context.save()
        }

        return totalOverdue
    }

    /// Updates the app icon badge to reflect the number of overdue commitments.
    static func updateBadgeCount(_ count: Int) async {
        try? await UNUserNotificationCenter.current().setBadgeCount(count)
    }

    /// Convenience: update statuses and badge in one call.
    static func processAndUpdateBadge(in context: ModelContext) async {
        let overdueCount = updateOverdueStatuses(in: context)
        await updateBadgeCount(overdueCount)
    }
}
