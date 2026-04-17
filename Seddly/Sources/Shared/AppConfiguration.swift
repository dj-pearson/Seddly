import Foundation

/// Centralized access to Info.plist-sourced configuration with validation.
///
/// US-147: The Supabase URL and anon key were previously read ad-hoc from
/// `Bundle.main.infoDictionary` in at least five call sites, each with its own
/// fallback behavior. This enum gives the app a single source of truth and a
/// guard against shipping the "YOUR_SUPABASE_URL" placeholder that lives in
/// the checked-in Info.plist template.
enum AppConfiguration {

    /// Resolved Supabase credentials, or `nil` when the Info.plist values are
    /// missing / still set to the template placeholder. Callers should treat a
    /// `nil` return as "sync/auth features disabled" rather than crashing.
    struct Supabase: Equatable {
        let url: URL
        let anonKey: String
    }

    /// Reads Supabase credentials from the app's Info.plist, validates them,
    /// and logs a fault in release builds if they are missing. In DEBUG builds
    /// a precondition fires to catch misconfigured local builds early.
    static var supabase: Supabase? {
        let rawURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
        let rawKey = Bundle.main.infoDictionary?["SUPABASE_KEY"] as? String ?? ""

        if isPlaceholder(rawURL) || isPlaceholder(rawKey) {
            #if DEBUG
            preconditionFailure(
                "Supabase credentials are unset. Populate SUPABASE_URL and SUPABASE_KEY in Info.plist (or inject via xcconfig) before running Pro+ flows."
            )
            #else
            // Release builds should not crash — sync is a Pro+ feature and the
            // app's free tier keeps working without a Supabase connection.
            return nil
            #endif
        }

        guard let url = URL(string: rawURL), url.scheme == "https" else {
            #if DEBUG
            preconditionFailure("SUPABASE_URL must be a valid https:// URL.")
            #else
            return nil
            #endif
        }

        return Supabase(url: url, anonKey: rawKey)
    }

    /// URL fallback kept for the AuthService environment default. Callers that
    /// need the *real* URL must use `supabase` and handle the `nil` case.
    static var supabaseURLOrPlaceholder: URL {
        supabase?.url ?? URL(string: "https://placeholder.supabase.co")!
    }

    static var supabaseAnonKeyOrEmpty: String {
        supabase?.anonKey ?? ""
    }

    private static func isPlaceholder(_ value: String) -> Bool {
        value.isEmpty || value.hasPrefix("YOUR_")
    }
}
