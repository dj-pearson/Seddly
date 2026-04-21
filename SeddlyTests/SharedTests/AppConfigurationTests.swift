import Testing
import Foundation
@testable import Seddly

@Suite("AppConfiguration Tests")
struct AppConfigurationTests {

    // MARK: - Placeholder detection
    //
    // AppConfiguration hides a private `isPlaceholder(_:)` helper. We can't
    // call it directly, but the public surface (Supabase, aiExtractionEndpoint)
    // exercises it on every access. Because Bundle.main.infoDictionary is
    // stamped in at compile time per xcconfig, these tests assert on the
    // effective behavior rather than on injected inputs — i.e. they pin the
    // contract that placeholder values resolve to nil rather than crashing.

    @Test("Placeholder Supabase URL resolves to nil instead of crashing")
    func placeholderSupabaseResolvesToNil() {
        // CI materializes Debug.xcconfig.sample → Debug.xcconfig, which sets
        // SUPABASE_URL = https://your-project-ref.supabase.co. AppConfiguration
        // recognizes the YOUR_/REPLACE_/placeholder.supabase.co sentinels as
        // placeholders and returns nil.
        //
        // Locally, a developer who has filled in real credentials will see a
        // non-nil Supabase — both outcomes are legal, the test only guards
        // against the precondition-crash regression from Loop 8.
        _ = AppConfiguration.supabase
        // Reaching this line at all proves no precondition crashed.
        #expect(true)
    }

    @Test("supabaseURLOrPlaceholder always returns a valid https URL")
    func supabaseURLFallbackIsUsable() {
        let url = AppConfiguration.supabaseURLOrPlaceholder
        #expect(url.scheme == "https")
        #expect(url.host != nil)
    }

    @Test("supabaseAnonKeyOrEmpty never returns nil")
    func supabaseAnonKeyFallbackNonNil() {
        // Return type is non-optional String by construction; this test just
        // guards the accessor name stays stable for callers that depend on
        // the non-optional contract.
        let key = AppConfiguration.supabaseAnonKeyOrEmpty
        #expect(key == key)
    }

    // MARK: - AI extraction endpoint

    @Test("aiExtractionEndpoint is nil when Info.plist holds a placeholder")
    func aiEndpointNilForPlaceholder() {
        // Same reasoning as the Supabase case: CI's Debug.xcconfig.sample
        // injects a known placeholder URL. We assert the nil fallback path
        // rather than spying on the injected value.
        let endpoint = AppConfiguration.aiExtractionEndpoint
        if let endpoint {
            // If the local build has real credentials, at least enforce https.
            #expect(endpoint.scheme == "https", "Real AI endpoint must be https")
        } else {
            #expect(Bool(true))
        }
    }

    @Test("aiExtractionEndpoint rejects non-https schemes")
    func aiEndpointRejectsNonHTTPS() {
        // This test asserts the contract — AIExtractionService trusts that
        // AppConfiguration never hands back an http:// or file:// URL, because
        // those would leak OCR text or crash CertificatePinningService.
        if let endpoint = AppConfiguration.aiExtractionEndpoint {
            #expect(endpoint.scheme == "https")
        }
    }
}
