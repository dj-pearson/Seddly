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
    @State private var showingReviewQueue = false
    @State private var isProcessing = false
    @State private var newCommitmentsCount = 0
    @State private var showingBulkAction = false

    private var visibleCommitments: [LocalCommitment] {
        if subscriptionService.currentTier == .free {
            return viewModel.applyFreeTierHistoryLimit(commitments)
        }
        return Array(commitments)
    }

    private var activeCommitments: [LocalCommitment] {
        visibleCommitments.filter { $0.status != .dismissed && $0.status != .fulfilled }
    }

    private var reviewQueueItems: [LocalCommitment] {
        commitments.filter { $0.needsAIProcessing || ($0.confidenceScore >= 4 && $0.confidenceScore <= 6 && $0.source == .auto) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleCommitments.isEmpty {
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
                    if viewModel.isSelecting {
                        Button("Done") {
                            viewModel.clearSelection()
                        }
                    } else {
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
                }
                ToolbarItem(placement: .secondaryAction) {
                    if !visibleCommitments.isEmpty {
                        Button(viewModel.isSelecting ? "Cancel" : "Select") {
                            if viewModel.isSelecting {
                                viewModel.clearSelection()
                            } else {
                                viewModel.isSelecting = true
                            }
                        }
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
                        Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
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
                VStack(spacing: 0) {
                    if !reviewQueueItems.isEmpty {
                        reviewQueueBanner
                    }
                    if subscriptionService.currentTier == .free && activeCommitments.count >= AppConstants.maxFreeCommitments {
                        upgradeBanner
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.isSelecting && !viewModel.selectedCommitments.isEmpty {
                    bulkActionBar
                }
            }
            .confirmationDialog("Bulk Action", isPresented: $showingBulkAction) {
                Menu("Set Status") {
                    ForEach(CommitmentStatus.allCases) { status in
                        Button(status.label) {
                            viewModel.bulkUpdateStatus(status, in: visibleCommitments)
                        }
                    }
                }
                Menu("Set Category") {
                    ForEach(CommitmentCategory.allCases) { category in
                        Button(category.label) {
                            viewModel.bulkUpdateCategory(category, in: visibleCommitments)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView()
            }
            .sheet(isPresented: $showingFilter) {
                FilterView(
                    selectedStatus: $viewModel.filterStatus,
                    selectedEntityName: $viewModel.filterEntityName,
                    hasDeadlineOnly: $viewModel.filterHasDeadlineOnly,
                    dateRangeStart: $viewModel.filterDateStart,
                    dateRangeEnd: $viewModel.filterDateEnd
                )
                .presentationDetents([.large])
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
            .sheet(isPresented: $showingReviewQueue) {
                ReviewQueueView()
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

            ForEach(viewModel.sortedCommitments(visibleCommitments)) { commitment in
                if viewModel.isSelecting {
                    Button {
                        viewModel.toggleSelection(for: commitment)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: viewModel.isSelected(commitment) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(viewModel.isSelected(commitment) ? .accent : .secondary)
                            CommitmentCardView(commitment: commitment)
                        }
                    }
                    .foregroundStyle(.primary)
                } else {
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

            if viewModel.isSelecting {
                Section {
                    HStack {
                        Button("Select All") {
                            viewModel.selectAll(viewModel.sortedCommitments(visibleCommitments))
                        }
                        .font(.caption)
                        Spacer()
                        Text("\(viewModel.selectedCommitments.count) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

    private var reviewQueueBanner: some View {
        Button {
            showingReviewQueue = true
        } label: {
            HStack {
                Image(systemName: "eye.circle.fill")
                    .foregroundStyle(.yellow)
                Text("\(reviewQueueItems.count) item\(reviewQueueItems.count == 1 ? "" : "s") to review")
                    .font(.caption)
                Spacer()
                Text("Review")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private var bulkActionBar: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.bulkUpdateStatus(.fulfilled, in: visibleCommitments)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle")
                    Text("Fulfill").font(.caption2)
                }
            }

            Button {
                viewModel.bulkUpdateStatus(.dismissed, in: visibleCommitments)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "xmark.circle")
                    Text("Dismiss").font(.caption2)
                }
            }

            Button {
                showingBulkAction = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "ellipsis.circle")
                    Text("More").font(.caption2)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var upgradeBanner: some View {
        Button {
            showingUpgrade = true
        } label: {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                Text("Free limit reached (\(AppConstants.maxFreeCommitments)). Upgrade to Pro for unlimited.")
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
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func processOnForeground() {
        // Free tier: no auto-scan
        guard subscriptionService.currentTier >= .pro else { return }
        guard !isProcessing else { return }
        isProcessing = true

        Task {
            let processingService = ScreenshotProcessingService()
            let lastProcessed = UserDefaults(suiteName: AppConstants.appGroupIdentifier)?
                .object(forKey: "lastProcessedDate") as? Date

            let result = await processingService.processNewScreenshots(
                since: lastProcessed,
                context: modelContext,
                aiEndpoint: nil,
                subscriptionTier: subscriptionService.currentTier
            )

            withAnimation {
                newCommitmentsCount = result.commitmentsDetected
                isProcessing = false
            }

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
