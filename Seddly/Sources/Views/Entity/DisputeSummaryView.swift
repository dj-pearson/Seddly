import SwiftUI

struct DisputeSummaryView: View {
    let entityName: String
    let summary: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Dispute Summary")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Generated for: \(entityName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Divider()

                    Text(summary)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                .padding()
            }
            .navigationTitle("Dispute Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: summary) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
