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

    private var normalEmptyView: some View {
        ContentUnavailableView {
            Label("No Commitments Yet", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Take a screenshot of a promise someone made, or add one manually.")
        } actions: {
            VStack(spacing: 12) {
                if hasPhotoAccess, let onScan = onScanScreenshots {
                    Button {
                        onScan()
                    } label: {
                        Label("Scan Existing Screenshots", systemImage: "photo.stack")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let onAddManually {
                    Button("Add Manually", action: onAddManually)
                        .buttonStyle(hasPhotoAccess ? .bordered : .borderedProminent)
                }
            }
        }
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
