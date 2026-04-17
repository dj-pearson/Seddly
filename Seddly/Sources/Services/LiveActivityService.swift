import Foundation
import ActivityKit

/// US-151: Starts, updates, and ends the Commitment Live Activity for the
/// pending commitment with the soonest deadline.
///
/// Only one activity is kept alive at a time — we show the single most
/// time-pressing commitment. The service auto-ends the activity when the
/// deadline has passed by more than 24 hours, when the commitment is
/// fulfilled/dismissed/snoozed, or when the user has no qualifying pending
/// commitments.
actor LiveActivityService {

    /// Only commitments whose deadline falls within this window are eligible
    /// to promote to a Live Activity. Matches the user story's 24-hour cap.
    static let eligibilityWindow: TimeInterval = 24 * 3600

    private var currentActivityID: String?
    private var currentCommitmentID: UUID?

    /// Evaluates the given list of commitments and ensures at most one Live
    /// Activity is running for the soonest-due pending commitment.
    func reconcile(pendingCommitments: [PendingCommitment]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await endAll()
            return
        }

        let eligible = pendingCommitments
            .filter { candidate in
                let remaining = candidate.deadline.timeIntervalSinceNow
                return remaining < Self.eligibilityWindow && remaining > -24 * 3600
            }
            .sorted { $0.deadline < $1.deadline }

        guard let target = eligible.first else {
            await endAll()
            return
        }

        // If we already have an activity for the same commitment, update it.
        if currentCommitmentID == target.id,
           let id = currentActivityID,
           let activity = Activity<CommitmentActivityAttributes>.activities
            .first(where: { $0.id == id }) {
            await activity.update(
                ActivityContent(
                    state: .init(summary: target.summary, deadline: target.deadline),
                    staleDate: target.deadline.addingTimeInterval(3600)
                )
            )
            return
        }

        // Otherwise end whatever is running and start a new one.
        await endAll()
        do {
            let activity = try Activity.request(
                attributes: CommitmentActivityAttributes(
                    commitmentID: target.id.uuidString,
                    entityName: target.entityName
                ),
                content: ActivityContent(
                    state: .init(summary: target.summary, deadline: target.deadline),
                    staleDate: target.deadline.addingTimeInterval(3600)
                ),
                pushType: nil
            )
            currentActivityID = activity.id
            currentCommitmentID = target.id
        } catch {
            AppLogger.general.error("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    /// Ends every running Commitment Live Activity. Called when the user has
    /// no qualifying commitments or the feature preference is off.
    func endAll() async {
        for activity in Activity<CommitmentActivityAttributes>.activities {
            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
        currentActivityID = nil
        currentCommitmentID = nil
    }

    /// Input snapshot the caller passes to `reconcile` — lets us stay
    /// decoupled from SwiftData types and keeps the actor easy to test.
    struct PendingCommitment: Sendable, Equatable {
        public let id: UUID
        public let entityName: String
        public let summary: String
        public let deadline: Date

        public init(id: UUID, entityName: String, summary: String, deadline: Date) {
            self.id = id
            self.entityName = entityName
            self.summary = summary
            self.deadline = deadline
        }
    }
}
