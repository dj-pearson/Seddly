import SwiftUI
import SwiftData

struct PrivacyAuditView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PrivacyAuditEntry.timestamp, order: .reverse)
    private var entries: [PrivacyAuditEntry]

    @State private var exportText: String?
    @State private var showExportSheet = false

    private var totalCharsSent: Int {
        entries.reduce(0) { $0 + $1.textLengthSent }
    }

    private var countsByType: [PrivacyAuditEntry.EventType: Int] {
        var counts: [PrivacyAuditEntry.EventType: Int] = [:]
        for entry in entries {
            counts[entry.eventType, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        List {
            summarySection
            breakdownSection
            logSection
        }
        .navigationTitle("Privacy Audit")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    generateExport()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(entries.isEmpty)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            if let exportText {
                ShareSheetView(text: exportText)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var summarySection: some View {
        Section("Summary") {
            if entries.isEmpty {
                Text("No data has left your device yet.")
                    .foregroundStyle(.secondary)
            } else {
                LabeledContent("Total transmissions", value: "\(entries.count)")
                LabeledContent("Characters sent off-device", value: "\(totalCharsSent)")
                if let first = entries.last?.timestamp {
                    LabeledContent("First transmission", value: first.formatted(date: .abbreviated, time: .shortened))
                }
                if let last = entries.first?.timestamp {
                    LabeledContent("Most recent", value: last.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
    }

    @ViewBuilder
    private var breakdownSection: some View {
        if !entries.isEmpty {
            Section("By Type") {
                ForEach(PrivacyAuditEntry.EventType.allCases, id: \.rawValue) { type in
                    let count = countsByType[type] ?? 0
                    if count > 0 {
                        Label {
                            HStack {
                                Text(type.label)
                                Spacer()
                                Text("\(count)")
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: type.icon)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var logSection: some View {
        if !entries.isEmpty {
            Section("Detailed Log") {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: entry.eventType.icon)
                                .foregroundStyle(.secondary)
                            Text(entry.eventType.label)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.dataSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Destination: \(entry.destination)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Export

    private func generateExport() {
        let service = PrivacyAuditService()
        Task {
            if let text = try? await service.exportReport(context: modelContext) {
                exportText = text
                showExportSheet = true
            }
        }
    }
}

private struct ShareSheetView: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        PrivacyAuditView()
    }
    .modelContainer(for: [PrivacyAuditEntry.self], inMemory: true)
}
