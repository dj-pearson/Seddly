import SwiftUI
import SwiftData

struct IPadLedgerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SubscriptionService.self) private var subscriptionService
    @Query(sort: \LocalCommitment.createdAt, order: .reverse) private var commitments: [LocalCommitment]
    @State private var viewModel = LedgerViewModel()
    @State private var selectedCommitment: LocalCommitment?
    @State private var showingManualEntry = false
    @State private var showingFilter = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

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
