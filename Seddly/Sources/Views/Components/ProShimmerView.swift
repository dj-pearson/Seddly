import SwiftUI

// MARK: - Pro Shimmer (US-141)
//
// A subtle animated shimmer used to signal premium/locked features. The
// shimmer moves a soft gold highlight across a masked surface, making paid
// features feel valuable rather than just "gated."

/// View modifier that applies a looping gold shimmer overlay.
struct ProShimmer: ViewModifier {
    var active: Bool = true
    var speed: Double = 2.4

    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    if active {
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.0), location: 0.0),
                                .init(color: .white.opacity(0.55), location: 0.5),
                                .init(color: .white.opacity(0.0), location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 1.4)
                        .offset(x: phase * geo.size.width * 1.8)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                    }
                }
                .mask(content)
            )
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

extension View {
    /// Applies a looping gold shimmer — use to signal Pro/premium features.
    func proShimmer(active: Bool = true, speed: Double = 2.4) -> some View {
        modifier(ProShimmer(active: active, speed: speed))
    }
}

/// Small gold "PRO" badge with gradient fill and subtle glow.
struct ProBadge: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.caption2)
            if !compact {
                Text("PRO")
                    .font(.caption2.weight(.heavy))
                    .tracking(0.8)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, 3)
        .background(SeddlyGradient.proShimmer)
        .clipShape(Capsule())
        .shadow(color: Color(red: 0.9, green: 0.7, blue: 0.2).opacity(0.4), radius: 6, x: 0, y: 2)
        .accessibilityLabel("Pro feature")
    }
}

/// Wraps content and gates it behind a Pro lock overlay with shimmer.
struct ProLockWrapper<Content: View>: View {
    let isLocked: Bool
    let content: () -> Content
    var onTap: (() -> Void)? = nil

    init(isLocked: Bool, onTap: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.isLocked = isLocked
        self.onTap = onTap
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content()
                .opacity(isLocked ? 0.55 : 1.0)
                .blur(radius: isLocked ? 0.5 : 0)

            if isLocked {
                ProBadge(compact: true)
                    .padding(6)
                    .proShimmer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isLocked {
                HapticsService.warning()
                onTap?()
            }
        }
        .accessibilityAddTraits(isLocked ? .isButton : [])
        .accessibilityHint(isLocked ? "Pro feature — tap to upgrade" : "")
    }
}

#Preview {
    VStack(spacing: 20) {
        ProBadge()
        ProBadge(compact: true)
        Text("Cloud Sync")
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .proShimmer()
    }
    .padding()
}
