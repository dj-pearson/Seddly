import Foundation
import LocalAuthentication

/// Wraps LAContext so the rest of the app can gate sensitive screens behind
/// Face ID / Touch ID / device passcode without sprinkling framework imports.
///
/// US-150: When `isAppLockEnabled` is on, the app requires a fresh biometric
/// check whenever it returns to the foreground after being in the background
/// for more than `inactivityTimeout`. Individual views (CommitmentDetailView,
/// DataExportView) can also request an ad-hoc unlock via `authenticate()`.
@Observable
@MainActor
final class BiometricService {

    enum Availability: Equatable {
        case available(BiometryKind)
        case notEnrolled
        case unavailable(reason: String)
    }

    enum BiometryKind {
        case faceID
        case touchID
        case opticID
        case none

        var displayName: String {
            switch self {
            case .faceID:  return "Face ID"
            case .touchID: return "Touch ID"
            case .opticID: return "Optic ID"
            case .none:    return "Passcode"
            }
        }
    }

    enum AuthError: Error, LocalizedError {
        case cancelled
        case failed
        case unavailable

        var errorDescription: String? {
            switch self {
            case .cancelled:   return "Authentication cancelled."
            case .failed:      return "Authentication failed."
            case .unavailable: return "Biometric authentication isn't available on this device."
            }
        }
    }

    /// Minimum time the app must be backgrounded before we ask for auth again.
    static let inactivityTimeout: TimeInterval = 30

    /// Key used to persist the user's preference in UserDefaults.
    private static let appLockKey = "biometrics.appLockEnabled"

    var isAppLockEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.appLockKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.appLockKey) }
    }

    /// True while the app is waiting for a biometric unlock. Views observe this
    /// to show a locked overlay.
    var isLocked: Bool = false

    private var lastBackgroundedAt: Date?

    func availability() -> Availability {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error
        )
        let kind: BiometryKind
        switch context.biometryType {
        case .faceID:  kind = .faceID
        case .touchID: kind = .touchID
        case .opticID: kind = .opticID
        @unknown default: kind = .none
        }
        if canEvaluate {
            return .available(kind)
        }
        if let error, error.code == LAError.biometryNotEnrolled.rawValue {
            return .notEnrolled
        }
        return .unavailable(reason: error?.localizedDescription ?? "Unknown")
    }

    func authenticate(reason: String) async throws {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        var probeError: NSError?
        // Fall through to passcode if biometrics aren't enrolled — matches the
        // acceptance criteria's LAError.biometryNotEnrolled handling.
        let policy: LAPolicy = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &probeError
        ) ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication

        if !context.canEvaluatePolicy(policy, error: &probeError) {
            AppLogger.biometrics.error("Biometrics unavailable: \(probeError?.localizedDescription ?? "unknown")")
            throw AuthError.unavailable
        }

        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            if !success { throw AuthError.failed }
            isLocked = false
            lastBackgroundedAt = nil
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel, .userFallback:
                throw AuthError.cancelled
            default:
                AppLogger.biometrics.error("Auth evaluate failed: \(error.localizedDescription)")
                throw AuthError.failed
            }
        }
    }

    /// Call from scenePhase transitions. Marks when we went to background so
    /// `evaluateLockOnForeground()` can decide whether to prompt.
    func markBackgrounded() {
        lastBackgroundedAt = .now
    }

    /// Returns true when the app should re-lock on foreground. The caller is
    /// expected to set `isLocked = true` and drive the unlock flow.
    func shouldLockOnForeground() -> Bool {
        guard isAppLockEnabled else { return false }
        guard let lastBackgroundedAt else { return true } // cold launch
        return Date.now.timeIntervalSince(lastBackgroundedAt) >= Self.inactivityTimeout
    }
}
