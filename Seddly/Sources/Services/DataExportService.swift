import Foundation
import SwiftData

struct DataExportService {
    enum ExportFormat {
        case csv
        case json
    }

    static func exportAll(commitments: [LocalCommitment], format: ExportFormat) -> String {
        switch format {
        case .csv: return exportCSV(commitments)
        case .json: return exportJSON(commitments)
        }
    }

    static func exportCSV(_ commitments: [LocalCommitment]) -> String {
        var csv = "ID,Entity,Summary,Deadline,Amount,Status,Confidence,Source,Category,Screenshot Date,Notes,Created,Updated\n"

        for c in commitments {
            let fields: [String] = [
                c.id.uuidString,
                escapeCSV(c.entityName),
                escapeCSV(c.summary),
                c.deadline?.ISO8601Format() ?? "",
                c.dollarAmount.map { "\($0)" } ?? "",
                c.status.label,
                "\(c.confidenceScore)",
                c.source.rawValue,
                c.categoryRaw ?? "uncategorized",
                c.screenshotDate?.ISO8601Format() ?? "",
                escapeCSV(c.notes ?? ""),
                c.createdAt.ISO8601Format(),
                c.updatedAt.ISO8601Format(),
            ]
            csv += fields.joined(separator: ",") + "\n"
        }

        return csv
    }

    static func exportJSON(_ commitments: [LocalCommitment]) -> String {
        struct ExportCommitment: Encodable {
            let id: String
            let entityName: String
            let summary: String
            let fullText: String
            let deadline: String?
            let dollarAmount: String?
            let status: String
            let confidence: Int
            let aiReasoning: String?
            let source: String
            let category: String
            let screenshotDate: String?
            let notes: String?
            let createdAt: String
            let updatedAt: String
        }

        let items = commitments.map { c in
            ExportCommitment(
                id: c.id.uuidString,
                entityName: c.entityName,
                summary: c.summary,
                fullText: c.fullText,
                deadline: c.deadline?.ISO8601Format(),
                dollarAmount: c.dollarAmount.map { "\($0)" },
                status: c.status.label,
                confidence: c.confidenceScore,
                aiReasoning: c.aiReasoning,
                source: c.source.rawValue,
                category: c.categoryRaw ?? "uncategorized",
                screenshotDate: c.screenshotDate?.ISO8601Format(),
                notes: c.notes,
                createdAt: c.createdAt.ISO8601Format(),
                updatedAt: c.updatedAt.ISO8601Format()
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(items),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    private static func escapeCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}
