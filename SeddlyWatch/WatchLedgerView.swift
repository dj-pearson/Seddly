import SwiftUI
import SwiftData

struct WatchLedgerView: View {
    @Query(
        filter: #Predicate<LocalCommitment> { $0.statusRaw == "pending" },
        sort: \LocalCommitment.createdAt,
        order: .reverse
    )
    private var pendingCommitments: [LocalCommitment]

    private var overdueCommitments: [LocalCommitment] {
        pendingCommitments.filter { $0.isOverdue }
    }

    private var upcomingCommitments: [LocalCommitment] {
        pendingCommitments
            .filter { !$0.isOverdue }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
    }

    var body: some View {
        NavigationStack {
            if pendingCommitments.isEmpty {
                ContentUnavailableView(
                    "No Commitments",
                    systemImage: "checkmark.circle",
                    description: Text("All clear! Open Seddly on your iPhone to add commitments.")
                )
            } else {
                List {
                    if !overdueCommitments.isEmpty {
                        Section {
                            ForEach(overdueCommitments) { commitment in
                                WatchCommitmentRow(commitment: commitment)
                            }
                        } header: {
                            Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                    }

                    if !upcomingCommitments.isEmpty {
                        Section("Upcoming") {
                            ForEach(upcomingCommitments.prefix(5)) { commitment in
                                WatchCommitmentRow(commitment: commitment)
                            }
                        }
                    }
                }
                .navigationTitle("Seddly")
            }
        }
    }
}

struct WatchCommitmentRow: View {
    let commitment: LocalCommitment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(commitment.entityName)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(commitment.summary)
                .font(.caption)
                .lineLimit(2)
            if let deadline = commitment.deadline {
                Text(deadline, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(commitment.isOverdue ? .red : .orange)
            }
        }
    }
}
