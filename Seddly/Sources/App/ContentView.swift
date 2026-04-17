import SwiftUI
import UIKit

// MARK: - Floating Tab Bar Appearance (US-143)
//
// Applies a premium floating tab bar treatment: translucent material
// background, inset from edges, continuous corners, subtle accent glow.
private enum SeddlyTabBarAppearance {
    static func configure() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.6)
        appearance.shadowColor = .clear

        // Tint selected items with accent color
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.selected.iconColor = UIColor.tintColor
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.tintColor,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]
        itemAppearance.normal.iconColor = UIColor.secondaryLabel
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("selectedTab") private var selectedTab = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(BiometricService.self) private var biometricService
    @State private var clipboardMonitor = ClipboardMonitorService()
    @State private var didRunColdLaunchLockCheck = false

    init() {
        SeddlyTabBarAppearance.configure()
    }

    var body: some View {
        ZStack {
            Group {
                if hasCompletedOnboarding {
                    if horizontalSizeClass == .regular {
                        // iPad: three-column split view
                        TabView(selection: $selectedTab) {
                            IPadLedgerView()
                                .tabItem {
                                    Label("Ledger", systemImage: "list.bullet.clipboard")
                                }
                                .tag(0)

                            SettingsView()
                                .tabItem {
                                    Label("Settings", systemImage: "gear")
                                }
                                .tag(1)
                        }
                    } else {
                        // iPhone: standard tab layout
                        TabView(selection: $selectedTab) {
                            LedgerView()
                                .tabItem {
                                    Label("Ledger", systemImage: "list.bullet.clipboard")
                                }
                                .tag(0)

                            SettingsView()
                                .tabItem {
                                    Label("Settings", systemImage: "gear")
                                }
                                .tag(1)
                        }
                    }
                } else {
                    OnboardingView()
                }
            }
            // US-150: Opaque lock overlay covers the entire app whenever
            // BiometricService.isLocked is true. Prevents screenshot / task
            // switcher leakage of commitment contents.
            if biometricService.isLocked {
                AppLockOverlayView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onChange(of: selectedTab) { _, _ in
            HapticsService.select()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                clipboardMonitor.checkClipboard()
                // US-150: Decide whether to lock whenever the app becomes
                // active. Cold launches always lock (no prior backgrounding
                // timestamp), foreground returns check the inactivity window.
                if biometricService.shouldLockOnForeground() {
                    biometricService.isLocked = true
                }
                didRunColdLaunchLockCheck = true
            } else if newPhase == .background {
                biometricService.markBackgrounded()
            }
        }
        .task {
            // Cold-launch path: scenePhase doesn't fire for the first .active
            // transition, so trigger the lock check once on first appearance.
            if !didRunColdLaunchLockCheck,
               biometricService.shouldLockOnForeground() {
                biometricService.isLocked = true
            }
            didRunColdLaunchLockCheck = true
        }
        .sheet(isPresented: $clipboardMonitor.showClipboardPrompt) {
            if let text = clipboardMonitor.detectedText {
                ClipboardCommitmentView(
                    text: text,
                    confidenceScore: clipboardMonitor.confidenceScore,
                    onDismiss: { clipboardMonitor.dismiss() }
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(BiometricService())
        .modelContainer(for: [LocalCommitment.self, LocalEntity.self, ProcessingQueue.self], inMemory: true)
}

// MARK: - US-150 — App Lock Overlay

/// Full-screen overlay shown when the app is locked awaiting biometric auth.
/// Avoids revealing any commitment content while the user is being prompted.
struct AppLockOverlayView: View {
    @Environment(BiometricService.self) private var biometricService
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: icon)
                    .font(.system(size: 72, weight: .regular))
                    .foregroundStyle(.accent)
                Text("Seddly is locked")
                    .font(.title2.weight(.semibold))
                Text("Authenticate to continue.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await unlock() }
                } label: {
                    Text(isAuthenticating ? "Authenticating…" : "Unlock")
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAuthenticating)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
        .task {
            await unlock()
        }
    }

    private var icon: String {
        switch biometricService.availability() {
        case .available(.faceID):  return "faceid"
        case .available(.touchID): return "touchid"
        case .available(.opticID): return "opticid"
        default:                   return "lock.fill"
        }
    }

    private func unlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }
        do {
            try await biometricService.authenticate(
                reason: "Unlock Seddly to view your commitments."
            )
        } catch BiometricService.AuthError.cancelled {
            // Leave the overlay up; user can retry.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
