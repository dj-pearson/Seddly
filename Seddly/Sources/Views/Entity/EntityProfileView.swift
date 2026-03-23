import SwiftUI

struct EntityProfileView: View {
    let entity: LocalEntity
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var disputeSummary: String?
    @State private var isGeneratingSummary = false
    @State private var showingSummary = false

    var body: some View {
        List {
            Section {
                HStack {
                    StatView(title: "Total", value: "\(entity.totalCommitments)")
                    Divider()
                    StatView(title: "Fulfilled", value: "\(entity.fulfilledCount)")
                    Divider()
                    StatView(title: "Overdue", value: "\(entity.overdueCount)")
                    Divider()
                    StatView(
                        title: "Rate",
                        value: entity.fulfillmentRate.formatted(.percent.precision(.fractionLength(0)))
                    )
                }
                .padding(.vertical, 8)

                if let avgDays = averageFulfillmentDays {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Average fulfillment: \(avgDays) days")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if subscriptionService.currentTier >= .proPlus {
                Section {
                    Button {
                        generateDisputeSummary()
                    } label: {
                        HStack {
                            Label("Generate Dispute Summary", systemImage: "doc.text")
                            Spacer()
                            if isGeneratingSummary {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isGeneratingSummary || entity.commitments.isEmpty)
                }
            }

            Section("Timeline") {
                ForEach(entity.commitments.sorted { $0.createdAt > $1.createdAt }) { commitment in
                    NavigationLink(value: commitment) {
                        HStack(spacing: 12) {
                            // Timeline node
                            VStack {
                                Circle()
                                    .fill(nodeColor(for: commitment))
                                    .frame(width: 12, height: 12)
                            }
                            .frame(width: 12)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(commitment.summary)
                                    .font(.subheadline)
                                    .lineLimit(2)

                                HStack {
                                    Text(commitment.createdAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if let deadline = commitment.deadline {
                                        Text("Due: \(deadline, style: .date)")
                                            .font(.caption)
                                            .foregroundStyle(commitment.isOverdue ? .red : .secondary)
                                    }
                                }

                                Text(commitment.status.label)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(nodeColor(for: commitment))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(entity.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: LocalCommitment.self) { commitment in
            CommitmentDetailView(commitment: commitment)
        }
        .sheet(isPresented: $showingSummary) {
            if let disputeSummary {
                DisputeSummaryView(
                    entityName: entity.name,
                    summary: disputeSummary
                )
            }
        }
    }

    private var averageFulfillmentDays: Int? {
        let fulfilled = entity.commitments.filter { $0.status == .fulfilled }
        guard !fulfilled.isEmpty else { return nil }

        let totalDays = fulfilled.reduce(0) { sum, commitment in
            let days = Calendar.current.dateComponents(
                [.day],
                from: commitment.createdAt,
                to: commitment.updatedAt
            ).day ?? 0
            return sum + days
        }

        return totalDays / fulfilled.count
    }

    private func nodeColor(for commitment: LocalCommitment) -> Color {
        switch commitment.status {
        case .pending: .blue
        case .fulfilled: .green
        case .overdue: .red
        case .disputed: .orange
        case .dismissed: .gray
        }
    }

    private func generateDisputeSummary() {
        isGeneratingSummary = true

        Task {
            // In production, this calls the generate-dispute-summary Edge Function
            // For now, generate a local summary
            var summary = "Timeline of commitments from \(entity.name):\n\n"

            for commitment in entity.commitments.sorted(by: { $0.createdAt < $1.createdAt }) {
                let dateStr = commitment.createdAt.formatted(date: .long, time: .omitted)
                summary += "\(dateStr) — \(commitment.summary)"

                if let deadline = commitment.deadline {
                    summary += " (Due: \(deadline.formatted(date: .long, time: .omitted)))"
                }

                if let amount = commitment.dollarAmount {
                    summary += " — $\(amount)"
                }

                summary += "\nSource: \(commitment.source == .auto ? "screenshot" : commitment.source == .shareSheet ? "share sheet" : "manual entry")"
                summary += "\nStatus: \(commitment.status.label)\n\n"
            }

            summary += "Summary: \(entity.fulfilledCount) of \(entity.totalCommitments) commitments fulfilled. \(entity.overdueCount) overdue."

            disputeSummary = summary
            isGeneratingSummary = false
            showingSummary = true
        }
    }
}

private struct StatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
