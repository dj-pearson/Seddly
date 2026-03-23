import Foundation
import SwiftData

actor PrivacyAuditService {
    func recordAIExtraction(
        textLength: Int,
        endpoint: URL,
        commitmentID: UUID? = nil,
        context: ModelContext
    ) {
        let entry = PrivacyAuditEntry(
            eventType: .aiExtraction,
            destination: endpoint.host ?? endpoint.absoluteString,
            dataSummary: "Sent \(textLength) characters of extracted OCR text for AI commitment analysis",
            textLengthSent: textLength,
            commitmentID: commitmentID
        )
        context.insert(entry)
        try? context.save()
    }

    func recordDisputeSummary(
        commitmentCount: Int,
        textLength: Int,
        endpoint: URL,
        context: ModelContext
    ) {
        let entry = PrivacyAuditEntry(
            eventType: .disputeSummary,
            destination: endpoint.host ?? endpoint.absoluteString,
            dataSummary: "Sent timeline data for \(commitmentCount) commitment(s) (\(textLength) chars) for dispute summary generation",
            textLengthSent: textLength,
            commitmentID: nil
        )
        context.insert(entry)
        try? context.save()
    }

    func recordCloudSync(
        commitmentCount: Int,
        context: ModelContext
    ) {
        let entry = PrivacyAuditEntry(
            eventType: .cloudSync,
            destination: "Supabase (Pro+ cloud backup)",
            dataSummary: "Synced \(commitmentCount) commitment(s) to cloud storage",
            textLengthSent: 0,
            commitmentID: nil
        )
        context.insert(entry)
        try? context.save()
    }

    func generateReport(context: ModelContext) throws -> PrivacyAuditReport {
        let descriptor = FetchDescriptor<PrivacyAuditEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let entries = try context.fetch(descriptor)

        let totalEvents = entries.count
        let totalCharsSent = entries.reduce(0) { $0 + $1.textLengthSent }

        var countsByType: [PrivacyAuditEntry.EventType: Int] = [:]
        for entry in entries {
            countsByType[entry.eventType, default: 0] += 1
        }

        let firstEvent = entries.last?.timestamp
        let lastEvent = entries.first?.timestamp

        return PrivacyAuditReport(
            totalEvents: totalEvents,
            totalCharactersSent: totalCharsSent,
            countsByType: countsByType,
            firstEventDate: firstEvent,
            lastEventDate: lastEvent,
            entries: entries
        )
    }

    func exportReport(context: ModelContext) throws -> String {
        let report = try generateReport(context: context)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var output = "SEDDLY PRIVACY AUDIT REPORT\n"
        output += "Generated: \(dateFormatter.string(from: .now))\n"
        output += String(repeating: "=", count: 40) + "\n\n"

        output += "SUMMARY\n"
        output += "Total data transmissions: \(report.totalEvents)\n"
        output += "Total characters sent off-device: \(report.totalCharactersSent)\n"

        if let first = report.firstEventDate {
            output += "First transmission: \(dateFormatter.string(from: first))\n"
        }
        if let last = report.lastEventDate {
            output += "Most recent: \(dateFormatter.string(from: last))\n"
        }

        output += "\nBREAKDOWN BY TYPE\n"
        for type in PrivacyAuditEntry.EventType.allCases {
            let count = report.countsByType[type] ?? 0
            output += "  \(type.label): \(count)\n"
        }

        output += "\nDETAILED LOG\n"
        output += String(repeating: "-", count: 40) + "\n"
        for entry in report.entries {
            output += "\(dateFormatter.string(from: entry.timestamp))\n"
            output += "  Type: \(entry.eventType.label)\n"
            output += "  Destination: \(entry.destination)\n"
            output += "  Detail: \(entry.dataSummary)\n\n"
        }

        return output
    }
}

struct PrivacyAuditReport {
    let totalEvents: Int
    let totalCharactersSent: Int
    let countsByType: [PrivacyAuditEntry.EventType: Int]
    let firstEventDate: Date?
    let lastEventDate: Date?
    let entries: [PrivacyAuditEntry]
}
