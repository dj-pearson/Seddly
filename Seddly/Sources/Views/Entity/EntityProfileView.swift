import SwiftUI

struct EntityProfileView: View {
    let entity: LocalEntity

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
            }

            Section("Commitments") {
                ForEach(entity.commitments.sorted { $0.createdAt > $1.createdAt }) { commitment in
                    NavigationLink(value: commitment) {
                        CommitmentCardView(commitment: commitment)
                    }
                }
            }
        }
        .navigationTitle(entity.name)
        .navigationBarTitleDisplayMode(.inline)
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
