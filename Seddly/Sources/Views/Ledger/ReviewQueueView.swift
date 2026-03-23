import SwiftUI
import SwiftData

struct ReviewQueueView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<LocalCommitment> { $0.needsAIProcessing == true },
        sort: \LocalCommitment.createdAt,
        order: .reverse
    )
    private var pendingReview: [LocalCommitment]

    var body: some View {
        NavigationStack {
            Group {
                if pendingReview.isEmpty {
                    ContentUnavailableView(
                        "All Caught Up",
                        systemImage: "checkmark.circle",
                        description: Text("No commitments need your review right now.")
                    )
                } else {
                    List {
                        Section {
                            Text("These items need your review. Seddly detected potential commitments but isn't confident enough to add them automatically.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(pendingReview) { commitment in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(commitment.entityName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    ConfidenceBadgeView(score: commitment.confidenceScore)
                                }

                                Text(commitment.summary)
                                    .font(.body)

                                if let reasoning = commitment.aiReasoning {
                                    Text(reasoning)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                HStack {
                                    Button {
                                        commitment.needsAIProcessing = false
                                        commitment.updatedAt = .now
                                    } label: {
                                        Label("Keep", systemImage: "checkmark")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)

                                    Button {
                                        commitment.status = .dismissed
                                        commitment.needsAIProcessing = false
                                        commitment.updatedAt = .now
                                    } label: {
                                        Label("Dismiss", systemImage: "xmark")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Review Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
