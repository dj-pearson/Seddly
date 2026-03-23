import SwiftUI
import SwiftData

@Observable
final class LedgerViewModel {
    var sortOrder: SortOrder = .deadline
    var filterStatus: CommitmentStatus?
    var searchText = ""

    enum SortOrder: String, CaseIterable {
        case deadline = "Deadline"
        case entity = "Entity"
        case dateAdded = "Date Added"
        case status = "Status"
    }

    func sortedCommitments(_ commitments: [LocalCommitment]) -> [LocalCommitment] {
        var filtered = commitments

        if let filterStatus {
            filtered = filtered.filter { $0.status == filterStatus }
        }

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

    func fulfill(_ commitment: LocalCommitment) {
        commitment.status = .fulfilled
        commitment.updatedAt = .now
    }

    func dismiss(_ commitment: LocalCommitment) {
        commitment.status = .dismissed
        commitment.updatedAt = .now
    }
}
