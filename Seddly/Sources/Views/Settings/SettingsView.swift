import SwiftUI
import SwiftData
import AuthenticationServices

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(\.authService) private var authService
    private static let appGroupDefaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
    @AppStorage("offlineMode", store: appGroupDefaults) private var offlineMode = false
    @AppStorage("autoAnalyze", store: appGroupDefaults) private var autoAnalyze = false
    @AppStorage("approvedExtractionCount", store: appGroupDefaults) private var approvedExtractionCount = 0
    @AppStorage("isSignedIn", store: appGroupDefaults) private var isSignedIn = false
    @AppStorage("signedInEmail", store: appGroupDefaults) private var signedInEmail = ""
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    @AppStorage("notificationsEnabled", store: appGroupDefaults) private var notificationsEnabled = true
    @State private var dailyDigestTime = DateComponents(hour: 20, minute: 0)
    @State private var signInError: String?

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
                                .disabled(approvedExtractionCount < AppConstants.autoApproveAfterCount && !autoAnalyze)
                            if autoAnalyze {
                                Text("Screenshots are sent for AI analysis without review. Medium-confidence items are added directly to your ledger.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if approvedExtractionCount >= AppConstants.autoApproveAfterCount {
                                Text("You've approved \(approvedExtractionCount) extractions — auto-analyze is now available!")
                                    .font(.caption)
                                    .foregroundStyle(.accent)
                            } else {
                                Text("You've approved \(approvedExtractionCount) of \(AppConstants.autoApproveAfterCount) extractions needed to unlock auto-analyze.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Notifications") {
                    Toggle("Deadline Alerts", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, enabled in
                            if !enabled {
                                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                            }
                        }
                    if notificationsEnabled {
                        DatePicker(
                            "Daily Digest Time",
                            selection: Binding(
                                get: {
                                    Calendar.current.date(from: dailyDigestTime) ?? Date.now
                                },
                                set: {
                                    dailyDigestTime = Calendar.current.dateComponents([.hour, .minute], from: $0)
                                    // Persist for background/foreground digest scheduling
                                    let components = Calendar.current.dateComponents([.hour, .minute], from: $0)
                                    (UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard).set(
                                        ["hour": components.hour ?? 20, "minute": components.minute ?? 0],
                                        forKey: "dailyDigestTime"
                                    )
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
                    NavigationLink("Refer a Friend") {
                        ReferralView()
                    }

                    if subscriptionService.currentTier == .proPlus {
                        if isSignedIn {
                            LabeledContent("Account", value: signedInEmail.isEmpty ? "Signed In" : signedInEmail)
                        } else {
                            SignInWithAppleButton(.signIn) { request in
                                request.requestedScopes = [.email]
                            } onCompletion: { result in
                                handleAppleSignIn(result)
                            }
                            .signInWithAppleButtonStyle(.black)
                            .frame(height: 44)

                            if let signInError {
                                Text(signInError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                Section("Data") {
                    NavigationLink("Export Data") {
                        DataExportView()
                    }
                    NavigationLink("Merge Duplicate Entities") {
                        EntityMergeView()
                    }
                    NavigationLink("Custom Workflows") {
                        WorkflowManagementView()
                    }
                    NavigationLink("API Access") {
                        APIAccessView()
                    }
                }

                Section("Privacy") {
                    NavigationLink("How Your Data Works") {
                        PrivacyInfoView()
                    }
                    NavigationLink("Privacy Audit Report") {
                        PrivacyAuditView()
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
                    Task {
                        await deleteAllData()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if isSignedIn {
                    Text("This will permanently delete all local data AND your server-side account, commitments, and sync history. This cannot be undone.")
                } else {
                    Text("This will permanently delete all commitments, entities, and processing history. This cannot be undone.")
                }
            }
            .alert("Deletion Error", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteErrorMessage)
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                signedInEmail = credential.email ?? ""
                signInError = nil

                Task {
                    do {
                        try await authService.signInWithApple(credential: credential)
                        isSignedIn = true
                    } catch {
                        signInError = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            signInError = error.localizedDescription
        }
    }

    private func deleteAllData() async {
        // For Pro+ signed-in users, delete server-side data first
        if isSignedIn {
            isDeletingAccount = true
            do {
                try await deleteServerAccount()
            } catch {
                isDeletingAccount = false
                deleteErrorMessage = "Failed to delete server data: \(error.localizedDescription). Local data was not deleted."
                showDeleteError = true
                return
            }
            isDeletingAccount = false
        }

        // Delete local data
        do {
            try modelContext.delete(model: LocalCommitment.self)
            try modelContext.delete(model: LocalEntity.self)
            try modelContext.delete(model: ProcessingQueue.self)
            try modelContext.delete(model: PrivacyAuditEntry.self)
            try modelContext.delete(model: CustomWorkflow.self)
            try modelContext.save()
        } catch {
            AppLogger.general.error("Local data deletion failed: \(error.localizedDescription)")
        }

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        approvedExtractionCount = 0
        autoAnalyze = false

        // Sign out after deletion
        if isSignedIn {
            await authService.signOut()
            isSignedIn = false
            signedInEmail = ""
        }
    }

    private func deleteServerAccount() async throws {
        guard let token = await authService.validAccessToken() else {
            throw URLError(.userAuthenticationRequired)
        }

        guard let cfg = AppConfiguration.supabase else {
            throw URLError(.badURL)
        }
        let url = cfg.url.appendingPathComponent("functions/v1/delete-account")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            AppLogger.auth.error("Server account deletion failed: status \(statusCode), body: \(body)")
            throw URLError(.cannotConnectToHost)
        }

        AppLogger.auth.info("Auth event: account_deleted — server data removed")
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [LocalCommitment.self, LocalEntity.self, ProcessingQueue.self], inMemory: true)
        .environment(SubscriptionService())
}
