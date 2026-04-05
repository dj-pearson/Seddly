import SwiftUI

// MARK: - Premium Design Tokens (US-135)
//
// Premium tier of the Seddly design system. Extends DesignSystem.swift with
// richer surfaces, gradients, shadows, motion tokens, and expressive typography
// to elevate the app above typical utility-style competitors. Every constant
// here is intentionally tuned so the app feels expensive in the hand without
// crossing into skeuomorphism.

// MARK: - Gradients

enum SeddlyGradient {
    /// Brand hero gradient — used for headers, onboarding, premium CTAs.
    static let hero = LinearGradient(
        colors: [
            Color.accentColor.opacity(0.95),
            Color.accentColor.opacity(0.65),
            Color(red: 0.35, green: 0.20, blue: 0.85).opacity(0.85)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Subtle surface gradient for cards — one-stop darker toward bottom.
    static let cardSurface = LinearGradient(
        colors: [
            Color(.secondarySystemGroupedBackground),
            Color(.secondarySystemGroupedBackground).opacity(0.92)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Gold shimmer for Pro feature locks.
    static let proShimmer = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.78, blue: 0.25),
            Color(red: 1.00, green: 0.90, blue: 0.55),
            Color(red: 0.85, green: 0.62, blue: 0.15)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Returns a subtle gradient tinted by a commitment status color.
    static func status(_ status: CommitmentStatus) -> LinearGradient {
        let base = SeddlyColors.status(status)
        return LinearGradient(
            colors: [base.opacity(0.18), base.opacity(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Shadows (Depth)

struct SeddlyShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    /// Soft ambient shadow used on cards.
    static let card = SeddlyShadow(
        color: Color.black.opacity(0.08),
        radius: 12,
        x: 0,
        y: 4
    )

    /// Raised shadow for active cards, sheets, floating elements.
    static let elevated = SeddlyShadow(
        color: Color.black.opacity(0.14),
        radius: 20,
        x: 0,
        y: 8
    )

    /// Subtle shadow used for pills and buttons.
    static let subtle = SeddlyShadow(
        color: Color.black.opacity(0.05),
        radius: 6,
        x: 0,
        y: 2
    )
}

extension View {
    /// Applies a Seddly depth shadow.
    func seddlyShadow(_ shadow: SeddlyShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Motion (Spring Presets)

enum SeddlyMotion {
    /// Crisp spring — buttons, toggles, tap feedback.
    static let snappy: Animation = .spring(response: 0.28, dampingFraction: 0.72)
    /// Smooth spring — card transitions, sheet reveals.
    static let smooth: Animation = .spring(response: 0.45, dampingFraction: 0.82)
    /// Gentle bounce — celebratory moments (fulfill, new commitment).
    static let celebratory: Animation = .spring(response: 0.55, dampingFraction: 0.65)
    /// Soft ease — banner appearance, background shifts.
    static let easeSoft: Animation = .easeInOut(duration: 0.28)
}

// MARK: - Expressive Typography

enum SeddlyDisplayFont {
    /// Hero numeric display (accountability score, streak count).
    static let hero: Font = .system(size: 48, weight: .bold, design: .rounded)
    /// Large title for headers (Weekly Momentum, etc).
    static let display: Font = .system(.largeTitle, design: .rounded).weight(.bold)
    /// Subtitle headline for section accents.
    static let accent: Font = .system(.headline, design: .rounded).weight(.semibold)
    /// Numeric label with tabular figures for steady counters.
    static let tabularNumber: Font = .system(.title3, design: .rounded).monospacedDigit().weight(.semibold)
}

// MARK: - Premium Card Modifier

struct PremiumCardStyle: ViewModifier {
    var tintGradient: LinearGradient? = nil
    var padding: CGFloat = SeddlySpacing.xl
    var cornerRadius: CGFloat = SeddlyRadius.large
    var shadow: SeddlyShadow = .card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    SeddlyGradient.cardSurface
                    if let tint = tintGradient {
                        tint
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .seddlyShadow(shadow)
    }
}

extension View {
    /// Premium card treatment: subtle gradient, continuous corners, hairline border, soft depth.
    func premiumCard(
        tint: LinearGradient? = nil,
        padding: CGFloat = SeddlySpacing.xl,
        cornerRadius: CGFloat = SeddlyRadius.large,
        shadow: SeddlyShadow = .card
    ) -> some View {
        modifier(PremiumCardStyle(
            tintGradient: tint,
            padding: padding,
            cornerRadius: cornerRadius,
            shadow: shadow
        ))
    }
}

// MARK: - Status Rail (vertical accent bar)

/// Thin gradient rail used as a status accent on cards.
struct StatusRail: View {
    let status: CommitmentStatus
    var width: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: width / 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        SeddlyColors.status(status),
                        SeddlyColors.status(status).opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width)
            .accessibilityHidden(true)
    }
}

// MARK: - Radii additions (premium sizes)

extension SeddlyRadius {
    /// 20pt - Hero cards, feature callouts.
    static let hero: CGFloat = 20
    /// 28pt - Sheet & modal corners on large content.
    static let sheet: CGFloat = 28
}
