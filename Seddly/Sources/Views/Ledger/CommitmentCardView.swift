import SwiftUI

struct CommitmentCardView: View {
    let commitment: LocalCommitment
    @ScaledMetric(relativeTo: .caption2) private var badgePadding: CGFloat = 6

    private var isNew: Bool {
        let lastViewed = UserDefaults.standard.object(forKey: "lastViewedDate") as? Date ?? .distantPast
        return commitment.createdAt > lastViewed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(commitment.entityName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                sourceIcon

                if isNew {
                    Text("New")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.accent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

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

                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.caption2)
                    Text(commitment.status.label)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.15))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var desc = "\(commitment.entityName): \(commitment.summary). Status: \(commitment.status.label)."
        if let deadline = commitment.deadline {
            desc += " Due \(deadline.formatted(date: .abbreviated, time: .omitted))."
        }
        if let amount = commitment.dollarAmount {
            desc += " Amount: \(amount) dollars."
        }
        if isNew { desc += " New." }
        return desc
    }

    private var statusIcon: String {
        switch commitment.status {
        case .pending: "clock"
        case .fulfilled: "checkmark.circle"
        case .overdue: "exclamationmark.triangle"
        case .disputed: "questionmark.circle"
        case .dismissed: "minus.circle"
        }
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
