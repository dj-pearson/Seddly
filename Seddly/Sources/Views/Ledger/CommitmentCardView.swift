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

                sourceIcon

                Spacer()

                ConfidenceBadgeView(score: commitment.confidenceScore)
            }

            Text(commitment.summary)
                .font(.body)
                .lineLimit(2)

            // AI reasoning preview (tap to see full detail)
            if let reasoning = commitment.aiReasoning, commitment.source == .auto {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                    Text(reasoning)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .foregroundStyle(.tertiary)
            }

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

                if commitment.category != .uncategorized {
                    Label(commitment.category.label, systemImage: commitment.category.icon)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                if let customStatus = commitment.customStatusLabel {
                    Text(customStatus)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.purple.opacity(0.1))
                        .foregroundStyle(.purple)
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

    @ViewBuilder
    private var sourceIcon: some View {
        switch commitment.source {
        case .auto:
            Image(systemName: "camera.viewfinder")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        case .shareSheet:
            Image(systemName: "square.and.arrow.up")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        case .manual:
            Image(systemName: "pencil")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
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
