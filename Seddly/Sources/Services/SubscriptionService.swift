import StoreKit

@Observable
final class SubscriptionService {
    private(set) var currentTier: SubscriptionTier = .free
    private var updateListenerTask: Task<Void, Never>?

    enum SubscriptionTier: Comparable {
        case free, pro, proPlus
    }

    init() {
        updateListenerTask = Task { await listenForTransactions() }
        Task { await refreshSubscriptionStatus() }
    }

    deinit {
        updateListenerTask?.cancel()
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

        currentTier = highestTier
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
