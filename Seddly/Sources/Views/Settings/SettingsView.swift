import SwiftUI

struct SettingsView: View {
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
                    Text("Notification preferences")
                }

                Section("Subscription") {
                    Text("Manage subscription")
                }

                Section("Privacy") {
                    NavigationLink("How Your Data Works") {
                        PrivacyInfoView()
                    }
                    Button("Delete All Data", role: .destructive) {
                        // TODO: Implement data deletion
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
