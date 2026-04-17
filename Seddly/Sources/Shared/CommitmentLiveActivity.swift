import Foundation
import ActivityKit

/// US-151: Live Activity attributes for the next-due pending commitment.
///
/// The attributes (`entityName`, `commitmentID`) are immutable for the life
/// of the activity. The content state (`summary`, `deadline`) is updated as
/// the user edits the commitment or as sibling reminders fire.
///
/// Lives under Sources/Shared so both the main app (which starts/ends the
/// activity) and the widget extension (which renders it) see the same type.
struct CommitmentActivityAttributes: ActivityAttributes {
    public typealias ContentState = CommitmentActivityState

    public struct CommitmentActivityState: Codable, Hashable {
        public var summary: String
        public var deadline: Date

        public init(summary: String, deadline: Date) {
            self.summary = summary
            self.deadline = deadline
        }
    }

    public let commitmentID: String
    public let entityName: String

    public init(commitmentID: String, entityName: String) {
        self.commitmentID = commitmentID
        self.entityName = entityName
    }
}
