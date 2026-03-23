import CoreML
import UIKit
import Vision

actor ClassifierService {
    enum ScreenshotCategory: String {
        case conversation
        case receipt
        case termsAgreement = "terms_agreement"
        case uiScreenshot = "ui_screenshot"
        case memeImage = "meme_image"
        case other

        var shouldProcess: Bool {
            switch self {
            case .conversation, .receipt, .termsAgreement:
                true
            case .uiScreenshot, .memeImage, .other:
                false
            }
        }
    }

    /// Classify a screenshot image into a category.
    ///
    /// Uses a Core ML model when available. Falls back to heuristic
    /// classification based on OCR text content until the trained
    /// model is integrated.
    func classify(_ image: UIImage, ocrText: String? = nil) async -> ScreenshotCategory {
        // Phase 1: Heuristic classification based on OCR text
        // Core ML model will replace this once trained with labeled data
        if let text = ocrText {
            return heuristicClassify(text: text)
        }

        return .other
    }

    private func heuristicClassify(text: String) -> ScreenshotCategory {
        let lowercased = text.lowercased()
        let lineCount = text.components(separatedBy: .newlines).count

        // Receipt/confirmation indicators
        let receiptSignals = ["order confirmation", "receipt", "transaction", "payment",
                              "invoice", "total:", "subtotal", "amount paid", "order #"]
        if receiptSignals.contains(where: { lowercased.contains($0) }) {
            return .receipt
        }

        // Terms/agreement indicators
        let termsSignals = ["terms of service", "privacy policy", "i agree", "terms and conditions",
                            "by signing", "agreement", "contract", "clause", "effective date"]
        if termsSignals.contains(where: { lowercased.contains($0) }) {
            return .termsAgreement
        }

        // Conversation indicators — messages tend to have short lines and multiple speakers
        let conversationSignals = ["imessage", "whatsapp", "messenger", "delivered", "read",
                                   "sent from", "reply", "typing"]
        let hasConversationSignals = conversationSignals.contains(where: { lowercased.contains($0) })
        let hasShortLines = lineCount > 3

        if hasConversationSignals || (hasShortLines && lineCount > 5) {
            return .conversation
        }

        // If there's substantial text, default to conversation (most screenshots with text are)
        if text.count > 50 {
            return .conversation
        }

        return .other
    }
}
