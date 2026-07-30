import Foundation
import Testing
@testable import Seddly

/// Marker used only to locate the test bundle that carries Seddly.storekit.
private final class TestBundleMarker {}

/// US-185: `Seddly.storekit` and `AppConstants.SubscriptionProductID` are two
/// independent lists of the same four product identifiers. Nothing connected
/// them, so renaming a product in one place and not the other would surface as
/// a purchase silently failing at runtime rather than as a build or test
/// failure — the existing coverage only asserted that the constants contained
/// the substrings "pro" and "proplus", which stays true through any rename.
///
/// These tests fail the build instead.
@Suite("StoreKit configuration")
struct StoreKitConfigurationTests {

    private func loadConfiguration() throws -> [String: Any] {
        let bundle = Bundle(for: TestBundleMarker.self)
        let url = try #require(
            bundle.url(forResource: "Seddly", withExtension: "storekit"),
            "Seddly.storekit is not in the test bundle — check the SeddlyTests resources in project.yml"
        )
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any], "Seddly.storekit is not a JSON object")
    }

    /// Every subscription's productID, flattened across all groups.
    private func configuredProductIDs() throws -> Set<String> {
        let config = try loadConfiguration()
        let groups = config["subscriptionGroups"] as? [[String: Any]] ?? []
        let ids = groups
            .flatMap { $0["subscriptions"] as? [[String: Any]] ?? [] }
            .compactMap { $0["productID"] as? String }
        return Set(ids)
    }

    private var codeProductIDs: Set<String> {
        [
            AppConstants.SubscriptionProductID.proMonthly,
            AppConstants.SubscriptionProductID.proYearly,
            AppConstants.SubscriptionProductID.proPlusMonthly,
            AppConstants.SubscriptionProductID.proPlusYearly,
        ]
    }

    @Test("Every product ID the app resolves exists in the StoreKit configuration")
    func codeProductsExistInConfiguration() throws {
        let configured = try configuredProductIDs()
        for id in codeProductIDs {
            #expect(
                configured.contains(id),
                "\(id) is resolved by SubscriptionService but missing from Seddly.storekit"
            )
        }
    }

    @Test("The StoreKit configuration defines no product the app cannot resolve")
    func configurationHasNoOrphanProducts() throws {
        let configured = try configuredProductIDs()
        for id in configured {
            #expect(
                codeProductIDs.contains(id),
                "\(id) is defined in Seddly.storekit but no AppConstants.SubscriptionProductID resolves it"
            )
        }
    }

    /// SubscriptionService distinguishes tiers with `productID.contains("proplus")`,
    /// checked before the `"pro"` branch. That ordering is load-bearing: every
    /// Pro+ identifier must contain "proplus", and no Pro identifier may.
    @Test("Tier detection substrings are unambiguous")
    func tierDetectionIsUnambiguous() {
        let proPlus = [
            AppConstants.SubscriptionProductID.proPlusMonthly,
            AppConstants.SubscriptionProductID.proPlusYearly,
        ]
        let pro = [
            AppConstants.SubscriptionProductID.proMonthly,
            AppConstants.SubscriptionProductID.proYearly,
        ]

        for id in proPlus {
            #expect(id.contains("proplus"), "\(id) must contain \"proplus\" for tier detection")
        }
        for id in pro {
            #expect(!id.contains("proplus"), "\(id) must not contain \"proplus\" — it would resolve as Pro+")
            #expect(id.contains("pro"), "\(id) must contain \"pro\" for tier detection")
        }
    }

    @Test("Identity fields are either real values or explicit placeholders")
    func identityFieldsAreNotSilentlyBlank() throws {
        let config = try loadConfiguration()
        let settings = try #require(config["settings"] as? [String: Any])

        for key in ["_applicationInternalID", "_developerTeamID"] {
            let value = settings[key] as? String ?? ""
            #expect(
                !value.isEmpty,
                "\(key) is blank. Set the real value from App Store Connect, or leave the "
                    + "REPLACE_WITH_ placeholder so it is obvious it still needs filling in."
            )
        }
    }
}
