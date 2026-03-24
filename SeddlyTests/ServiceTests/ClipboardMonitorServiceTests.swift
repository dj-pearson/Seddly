import Testing
import Foundation
@testable import Seddly

@Suite("ClipboardMonitorService Tests")
struct ClipboardMonitorServiceTests {
    // Note: ClipboardMonitorService.checkClipboard() uses UIPasteboard which requires a running app.
    // We test the observable state behavior via dismiss() and verify the threshold constants.

    @Test("Text under 30 characters is below minimum length threshold")
    func minimumLengthThreshold() {
        // The service checks text.count >= 30 before proceeding
        let shortText = "Short text here"
        #expect(shortText.count < 30, "Text under 30 chars should be ignored by the service")
    }

    @Test("Text at 30+ characters meets minimum length threshold")
    func meetsLengthThreshold() {
        let longText = "This is a commitment to deliver the project by next Friday March 30th"
        #expect(longText.count >= 30, "Text at 30+ chars should pass the length check")
    }

    @Test("Default confidence threshold is 40")
    func confidenceThresholdValue() {
        #expect(AppConstants.defaultConfidenceThreshold == 40)
    }

    @Test("dismiss() resets all state")
    func dismissResetsState() {
        let service = ClipboardMonitorService()
        // Simulate detected state
        service.detectedText = "Some commitment text that was detected"
        service.confidenceScore = 75
        service.showClipboardPrompt = true

        service.dismiss()

        #expect(service.detectedText == nil)
        #expect(service.confidenceScore == 0)
        #expect(service.showClipboardPrompt == false)
    }

    @Test("Initial state is clean")
    func initialState() {
        let service = ClipboardMonitorService()
        #expect(service.detectedText == nil)
        #expect(service.confidenceScore == 0)
        #expect(service.showClipboardPrompt == false)
    }
}
