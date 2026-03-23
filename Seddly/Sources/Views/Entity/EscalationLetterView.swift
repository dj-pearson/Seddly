import SwiftUI

struct EscalationLetterView: View {
    let entity: LocalEntity
    @State private var selectedCategory: CommitmentCategory = .uncategorized
    @State private var senderName = ""
    @State private var generatedLetter: String?

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

            Section("Your Name") {
                TextField("Enter your name", text: $senderName)
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
                    generatedLetter = EscalationTemplateService.generateLetter(
                        for: entity,
                        category: selectedCategory,
                        senderName: senderName.isEmpty ? "[Your Name]" : senderName
                    )
                } label: {
                    Label("Generate Letter", systemImage: "doc.text")
                }
                .disabled(outstandingCount == 0)
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
                selectedCategory = .housing // Default
            }
        }
    }
}
