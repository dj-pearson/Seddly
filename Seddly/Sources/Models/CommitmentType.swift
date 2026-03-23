import Foundation

enum CommitmentType: String, Codable, CaseIterable {
    case firmPromise = "firm_promise"
    case softCommitment = "soft_commitment"
    case informational
    case irrelevant
}
