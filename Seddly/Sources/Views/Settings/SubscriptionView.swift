import SwiftUI
import StoreKit

// MARK: - Premium Paywall (US-140)
//
// Redesigned subscription screen that feels like an aspirational showroom:
// hero gradient header, horizontally scrolling feature showcase cards with
// shimmer, annual toggle with savings pill, social proof, and prominent CTAs.

struct SubscriptionView: View {
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var billingPeriod: BillingPeriod = .yearly
    @State private var selectedTier: Tier = .pro
    @State private var isPurchasing: Bool = false

    enum BillingPeriod: String, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"
    }

    enum Tier { case pro, proPlus }

    var body: some View {
        ScrollView {
            VStack(spacing: SeddlySpacing.xxl) {
                heroHeader

                featureShowcase
                    .padding(.top, -SeddlySpacing.xxl)

                billingToggle
                    .padding(.horizontal)

                tierCards
                    .padding(.horizontal)

                socialProof
                    .padding(.horizontal)

                ctaButton
                    .padding(.horizontal)

                footerLinks
                    .padding(.bottom, SeddlySpacing.xxl)
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottom) {
            SeddlyGradient.hero
                .frame(height: 280)
                .clipShape(
                    RoundedRectangle(cornerRadius: SeddlyRadius.sheet, style: .continuous)
                        .offset(y: 0)
                )

            VStack(spacing: SeddlySpacing.md) {
                ProBadge()
                    .padding(.bottom, SeddlySpacing.xs)

                Text("Unlock Your Full Ledger")
                    .font(SeddlyDisplayFont.display)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("AI extraction. Unlimited commitments. Cross-device sync.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SeddlySpacing.xxl)
            }
            .padding(.bottom, SeddlySpacing.xxl + SeddlySpacing.xl)
        }
    }

    // MARK: - Feature Showcase

    private struct Showcase: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let benefit: String
    }

    private let features: [Showcase] = [
        .init(icon: "sparkles", title: "AI Extraction", benefit: "Never miss a promise — Seddly reads your screenshots for you."),
        .init(icon: "infinity", title: "Unlimited Ledger", benefit: "Track as many commitments as life throws at you."),
        .init(icon: "icloud.and.arrow.up", title: "Cloud Sync", benefit: "Stay accountable from iPhone, iPad, and Mac."),
        .init(icon: "bell.badge.fill", title: "Smart Reminders", benefit: "Get nudged at exactly the right moment."),
        .init(icon: "doc.text.magnifyingglass", title: "Dispute Summaries", benefit: "AI-ready timelines when you need to escalate.")
    ]

    private var featureShowcase: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SeddlySpacing.lg) {
                ForEach(features) { f in
                    VStack(alignment: .leading, spacing: SeddlySpacing.md) {
                        ZStack {
                            Circle()
                                .fill(SeddlyGradient.hero)
                                .frame(width: 44, height: 44)
                            Image(systemName: f.icon)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                        }

                        Text(f.title)
                            .font(SeddlyDisplayFont.accent)
                            .foregroundStyle(.primary)

                        Text(f.benefit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .padding(SeddlySpacing.lg)
                    .frame(width: 220, height: 180, alignment: .topLeading)
                    .background(SeddlyAdaptiveColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: SeddlyRadius.large, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: SeddlyRadius.large, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
                    )
                    .seddlyShadow(.card)
                    .proShimmer(speed: 3.2)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Billing Toggle

    private var billingToggle: some View {
        HStack(spacing: 0) {
            ForEach(BillingPeriod.allCases, id: \.self) { period in
                Button {
                    HapticsService.select()
                    withAnimation(SeddlyMotion.snappy) { billingPeriod = period }
                } label: {
                    HStack(spacing: 6) {
                        Text(period.rawValue)
                            .font(.subheadline.weight(.semibold))
                        if period == .yearly {
                            Text("Save 33%")
                                .font(.caption2.weight(.heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(billingPeriod == .yearly ? 0.25 : 0.15))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        billingPeriod == period
                            ? AnyShapeStyle(SeddlyGradient.hero)
                            : AnyShapeStyle(Color.clear)
                    )
                    .foregroundStyle(billingPeriod == period ? .white : .primary)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
    }

    // MARK: - Tier Cards

    private var tierCards: some View {
        VStack(spacing: SeddlySpacing.lg) {
            tierCard(
                tier: .pro,
                name: "Pro",
                price: billingPeriod == .monthly ? "$4.99" : "$39.99",
                period: billingPeriod == .monthly ? "/mo" : "/yr",
                tagline: "For serious accountability",
                highlights: [
                    "Auto-scan Screenshots album",
                    "Unlimited commitments",
                    "AI extraction",
                    "Full notification suite"
                ]
            )

            tierCard(
                tier: .proPlus,
                name: "Pro+",
                price: billingPeriod == .monthly ? "$9.99" : "$79.99",
                period: billingPeriod == .monthly ? "/mo" : "/yr",
                tagline: "Everything in Pro, plus sync & disputes",
                highlights: [
                    "Cross-device sync",
                    "AI dispute summaries",
                    "Unlimited history",
                    "Priority processing"
                ]
            )
        }
    }

    private func tierCard(
        tier: Tier,
        name: String,
        price: String,
        period: String,
        tagline: String,
        highlights: [String]
    ) -> some View {
        let isSelected = selectedTier == tier
        let isCurrent = (tier == .pro && subscriptionService.currentTier == .pro) ||
                        (tier == .proPlus && subscriptionService.currentTier == .proPlus)

        return Button {
            HapticsService.tap()
            withAnimation(SeddlyMotion.snappy) { selectedTier = tier }
        } label: {
            VStack(alignment: .leading, spacing: SeddlySpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(name)
                        .font(SeddlyDisplayFont.accent)
                    if tier == .proPlus {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.25))
                    }
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(price)
                            .font(.title3.weight(.bold))
                        Text(period)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(tagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(highlights, id: \.self) { h in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text(h)
                            .font(.caption)
                    }
                }

                if isCurrent {
                    Text("Current Plan")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }
            .padding(SeddlySpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SeddlyAdaptiveColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: SeddlyRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SeddlyRadius.large, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .seddlyShadow(isSelected ? .elevated : .card)
            .scaleEffect(isSelected ? 1.0 : 0.98)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Social Proof

    private var socialProof: some View {
        VStack(spacing: SeddlySpacing.sm) {
            HStack(spacing: 2) {
                ForEach(0..<5) { _ in
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.25))
                }
                Text("4.9 · 2,400+ reviews")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }

            Text("“Seddly caught a $1,200 refund I would have forgotten. Worth every penny.”")
                .font(.caption.italic())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(SeddlySpacing.lg)
        .frame(maxWidth: .infinity)
        .background(SeddlyAdaptiveColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: SeddlyRadius.large, style: .continuous))
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            Task { await purchaseSelected() }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                }
                Text(selectedTier == .pro ? "Start Pro" : "Start Pro+")
            }
        }
        .buttonStyle(.seddlyPrimary)
        .disabled(isPurchasing)
    }

    private func purchaseSelected() async {
        isPurchasing = true
        defer { isPurchasing = false }
        let productID: String
        switch (selectedTier, billingPeriod) {
        case (.pro, .monthly): productID = AppConstants.SubscriptionProductID.proMonthly
        case (.pro, .yearly): productID = AppConstants.SubscriptionProductID.proYearly
        case (.proPlus, .monthly): productID = AppConstants.SubscriptionProductID.proPlusMonthly
        case (.proPlus, .yearly): productID = AppConstants.SubscriptionProductID.proPlusYearly
        }
        do {
            _ = try await subscriptionService.purchase(productID)
            HapticsService.celebrate()
        } catch {
            HapticsService.error()
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
        VStack(spacing: SeddlySpacing.md) {
            Button("Restore Purchases") {
                Task { await subscriptionService.refreshSubscriptionStatus() }
            }
            .font(.caption)

            HStack(spacing: SeddlySpacing.xl) {
                Link("Terms", destination: URL(string: "https://seddly.com/terms")!)
                Link("Privacy", destination: URL(string: "https://seddly.com/privacy")!)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}
