import SwiftUI

struct AITextReviewView: View {
    let extractedText: String
    let onApprove: () -> Void
    let onEdit: (String) -> Void
    let onSkip: () -> Void

    @State private var editableText: String
    @State private var isEditing = false

    init(
        extractedText: String,
        onApprove: @escaping () -> Void,
        onEdit: @escaping (String) -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.extractedText = extractedText
        self.onApprove = onApprove
        self.onEdit = onEdit
        self.onSkip = onSkip
        self._editableText = State(initialValue: extractedText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Review Before Analysis", systemImage: "eye")
                        .font(.headline)

                    Text("Seddly wants to analyze this text for commitments. Review what will be sent:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                GroupBox {
                    if isEditing {
                        TextEditor(text: $editableText)
                            .frame(minHeight: 150)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        ScrollView {
                            Text(editableText)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 150, maxHeight: 300)
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Label("Only this text is sent — never the screenshot image.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("No name, email, or device ID is attached.", systemImage: "person.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        if editableText != extractedText {
                            onEdit(editableText)
                        } else {
                            onApprove()
                        }
                    } label: {
                        Text("Approve & Analyze")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    HStack(spacing: 16) {
                        Button {
                            isEditing.toggle()
                        } label: {
                            Label(isEditing ? "Done Editing" : "Edit Text", systemImage: "pencil")
                        }

                        Button(role: .cancel) {
                            onSkip()
                        } label: {
                            Text("Skip")
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
            }
            .navigationTitle("AI Text Review")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AITextReviewView(
        extractedText: "Hey, I'll have the AC fixed by next Friday. The repair should be free since it's under warranty.",
        onApprove: {},
        onEdit: { _ in },
        onSkip: {}
    )
}
