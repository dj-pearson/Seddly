import SwiftUI

// MARK: - Semantic Colors

enum SeddlyColors {
    // Status colors
    static let pending = Color.blue
    static let fulfilled = Color.green
    static let overdue = Color.red
    static let disputed = Color.orange
    static let dismissed = Color.gray

    // Confidence levels
    static let confidenceHigh = Color.green
    static let confidenceMedium = Color.yellow
    static let confidenceLow = Color.gray

    // Urgency
    static let urgencyOverdue = Color.red
    static let urgencyApproaching = Color.yellow
    static let urgencySafe = Color.green
    static let urgencyNone = Color.secondary

    // Surfaces
    static let surfaceSecondary = Color(.systemGray6)
    static let customWorkflow = Color.purple

    // Banners
    static let offlineBanner = Color.orange

    /// Returns the semantic color for a commitment status.
    static func status(_ status: CommitmentStatus) -> Color {
        switch status {
        case .pending: pending
        case .fulfilled: fulfilled
        case .overdue: overdue
        case .disputed: disputed
        case .dismissed: dismissed
        }
    }

    /// Returns the semantic color for an urgency level.
    static func urgency(_ level: LocalCommitment.UrgencyLevel) -> Color {
        switch level {
        case .overdue: urgencyOverdue
        case .approaching: urgencyApproaching
        case .safe: urgencySafe
        case .none: urgencyNone
        }
    }

    /// Returns the semantic color for a confidence score (0-10).
    static func confidence(_ score: Int) -> Color {
        switch score {
        case 8...10: confidenceHigh
        case 5...7: confidenceMedium
        default: confidenceLow
        }
    }
}

// MARK: - Spacing

enum SeddlySpacing {
    /// 2pt - Tight vertical spacing (badge padding, date notes)
    static let xxs: CGFloat = 2
    /// 4pt - Small spacing (between related elements, card vertical padding)
    static let xs: CGFloat = 4
    /// 6pt - Card internal spacing
    static let sm: CGFloat = 6
    /// 8pt - Standard component padding
    static let md: CGFloat = 8
    /// 12pt - Section spacing, HStack gaps
    static let lg: CGFloat = 12
    /// 16pt - Screen-edge horizontal padding, banner padding
    static let xl: CGFloat = 16
    /// 24pt - Large section gaps
    static let xxl: CGFloat = 24
}

// MARK: - Corner Radii

enum SeddlyRadius {
    /// 8pt - Screenshots, small containers
    static let small: CGFloat = 8
    /// 12pt - Cards, banners, standard containers
    static let medium: CGFloat = 12
    /// 16pt - Bulk action bars, large containers
    static let large: CGFloat = 16
}

// MARK: - Typography Presets

enum SeddlyFont {
    /// Primary card title: .subheadline.weight(.semibold)
    static let cardTitle = Font.subheadline.weight(.semibold)
    /// Body text: .body
    static let cardBody = Font.body
    /// Supporting info: .caption
    static let supporting = Font.caption
    /// Fine print, badges: .caption2
    static let badge = Font.caption2
    /// Bold badge: .caption2.weight(.bold)
    static let badgeBold = Font.caption2.weight(.bold)
    /// Monospaced text for raw content
    static let monospaced = Font.system(.subheadline, design: .monospaced)
}

// MARK: - Pill/Badge View Modifier

struct SeddlyPillStyle: ViewModifier {
    var horizontalPadding: CGFloat = SeddlySpacing.sm
    var verticalPadding: CGFloat = SeddlySpacing.xxs

    func body(content: Content) -> some View {
        content
            .font(SeddlyFont.badge)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .clipShape(Capsule())
    }
}

extension View {
    /// Applies standard pill/badge styling with capsule shape.
    func seddlyPill(
        horizontalPadding: CGFloat = SeddlySpacing.sm,
        verticalPadding: CGFloat = SeddlySpacing.xxs
    ) -> some View {
        modifier(SeddlyPillStyle(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
        ))
    }
}

// MARK: - Banner View Modifier

struct SeddlyBannerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: SeddlyRadius.medium))
    }
}

extension View {
    /// Applies standard banner styling (padding, material background, rounded corners).
    func seddlyBanner() -> some View {
        modifier(SeddlyBannerStyle())
    }
}

// MARK: - Custom Button Styles (US-110)

/// Primary action button — filled accent background with white text.
struct SeddlyPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, SeddlySpacing.xl)
            .padding(.vertical, SeddlySpacing.lg)
            .frame(maxWidth: .infinity)
            .background(.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: SeddlyRadius.medium))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary action button — bordered with accent tint.
struct SeddlySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .padding(.horizontal, SeddlySpacing.xl)
            .padding(.vertical, SeddlySpacing.lg)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .foregroundStyle(.accent)
            .clipShape(RoundedRectangle(cornerRadius: SeddlyRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: SeddlyRadius.medium)
                    .stroke(.accent.opacity(0.3), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Destructive action button — red tint.
struct SeddlyDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, SeddlySpacing.xl)
            .padding(.vertical, SeddlySpacing.lg)
            .frame(maxWidth: .infinity)
            .background(SeddlyColors.overdue.opacity(0.12))
            .foregroundStyle(SeddlyColors.overdue)
            .clipShape(RoundedRectangle(cornerRadius: SeddlyRadius.medium))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SeddlyPrimaryButtonStyle {
    static var seddlyPrimary: SeddlyPrimaryButtonStyle { SeddlyPrimaryButtonStyle() }
}

extension ButtonStyle where Self == SeddlySecondaryButtonStyle {
    static var seddlySecondary: SeddlySecondaryButtonStyle { SeddlySecondaryButtonStyle() }
}

extension ButtonStyle where Self == SeddlyDestructiveButtonStyle {
    static var seddlyDestructive: SeddlyDestructiveButtonStyle { SeddlyDestructiveButtonStyle() }
}

// MARK: - Card View Modifier

struct SeddlyCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(SeddlySpacing.xl)
            .background(SeddlyColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: SeddlyRadius.medium))
    }
}

extension View {
    /// Applies card styling (padding, surface background, rounded corners).
    func seddlyCard() -> some View {
        modifier(SeddlyCardStyle())
    }
}

// MARK: - Dark Mode Semantic Colors (US-111)

/// Adaptive colors that automatically adjust for light and dark mode.
/// Use these for any color that needs to look good in both appearances.
enum SeddlyAdaptiveColors {
    /// Surface for cards and grouped content — light gray in light mode, dark gray in dark mode.
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    /// Primary surface — white in light mode, near-black in dark mode.
    static let primaryBackground = Color(.systemBackground)
    /// Grouped content background.
    static let groupedBackground = Color(.systemGroupedBackground)
    /// Separator lines.
    static let separator = Color(.separator)
    /// Subtle text on colored backgrounds.
    static let onAccent = Color.white
    /// Status badge background that works in both modes.
    static func statusBackground(_ status: CommitmentStatus) -> Color {
        SeddlyColors.status(status).opacity(0.15)
    }
}
