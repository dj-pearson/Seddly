import Foundation

struct CommitmentTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let category: CommitmentCategory
    let defaultSummary: String
    let suggestedDeadlineDays: Int?
    let hasDollarAmount: Bool

    static let allTemplates: [CommitmentTemplate] = [
        CommitmentTemplate(
            name: "Lease / Rental Promise",
            icon: "house",
            category: .housing,
            defaultSummary: "Promised to complete repair/maintenance",
            suggestedDeadlineDays: 14,
            hasDollarAmount: false
        ),
        CommitmentTemplate(
            name: "Security Deposit Return",
            icon: "banknote",
            category: .housing,
            defaultSummary: "Promised to return security deposit",
            suggestedDeadlineDays: 30,
            hasDollarAmount: true
        ),
        CommitmentTemplate(
            name: "Payment Agreement",
            icon: "dollarsign.circle",
            category: .freelance,
            defaultSummary: "Agreed to pay invoice",
            suggestedDeadlineDays: 30,
            hasDollarAmount: true
        ),
        CommitmentTemplate(
            name: "Service Guarantee",
            icon: "wrench.and.screwdriver",
            category: .purchases,
            defaultSummary: "Guaranteed service/repair completion",
            suggestedDeadlineDays: 7,
            hasDollarAmount: false
        ),
        CommitmentTemplate(
            name: "Delivery Window",
            icon: "shippingbox",
            category: .purchases,
            defaultSummary: "Promised delivery by specified date",
            suggestedDeadlineDays: 7,
            hasDollarAmount: false
        ),
        CommitmentTemplate(
            name: "Warranty Claim",
            icon: "shield.checkered",
            category: .purchases,
            defaultSummary: "Accepted warranty claim for replacement/repair",
            suggestedDeadlineDays: 14,
            hasDollarAmount: false
        ),
        CommitmentTemplate(
            name: "Refund Promise",
            icon: "arrow.counterclockwise.circle",
            category: .purchases,
            defaultSummary: "Promised refund",
            suggestedDeadlineDays: 10,
            hasDollarAmount: true
        ),
        CommitmentTemplate(
            name: "Insurance Claim",
            icon: "shield",
            category: .insurance,
            defaultSummary: "Committed to processing claim",
            suggestedDeadlineDays: 30,
            hasDollarAmount: true
        ),
        CommitmentTemplate(
            name: "Medical Appointment / Follow-Up",
            icon: "cross.case",
            category: .medical,
            defaultSummary: "Scheduled follow-up or procedure",
            suggestedDeadlineDays: 14,
            hasDollarAmount: false
        ),
    ]
}
