import SwiftUI
import SwiftData

struct IPadLedgerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(\.authService) private var authService
    @Query(sort: \LocalCommitment.createdAt, order: .reverse) private var commitments: [LocalCommitment]
    @State private var viewModel = LedgerViewModel()
    @State private var selectedCommitment: LocalCommitment?
    @State private var showingManualEntry = false
    @State private var showingFilter = false
    @State private var showingDismissConfirm = false
    @State private var showingFulfillConfirm = false
    @State private var pendingSwipeCommitment: LocalCommitment?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    private static let appGroupDefaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
    @AppStorage("isSignedIn", store: appGroupDefaults) private var isSignedIn = false

    private var visibleCommitments: [LocalCommitment] {
        viewModel.applyHistoryLimit(Array(commitments), tier: subscriptionService.currentTier)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } content: {
            commitmentList
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView()
        }
        .alert("Dismiss Commitment?", isPresented: $showingDismissConfirm) {
            Button("Dismiss", role: .destructive) {
                if let commitment = pendingSwipeCommitment {
                    viewModel.dismiss(commitment)
                }
                pendingSwipeCommitment = nil
            }
            Button("Cancel", role: .cancel) {
                pendingSwipeCommitment = nil
            }
        } message: {
            if let commitment = pendingSwipeCommitment {
                Text("\"\(commitment.summary)\" will be dismissed. You can undo this from the commitment detail view.")
            }
        }
        .alert("Mark as Fulfilled?", isPresented: $showingFulfillConfirm) {
            Button("Fulfill") {
                if let commitment = pendingSwipeCommitment {
                    viewModel.fulfill(commitment)
                }
                pendingSwipeCommitment = nil
            }
            Button("Cancel", role: .cancel) {
                pendingSwipeCommitment = nil
            }
        } message: {
            if let commitment = pendingSwipeCommitment {
                Text("\"\(commitment.summary)\" will be marked as fulfilled. You can undo this from the commitment detail view.")
            }
        }
        .sheet(isPresented: $showingFilter) {
            FilterView(
                selectedStatus: $viewModel.filterStatus,
                selectedEntityName: $viewModel.filterEntityName,
                hasDeadlineOnly: $viewModel.filterHasDeadlineOnly,
                dateRangeStart: $viewModel.filterDateStart,
                dateRangeEnd: $viewModel.filterDateEnd
            )
        }
    }

    // MARK: - Sidebar (entities + stats)

    @ViewBuilder
    private var sidebar: some View {
        let entities = Array(Set(visibleCommitments.compactMap(\.entity)))
            .sorted { $0.name < $1.name }

        List {
            Section("Overview") {
                Button {
                    viewModel.filterEntityName = nil
                } label: {
                    Label("All Commitments (\(visibleCommitments.count))", systemImage: "list.bullet.clipboard")
                }
                .foregroundStyle(.primary)

                let overdue = visibleCommitments.filter { $0.isOverdue }
                if !overdue.isEmpty {
                    Button {
                        viewModel.filterStatus = .overdue
                        viewModel.filterEntityName = nil
                    } label: {
                        Label {
                            Text("Overdue (\(overdue.count))")
                                .foregroundStyle(.red)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            Section("Entities") {
                ForEach(entities) { entity in
                    Button {
                        viewModel.filterEntityName = entity.name
                        viewModel.filterStatus = nil
                    } label: {
                        HStack {
                            Text(entity.name)
                            Spacer()
                            Text("\(entity.totalCommitments)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("Seddly")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingManualEntry = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Content (commitment list)

    private var commitmentList: some View {
        List(viewModel.sortedCommitments(visibleCommitments), selection: $selectedCommitment) { commitment in
            CommitmentCardView(commitment: commitment)
                .tag(commitment)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        pendingSwipeCommitment = commitment
                        showingDismissConfirm = true
                    } label: {
                        Label("Dismiss", systemImage: "xmark")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        pendingSwipeCommitment = commitment
                        showingFulfillConfirm = true
                    } label: {
                        Label("Fulfilled", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
        }
        .refreshable {
            await refreshLedger()
        }
        .navigationTitle(viewModel.filterEntityName ?? "All Commitments")
        .searchable(text: $viewModel.searchText, prompt: "Search commitments")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
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
    }

    // MARK: - Refresh

    private func refreshLedger() async {
        await StatusUpdateService.processAndUpdateBadge(in: modelContext)

        if subscriptionService.currentTier == .proPlus, isSignedIn {
            if let supabaseURLString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
               let supabaseURL = URL(string: supabaseURLString),
               let supabaseKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_KEY") as? String {
                let syncService = SyncService(supabaseURL: supabaseURL, supabaseKey: supabaseKey, authService: authService)
                try? await syncService.pullCommitments(context: modelContext)
                try? await syncService.syncCommitments(context: modelContext)
            }
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Detail pane

    @ViewBuilder
    private var detailPane: some View {
        if let commitment = selectedCommitment {
            CommitmentDetailView(commitment: commitment)
        } else {
            ContentUnavailableView(
                "Select a Commitment",
                systemImage: "doc.text",
                description: Text("Choose a commitment from the list to view its details.")
            )
        }
    }
}
