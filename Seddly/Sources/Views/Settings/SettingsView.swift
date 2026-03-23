import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
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
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [LocalCommitment.self, LocalEntity.self, ProcessingQueue.self], inMemory: true)
}
