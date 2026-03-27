import SwiftUI
import SwiftData

struct BackfillView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var selectedRange: BackfillRange = .thirtyDays
    @State private var isProcessing = false
    @State private var progress = BackfillProgress()
    @State private var isComplete = false

    var onComplete: () -> Void

    enum BackfillRange: String, CaseIterable {
        case sevenDays = "Last 7 days"
        case thirtyDays = "Last 30 days"
        case ninetyDays = "Last 90 days"
        case allTime = "All screenshots"

        var date: Date? {
            switch self {
            case .sevenDays: Calendar.current.date(byAdding: .day, value: -7, to: .now)
            case .thirtyDays: Calendar.current.date(byAdding: .day, value: -30, to: .now)
            case .ninetyDays: Calendar.current.date(byAdding: .day, value: -90, to: .now)
            case .allTime: nil
            }
        }
    }

    struct BackfillProgress {
        var screenshotsFound = 0
        var screenshotsProcessed = 0
        var commitmentsDetected = 0
        var conversationGroups = 0
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if isComplete {
                completeView
            } else if isProcessing {
                processingView
            } else {
                selectionView
            }

            Spacer()
        }
        .padding()
    }

    private var selectionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.accent)

            Text("Scan Existing Screenshots")
                .font(.title2)
                .fontWeight(.bold)

            Text("Want to check your existing screenshots for commitments people have already made?")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(BackfillRange.allCases, id: \.self) { range in
                    Button {
                        selectedRange = range
                    } label: {
                        HStack {
                            Text(range.rawValue)
                            Spacer()
                            if selectedRange == range {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.accent)
                            }
                        }
                        .padding()
                        .background(selectedRange == range ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                startBackfill()
            } label: {
                Text("Start Scanning")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Skip") {
                onComplete()
            }
            .foregroundStyle(.secondary)
        }
    }

    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Scanning...")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                Text("\(progress.screenshotsFound) screenshots found")
                    .foregroundStyle(.secondary)
                if progress.conversationGroups > 0 {
                    Text("\(progress.conversationGroups) conversation thread\(progress.conversationGroups == 1 ? "" : "s") detected")
                        .foregroundStyle(.secondary)
                }
                Text("\(progress.screenshotsProcessed) processed")
                    .foregroundStyle(.secondary)
                Text("\(progress.commitmentsDetected) potential commitments detected")
                    .fontWeight(.medium)
                    .foregroundStyle(.accent)
            }
            .font(.subheadline)
        }
    }

    private var completeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Scan Complete")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                Text("\(progress.screenshotsProcessed) screenshots scanned")
                    .foregroundStyle(.secondary)

                if progress.commitmentsDetected > 0 {
                    Text("\(progress.commitmentsDetected) commitments found!")
                        .fontWeight(.semibold)
                        .foregroundStyle(.accent)
                } else {
                    Text("No commitments detected yet.")
                        .foregroundStyle(.secondary)
                    Text("Take a screenshot of a promise, or add one manually.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)

            Button {
                onComplete()
            } label: {
                Text("View Ledger")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func startBackfill() {
        isProcessing = true

        Task {
            let screenshotService = ScreenshotService()
            let assets = await screenshotService.fetchNewScreenshots(since: selectedRange.date)
            progress.screenshotsFound = assets.count

            // Smart grouping: cluster related screenshots from the same conversation
            let smartBackfill = SmartBackfillService()
            let groups = await smartBackfill.groupRelatedScreenshots(assets: assets)
            progress.conversationGroups = groups.filter { $0.assets.count > 1 }.count

            // Process using standard pipeline (groups' combined text gives better context)
            let processingService = ScreenshotProcessingService()
            let result = await processingService.processNewScreenshots(
                since: selectedRange.date,
                context: modelContext,
                aiEndpoint: nil, // Backfill uses on-device only for speed
                subscriptionTier: subscriptionService.currentTier
            )

            progress.screenshotsProcessed = result.screenshotsProcessed
            progress.commitmentsDetected = result.commitmentsDetected
            isComplete = true
            isProcessing = false

            if progress.commitmentsDetected > 0 {
                (UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard).set(true, forKey: "showBackfillReviewBanner")
            }
        }
    }
}
