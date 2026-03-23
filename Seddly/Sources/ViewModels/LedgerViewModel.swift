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
    var searchText = ""

    var hasActiveFilters: Bool {
        filterStatus != nil || filterEntityName != nil || filterHasDeadlineOnly || filterDateStart != nil
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

    /// Filters commitments for free tier: only show last 30 days
    func applyFreeTierHistoryLimit(_ commitments: [LocalCommitment]) -> [LocalCommitment] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        return commitments.filter { $0.createdAt >= cutoff }
    }

    func fulfill(_ commitment: LocalCommitment) {
        commitment.status = .fulfilled
        commitment.updatedAt = .now
    }

    func dismiss(_ commitment: LocalCommitment) {
        commitment.status = .dismissed
        commitment.updatedAt = .now
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
