import SwiftUI
import UIKit

struct DisputeSummaryView: View {
    let entityName: String
    let summary: String
    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL?
    @State private var showShareSheet = false

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

                    Text(Date.now.formatted(date: .long, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)

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
                ToolbarItemGroup(placement: .primaryAction) {
                    ShareLink(item: summary) {
                        Label("Share Text", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        generateAndSharePDF()
                    } label: {
                        Label("Export PDF", systemImage: "doc.richtext")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let pdfURL {
                    PDFShareSheet(url: pdfURL)
                }
            }
        }
    }

    private func generateAndSharePDF() {
        let pdfData = generatePDF()
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Seddly-Dispute-\(entityName.replacingOccurrences(of: " ", with: "-")).pdf")

        do {
            try pdfData.write(to: tempURL)
            pdfURL = tempURL
            showShareSheet = true
        } catch {
            // PDF write failed
        }
    }

    private func generatePDF() -> Data {
        let pageWidth: CGFloat = 612 // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            context.beginPage()

            var yPosition: CGFloat = margin

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.label
            ]
            let title = "Dispute Summary — \(entityName)"
            let titleRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 30)
            title.draw(in: titleRect, withAttributes: titleAttrs)
            yPosition += 35

            // Date
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let dateStr = "Generated: \(Date.now.formatted(date: .long, time: .shortened)) by Seddly"
            let dateRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 16)
            dateStr.draw(in: dateRect, withAttributes: dateAttrs)
            yPosition += 25

            // Separator
            let separatorPath = UIBezierPath()
            separatorPath.move(to: CGPoint(x: margin, y: yPosition))
            separatorPath.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
            UIColor.separator.setStroke()
            separatorPath.stroke()
            yPosition += 15

            // Body text
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.label
            ]

            let paragraphs = summary.components(separatedBy: "\n")
            for paragraph in paragraphs {
                let text = paragraph as NSString
                let textSize = text.boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: bodyAttrs,
                    context: nil
                )

                // Check if we need a new page
                if yPosition + textSize.height > pageHeight - margin {
                    context.beginPage()
                    yPosition = margin
                }

                let textRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: textSize.height)
                text.draw(in: textRect, withAttributes: bodyAttrs)
                yPosition += textSize.height + 4
            }

            // Footer
            let footerY = pageHeight - margin + 10
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.tertiaryLabel
            ]
            let footer = "This document was generated by Seddly (seddly.com). It is a factual timeline of recorded commitments and does not constitute legal advice."
            let footerRect = CGRect(x: margin, y: footerY, width: contentWidth, height: 30)
            footer.draw(in: footerRect, withAttributes: footerAttrs)
        }
    }
}

private struct PDFShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
