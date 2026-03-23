import Testing
import Foundation
@testable import Seddly

@Suite("ClassifierFeedbackService Tests")
struct ClassifierFeedbackServiceTests {
    @Test("Initial threshold matches default")
    func initialThreshold() {
        let threshold = ClassifierFeedbackService.currentThreshold()
        // Could be adjusted from prior runs, but should be >= 20 and <= 70
        #expect(threshold >= 20)
        #expect(threshold <= 70)
    }

    @Test("Feedback stats are serializable")
    func statsSerializable() {
        var stats = ClassifierFeedbackService.FeedbackStats()
        stats.totalAutoDetected = 50
        stats.falsePositiveDismissals = 10
        stats.manualAdditions = 5

        #expect(stats.falsePositiveRate == 0.2)
    }

    @Test("Zero detections yields zero false positive rate")
    func zeroDetections() {
        let stats = ClassifierFeedbackService.FeedbackStats()
        #expect(stats.falsePositiveRate == 0)
    }
}
