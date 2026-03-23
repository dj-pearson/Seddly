import Foundation

struct RuleFilterService {
    private static let commitmentSignals = [
        "will", "guarantee", "promise", "by ", "no later than",
        "committed to", "scheduled for", "confirmed", "agreed",
        "i'll", "we'll", "we will", "i will", "expect to",
        "deliver", "complete", "finish", "have it done", "get it done"
    ]

    private static let hedgingLanguage = [
        "might", "probably", "try to", "hopefully", "if possible",
        "no guarantees", "can't promise", "not sure", "maybe",
        "we'll see", "depends on", "subject to"
    ]

    static func score(text: String) -> Int {
        let lowercased = text.lowercased()

        let signalCount = commitmentSignals.reduce(0) { count, signal in
            count + (lowercased.contains(signal) ? 1 : 0)
        }

        let hedgeCount = hedgingLanguage.reduce(0) { count, hedge in
            count + (lowercased.contains(hedge) ? 1 : 0)
        }

        let datePattern = /\b\d{1,2}[\/\-]\d{1,2}[\/\-]?\d{0,4}\b|\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|next week|end of (week|month|day))\b/
        let hasDates = lowercased.contains(datePattern)

        let dollarPattern = /\$[\d,]+\.?\d{0,2}/
        let hasDollars = text.contains(dollarPattern)

        var score = signalCount * 15
        score -= hedgeCount * 20
        if hasDates { score += 20 }
        if hasDollars { score += 10 }

        return max(0, min(100, score))
    }
}
