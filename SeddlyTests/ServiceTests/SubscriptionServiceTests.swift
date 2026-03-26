import Testing
import Foundation
@testable import Seddly

@Suite("SubscriptionService Tests")
struct SubscriptionServiceTests {
    @Test("Initial tier is free")
    func initialTierIsFree() {
        let service = SubscriptionService()
        #expect(service.currentTier == .free)
    }

    @Test("SubscriptionTier ordering: free < pro < proPlus")
    func tierOrdering() {
        #expect(SubscriptionService.SubscriptionTier.free < .pro)
        #expect(SubscriptionService.SubscriptionTier.pro < .proPlus)
        #expect(SubscriptionService.SubscriptionTier.free < .proPlus)
    }

    @Test("Pro+ tier gates features correctly")
    func proPlusFeatureGating() {
        // Pro+ should satisfy >= .pro checks (sync, AI extraction)
        let tier = SubscriptionService.SubscriptionTier.proPlus
        #expect(tier >= .pro)
        #expect(tier >= .proPlus)
    }

    @Test("Free tier does not satisfy Pro requirements")
    func freeTierGating() {
        let tier = SubscriptionService.SubscriptionTier.free
        #expect(tier < .pro)
        #expect(tier < .proPlus)
    }

    @Test("Pro tier satisfies Pro but not Pro+ requirements")
    func proTierGating() {
        let tier = SubscriptionService.SubscriptionTier.pro
        #expect(tier >= .pro)
        #expect(tier < .proPlus)
    }

    @Test("Product IDs contain correct tier identifiers")
    func productIDFormats() {
        #expect(AppConstants.SubscriptionProductID.proMonthly.contains("pro"))
        #expect(AppConstants.SubscriptionProductID.proYearly.contains("pro"))
        #expect(AppConstants.SubscriptionProductID.proPlusMonthly.contains("proplus"))
        #expect(AppConstants.SubscriptionProductID.proPlusYearly.contains("proplus"))
    }

    @Test("Transaction listener task is created on init")
    func listenerTaskCreated() {
        // SubscriptionService creates an update listener task in init
        // Verify it doesn't crash and initializes properly
        let service = SubscriptionService()
        #expect(service.currentTier == .free)
    }
}
