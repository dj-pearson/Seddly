import SwiftUI
import SwiftData
import PhotosUI

struct ManualEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingEntities: [LocalEntity]
    @State private var viewModel = ManualEntryViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var attachedImage: UIImage?
    @State private var showingSuggestions = false

    private var filteredEntities: [LocalEntity] {
        guard !viewModel.entityName.isEmpty else { return [] }
        let query = viewModel.entityName.lowercased()
        return existingEntities.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Who made the commitment?") {
                    TextField("Person or company name", text: $viewModel.entityName)
                        .onChange(of: viewModel.entityName) {
                            showingSuggestions = !filteredEntities.isEmpty && !viewModel.entityName.isEmpty
                        }

                    if showingSuggestions {
                        ForEach(filteredEntities) { entity in
                            Button {
                                viewModel.entityName = entity.name
                                showingSuggestions = false
                            } label: {
                                HStack {
                                    Image(systemName: "person.circle")
                                        .foregroundStyle(.secondary)
                                    Text(entity.name)
                                    Spacer()
                                    Text("\(entity.totalCommitments) commitments")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
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

                Section("Screenshot (optional)") {
                    if let attachedImage {
                        Image(uiImage: attachedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button("Remove Screenshot", role: .destructive) {
                            self.attachedImage = nil
                            selectedPhoto = nil
                        }
                    } else {
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .screenshots
                        ) {
                            Label("Attach Screenshot", systemImage: "photo")
                        }
                    }
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
            .onChange(of: selectedPhoto) {
                Task {
                    if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                        attachedImage = UIImage(data: data)
                    }
                }
            }
        }
    }
}

#Preview {
    ManualEntryView()
        .modelContainer(for: [LocalCommitment.self, LocalEntity.self], inMemory: true)
}
