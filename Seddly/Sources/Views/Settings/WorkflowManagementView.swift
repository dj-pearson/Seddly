import SwiftUI
import SwiftData

struct WorkflowManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomWorkflow.createdAt) private var workflows: [CustomWorkflow]
    @State private var showingCreateSheet = false

    var body: some View {
        List {
            Section("Your Workflows") {
                if workflows.isEmpty {
                    Text("No custom workflows yet. The default status flow (Pending → Fulfilled / Overdue / Disputed / Dismissed) is always available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(workflows) { workflow in
                    NavigationLink {
                        WorkflowDetailView(workflow: workflow)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(workflow.name)
                                    .fontWeight(.medium)
                                if workflow.isDefault {
                                    Text("Default")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.accent.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            Text(workflow.steps.joined(separator: " → "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(workflows[index])
                    }
                }
            }

            Section("Presets") {
                ForEach(CustomWorkflow.presets, id: \.name) { preset in
                    Button {
                        let workflow = CustomWorkflow(name: preset.name, steps: preset.steps)
                        modelContext.insert(workflow)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .font(.subheadline)
                            Text(preset.steps.joined(separator: " → "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("Workflows")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateWorkflowView()
        }
    }
}

struct WorkflowDetailView: View {
    @Bindable var workflow: CustomWorkflow
    @State private var newStep = ""

    var body: some View {
        List {
            Section("Workflow Name") {
                TextField("Name", text: $workflow.name)
            }

            Section("Steps (in order)") {
                ForEach(Array(workflow.steps.enumerated()), id: \.offset) { index, step in
                    HStack {
                        Image(systemName: "\(index + 1).circle")
                            .foregroundStyle(.secondary)
                        Text(step)
                        if index < workflow.steps.count - 1 {
                            Spacer()
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .onMove { from, to in
                    workflow.steps.move(fromOffsets: from, toOffset: to)
                }
                .onDelete { offsets in
                    workflow.steps.remove(atOffsets: offsets)
                }

                HStack {
                    TextField("Add step...", text: $newStep)
                    Button {
                        guard !newStep.isEmpty else { return }
                        workflow.steps.append(newStep)
                        newStep = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newStep.isEmpty)
                }
            }
        }
        .navigationTitle(workflow.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CreateWorkflowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var steps: [String] = []
    @State private var newStep = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Workflow name", text: $name)
                }

                Section("Steps") {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack {
                            Image(systemName: "\(index + 1).circle")
                                .foregroundStyle(.secondary)
                            Text(step)
                        }
                    }
                    .onDelete { offsets in
                        steps.remove(atOffsets: offsets)
                    }

                    HStack {
                        TextField("Add step...", text: $newStep)
                        Button {
                            guard !newStep.isEmpty else { return }
                            steps.append(newStep)
                            newStep = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newStep.isEmpty)
                    }
                }
            }
            .navigationTitle("New Workflow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let workflow = CustomWorkflow(name: name, steps: steps)
                        modelContext.insert(workflow)
                        dismiss()
                    }
                    .disabled(name.isEmpty || steps.count < 2)
                }
            }
        }
    }
}
