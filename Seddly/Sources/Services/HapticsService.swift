import UIKit

/// Centralized haptic feedback (US-139).
///
/// Using a single entry-point keeps haptic "language" consistent across the
/// app — taps feel identical everywhere, and the generators get reused instead
/// of being reallocated on every interaction.
@MainActor
enum HapticsService {

    // Reusable generators (cheaper than allocating per call).
    private static let selection = UISelectionFeedbackGenerator()
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private static let notification = UINotificationFeedbackGenerator()

    /// Prepare all generators — call on screen appear for responsive feedback.
    static func prepare() {
        selection.prepare()
        lightImpact.prepare()
        mediumImpact.prepare()
        notification.prepare()
    }

    // MARK: - Semantic Haptics

    /// Light tap — used for row taps, toggles, minor state changes.
    static func tap() {
        lightImpact.impactOccurred(intensity: 0.7)
    }

    /// Selection change — picker/tab changes.
    static func select() {
        selection.selectionChanged()
    }

    /// Medium confirmation — destructive dialog confirmations.
    static func confirm() {
        mediumImpact.impactOccurred()
    }

    /// Success — commitment fulfilled, save completed, upgrade purchased.
    static func success() {
        notification.notificationOccurred(.success)
    }

    /// Warning — validation failure, limit reached.
    static func warning() {
        notification.notificationOccurred(.warning)
    }

    /// Error — operation failed.
    static func error() {
        notification.notificationOccurred(.error)
    }

    /// Celebratory moment — streak extended, big milestone. A crisp double-tap.
    static func celebrate() {
        rigidImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            softImpact.impactOccurred(intensity: 0.85)
        }
    }

    /// Heavy thud — long-press activation, bulk selection enter.
    static func longPress() {
        heavyImpact.impactOccurred(intensity: 0.85)
    }
}
