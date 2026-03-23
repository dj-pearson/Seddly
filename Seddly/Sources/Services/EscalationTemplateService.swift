import Foundation

struct EscalationTemplateService {
    struct EscalationTemplate {
        let title: String
        let category: CommitmentCategory
        let body: String
    }

    static func generateLetter(
        for entity: LocalEntity,
        category: CommitmentCategory,
        senderName: String = "[Your Name]"
    ) -> String {
        let template = template(for: category)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let today = dateFormatter.string(from: .now)

        let commitments = entity.commitments
            .filter { $0.status == .overdue || $0.status == .disputed || $0.status == .pending }
            .sorted { $0.createdAt < $1.createdAt }

        var letter = "\(today)\n\n"
        letter += "To: \(entity.name)\n"
        letter += "From: \(senderName)\n"
        letter += "Re: \(template.title)\n\n"

        letter += template.body + "\n\n"

        // Insert commitment timeline
        letter += "The following commitments remain outstanding:\n\n"
        for (index, commitment) in commitments.enumerated() {
            letter += "\(index + 1). \(commitment.summary)\n"
            letter += "   Recorded: \(dateFormatter.string(from: commitment.createdAt))\n"
            if let deadline = commitment.deadline {
                letter += "   Deadline: \(dateFormatter.string(from: deadline))\n"
                if commitment.isOverdue {
                    let days = Calendar.current.dateComponents([.day], from: deadline, to: .now).day ?? 0
                    letter += "   Status: OVERDUE by \(days) day(s)\n"
                }
            }
            if let amount = commitment.dollarAmount {
                letter += "   Amount: $\(amount)\n"
            }
            letter += "\n"
        }

        letter += closingText(for: category)
        letter += "\n\nSincerely,\n\(senderName)\n"
        letter += "\n— Evidence compiled by Seddly (seddly.com)"

        return letter
    }

    static func availableTemplates() -> [EscalationTemplate] {
        CommitmentCategory.allCases
            .filter { $0 != .uncategorized && $0 != .personal }
            .map { template(for: $0) }
    }

    private static func template(for category: CommitmentCategory) -> EscalationTemplate {
        switch category {
        case .housing:
            EscalationTemplate(
                title: "Formal Notice — Unfulfilled Maintenance/Repair Commitments",
                category: .housing,
                body: "I am writing to formally document commitments that were made regarding my rental unit and remain unfulfilled. As a tenant, I have documented each promise and its associated deadline. I am requesting immediate action on the following outstanding items, as continued delay may constitute a breach of the implied warranty of habitability."
            )
        case .freelance:
            EscalationTemplate(
                title: "Formal Notice — Outstanding Payment/Deliverable Commitments",
                category: .freelance,
                body: "I am writing to formally document commitments made during our professional engagement that remain unfulfilled. I have maintained records of each agreement, including deadlines and amounts discussed. I am requesting immediate resolution of the following outstanding items to avoid the need for further action."
            )
        case .purchases:
            EscalationTemplate(
                title: "Formal Complaint — Unfulfilled Purchase/Warranty Commitments",
                category: .purchases,
                body: "I am writing to formally document commitments made at the time of purchase or during subsequent customer service interactions that remain unfulfilled. I have records of each promise made, including dates and specifics. I am requesting prompt resolution of the following items."
            )
        case .medical:
            EscalationTemplate(
                title: "Formal Notice — Unfulfilled Healthcare Provider Commitments",
                category: .medical,
                body: "I am writing to document commitments made by your office regarding my care, billing, or scheduling that remain unresolved. I have maintained records of each commitment and its timeline. I am requesting prompt attention to the following outstanding matters."
            )
        case .insurance:
            EscalationTemplate(
                title: "Formal Complaint — Unfulfilled Insurance Claim Commitments",
                category: .insurance,
                body: "I am writing to formally document commitments made by your company regarding my claim that remain unfulfilled. I have documented each promise, including representative names, dates, and specifics discussed. I am requesting immediate resolution of the following items, as continued delay may warrant escalation to the state insurance commissioner."
            )
        case .personal, .uncategorized:
            EscalationTemplate(
                title: "Formal Notice — Unfulfilled Commitments",
                category: .uncategorized,
                body: "I am writing to formally document commitments that were made and remain unfulfilled. I have maintained records of each promise and its associated timeline. I am requesting prompt resolution of the following outstanding items."
            )
        }
    }

    private static func closingText(for category: CommitmentCategory) -> String {
        switch category {
        case .housing:
            "I am requesting written confirmation of a plan to address these items within 7 business days. If I do not receive a response, I may be compelled to pursue remedies available under my local tenant protection laws, including but not limited to repair-and-deduct, rent withholding, or filing a complaint with the relevant housing authority."
        case .freelance:
            "I am requesting written confirmation of a resolution plan within 5 business days. If payment or deliverables are not received by that date, I will pursue appropriate collection remedies."
        case .insurance:
            "I am requesting written confirmation of next steps within 10 business days. If this matter is not resolved promptly, I will file a formal complaint with the state Department of Insurance."
        default:
            "I am requesting written confirmation of a resolution plan within 10 business days. I look forward to resolving this matter promptly."
        }
    }
}
