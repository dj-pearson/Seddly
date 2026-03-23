import SwiftUI

struct CommitmentDetailView: View {
    @Bindable var commitment: LocalCommitment
    @State private var isEditing = false

    var body: some View {
        List {
            Section("Details") {
                if let entity = commitment.entity {
                    NavigationLink {
                        EntityProfileView(entity: entity)
                    } label: {
                        LabeledContent("Who") {
                            Text(commitment.entityName)
                        }
                    }
                } else {
                    LabeledContent("Who") {
                        if isEditing {
                            TextField("Entity", text: $commitment.entityName)
                                .multilineTextAlignment(.trailing)
                        } else {
                            Text(commitment.entityName)
                        }
                    }
                }

                LabeledContent("What") {
                    if isEditing {
                        TextField("Summary", text: $commitment.summary)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(commitment.summary)
                    }
                }

                if isEditing {
                    DatePicker(
                        "Deadline",
                        selection: Binding(
                            get: { commitment.deadline ?? .now },
                            set: { commitment.deadline = $0 }
                        ),
                        displayedComponents: .date
                    )
                } else if let deadline = commitment.deadline {
                    LabeledContent("Deadline") {
                        Text(deadline, style: .date)
                            .foregroundStyle(deadlineColor)
                    }
                }

                if let amount = commitment.dollarAmount {
                    LabeledContent("Amount") {
                        Text(amount, format: .currency(code: "USD"))
                    }
                }

                Picker("Status", selection: Binding(
                    get: { commitment.status },
                    set: {
                        commitment.status = $0
                        commitment.updatedAt = .now
                    }
                )) {
                    ForEach(CommitmentStatus.allCases) { status in
                        Text(status.label).tag(status)
                    }
                }
            }

            if let reasoning = commitment.aiReasoning {
                Section("Why Seddly Flagged This") {
                    HStack {
                        ConfidenceBadgeView(score: commitment.confidenceScore)
                        Text(reasoning)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !commitment.fullText.isEmpty && commitment.fullText != commitment.summary {
                Section("Original Text") {
                    Text(commitment.fullText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notes") {
                TextField("Add notes...", text: Binding(
                    get: { commitment.notes ?? "" },
                    set: { commitment.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(3...6)
            }

            if commitment.source != .manual {
                Section("Source") {
                    LabeledContent("Detected via") {
                        switch commitment.source {
                        case .auto: Text("Auto-scan")
                        case .shareSheet: Text("Share Sheet")
                        case .manual: Text("Manual")
                        }
                    }
                    if let date = commitment.screenshotDate {
                        LabeledContent("Screenshot taken") {
                            Text(date, style: .date)
                        }
                    }
                }
            }

            Section {
                ShareLink(
                    item: shareText,
                    subject: Text("Commitment from \(commitment.entityName)"),
                    message: Text(shareText)
                ) {
                    Label("Share as Text", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    commitment.status = .dismissed
                    commitment.updatedAt = .now
                } label: {
                    Label("Dismiss Commitment", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Commitment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                    if !isEditing {
                        commitment.updatedAt = .now
                    }
                }
            }
        }
    }

    private var deadlineColor: Color {
        switch commitment.urgencyLevel {
        case .overdue: .red
        case .approaching: .yellow
        case .safe: .green
        case .none: .secondary
        }
    }

    private var shareText: String {
        var text = "Commitment from \(commitment.entityName):\n\(commitment.summary)"
        if let deadline = commitment.deadline {
            text += "\nDeadline: \(deadline.formatted(date: .long, time: .omitted))"
        }
        if let amount = commitment.dollarAmount {
            text += "\nAmount: $\(amount)"
        }
        text += "\nStatus: \(commitment.status.label)"
        if let notes = commitment.notes, !notes.isEmpty {
            text += "\nNotes: \(notes)"
        }
        return text
    }
}
