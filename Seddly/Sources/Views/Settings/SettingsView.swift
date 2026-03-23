import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionService.self) private var subscriptionService
    @AppStorage("offlineMode") private var offlineMode = false
    @AppStorage("autoAnalyze") private var autoAnalyze = false
    @AppStorage("approvedExtractionCount") private var approvedExtractionCount = 0
    @State private var showDeleteConfirmation = false
    @State private var notificationsEnabled = true
    @State private var dailyDigestTime = DateComponents(hour: 20, minute: 0)

    var body: some View {
        NavigationStack {
            List {
                Section("Photo Access") {
                    NavigationLink("What Seddly Can See") {
                        PrivacyInfoView()
                    }
                    Button("Manage in Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                if subscriptionService.currentTier >= .pro {
                    Section("AI Processing") {
                        Toggle("Offline Mode", isOn: $offlineMode)
                        Text("All processing stays on your device. Commitment detection may be less accurate.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !offlineMode {
                            Toggle("Auto-analyze screenshots", isOn: $autoAnalyze)
                            if autoAnalyze {
                                Text("Screenshots are sent for AI analysis without asking first.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("You've approved \(approvedExtractionCount) extraction\(approvedExtractionCount == 1 ? "" : "s"). After \(AppConstants.autoApproveAfterCount), you can enable auto-analyze.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Notifications") {
                    Toggle("Deadline Alerts", isOn: $notificationsEnabled)
                    if notificationsEnabled {
                        DatePicker(
                            "Daily Digest Time",
                            selection: Binding(
                                get: {
                                    Calendar.current.date(from: dailyDigestTime) ?? Date.now
                                },
                                set: {
                                    dailyDigestTime = Calendar.current.dateComponents([.hour, .minute], from: $0)
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                }

                Section("Subscription") {
                    NavigationLink("Manage Subscription") {
                        SubscriptionView()
                    }
                }

                Section("Privacy") {
                    NavigationLink("How Your Data Works") {
                        PrivacyInfoView()
                    }
                    Button("Delete All Data", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                }
            }
            .navigationTitle("Settings")
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all commitments, entities, and processing history. This cannot be undone.")
            }
        }
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: LocalCommitment.self)
            try modelContext.delete(model: LocalEntity.self)
            try modelContext.delete(model: ProcessingQueue.self)
            try modelContext.save()
        } catch {
            // Deletion failed — SwiftData will retry on next save
        }

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        approvedExtractionCount = 0
        autoAnalyze = false
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [LocalCommitment.self, LocalEntity.self, ProcessingQueue.self], inMemory: true)
        .environment(SubscriptionService())
}
