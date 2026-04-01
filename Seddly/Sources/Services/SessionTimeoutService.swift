import Foundation
import os

/// Monitors user session inactivity and triggers sign-out when the app
/// returns to foreground after the inactivity timeout has elapsed.
/// Works in conjunction with AuthService.sessionInactivityTimeout.
actor SessionTimeoutService {
    private let authService: AuthService
    private var backgroundEnteredAt: Date?

    init(authService: AuthService) {
        self.authService = authService
    }

    /// Called when app enters background. Records the timestamp.
    func appDidEnterBackground() {
        backgroundEnteredAt = .now
    }

    /// Called when app returns to foreground. Checks if the session
    /// has been inactive longer than the timeout threshold.
    /// If so, triggers sign-out via AuthService.
    func appWillEnterForeground() async {
        guard let backgroundTime = backgroundEnteredAt else { return }
        backgroundEnteredAt = nil

        let elapsed = Date.now.timeIntervalSince(backgroundTime)
        if elapsed > AuthService.sessionInactivityTimeout {
            AppLogger.auth.warning("Session timeout: app was backgrounded for \(Int(elapsed))s (threshold: \(Int(AuthService.sessionInactivityTimeout))s)")
            await authService.signOut()
        }
    }
}
