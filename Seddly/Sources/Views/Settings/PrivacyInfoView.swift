import SwiftUI
import Photos
import SwiftData

struct PrivacyInfoView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var auditEntries: [PrivacyAuditEntry]
    @State private var screenshotCount: Int?
    @State private var accessLevel: String = "Unknown"
    @State private var totalProcessed: Int = 0
    @State private var isLoadingInfo = false
    @State private var loadError = false

    private var totalCharsSent: Int {
        auditEntries.reduce(0) { $0 + $1.textLengthSent }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("Privacy by Architecture")
                        .font(.headline)
                    Text("When you take a screenshot, here's exactly what happens:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // Processing pipeline visual
            Section("How Your Screenshots Are Processed") {
                PipelineStepRow(number: 1, icon: "camera.viewfinder", title: "Screenshot Detected", detail: "Seddly checks your Screenshots album for new images.", location: "On your device")
                PipelineStepRow(number: 2, icon: "text.viewfinder", title: "Text Extracted (OCR)", detail: "Apple Vision framework reads text from the image.", location: "On your device")
                PipelineStepRow(number: 3, icon: "tag", title: "Classified", detail: "On-device classifier determines if it's a conversation, receipt, or irrelevant.", location: "On your device")
                PipelineStepRow(number: 4, icon: "magnifyingglass", title: "Scanned for Commitments", detail: "Rule-based filter checks for promise language, dates, and amounts.", location: "On your device")
                PipelineStepRow(number: 5, icon: "brain", title: "AI Analysis (Pro only)", detail: "Only the extracted text — never the image — is sent for AI commitment extraction.", location: "Cloud (encrypted)")
            }

            Section("What Seddly Can See") {
                if isLoadingInfo {
                    HStack {
                        ProgressView()
                        Text("Loading photo access info...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if loadError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Couldn't load photo access info")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundStyle(.accent)
                        VStack(alignment: .leading) {
                            Text("Screenshots Album Only")
                                .font(.subheadline.weight(.medium))
                            Text("Access level: \(accessLevel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let count = screenshotCount {
                            Text("\(count)")
                                .font(.title3.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("What Stays on Your Device") {
                DataRow(icon: "photo", text: "Your screenshot images", detail: "Never uploaded, never transmitted")
                DataRow(icon: "text.alignleft", text: "Extracted text from OCR", detail: "Stored locally in SwiftData")
                DataRow(icon: "list.bullet.clipboard", text: "Your commitment ledger", detail: "All commitments, entities, notes")
                DataRow(icon: "clock.arrow.circlepath", text: "Processing history", detail: "Which screenshots were scanned and when")
            }

            Section("What Leaves Your Device (Pro Only)") {
                DataRow(icon: "text.bubble", text: "Filtered text snippets", detail: "Only text that passed commitment detection — sent for AI analysis")
                DataRow(icon: "person.slash", text: "No identifiers attached", detail: "No name, email, phone, device ID, or IP logged")
                DataRow(icon: "photo.slash", text: "No images ever transmitted", detail: "Only plain text — no image data, metadata, or EXIF")

                if !auditEntries.isEmpty {
                    HStack {
                        Image(systemName: "chart.bar")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading) {
                            Text("Total data sent off-device")
                                .font(.subheadline)
                            Text("\(auditEntries.count) transmission\(auditEntries.count == 1 ? "" : "s"), \(totalCharsSent) characters total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("What Syncs to Cloud (Pro+ Only)") {
                DataRow(icon: "icloud.and.arrow.up", text: "Commitment data", detail: "Entity names, summaries, deadlines, amounts, status")
                DataRow(icon: "person.badge.key", text: "Account info", detail: "Apple ID identifier and subscription status only")
                DataRow(icon: "xmark.icloud", text: "Never synced", detail: "Screenshots, raw OCR text, processing queue, local preferences")
            }

            Section("What Seddly NEVER Does") {
                NeverRow(text: "Uploads your screenshots")
                NeverRow(text: "Accesses personal photos or videos")
                NeverRow(text: "Reads screenshots in the background without showing you")
                NeverRow(text: "Shares data with third parties")
                NeverRow(text: "Tracks you across apps or websites")
                NeverRow(text: "Requires an account for the free tier")
            }

            Section {
                NavigationLink("Privacy Audit Report") {
                    PrivacyAuditView()
                }
                Button("Manage Photo Access in Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .navigationTitle("How Your Data Works")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPhotoInfo()
        }
    }

    private func loadPhotoInfo() async {
        isLoadingInfo = true

        // Timeout after 15 seconds
        let loadTask = Task {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            switch status {
            case .authorized: accessLevel = "Full (filtered to Screenshots only)"
            case .limited: accessLevel = "Limited (user-selected)"
            case .denied: accessLevel = "Denied"
            case .restricted: accessLevel = "Restricted"
            case .notDetermined: accessLevel = "Not yet requested"
            @unknown default: accessLevel = "Unknown"
            }

            guard status == .authorized || status == .limited else { return }

            guard let album = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .smartAlbumScreenshots,
                options: nil
            ).firstObject else { return }

            screenshotCount = PHAsset.fetchAssets(in: album, options: nil).count

            let descriptor = FetchDescriptor<ProcessingQueue>()
            totalProcessed = (try? modelContext.fetchCount(descriptor)) ?? 0
        }

        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(15))
            if isLoadingInfo {
                loadTask.cancel()
                loadError = true
                isLoadingInfo = false
            }
        }

        await loadTask.value
        timeoutTask.cancel()
        isLoadingInfo = false
    }
}

// MARK: - Subviews

private struct PipelineStepRow: View {
    let number: Int
    let icon: String
    let title: String
    let detail: String
    let location: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(location == "On your device" ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(location == "On your device" ? .green : .blue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(number). \(title)")
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: location == "On your device" ? "iphone" : "cloud")
                        .font(.caption2)
                    Text(location)
                        .font(.caption2)
                }
                .foregroundStyle(location == "On your device" ? .green : .blue)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct DataRow: View {
    let icon: String
    let text: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.subheadline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct NeverRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}
