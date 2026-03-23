import UIKit

@Observable
final class ClipboardMonitorService {
    var detectedText: String?
    var confidenceScore: Int = 0
    var showClipboardPrompt = false

    private var lastCheckedChangeCount: Int = 0

    func checkClipboard() {
        let pasteboard = UIPasteboard.general

        // Only check if clipboard content changed since last check
        guard pasteboard.changeCount != lastCheckedChangeCount else { return }
        lastCheckedChangeCount = pasteboard.changeCount

        guard pasteboard.hasStrings, let text = pasteboard.string else { return }

        // Must be meaningful text (not just a URL or short snippet)
        guard text.count >= 30 else { return }

        let score = RuleFilterService.score(text: text)
        guard score >= AppConstants.defaultConfidenceThreshold else { return }

        detectedText = text
        confidenceScore = score
        showClipboardPrompt = true
    }

    func dismiss() {
        detectedText = nil
        confidenceScore = 0
        showClipboardPrompt = false
    }
}
