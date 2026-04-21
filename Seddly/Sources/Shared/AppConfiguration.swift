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
    /// and returns `nil` when the build was produced without secrets injected
    /// (CI simulator builds, free-tier local builds). Free-tier paths continue
    /// to work; Pro+ code paths are expected to gracefully no-op on `nil`.
    static var supabase: Supabase? {
        let rawURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
        let rawKey = Bundle.main.infoDictionary?["SUPABASE_KEY"] as? String ?? ""

        if isPlaceholder(rawURL) || isPlaceholder(rawKey) {
            return nil
        }

        guard let url = URL(string: rawURL), url.scheme == "https" else {
            return nil
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

    /// AI-extraction Edge Function endpoint injected via xcconfig. Returns nil
    /// when the build is not wired to a Supabase project — callers should
    /// gracefully disable AI extraction rather than crash.
    static var aiExtractionEndpoint: URL? {
        let raw = Bundle.main.infoDictionary?["AI_EXTRACTION_ENDPOINT"] as? String ?? ""
        guard !isPlaceholder(raw), let url = URL(string: raw), url.scheme == "https" else {
            return nil
        }
        return url
    }

    private static func isPlaceholder(_ value: String) -> Bool {
        value.isEmpty || value.hasPrefix("YOUR_") || value.contains("REPLACE_") || value.contains("placeholder.supabase.co")
    }
}
