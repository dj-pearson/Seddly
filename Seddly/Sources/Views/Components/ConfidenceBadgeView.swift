import SwiftUI

struct ConfidenceBadgeView: View {
    let score: Int
    @ScaledMetric(relativeTo: .caption2) private var badgeSize: CGFloat = 24

    var body: some View {
        if score > 0 {
            Text("\(score)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: badgeSize, height: badgeSize)
                .background(badgeColor)
                .clipShape(Circle())
                .accessibilityLabel("Confidence: \(confidenceLevel), \(score) out of 10")
        }
    }

    private var confidenceLevel: String {
        switch score {
        case 8...10: "High"
        case 5...7: "Medium"
        default: "Low"
        }
    }

    private var badgeColor: Color {
        switch score {
        case 8...10: .green
        case 5...7: .yellow
        default: .gray
        }
    }
}

#Preview {
    HStack {
        ConfidenceBadgeView(score: 9)
        ConfidenceBadgeView(score: 6)
        ConfidenceBadgeView(score: 3)
    }
}
