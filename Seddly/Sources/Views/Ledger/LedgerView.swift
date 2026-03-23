import SwiftUI
import SwiftData

struct LedgerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SubscriptionService.self) private var subscriptionService
    @Query(sort: \LocalCommitment.createdAt, order: .reverse) private var commitments: [LocalCommitment]
    @State private var viewModel = LedgerViewModel()
    @State private var showingManualEntry = false
    @State private var showingFilter = false
    @State private var showingUpgrade = false
    @State private var isProcessing = false
    @State private var newCommitmentsCount = 0

    private var activeCommitments: [LocalCommitment] {
        commitments.filter { $0.status != .dismissed && $0.status != .fulfilled }
    }

    var body: some View {
        NavigationStack {
            Group {
                if commitments.isEmpty {
                    EmptyLedgerView {
                        showingManualEntry = true
                    }
                } else {
                    commitmentList
                }
            }
            .navigationTitle("Seddly")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if subscriptionService.currentTier == .free &&
                            activeCommitments.count >= AppConstants.maxFreeCommitments {
                            showingUpgrade = true
                        } else {
                            showingManualEntry = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $viewModel.sortOrder) {
                            ForEach(LedgerViewModel.SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }

                    Button {
                        showingFilter.toggle()
                    } label: {
                        Image(systemName: viewModel.filterStatus != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search commitments")
            .overlay(alignment: .top) {
                if isProcessing {
                    processingBanner
                }
            }
            .overlay(alignment: .bottom) {
                if subscriptionService.currentTier == .free && activeCommitments.count >= AppConstants.maxFreeCommitments {
                    upgradeBanner
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView()
            }
            .sheet(isPresented: $showingFilter) {
                FilterView(selectedStatus: $viewModel.filterStatus)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingUpgrade) {
                NavigationStack {
                    SubscriptionView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showingUpgrade = false }
                            }
                        }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    processOnForeground()
                }
            }
        }
    }

    private var commitmentList: some View {
        List {
            if newCommitmentsCount > 0 {
                Section {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.accent)
                        Text("\(newCommitmentsCount) new commitment\(newCommitmentsCount == 1 ? "" : "s") detected")
                            .font(.subheadline)
                            .foregroundStyle(.accent)
                    }
                }
            }

            ForEach(viewModel.sortedCommitments(commitments)) { commitment in
                NavigationLink(value: commitment) {
                    CommitmentCardView(commitment: commitment)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.dismiss(commitment)
                    } label: {
                        Label("Dismiss", systemImage: "xmark")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        viewModel.fulfill(commitment)
                    } label: {
                        Label("Fulfilled", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
            }
        }
        .navigationDestination(for: LocalCommitment.self) { commitment in
            CommitmentDetailView(commitment: commitment)
        }
    }

    private var processingBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(.white)
            Text("Processing new screenshots...")
                .font(.caption)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.accent)
        .clipShape(Capsule())
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var upgradeBanner: some View {
        Button {
            showingUpgrade = true
        } label: {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                Text("You've reached the free limit (\(AppConstants.maxFreeCommitments) commitments). Upgrade to Pro for unlimited.")
                    .font(.caption)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding()
    }

    private func processOnForeground() {
        guard !isProcessing else { return }
        isProcessing = true

        Task {
            let processingService = ScreenshotProcessingService()
            let lastProcessed = UserDefaults(suiteName: AppConstants.appGroupIdentifier)?
                .object(forKey: "lastProcessedDate") as? Date

            let result = await processingService.processNewScreenshots(
                since: lastProcessed,
                context: modelContext,
                aiEndpoint: nil, // Will be configured with real endpoint
                subscriptionTier: subscriptionService.currentTier
            )

            withAnimation {
                newCommitmentsCount = result.commitmentsDetected
                isProcessing = false
            }

            // Clear the "new" badge after 5 seconds
            if newCommitmentsCount > 0 {
                try? await Task.sleep(for: .seconds(5))
                withAnimation { newCommitmentsCount = 0 }
            }
        }
    }
}

#Preview {
    LedgerView()
        .modelContainer(for: [LocalCommitment.self, LocalEntity.self, ProcessingQueue.self], inMemory: true)
        .environment(SubscriptionService())
}
