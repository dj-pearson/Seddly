import SwiftUI
import SwiftData

struct LedgerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalCommitment.createdAt, order: .reverse) private var commitments: [LocalCommitment]
    @State private var viewModel = LedgerViewModel()
    @State private var showingManualEntry = false

    var body: some View {
        NavigationStack {
            Group {
                if commitments.isEmpty {
                    EmptyLedgerView()
                } else {
                    commitmentList
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
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $viewModel.sortOrder) {
                            ForEach(LedgerViewModel.SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search commitments")
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView()
            }
        }
    }

    private var commitmentList: some View {
        List {
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
}

#Preview {
    LedgerView()
        .modelContainer(for: [LocalCommitment.self, LocalEntity.self, ProcessingQueue.self], inMemory: true)
}
