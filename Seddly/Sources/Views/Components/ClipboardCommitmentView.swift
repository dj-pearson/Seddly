import SwiftUI
import SwiftData

struct ClipboardCommitmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let text: String
    let confidenceScore: Int
    var onDismiss: () -> Void

    @State private var entityName = ""
    @State private var summary = ""
    @State private var deadline: Date?
    @State private var hasDeadline = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Detected from Clipboard") {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                }

                Section("Commitment Details") {
                    TextField("Who made this promise?", text: $entityName)
                    TextField("What did they promise?", text: $summary)
                    Toggle("Has Deadline", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Deadline", selection: Binding(
                            get: { deadline ?? .now.addingTimeInterval(86400 * 7) },
                            set: { deadline = $0 }
                        ), displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Add from Clipboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        onDismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveCommitment()
                        onDismiss()
                        dismiss()
                    }
                    .disabled(entityName.isEmpty || summary.isEmpty)
                }
            }
        }
    }

    private func saveCommitment() {
        let entityNameValue = entityName
        let entityDescriptor = FetchDescriptor<LocalEntity>(
            predicate: #Predicate { $0.name == entityNameValue }
        )
        let entity: LocalEntity
        if let existing = try? modelContext.fetch(entityDescriptor).first {
            entity = existing
        } else {
            entity = LocalEntity(name: entityName)
            modelContext.insert(entity)
        }

        let commitment = LocalCommitment(
            entityName: entityName,
            summary: summary,
            fullText: text,
            deadline: hasDeadline ? deadline : nil,
            status: .pending,
            confidenceScore: confidenceScore,
            source: .manual,
            needsAIProcessing: false
        )
        commitment.entity = entity
        modelContext.insert(commitment)
        try? modelContext.save()
    }
}
