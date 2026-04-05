import SwiftUI

// MARK: - Hero Accountability Header (US-136)
//
// Visible at the top of the Ledger. Celebrates the user's momentum with a
// weekly fulfilled % ring, a streak counter, and a pending count — giving the
// ledger a coach-like feel rather than a database-viewer feel. Tappable to
// expand a weekly sparkline.

struct LedgerHeaderView: View {
    let pendingCount: Int
    let fulfilledThisWeek: Int
    let totalThisWeek: Int
    let streakDays: Int
    /// Daily fulfilled counts for the last 7 days (oldest → newest).
    let weekly: [Int]

    @State private var expanded: Bool = false
    @State private var ringProgress: Double = 0
    @State private var didAnimate: Bool = false

    private var momentum: Double {
        guard totalThisWeek > 0 else { return 0 }
        return Double(fulfilledThisWeek) / Double(totalThisWeek)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SeddlySpacing.lg) {
            HStack(alignment: .center, spacing: SeddlySpacing.xl) {
                MomentumRing(progress: ringProgress)
                    .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Momentum")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .textCase(.uppercase)
                        .tracking(0.8)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int((momentum * 100).rounded()))")
                            .font(SeddlyDisplayFont.hero)
                            .foregroundStyle(.white)
                        Text("%")
                            .font(SeddlyDisplayFont.accent)
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Text("\(fulfilledThisWeek) of \(totalThisWeek) fulfilled this week")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()
            }

            HStack(spacing: SeddlySpacing.md) {
                StatChip(icon: "flame.fill", value: "\(streakDays)", label: streakDays == 1 ? "day streak" : "day streak")
                StatChip(icon: "clock.fill", value: "\(pendingCount)", label: pendingCount == 1 ? "pending" : "pending")
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            if expanded {
                WeeklySparkline(values: weekly)
                    .frame(height: 56)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .padding(SeddlySpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SeddlyGradient.hero)
        .clipShape(RoundedRectangle(cornerRadius: SeddlyRadius.hero, style: .continuous))
        .seddlyShadow(.elevated)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticsService.select()
            withAnimation(SeddlyMotion.smooth) { expanded.toggle() }
        }
        .onAppear {
            guard !didAnimate else { return }
            didAnimate = true
            withAnimation(SeddlyMotion.celebratory.delay(0.1)) {
                ringProgress = momentum
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int((momentum * 100).rounded())) percent momentum. \(pendingCount) pending. \(streakDays) day streak.")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(expanded ? "Tap to collapse weekly chart" : "Tap to expand weekly chart")
    }
}

// MARK: - Momentum Ring

private struct MomentumRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 8)

            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: "bolt.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Stat Chip

private struct StatChip: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.18))
        .clipShape(Capsule())
    }
}

// MARK: - Weekly Sparkline

private struct WeeklySparkline: View {
    let values: [Int]

    var body: some View {
        GeometryReader { geo in
            let maxValue = max(values.max() ?? 0, 1)
            let barWidth = (geo.size.width - CGFloat(max(values.count - 1, 0)) * 6) / CGFloat(max(values.count, 1))

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    let ratio = CGFloat(v) / CGFloat(maxValue)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.85))
                        .frame(width: barWidth, height: max(4, geo.size.height * ratio))
                }
            }
        }
    }
}

#Preview {
    LedgerHeaderView(
        pendingCount: 7,
        fulfilledThisWeek: 4,
        totalThisWeek: 6,
        streakDays: 12,
        weekly: [1, 3, 0, 2, 4, 2, 5]
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
