import SwiftUI

struct EscalationLetterView: View {
    let entity: LocalEntity
    @State private var selectedCategory: CommitmentCategory = .uncategorized
    @State private var senderName = ""
    @State private var generatedLetter: String?
    @State private var showNameWarning = false

    private var outstandingCount: Int {
        entity.commitments.filter {
            $0.status == .overdue || $0.status == .disputed || $0.status == .pending
        }.count
    }

    var body: some View {
        List {
            Section("Letter Type") {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(CommitmentCategory.allCases.filter { $0 != .uncategorized && $0 != .personal }) { category in
                        Label(category.label, systemImage: category.icon).tag(category)
                    }
                }
            }

            Section {
                TextField("Enter your name", text: $senderName)
                if senderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label("Your name will appear as the sender. Leave blank and \"[Your Name]\" will be used as a placeholder.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Your Name")
            }

            Section {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("\(outstandingCount) outstanding commitment\(outstandingCount == 1 ? "" : "s") from \(entity.name) will be included.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    if senderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        showNameWarning = true
                    } else {
                        generateLetter()
                    }
                } label: {
                    Label("Generate Letter", systemImage: "doc.text")
                }
                .disabled(outstandingCount == 0)
                .confirmationDialog("Missing Sender Name", isPresented: $showNameWarning, titleVisibility: .visible) {
                    Button("Generate Anyway") {
                        generateLetter()
                    }
                    Button("Enter Name", role: .cancel) {}
                } message: {
                    Text("Your letter will contain \"[Your Name]\" as a placeholder. Would you like to enter your name first?")
                }
            }

            if let letter = generatedLetter {
                Section("Preview") {
                    Text(letter)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }

                Section {
                    ShareLink(
                        item: letter,
                        subject: Text("Escalation Letter — \(entity.name)")
                    ) {
                        Label("Share Letter", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        UIPasteboard.general.string = letter
                    } label: {
                        Label("Copy to Clipboard", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .navigationTitle("Escalation Letter")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Auto-detect category from entity's most common commitment category
            let categories = entity.commitments.map(\.category)
            let counted = Dictionary(grouping: categories, by: \.self).mapValues(\.count)
            if let mostCommon = counted.max(by: { $0.value < $1.value })?.key,
               mostCommon != .uncategorized {
                selectedCategory = mostCommon
            } else {
                selectedCategory = .housing
            }
        }
    }

    private func generateLetter() {
        generatedLetter = EscalationTemplateService.generateLetter(
            for: entity,
            category: selectedCategory,
            senderName: senderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "[Your Name]" : senderName
        )
    }
}
