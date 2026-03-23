import Foundation
import SwiftData

@Model
final class ProcessingQueue {
    #Unique<ProcessingQueue>([\.id])

    @Attribute(.unique) var id: UUID
    var screenshotAssetID: String
    var extractedText: String?
    var classifierResult: String?
    var ruleBasedScore: Int?
    var processingStatusRaw: String
    var createdAt: Date

    var processingStatus: ProcessingStatus {
        get { ProcessingStatus(rawValue: processingStatusRaw) ?? .pending }
        set { processingStatusRaw = newValue.rawValue }
    }

    init(screenshotAssetID: String) {
        self.id = UUID()
        self.screenshotAssetID = screenshotAssetID
        self.processingStatusRaw = ProcessingStatus.pending.rawValue
        self.createdAt = .now
    }

    enum ProcessingStatus: String, Codable {
        case pending
        case processing
        case awaitingReview  // Text extracted, needs user approval before AI send
        case completed
        case skipped
    }
}
