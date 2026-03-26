import SwiftUI
import SwiftData

struct WatchLedgerView: View {
    @Query(
        filter: #Predicate<LocalCommitment> { $0.statusRaw == "pending" },
        sort: \LocalCommitment.createdAt,
        order: .reverse
    )
    private var pendingCommitments: [LocalCommitment]

    @Environment(\.modelContext) private var modelContext

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
                    syncStatusSection

                    if !overdueCommitments.isEmpty {
                        Section {
                            ForEach(overdueCommitments) { commitment in
                                WatchCommitmentRow(commitment: commitment)
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            fulfillCommitment(commitment)
                                        } label: {
                                            Label("Fulfill", systemImage: "checkmark.circle.fill")
                                        }
                                        .tint(.green)
                                    }
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
                                    .swipeActions(edge: .trailing) {
                                        Button {
                                            fulfillCommitment(commitment)
                                        } label: {
                                            Label("Fulfill", systemImage: "checkmark.circle.fill")
                                        }
                                        .tint(.green)
                                    }
                            }
                        }
                    }
                }
                .navigationTitle("Seddly")
            }
        }
    }

    @ViewBuilder
    private var syncStatusSection: some View {
        let syncService = WatchSyncService.shared
        Section {
            HStack(spacing: 6) {
                Circle()
                    .fill(syncStatusColor(syncService.syncStatus))
                    .frame(width: 8, height: 8)
                Text(syncStatusText(syncService.syncStatus))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let lastSync = syncService.lastSyncDate {
                    Text(lastSync, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func syncStatusColor(_ status: WatchSyncService.WatchSyncStatus) -> Color {
        switch status {
        case .synced: .green
        case .syncing: .orange
        case .unreachable: .red
        case .idle: .gray
        }
    }

    private func syncStatusText(_ status: WatchSyncService.WatchSyncStatus) -> String {
        switch status {
        case .synced: "Synced with iPhone"
        case .syncing: "Syncing..."
        case .unreachable: "iPhone unreachable"
        case .idle: "Waiting to connect"
        }
    }

    private func fulfillCommitment(_ commitment: LocalCommitment) {
        commitment.statusRaw = "completed"
        commitment.updatedAt = Date()
        try? modelContext.save()

        WatchSyncService.shared.sendFulfillment(commitmentID: commitment.id)
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
