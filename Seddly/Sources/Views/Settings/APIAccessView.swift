import SwiftUI
import Security

struct APIAccessView: View {
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var showingToken = false
    @State private var copiedEndpoint = false
    @State private var copiedToken = false

    @AppStorage("isSignedIn", store: UserDefaults(suiteName: AppConstants.appGroupIdentifier)) private var isSignedIn = false

    private var apiToken: String {
        // Read JWT from Keychain if signed in
        guard isSignedIn else { return "Sign in with Apple first" }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pearsonmedia.Seddly.auth",
            kSecAttrAccount as String: "accessToken",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return "Token unavailable — sign in again"
        }
        return "Bearer \(token)"
    }

    private var baseEndpoint: String {
        guard let cfg = AppConfiguration.supabase else {
            return "https://your-project.supabase.co/functions/v1/api-commitments"
        }
        return cfg.url.appendingPathComponent("functions/v1/api-commitments").absoluteString
    }

    var body: some View {
        List {
            if subscriptionService.currentTier < .proPlus {
                Section {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.orange)
                        Text("API access requires a Pro+ subscription.")
                            .font(.subheadline)
                    }
                    NavigationLink("Upgrade to Pro+") {
                        SubscriptionView()
                    }
                }
            } else {
                Section("Endpoint") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(baseEndpoint)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        Button {
                            UIPasteboard.general.string = baseEndpoint
                            copiedEndpoint = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copiedEndpoint = false
                            }
                        } label: {
                            Label(copiedEndpoint ? "Copied!" : "Copy Endpoint", systemImage: copiedEndpoint ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                        }
                    }
                }

                Section("Authentication") {
                    Text("Include your Supabase JWT token in the Authorization header.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        UIPasteboard.general.string = apiToken
                        copiedToken = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedToken = false
                        }
                    } label: {
                        Label(copiedToken ? "Copied!" : "Copy Auth Token", systemImage: copiedToken ? "checkmark" : "key")
                    }
                }

                Section("Available Endpoints") {
                    EndpointRow(method: "GET", path: "/", description: "List commitments. Supports ?status=, ?entity=, ?limit=, ?offset= query params.")
                    EndpointRow(method: "GET", path: "/?id=<uuid>", description: "Get a single commitment by ID.")
                    EndpointRow(method: "POST", path: "/", description: "Create a commitment. Required fields: entity_name, summary.")
                    EndpointRow(method: "PATCH", path: "/", description: "Update a commitment. Required: id in body. Optional: entity_name, summary, status, deadline, dollar_amount, notes.")
                    EndpointRow(method: "DELETE", path: "/?id=<uuid>", description: "Delete a commitment by ID.")
                }

                Section("Example — cURL") {
                    Text(curlExample)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Section("Integrations") {
                    Label("Zapier — Use webhooks with the endpoint above", systemImage: "bolt.fill")
                        .font(.caption)
                    Label("Notion — POST new commitments from Notion databases", systemImage: "doc.fill")
                        .font(.caption)
                    Label("Airtable — Sync commitment status with Airtable scripts", systemImage: "tablecells")
                        .font(.caption)
                }
            }
        }
        .navigationTitle("API Access")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var curlExample: String {
        """
        curl -X GET \\
          '\(baseEndpoint)?status=pending&limit=10' \\
          -H 'Authorization: Bearer YOUR_TOKEN' \\
          -H 'Content-Type: application/json'
        """
    }
}

private struct EndpointRow: View {
    let method: String
    let path: String
    let description: String

    private var methodColor: Color {
        switch method {
        case "GET": .green
        case "POST": .blue
        case "PATCH": .orange
        case "DELETE": .red
        default: .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(method)
                    .font(.caption2.bold().monospaced())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(methodColor.opacity(0.15))
                    .foregroundStyle(methodColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text(path)
                    .font(.caption.monospaced())
            }
            Text(description)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
