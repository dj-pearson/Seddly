import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var billingPeriod: BillingPeriod = .monthly

    enum BillingPeriod: String, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"
    }

    var body: some View {
        List {
            Section {
                currentTierRow
            }

            Section {
                Picker("Billing", selection: $billingPeriod) {
                    ForEach(BillingPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Section("Plans") {
                SubscriptionTierRow(
                    name: "Free",
                    price: "$0",
                    period: "",
                    savings: nil,
                    features: [
                        "Manual screenshot import via Share Sheet",
                        "5 active commitments",
                        "On-device processing only",
                        "Basic deadline alerts",
                        "30-day history"
                    ],
                    isCurrent: subscriptionService.currentTier == .free
                )

                SubscriptionTierRow(
                    name: "Pro",
                    price: billingPeriod == .monthly ? "$4.99" : "$39.99",
                    period: billingPeriod == .monthly ? "/mo" : "/yr",
                    savings: billingPeriod == .yearly ? "Save 33%" : nil,
                    features: [
                        "Auto-scan Screenshots album",
                        "Unlimited active commitments",
                        "AI-powered commitment extraction",
                        "Full notification suite",
                        "Search & filter",
                        "Entity profiles with fulfillment rates",
                        "1-year history"
                    ],
                    isCurrent: subscriptionService.currentTier == .pro
                ) {
                    let productID = billingPeriod == .monthly
                        ? AppConstants.SubscriptionProductID.proMonthly
                        : AppConstants.SubscriptionProductID.proYearly
                    await purchase(productID)
                }

                SubscriptionTierRow(
                    name: "Pro+",
                    price: billingPeriod == .monthly ? "$9.99" : "$79.99",
                    period: billingPeriod == .monthly ? "/mo" : "/yr",
                    savings: billingPeriod == .yearly ? "Save 33%" : nil,
                    features: [
                        "Everything in Pro",
                        "AI-generated dispute summaries",
                        "PDF export",
                        "iCloud sync across devices",
                        "Unlimited history",
                        "Custom reminder scheduling",
                        "Priority AI processing",
                        "API access"
                    ],
                    isCurrent: subscriptionService.currentTier == .proPlus
                ) {
                    let productID = billingPeriod == .monthly
                        ? AppConstants.SubscriptionProductID.proPlusMonthly
                        : AppConstants.SubscriptionProductID.proPlusYearly
                    await purchase(productID)
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
    let period: String
    let savings: String?
    let features: [String]
    let isCurrent: Bool
    var onSubscribe: (() async -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.headline)
                if let savings {
                    Text(savings)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(price)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.accent)
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
