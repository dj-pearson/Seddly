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

    // MARK: - Cinematic Pages (US-142)

    private var welcomePage: some View {
        CinematicPage(
            gradient: SeddlyGradient.hero,
            icon: "checkmark.shield.fill",
            title: "Seddly",
            subtitle: "Hold everyone to their word.",
            bullets: [],
            cta: nextButton
        )
    }

    private var howItWorksPage: some View {
        CinematicPage(
            gradient: LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.36, blue: 0.85),
                    Color(red: 0.52, green: 0.29, blue: 0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            icon: "camera.viewfinder",
            title: "How It Works",
            subtitle: "Three steps to accountability.",
            bullets: [
                ("camera.viewfinder", "Screenshot", "Take a screenshot of any promise or agreement."),
                ("text.viewfinder", "Extract", "AI detects who promised what — automatically."),
                ("bell.badge.fill", "Remind", "Get nudged when deadlines approach or pass.")
            ],
            cta: nextButton
        )
    }

    private var privacyPage: some View {
        CinematicPage(
            gradient: LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.55, blue: 0.42),
                    Color(red: 0.04, green: 0.35, blue: 0.52)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            icon: "lock.shield.fill",
            title: "Privacy, First",
            subtitle: "Your screenshots never leave your device.",
            bullets: [
                ("checkmark.circle.fill", "On-device", "All text extraction happens on your iPhone."),
                ("xmark.circle.fill", "No uploads", "Screenshots are never sent to our servers."),
                ("xmark.circle.fill", "No tracking", "We don't share data with anyone.")
            ],
            cta: nextButton
        )
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
            HapticsService.tap()
            withAnimation(SeddlyMotion.smooth) {
                viewModel.advancePage()
            }
        } label: {
            Text("Continue")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .foregroundStyle(Color.accentColor)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
        }
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

// MARK: - Cinematic Page (US-142)

private struct CinematicPage<CTA: View>: View {
    let gradient: LinearGradient
    let icon: String
    let title: String
    let subtitle: String
    /// (icon, title, description) — rendered as staggered feature rows.
    let bullets: [(String, String, String)]
    let cta: CTA

    @State private var parallax: CGFloat = 0
    @State private var iconScale: CGFloat = 0.6
    @State private var bulletsVisible: Bool = false

    var body: some View {
        ZStack {
            gradient
                .ignoresSafeArea()

            // Soft background orb for depth
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 420, height: 420)
                .offset(x: parallax * 0.3, y: -120 + parallax * 0.2)
                .blur(radius: 40)

            VStack(spacing: SeddlySpacing.xl) {
                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 78, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.4), radius: 20, x: 0, y: 0)
                    .scaleEffect(iconScale)
                    .offset(y: parallax * -0.5)

                VStack(spacing: SeddlySpacing.md) {
                    Text(title)
                        .font(SeddlyDisplayFont.display)
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SeddlySpacing.xxl)
                }

                if !bullets.isEmpty {
                    VStack(alignment: .leading, spacing: SeddlySpacing.lg) {
                        ForEach(Array(bullets.enumerated()), id: \.offset) { idx, b in
                            HStack(alignment: .top, spacing: SeddlySpacing.lg) {
                                Image(systemName: b.0)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(b.1)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(b.2)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                                Spacer()
                            }
                            .opacity(bulletsVisible ? 1 : 0)
                            .offset(y: bulletsVisible ? 0 : 12)
                            .animation(
                                SeddlyMotion.smooth.delay(0.25 + Double(idx) * 0.08),
                                value: bulletsVisible
                            )
                        }
                    }
                    .padding(.horizontal, SeddlySpacing.xxl)
                }

                Spacer()

                cta
                    .padding(.horizontal, SeddlySpacing.xxl)
                    .padding(.bottom, SeddlySpacing.xxl)
            }
        }
        .onAppear {
            withAnimation(SeddlyMotion.celebratory) {
                iconScale = 1.0
            }
            withAnimation(SeddlyMotion.smooth.delay(0.1)) {
                parallax = 1
            }
            bulletsVisible = true
        }
    }
}

#Preview {
    OnboardingView()
}
