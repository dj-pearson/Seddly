import SwiftUI

struct DeadlineIndicatorView: View {
    let deadline: Date
    let urgency: LocalCommitment.UrgencyLevel
    @ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = 12
    @ScaledMetric(relativeTo: .caption) private var spacing: CGFloat = 4

    var body: some View {
        HStack(spacing: spacing) {
            Image(systemName: "clock")
                .font(.caption2)
                .frame(width: iconSize, height: iconSize)
            Text(deadline, style: .date)
                .font(.caption)
        }
        .foregroundStyle(urgencyColor)
        .accessibilityLabel("Deadline: \(deadline.formatted(date: .abbreviated, time: .omitted)), \(urgencyText)")
    }

    private var urgencyText: String {
        switch urgency {
        case .overdue: "Overdue"
        case .approaching: "Approaching deadline"
        case .safe: "On track"
        case .none: "No urgency"
        }
    }

    private var urgencyColor: Color {
        switch urgency {
        case .overdue: .red
        case .approaching: .yellow
        case .safe: .green
        case .none: .secondary
        }
    }
}
