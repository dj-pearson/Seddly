import SwiftUI
import SwiftData

struct DataExportView: View {
    @Query private var commitments: [LocalCommitment]
    @State private var exportedText: String?
    @State private var selectedFormat: DataExportService.ExportFormat = .csv

    var body: some View {
        List {
            Section("Format") {
                Picker("Export format", selection: $selectedFormat) {
                    Text("CSV").tag(DataExportService.ExportFormat.csv)
                    Text("JSON").tag(DataExportService.ExportFormat.json)
                }
                .pickerStyle(.segmented)
            }

            Section("Data") {
                LabeledContent("Commitments", value: "\(commitments.count)")
            }

            Section {
                Button {
                    exportedText = DataExportService.exportAll(
                        commitments: commitments,
                        format: selectedFormat
                    )
                } label: {
                    Label("Generate Export", systemImage: "square.and.arrow.up")
                }

                if let exportedText {
                    ShareLink(
                        item: exportedText,
                        subject: Text("Seddly Export"),
                        message: Text("Exported \(commitments.count) commitments from Seddly")
                    ) {
                        Label(
                            "Share \(selectedFormat == .csv ? "CSV" : "JSON")",
                            systemImage: "paperplane"
                        )
                    }
                }
            }

            if let exportedText {
                Section("Preview") {
                    ScrollView(.horizontal) {
                        Text(String(exportedText.prefix(500)))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}
