import Foundation

enum CommitmentStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case fulfilled
    case overdue
    case disputed
    case dismissed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending: "Pending"
        case .fulfilled: "Fulfilled"
        case .overdue: "Overdue"
        case .disputed: "Disputed"
        case .dismissed: "Dismissed"
        }
    }
}
