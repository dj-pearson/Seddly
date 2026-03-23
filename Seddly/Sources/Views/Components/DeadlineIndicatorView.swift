import SwiftUI

struct DeadlineIndicatorView: View {
    let deadline: Date
    let urgency: LocalCommitment.UrgencyLevel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption2)
            Text(deadline, style: .date)
                .font(.caption)
        }
        .foregroundStyle(urgencyColor)
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
