import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(SubscriptionService.self) private var subscriptionService

    var body: some View {
        List {
            Section {
                currentTierRow
            }

            Section("Plans") {
                SubscriptionTierRow(
                    name: "Free",
                    price: "$0",
                    features: ["Manual screenshot import", "5 active commitments", "On-device processing only", "Basic deadline alerts"],
                    isCurrent: subscriptionService.currentTier == .free
                )

                SubscriptionTierRow(
                    name: "Pro",
                    price: "$4.99/mo",
                    features: ["Auto-scan Screenshots album", "Unlimited commitments", "AI-powered extraction", "Full notification suite", "Search & filter", "Entity profiles"],
                    isCurrent: subscriptionService.currentTier == .pro
                ) {
                    await purchase(AppConstants.SubscriptionProductID.proMonthly)
                }

                SubscriptionTierRow(
                    name: "Pro+",
                    price: "$9.99/mo",
                    features: ["Everything in Pro", "AI dispute summaries", "PDF export", "iCloud sync", "Unlimited history", "Priority processing"],
                    isCurrent: subscriptionService.currentTier == .proPlus
                ) {
                    await purchase(AppConstants.SubscriptionProductID.proPlusMonthly)
                }
            }

            Section {
                Button("Restore Purchases") {
                    Task { await subscriptionService.refreshSubscriptionStatus() }
                }
                Link("Terms of Use", destination: URL(string: "https://seddly.com/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://seddly.com/privacy")!)
            }
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentTierRow: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Current Plan")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(tierName)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Spacer()
            Image(systemName: tierIcon)
                .font(.title)
                .foregroundStyle(.accent)
        }
    }

    private var tierName: String {
        switch subscriptionService.currentTier {
        case .free: "Free"
        case .pro: "Pro"
        case .proPlus: "Pro+"
        }
    }

    private var tierIcon: String {
        switch subscriptionService.currentTier {
        case .free: "person.crop.circle"
        case .pro: "star.circle.fill"
        case .proPlus: "crown.fill"
        }
    }

    private func purchase(_ productID: String) async {
        _ = try? await subscriptionService.purchase(productID)
    }
}

private struct SubscriptionTierRow: View {
    let name: String
    let price: String
    let features: [String]
    let isCurrent: Bool
    var onSubscribe: (() async -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.headline)
                Spacer()
                Text(price)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.accent)
            }

            ForEach(features, id: \.self) { feature in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text(feature)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !isCurrent, let onSubscribe {
                Button {
                    Task { await onSubscribe() }
                } label: {
                    Text("Subscribe")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 4)
            }

            if isCurrent {
                Text("Current Plan")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}
