import SwiftUI
import SwiftData

struct FilterView: View {
    @Binding var selectedStatus: CommitmentStatus?
    @Binding var selectedEntityName: String?
    @Binding var hasDeadlineOnly: Bool
    @Binding var dateRangeStart: Date?
    @Binding var dateRangeEnd: Date?
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LocalEntity.name) private var entities: [LocalEntity]

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    Button {
                        selectedStatus = nil
                    } label: {
                        filterRow(label: "All", isSelected: selectedStatus == nil)
                    }
                    .foregroundStyle(.primary)

                    ForEach(CommitmentStatus.allCases) { status in
                        Button {
                            selectedStatus = status
                        } label: {
                            HStack {
                                Circle()
                                    .fill(colorForStatus(status))
                                    .frame(width: 10, height: 10)
                                filterRow(label: status.label, isSelected: selectedStatus == status)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Section("Entity") {
                    Button {
                        selectedEntityName = nil
                    } label: {
                        filterRow(label: "All", isSelected: selectedEntityName == nil)
                    }
                    .foregroundStyle(.primary)

                    ForEach(entities) { entity in
                        Button {
                            selectedEntityName = entity.name
                        } label: {
                            filterRow(
                                label: "\(entity.name) (\(entity.totalCommitments))",
                                isSelected: selectedEntityName == entity.name
                            )
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Section("Deadline") {
                    Toggle("Has deadline only", isOn: $hasDeadlineOnly)
                }

                Section("Date Range") {
                    Toggle("Filter by date", isOn: Binding(
                        get: { dateRangeStart != nil },
                        set: {
                            if $0 {
                                dateRangeStart = Calendar.current.date(byAdding: .month, value: -1, to: .now)
                                dateRangeEnd = .now
                            } else {
                                dateRangeStart = nil
                                dateRangeEnd = nil
                            }
                        }
                    ))

                    if let start = dateRangeStart {
                        DatePicker("From", selection: Binding(
                            get: { start },
                            set: { dateRangeStart = $0 }
                        ), displayedComponents: .date)

                        DatePicker("To", selection: Binding(
                            get: { dateRangeEnd ?? .now },
                            set: { dateRangeEnd = $0 }
                        ), displayedComponents: .date)
                    }
                }

                Section {
                    Button("Clear All Filters") {
                        selectedStatus = nil
                        selectedEntityName = nil
                        hasDeadlineOnly = false
                        dateRangeStart = nil
                        dateRangeEnd = nil
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func filterRow(label: String, isSelected: Bool) -> some View {
        HStack {
            Text(label)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.accent)
            }
        }
    }

    private func colorForStatus(_ status: CommitmentStatus) -> Color {
        switch status {
        case .pending: .blue
        case .fulfilled: .green
        case .overdue: .red
        case .disputed: .orange
        case .dismissed: .gray
        }
    }
}
