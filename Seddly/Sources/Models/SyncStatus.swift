import Foundation

enum SyncStatus: String, Codable {
    case local
    case synced
    case pendingSync
}
