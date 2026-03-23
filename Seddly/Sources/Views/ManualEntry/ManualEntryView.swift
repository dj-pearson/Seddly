import SwiftUI

struct ManualEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ManualEntryViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Who made the commitment?") {
                    TextField("Person or company name", text: $viewModel.entityName)
                }

                Section("What did they promise?") {
                    TextField("Describe the commitment", text: $viewModel.summary, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Deadline") {
                    Toggle("Has a deadline", isOn: $viewModel.hasDeadline)
                    if viewModel.hasDeadline {
                        DatePicker(
                            "Due by",
                            selection: Binding(
                                get: { viewModel.deadline ?? .now },
                                set: { viewModel.deadline = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }

                Section("Amount (optional)") {
                    TextField("$0.00", text: $viewModel.dollarAmount)
                        .keyboardType(.decimalPad)
                }

                Section("Notes (optional)") {
                    TextField("Any additional context", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Add Commitment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        _ = viewModel.createCommitment(in: modelContext)
                        dismiss()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
    }
}

#Preview {
    ManualEntryView()
        .modelContainer(for: [LocalCommitment.self, LocalEntity.self], inMemory: true)
}
