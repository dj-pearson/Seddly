import SwiftUI
import SwiftData

@Observable
final class LedgerViewModel {
    var sortOrder: SortOrder = .deadline
    var filterStatus: CommitmentStatus?
    var filterEntityName: String?
    var filterHasDeadlineOnly = false
    var filterDateStart: Date?
    var filterDateEnd: Date?
    var filterCategory: CommitmentCategory?
    var filterAmountMin: Double?
    var filterAmountMax: Double?
    var searchText = ""

    var hasActiveFilters: Bool {
        filterStatus != nil || filterEntityName != nil || filterHasDeadlineOnly || filterDateStart != nil || filterCategory != nil || filterAmountMin != nil
    }

    enum SortOrder: String, CaseIterable {
        case deadline = "Deadline"
        case entity = "Entity"
        case dateAdded = "Date Added"
        case status = "Status"
    }

    func sortedCommitments(_ commitments: [LocalCommitment]) -> [LocalCommitment] {
        var filtered = commitments

        // Status filter
        if let filterStatus {
            filtered = filtered.filter { $0.status == filterStatus }
        }

        // Entity filter
        if let filterEntityName {
            filtered = filtered.filter { $0.entityName == filterEntityName }
        }

        // Deadline filter
        if filterHasDeadlineOnly {
            filtered = filtered.filter { $0.deadline != nil }
        }

        // Category filter
        if let filterCategory {
            filtered = filtered.filter { $0.category == filterCategory }
        }

        // Amount filter
        if let min = filterAmountMin {
            filtered = filtered.filter {
                guard let amount = $0.dollarAmount else { return false }
                return NSDecimalNumber(decimal: amount).doubleValue >= min
            }
        }
        if let max = filterAmountMax {
            filtered = filtered.filter {
                guard let amount = $0.dollarAmount else { return false }
                return NSDecimalNumber(decimal: amount).doubleValue <= max
            }
        }

        // Date range filter
        if let start = filterDateStart {
            filtered = filtered.filter { $0.createdAt >= start }
        }
        if let end = filterDateEnd {
            filtered = filtered.filter { $0.createdAt <= end }
        }

        // Search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter {
                $0.summary.lowercased().contains(query) ||
                $0.entityName.lowercased().contains(query) ||
                $0.fullText.lowercased().contains(query)
            }
        }

        switch sortOrder {
        case .deadline:
            return filtered.sorted {
                ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture)
            }
        case .entity:
            return filtered.sorted { $0.entityName < $1.entityName }
        case .dateAdded:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        case .status:
            let statusPriority: [CommitmentStatus: Int] = [
                .overdue: 0, .pending: 1, .disputed: 2, .fulfilled: 3, .dismissed: 4
            ]
            return filtered.sorted {
                (statusPriority[$0.status] ?? 5) < (statusPriority[$1.status] ?? 5)
            }
        }
    }

    /// Applies history limits based on subscription tier.
    /// Free: 30 days. Pro: 1 year. Pro+: unlimited.
    func applyHistoryLimit(_ commitments: [LocalCommitment], tier: SubscriptionService.SubscriptionTier) -> [LocalCommitment] {
        switch tier {
        case .free:
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
            return commitments.filter { $0.createdAt >= cutoff }
        case .pro:
            let cutoff = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .distantPast
            return commitments.filter { $0.createdAt >= cutoff }
        case .proPlus:
            return commitments
        }
    }

    /// Legacy convenience for free tier
    func applyFreeTierHistoryLimit(_ commitments: [LocalCommitment]) -> [LocalCommitment] {
        applyHistoryLimit(commitments, tier: .free)
    }

    func fulfill(_ commitment: LocalCommitment) {
        commitment.status = .fulfilled
        commitment.updatedAt = .now
        // Record as successful detection if it was auto-detected
        if commitment.source == .auto {
            ClassifierFeedbackService.recordAutoDetection()
        }
    }

    func dismiss(_ commitment: LocalCommitment) {
        commitment.status = .dismissed
        commitment.updatedAt = .now
        // Record as false positive if it was auto-detected
        if commitment.source == .auto {
            ClassifierFeedbackService.recordDismissal()
        }
    }

    // MARK: - Bulk Edit

    var isSelecting = false
    var selectedCommitments: Set<UUID> = []

    func toggleSelection(for commitment: LocalCommitment) {
        if selectedCommitments.contains(commitment.id) {
            selectedCommitments.remove(commitment.id)
        } else {
            selectedCommitments.insert(commitment.id)
        }
    }

    func isSelected(_ commitment: LocalCommitment) -> Bool {
        selectedCommitments.contains(commitment.id)
    }

    func selectAll(_ commitments: [LocalCommitment]) {
        selectedCommitments = Set(commitments.map(\.id))
    }

    func clearSelection() {
        selectedCommitments.removeAll()
        isSelecting = false
    }

    func bulkUpdateStatus(_ status: CommitmentStatus, in commitments: [LocalCommitment]) {
        for commitment in commitments where selectedCommitments.contains(commitment.id) {
            commitment.status = status
            commitment.updatedAt = .now
        }
        clearSelection()
    }

    func bulkUpdateCategory(_ category: CommitmentCategory, in commitments: [LocalCommitment]) {
        for commitment in commitments where selectedCommitments.contains(commitment.id) {
            commitment.category = category
            commitment.updatedAt = .now
        }
        clearSelection()
    }

    func bulkReassignEntity(_ entityName: String, entity: LocalEntity?, in commitments: [LocalCommitment]) {
        for commitment in commitments where selectedCommitments.contains(commitment.id) {
            commitment.entityName = entityName
            commitment.entity = entity
            commitment.updatedAt = .now
        }
        clearSelection()
    }
}
