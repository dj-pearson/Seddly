import SwiftUI
import SwiftData

struct ReviewQueueView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    private static let appGroupDefaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
    @AppStorage("approvedExtractionCount", store: appGroupDefaults) private var approvedExtractionCount = 0
    @AppStorage("autoAnalyze", store: appGroupDefaults) private var autoAnalyze = false
    @Query(
        filter: #Predicate<LocalCommitment> { $0.needsAIProcessing == true },
        sort: \LocalCommitment.createdAt,
        order: .reverse
    )
    private var pendingReview: [LocalCommitment]
    @State private var searchText = ""

    private var filteredReview: [LocalCommitment] {
        guard !searchText.isEmpty else { return pendingReview }
        return pendingReview.filter {
            $0.entityName.localizedCaseInsensitiveContains(searchText) ||
            $0.summary.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if pendingReview.isEmpty {
                    ContentUnavailableView(
                        "All Caught Up",
                        systemImage: "checkmark.circle",
                        description: Text("No commitments need your review right now.")
                    )
                } else if filteredReview.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        Section {
                            Text("These items need your review. Seddly detected potential commitments but isn't confident enough to add them automatically.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(filteredReview) { commitment in
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
                                        approvedExtractionCount += 1
                                        ClassifierFeedbackService.recordAutoDetection()
                                        // Auto-enable auto-analyze after threshold
                                        if approvedExtractionCount >= AppConstants.autoApproveAfterCount && !autoAnalyze {
                                            autoAnalyze = true
                                        }
                                    } label: {
                                        Label("Keep", systemImage: "checkmark")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)

                                    Button {
                                        commitment.status = .dismissed
                                        commitment.needsAIProcessing = false
                                        commitment.updatedAt = .now
                                        ClassifierFeedbackService.recordDismissal()
                                        WatchSyncService.shared.sendCommitmentUpdate(
                                            id: commitment.id, action: "updated",
                                            entityName: commitment.entityName, summary: commitment.summary,
                                            statusRaw: commitment.statusRaw
                                        )
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
            .searchable(text: $searchText, prompt: "Search by name or summary")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
