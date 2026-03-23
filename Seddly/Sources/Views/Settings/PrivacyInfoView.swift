import SwiftUI
import Photos

struct PrivacyInfoView: View {
    @State private var screenshotCount: Int?

    var body: some View {
        List {
            Section("What Seddly Can See") {
                HStack {
                    Image(systemName: "camera.viewfinder")
                    VStack(alignment: .leading) {
                        Text("Screenshots Album")
                        if let count = screenshotCount {
                            Text("\(count) screenshots")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("What Stays on Your Device") {
                InfoRow(icon: "iphone", text: "Your screenshot images")
                InfoRow(icon: "text.alignleft", text: "Extracted text from screenshots")
                InfoRow(icon: "list.bullet", text: "Your commitment ledger")
            }

            Section("What Is Processed in the Cloud") {
                InfoRow(icon: "text.bubble", text: "Text snippets sent for AI analysis (Pro only)")
                Text("No images, metadata, or personal identifiers are ever transmitted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Your Data")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadScreenshotCount()
        }
    }

    private func loadScreenshotCount() async {
        guard let album = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumScreenshots,
            options: nil
        ).firstObject else { return }

        let count = PHAsset.fetchAssets(in: album, options: nil).count
        screenshotCount = count
    }
}

private struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}
