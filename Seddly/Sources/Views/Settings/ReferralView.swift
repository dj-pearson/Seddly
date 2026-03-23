import SwiftUI

struct ReferralView: View {
    @AppStorage("referralCode") private var referralCode = ""
    @State private var showingShareSheet = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.accent)

                    Text("Give 1 Month, Get 1 Month")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("Share your referral code with a friend. When they subscribe to Pro, you both get 1 month free.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            Section("Your Referral Code") {
                HStack {
                    Text(currentReferralCode)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .textSelection(.enabled)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = currentReferralCode
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }

                ShareLink(
                    item: "Try Seddly — it tracks promises people make to you. Use my code \(currentReferralCode) for a free month of Pro! https://seddly.com",
                    subject: Text("Try Seddly"),
                    message: Text("Use my referral code \(currentReferralCode)")
                ) {
                    Label("Share with a Friend", systemImage: "square.and.arrow.up")
                }
            }

            Section("How It Works") {
                StepRow(number: "1", text: "Share your code with a friend")
                StepRow(number: "2", text: "They download Seddly and enter your code")
                StepRow(number: "3", text: "When they subscribe to Pro, you both get 1 month free")
            }
        }
        .navigationTitle("Refer a Friend")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentReferralCode: String {
        if referralCode.isEmpty {
            let code = generateReferralCode()
            referralCode = code
            return code
        }
        return referralCode
    }

    private func generateReferralCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return "SEDDLY-" + String((0..<6).map { _ in chars.randomElement()! })
    }
}

private struct StepRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.accent)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
        }
    }
}
