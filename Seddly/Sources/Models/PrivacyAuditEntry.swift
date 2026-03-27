import Foundation
import SwiftData

@Model
final class PrivacyAuditEntry {
    #Index<PrivacyAuditEntry>([\.timestamp])

    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var eventTypeRaw: String
    var destination: String
    var dataSummary: String
    var textLengthSent: Int
    var commitmentID: UUID?

    var eventType: EventType {
        get { EventType(rawValue: eventTypeRaw) ?? .aiExtraction }
        set { eventTypeRaw = newValue.rawValue }
    }

    enum EventType: String, CaseIterable {
        case aiExtraction = "ai_extraction"
        case disputeSummary = "dispute_summary"
        case cloudSync = "cloud_sync"

        var label: String {
            switch self {
            case .aiExtraction: "AI Commitment Extraction"
            case .disputeSummary: "Dispute Summary Generation"
            case .cloudSync: "Cloud Sync (Pro+)"
            }
        }

        var icon: String {
            switch self {
            case .aiExtraction: "brain"
            case .disputeSummary: "doc.text"
            case .cloudSync: "icloud.and.arrow.up"
            }
        }
    }

    init(
        eventType: EventType,
        destination: String,
        dataSummary: String,
        textLengthSent: Int,
        commitmentID: UUID? = nil
    ) {
        self.id = UUID()
        self.timestamp = .now
        self.eventTypeRaw = eventType.rawValue
        self.destination = destination
        self.dataSummary = dataSummary
        self.textLengthSent = textLengthSent
        self.commitmentID = commitmentID
    }
}
