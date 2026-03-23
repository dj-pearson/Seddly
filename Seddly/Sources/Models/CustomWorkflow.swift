import Foundation
import SwiftData

@Model
final class CustomWorkflow {
    @Attribute(.unique) var id: UUID
    var name: String
    var steps: [String]
    var isDefault: Bool
    var createdAt: Date

    init(name: String, steps: [String], isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.steps = steps
        self.isDefault = isDefault
        self.createdAt = .now
    }

    static let defaultWorkflow = CustomWorkflow(
        name: "Default",
        steps: ["Pending", "Fulfilled", "Overdue", "Disputed", "Dismissed"],
        isDefault: true
    )

    static let presets: [(name: String, steps: [String])] = [
        ("Landlord / Housing", ["Reported", "Acknowledged", "Scheduled", "In Progress", "Completed", "Escalated"]),
        ("Payment Collection", ["Invoiced", "Reminded", "Promised", "Partial Payment", "Paid", "Collections"]),
        ("Service / Repair", ["Requested", "Quoted", "Scheduled", "In Progress", "Completed", "Warranty Claim"]),
        ("Insurance Claim", ["Filed", "Under Review", "Additional Info Requested", "Approved", "Paid Out", "Denied"]),
    ]
}
