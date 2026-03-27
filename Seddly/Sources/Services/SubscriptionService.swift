import StoreKit

@Observable
final class SubscriptionService {
    private(set) var currentTier: SubscriptionTier = .free
    private(set) var previousTier: SubscriptionTier = .free
    private(set) var tierDowngradeDetected = false
    private var updateListenerTask: Task<Void, Never>?

    enum SubscriptionTier: Comparable {
        case free, pro, proPlus

        var displayName: String {
            switch self {
            case .free: "Free"
            case .pro: "Pro"
            case .proPlus: "Pro+"
            }
        }
    }

    var downgradeMessage: String {
        "Your subscription changed from \(previousTier.displayName) to \(currentTier.displayName). Some features have been adjusted."
    }

    var isSyncEnabled: Bool {
        currentTier == .proPlus
    }

    var isAIExtractionEnabled: Bool {
        currentTier >= .pro
    }

    init() {
        updateListenerTask = Task { await listenForTransactions() }
        Task { await refreshSubscriptionStatus() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func dismissDowngradeAlert() {
        tierDowngradeDetected = false
    }

    func refreshSubscriptionStatus() async {
        var highestTier: SubscriptionTier = .free

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if transaction.productID.contains("proplus") {
                highestTier = max(highestTier, .proPlus)
            } else if transaction.productID.contains("pro") {
                highestTier = max(highestTier, .pro)
            }
        }

        let oldTier = currentTier
        currentTier = highestTier

        if highestTier < oldTier {
            previousTier = oldTier
            tierDowngradeDetected = true
        }
    }

    func purchase(_ productID: String) async throws -> Transaction? {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else { return nil }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return nil }
            await transaction.finish()
            await refreshSubscriptionStatus()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await refreshSubscriptionStatus()
        }
    }
}
