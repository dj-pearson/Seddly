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
    @State private var showingTemplates = false

    private var filteredEntities: [LocalEntity] {
        guard !viewModel.entityName.isEmpty else { return [] }
        let query = viewModel.entityName.lowercased()
        return existingEntities.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingTemplates = true
                    } label: {
                        Label("Use a Template", systemImage: "doc.on.clipboard")
                    }
                }

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

                Section("Category") {
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(CommitmentCategory.allCases) { category in
                            Label(category.label, systemImage: category.icon).tag(category)
                        }
                    }
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
            .sheet(isPresented: $showingTemplates) {
                TemplatePickerView { template in
                    viewModel.summary = template.defaultSummary
                    if let days = template.suggestedDeadlineDays {
                        viewModel.hasDeadline = true
                        viewModel.deadline = Calendar.current.date(
                            byAdding: .day, value: days, to: .now
                        )
                    }
                    showingTemplates = false
                }
            }
        }
    }
}

private struct TemplatePickerView: View {
    let onSelect: (CommitmentTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    private var groupedTemplates: [CommitmentCategory: [CommitmentTemplate]] {
        Dictionary(grouping: CommitmentTemplate.allTemplates, by: \.category)
    }

    private var sortedCategories: [CommitmentCategory] {
        groupedTemplates.keys.sorted { $0.label < $1.label }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedCategories, id: \.self) { category in
                    Section(category.label) {
                        ForEach(groupedTemplates[category] ?? []) { template in
                            Button {
                                onSelect(template)
                            } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.name)
                                            .font(.subheadline)
                                        Text(template.defaultSummary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let days = template.suggestedDeadlineDays {
                                            Text("Default deadline: \(days) days")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                } icon: {
                                    Image(systemName: template.icon)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ManualEntryView()
        .modelContainer(for: [LocalCommitment.self, LocalEntity.self], inMemory: true)
}
