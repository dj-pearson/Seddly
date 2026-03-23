import Foundation
import SwiftData

/// Tracks user feedback (dismissals, manual additions) to improve
/// the rule-based classifier thresholds over time.
struct ClassifierFeedbackService {
    private static let feedbackKey = "classifierFeedback"
    private static let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)

    struct FeedbackStats: Codable {
        var totalAutoDetected: Int = 0
        var falsePositiveDismissals: Int = 0
        var manualAdditions: Int = 0
        var adjustedThreshold: Int = AppConstants.defaultConfidenceThreshold

        var falsePositiveRate: Double {
            guard totalAutoDetected > 0 else { return 0 }
            return Double(falsePositiveDismissals) / Double(totalAutoDetected)
        }
    }

    static func recordAutoDetection() {
        var stats = loadStats()
        stats.totalAutoDetected += 1
        saveStats(stats)
    }

    static func recordDismissal() {
        var stats = loadStats()
        stats.falsePositiveDismissals += 1
        recalculateThreshold(&stats)
        saveStats(stats)
    }

    static func recordManualAddition() {
        var stats = loadStats()
        stats.manualAdditions += 1
        recalculateThreshold(&stats)
        saveStats(stats)
    }

    static func currentThreshold() -> Int {
        loadStats().adjustedThreshold
    }

    static func loadStats() -> FeedbackStats {
        guard let data = defaults?.data(forKey: feedbackKey),
              let stats = try? JSONDecoder().decode(FeedbackStats.self, from: data) else {
            return FeedbackStats()
        }
        return stats
    }

    /// Adjust the rule-based threshold based on false positive rate.
    /// High false positive rate → raise threshold (be more selective).
    /// High manual addition rate → lower threshold (catch more).
    private static func recalculateThreshold(_ stats: inout FeedbackStats) {
        let baseThreshold = AppConstants.defaultConfidenceThreshold

        if stats.totalAutoDetected >= 20 {
            if stats.falsePositiveRate > 0.30 {
                // Too many false positives — raise threshold
                stats.adjustedThreshold = min(70, baseThreshold + 10)
            } else if stats.falsePositiveRate < 0.10 && stats.manualAdditions > 5 {
                // Very few false positives but user adds manually — lower threshold
                stats.adjustedThreshold = max(20, baseThreshold - 10)
            } else {
                stats.adjustedThreshold = baseThreshold
            }
        }
    }

    private static func saveStats(_ stats: FeedbackStats) {
        if let data = try? JSONEncoder().encode(stats) {
            defaults?.set(data, forKey: feedbackKey)
        }
    }
}
