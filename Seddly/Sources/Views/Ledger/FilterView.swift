import SwiftUI
import SwiftData

struct FilterView: View {
    @Binding var selectedStatus: CommitmentStatus?
    @Binding var selectedEntityName: String?
    @Binding var hasDeadlineOnly: Bool
    @Binding var dateRangeStart: Date?
    @Binding var dateRangeEnd: Date?
    @Binding var selectedCategory: CommitmentCategory?
    @Binding var amountMin: Double?
    @Binding var amountMax: Double?
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LocalEntity.name) private var entities: [LocalEntity]
    @ScaledMetric(relativeTo: .caption) private var statusDotSize: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var categoryIconWidth: CGFloat = 20

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
                                    .frame(width: statusDotSize, height: statusDotSize)
                                    .accessibilityLabel("\(status.label) status")
                                filterRow(label: status.label, isSelected: selectedStatus == status)
                            }
                        }
                        .foregroundStyle(.primary)
                        .accessibilityLabel("Filter by \(status.label)\(selectedStatus == status ? ", selected" : "")")
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

                Section("Category") {
                    Button {
                        selectedCategory = nil
                    } label: {
                        filterRow(label: "All", isSelected: selectedCategory == nil)
                    }
                    .foregroundStyle(.primary)

                    ForEach(CommitmentCategory.allCases) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            HStack {
                                Image(systemName: category.icon)
                                    .frame(width: categoryIconWidth)
                                filterRow(label: category.label, isSelected: selectedCategory == category)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Section("Deadline") {
                    Toggle("Has deadline only", isOn: $hasDeadlineOnly)
                }

                Section("Dollar Amount") {
                    Toggle("Filter by amount", isOn: Binding(
                        get: { amountMin != nil || amountMax != nil },
                        set: {
                            if $0 {
                                amountMin = 0
                                amountMax = nil
                            } else {
                                amountMin = nil
                                amountMax = nil
                            }
                        }
                    ))

                    if amountMin != nil {
                        HStack {
                            Text("Min $")
                            TextField("0", value: $amountMin, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                            Text("Max $")
                            TextField("Any", value: $amountMax, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                        .font(.subheadline)

                        if let min = amountMin, let max = amountMax, min > max {
                            Text("Min amount must be less than or equal to max amount")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
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
                        selectedCategory = nil
                        hasDeadlineOnly = false
                        dateRangeStart = nil
                        dateRangeEnd = nil
                        amountMin = nil
                        amountMax = nil
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
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
