import Foundation

enum CommitmentCategory: String, Codable, CaseIterable, Identifiable {
    case housing
    case freelance
    case purchases
    case personal
    case medical
    case insurance
    case uncategorized

    var id: String { rawValue }

    var label: String {
        switch self {
        case .housing: "Housing"
        case .freelance: "Freelance"
        case .purchases: "Purchases"
        case .personal: "Personal"
        case .medical: "Medical"
        case .insurance: "Insurance"
        case .uncategorized: "Uncategorized"
        }
    }

    var icon: String {
        switch self {
        case .housing: "house"
        case .freelance: "briefcase"
        case .purchases: "cart"
        case .personal: "person"
        case .medical: "cross.case"
        case .insurance: "shield"
        case .uncategorized: "folder"
        }
    }
}
