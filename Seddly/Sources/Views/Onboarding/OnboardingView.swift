import SwiftUI
import Photos

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var viewModel = OnboardingViewModel()
    @State private var showBackfill = false
    @State private var showAICoach = false

    var body: some View {
        if showAICoach {
            AICoachView {
                if viewModel.photoAuthStatus == .authorized || viewModel.photoAuthStatus == .limited {
                    showAICoach = false
                    showBackfill = true
                } else {
                    hasCompletedOnboarding = true
                }
            }
        } else if showBackfill {
            BackfillView {
                hasCompletedOnboarding = true
            }
        } else {
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 0) {
                    if viewModel.currentPage > 0 {
                        Button {
                            withAnimation { viewModel.currentPage -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                        }
                    } else {
                        Color.clear.frame(width: 24)
                    }

                    Spacer()

                    Text("Step \(viewModel.currentPage + 1) of 5")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Skip") {
                        finishOnboarding()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Step progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * CGFloat(viewModel.currentPage + 1) / 5.0, height: 4)
                            .animation(.easeInOut, value: viewModel.currentPage)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal)

                TabView(selection: $viewModel.currentPage) {
                    welcomePage.tag(0)
                    howItWorksPage.tag(1)
                    privacyPage.tag(2)
                    permissionPage.tag(3)
                    notificationPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.shield")
                .font(.system(size: 80))
                .foregroundStyle(.accent)
            Text("Seddly")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Hold everyone to their word.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
            nextButton
        }
        .padding()
    }

    private var howItWorksPage: some View {
        VStack(spacing: 32) {
            Spacer()
            StepRow(icon: "camera.viewfinder", title: "Screenshot", description: "Take a screenshot of any promise, commitment, or agreement.")
            StepRow(icon: "text.viewfinder", title: "Extract", description: "AI detects who promised what and by when — automatically.")
            StepRow(icon: "bell.badge", title: "Remind", description: "Get notified when deadlines approach or pass.")
            Spacer()
            nextButton
        }
        .padding()
    }

    private var privacyPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            Text("Your Privacy Comes First")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 16) {
                PrivacyRow(icon: "xmark.circle", text: "Never uploads your screenshots", color: .red)
                PrivacyRow(icon: "xmark.circle", text: "Never accesses photos or videos", color: .red)
                PrivacyRow(icon: "xmark.circle", text: "Never shares data with third parties", color: .red)
                PrivacyRow(icon: "checkmark.circle", text: "All text extraction happens on your device", color: .green)
            }

            Spacer()
            nextButton
        }
        .padding()
    }

    private var permissionPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 60))
                .foregroundStyle(.accent)
            Text("Screenshot Access")
                .font(.title2)
                .fontWeight(.bold)
            Text("Seddly only reads your Screenshots album — never your personal photos, videos, or camera roll.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                Task {
                    await viewModel.requestPhotoAccess()
                    withAnimation { viewModel.advancePage() }
                }
            } label: {
                Text("Allow Screenshot Access")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isRequestingPermission)

            Button("Skip for Now") {
                withAnimation { viewModel.advancePage() }
            }
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var notificationPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "bell.badge")
                .font(.system(size: 60))
                .foregroundStyle(.accent)
            Text("Stay on Top of Deadlines")
                .font(.title2)
                .fontWeight(.bold)
            Text("Get notified when deadlines approach and when commitments go overdue.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                Task {
                    await viewModel.requestNotificationAccess()
                    finishOnboarding()
                }
            } label: {
                Text("Enable Notifications & Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Start Without Notifications") {
                finishOnboarding()
            }
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var nextButton: some View {
        Button {
            withAnimation {
                viewModel.advancePage()
            }
        } label: {
            Text("Continue")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func finishOnboarding() {
        if viewModel.photoAuthStatus == .authorized || viewModel.photoAuthStatus == .limited {
            showAICoach = true
        } else {
            hasCompletedOnboarding = true
        }
    }
}

private struct StepRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.accent)
                .frame(width: 44)
            VStack(alignment: .leading) {
                Text(title).fontWeight(.semibold)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PrivacyRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    OnboardingView()
}
