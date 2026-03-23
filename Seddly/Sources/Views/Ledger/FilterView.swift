import SwiftUI

struct FilterView: View {
    @Binding var selectedStatus: CommitmentStatus?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Filter by Status") {
                    Button {
                        selectedStatus = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("All")
                            Spacer()
                            if selectedStatus == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.accent)
                            }
                        }
                    }
                    .foregroundStyle(.primary)

                    ForEach(CommitmentStatus.allCases) { status in
                        Button {
                            selectedStatus = status
                            dismiss()
                        } label: {
                            HStack {
                                Circle()
                                    .fill(colorForStatus(status))
                                    .frame(width: 10, height: 10)
                                Text(status.label)
                                Spacer()
                                if selectedStatus == status {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.accent)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
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
