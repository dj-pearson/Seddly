import Foundation
import SwiftData

@Model
final class LocalCommitment {
    #Unique<LocalCommitment>([\.id])
    #Index<LocalCommitment>([\.statusRaw], [\.deadline])

    @Attribute(.unique) var id: UUID
    var entityName: String
    var summary: String
    var fullText: String
    var deadline: Date?
    var dollarAmount: Decimal?
    var statusRaw: String
    var confidenceScore: Int
    var aiReasoning: String?
    var sourceRaw: String
    var commitmentTypeRaw: String?
    var screenshotAssetID: String?
    var screenshotDate: Date?
    var notes: String?
    var needsAIProcessing: Bool
    var syncStatusRaw: String
    var categoryRaw: String?
    var calendarEventID: String?
    var customStatusLabel: String?
    var workflowID: UUID?
    var createdAt: Date
    var updatedAt: Date
    /// US-149: Hides the commitment from the active ledger until this date
    /// passes. Nil when not snoozed. Lightweight SwiftData migration handles
    /// existing rows (default nil). The original deadline is untouched, so
    /// urgency and notifications still reflect the real promise date once
    /// the snooze ends.
    var snoozedUntil: Date?

    @Relationship(inverse: \LocalEntity.commitments)
    var entity: LocalEntity?

    var status: CommitmentStatus {
        get { CommitmentStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var source: CommitmentSource {
        get { CommitmentSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var commitmentType: CommitmentType? {
        get { commitmentTypeRaw.flatMap { CommitmentType(rawValue: $0) } }
        set { commitmentTypeRaw = newValue?.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .local }
        set { syncStatusRaw = newValue.rawValue }
    }

    var category: CommitmentCategory {
        get { CommitmentCategory(rawValue: categoryRaw ?? "") ?? .uncategorized }
        set { categoryRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard let deadline, status == .pending else { return false }
        return deadline < .now
    }

    var urgencyLevel: UrgencyLevel {
        guard let deadline, status == .pending else { return .none }
        let daysUntil = Calendar.current.dateComponents([.day], from: .now, to: deadline).day ?? 0
        if daysUntil < 0 { return .overdue }
        if daysUntil <= 6 { return .approaching }
        return .safe
    }

    /// US-149: True when the commitment is currently snoozed (hidden from the
    /// active ledger). Callers should use this instead of reading
    /// `snoozedUntil` directly so the "date has passed" case is handled.
    var isSnoozed: Bool {
        guard let snoozedUntil else { return false }
        return snoozedUntil > .now
    }

    init(
        entityName: String,
        summary: String,
        fullText: String,
        deadline: Date? = nil,
        dollarAmount: Decimal? = nil,
        status: CommitmentStatus = .pending,
        confidenceScore: Int = 0,
        aiReasoning: String? = nil,
        source: CommitmentSource = .manual,
        commitmentType: CommitmentType? = nil,
        screenshotAssetID: String? = nil,
        screenshotDate: Date? = nil,
        notes: String? = nil,
        needsAIProcessing: Bool = false
    ) {
        self.id = UUID()
        self.entityName = entityName
        self.summary = summary
        self.fullText = fullText
        self.deadline = deadline
        self.dollarAmount = dollarAmount
        self.statusRaw = status.rawValue
        self.confidenceScore = confidenceScore
        self.aiReasoning = aiReasoning
        self.sourceRaw = source.rawValue
        self.commitmentTypeRaw = commitmentType?.rawValue
        self.screenshotAssetID = screenshotAssetID
        self.screenshotDate = screenshotDate
        self.notes = notes
        self.needsAIProcessing = needsAIProcessing
        self.syncStatusRaw = SyncStatus.local.rawValue
        self.createdAt = .now
        self.updatedAt = .now
    }

    enum UrgencyLevel {
        case overdue, approaching, safe, none
    }
}
