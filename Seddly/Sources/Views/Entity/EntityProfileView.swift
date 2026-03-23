import SwiftUI

struct EntityProfileView: View {
    let entity: LocalEntity
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var disputeSummary: String?
    @State private var isGeneratingSummary = false
    @State private var showingSummary = false
    @State private var summaryError: String?

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

                // Accountability Score
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                            .frame(width: 50, height: 50)
                        Circle()
                            .trim(from: 0, to: Double(entity.accountabilityScore) / 100.0)
                            .stroke(scoreColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        Text(entity.accountabilityGrade)
                            .font(.title3.bold())
                            .foregroundStyle(scoreColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accountability Score")
                            .font(.subheadline.weight(.medium))
                        Text("\(entity.accountabilityScore)/100")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ShareLink(item: entity.shareableScoreCard) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)

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

                    NavigationLink {
                        EscalationLetterView(entity: entity)
                    } label: {
                        Label("Draft Escalation Letter", systemImage: "envelope.badge.person.crop")
                    }
                    .disabled(entity.commitments.isEmpty)
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

    private var scoreColor: Color {
        switch entity.accountabilityScore {
        case 80...100: .green
        case 60..<80: .yellow
        case 40..<60: .orange
        default: .red
        }
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
        summaryError = nil

        Task {
            let service = DisputeSummaryService(
                endpointURL: URL(string: "https://your-project.supabase.co/functions/v1/generate-dispute-summary")!
            )

            do {
                // Try AI-powered summary via Edge Function
                let summary = try await service.generateSummary(
                    entityName: entity.name,
                    commitments: entity.commitments,
                    context: modelContext
                )
                disputeSummary = summary
            } catch {
                // Fallback to local generation
                summaryError = error.localizedDescription
                disputeSummary = service.generateLocalSummary(
                    entityName: entity.name,
                    commitments: entity.commitments
                )
            }

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
