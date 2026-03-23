import SwiftUI

struct ConfidenceBadgeView: View {
    let score: Int

    var body: some View {
        if score > 0 {
            Text("\(score)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(badgeColor)
                .clipShape(Circle())
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
