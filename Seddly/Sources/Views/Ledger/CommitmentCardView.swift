import SwiftUI

struct CommitmentCardView: View {
    let commitment: LocalCommitment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(commitment.entityName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                ConfidenceBadgeView(score: commitment.confidenceScore)
            }

            Text(commitment.summary)
                .font(.body)
                .lineLimit(2)

            HStack {
                if let deadline = commitment.deadline {
                    DeadlineIndicatorView(deadline: deadline, urgency: commitment.urgencyLevel)
                }

                if let amount = commitment.dollarAmount {
                    Text(amount, format: .currency(code: "USD"))
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                Spacer()

                Text(commitment.status.label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch commitment.status {
        case .pending: .blue
        case .fulfilled: .green
        case .overdue: .red
        case .disputed: .orange
        case .dismissed: .gray
        }
    }
}
