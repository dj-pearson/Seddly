import Foundation

enum CommitmentSource: String, Codable, CaseIterable {
    case auto
    case manual
    case shareSheet
}
