import SwiftUI
import Photos

struct EmptyLedgerView: View {
    var onAddManually: (() -> Void)?
    var onScanScreenshots: (() -> Void)?

    private var photoAccessDenied: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .denied || status == .restricted
    }

    var body: some View {
        if photoAccessDenied {
            permissionDeniedView
        } else {
            normalEmptyView
        }
    }

    private var hasPhotoAccess: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    @State private var floatOffset: CGFloat = 0
    @State private var glowOpacity: Double = 0.4

    private var normalEmptyView: some View {
        VStack(spacing: SeddlySpacing.xxl) {
            Spacer()

            // Floating hero illustration with animated glow (US-138)
            ZStack {
                Circle()
                    .fill(SeddlyGradient.hero)
                    .frame(width: 180, height: 180)
                    .blur(radius: 40)
                    .opacity(glowOpacity)

                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 140, height: 140)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 62, weight: .light))
                    .foregroundStyle(SeddlyGradient.hero)
                    .symbolRenderingMode(.hierarchical)
                    .offset(y: floatOffset)
            }
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                    floatOffset = -10
                }
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.75
                }
            }

            VStack(spacing: SeddlySpacing.md) {
                Text("Your Ledger Awaits")
                    .font(SeddlyDisplayFont.display)
                    .multilineTextAlignment(.center)

                Text("Capture a screenshot of a promise — Seddly quietly holds people accountable so you don't have to.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SeddlySpacing.xxl)
            }

            VStack(spacing: SeddlySpacing.lg) {
                if hasPhotoAccess, let onScan = onScanScreenshots {
                    Button {
                        HapticsService.tap()
                        onScan()
                    } label: {
                        Label("Scan Existing Screenshots", systemImage: "photo.stack")
                    }
                    .buttonStyle(.seddlyPrimary)
                }

                if let onAddManually {
                    Button {
                        HapticsService.tap()
                        onAddManually()
                    } label: {
                        Label("Add Manually", systemImage: "plus.circle")
                    }
                    .buttonStyle(.seddlySecondary)
                }
            }
            .padding(.horizontal, SeddlySpacing.xxl)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionDeniedView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                Image(systemName: "photo.slash")
                    .font(.system(size: 50))
                    .foregroundStyle(.secondary)

                Text("Screenshot Access Not Granted")
                    .font(.title3.bold())

                Text("Seddly works best when it can scan your Screenshots album, but you can still use it without photo access.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    AlternativeRow(
                        icon: "square.and.arrow.up",
                        title: "Share Sheet",
                        detail: "Share any screenshot directly to Seddly from Photos, Messages, or any app — no photo access needed."
                    )
                    AlternativeRow(
                        icon: "plus.circle",
                        title: "Manual Entry",
                        detail: "Tap + to add commitments by hand — great for verbal promises or phone calls."
                    )
                    AlternativeRow(
                        icon: "doc.on.clipboard",
                        title: "Clipboard",
                        detail: "Copy text from a conversation and Seddly will detect commitments when you open the app."
                    )
                }
                .padding()
                .background(SeddlyColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: SeddlyRadius.medium))

                VStack(spacing: 12) {
                    if let onAddManually {
                        Button {
                            onAddManually()
                        } label: {
                            Text("Add a Commitment")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Grant Screenshot Access in Settings")
                            .frame(maxWidth: .infinity)
                        }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding()
        }
    }
}

private struct AlternativeRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    EmptyLedgerView()
}
